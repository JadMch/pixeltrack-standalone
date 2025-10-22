#
#Original Author: Felice Pantaleo, CERN
#
#
##define NTUPLE_DEBUG



import CAConstants
import cms
import gpuPixelDoublets
from sys import is_defined

alias HitToTuple = CAConstants.HitToTuple
alias TupleMultiplicity = CAConstants.TupleMultiplicity

alias Quality = pixelTrack.Quality
alias TkSoA = pixelTrack.TrackSoA
alias HitContainer = pixelTrack.HitContainer

fn Kernel_checkOverflows(
    foundNtuplets: UnsafePointer[HitContainer],
    tupleMultiplicity: UnsafePointer[TupleMultiplicity],
    apc: UnsafePointer[cms.cuda.AtomicPairCounter],
    cells: UnsafePointer[GPUCACell],  # __restrict__ dropped
    nCells: UnsafePointer[UInt32],    # uint32_t const*
    cellNeighbors: UnsafePointer[gpuPixelDoublets.CellNeighborsVector],
    cellTracks: UnsafePointer[gpuPixelDoublets.CellTracksVector],
    isOuterHitOfCell: UnsafePointer[GPUCACell.OuterHitOfCell],
    nHits: UInt32,
    maxNumberOfDoublets: UInt32,
    counters: UnsafePointer[CAHitNtupletGeneratorKernelsCPU.Counters]
    ):


    var first: UInt32 = 0
    
    ref c = counters[]
    if first == 0 :
        Atomic.fetch_add[ordering = Consistency.SEQUENTIAL](UnsafePointer(to=c.nEvents), 1)  
        Atomic.fetch_add[ordering = Consistency.SEQUENTIAL](UnsafePointer(to=c.nHits),nHits)
        Atomic.fetch_add[ordering = Consistency.SEQUENTIAL](UnsafePointer(to=c.Cells),UnsafePointer[nCells] )
        Atomic.fetch_add[ordering = Consistency.SEQUENTIAL](UnsafePointer(to=c.nTuples),apc[][].m )
        Atomic.fetch_add[ordering = Consistency.SEQUENTIAL](UnsafePointer(to=c.nFitTracks),tupleMultiplicity[].size())

    @parameter
    if is_defined["NTUPLE_DEBUG"]():
        if first == 0:
            print("number of found cells", nCells, 
                  "found tuples", apc[][].m, 
                  "with total hits", apc[][].n, 
                  "out of", nHits)
            if apc[][].m < CAConstants.maxNumberOfQuadruplets():
                debug_assert(foundNtuplets[].size(apc[][].m) == 0, "Expected size 0")
                debug_assert(foundNtuplets[].size() == apc[][].n, "Size mismatch")
    @parameter
    if is_defined["NTUPLE_DEBUG"]():
        for idx in range(first , foundNtuplets[].nbins() , 1):
            if foundNtuplets[].size() > 5:
                print("ERROR" , idx , ", " , foundNtuplets[].size(idx))
            debug_assert(foundNtuplets[].size(idx) < 6)

            var ih = foundNtuplets[].begin(idx)
            var end = foundNtuplets[].end(idx)
            while ih != end:
                debug_assert(ih[] < nHits)
                ih+=1
    if (0 == first):
        if (apc[][].m >= CAConstants.maxNumberOfQuadruplets()):
          print("Tuples overflow\n")
        if (nCells[] >= maxNumberOfDoublets):
          print("Cells overflow\n")
        if (cellNeighbors and cellNeighbors[].full()):
          print("cellNeighbors overflow\n")
        if (cellTracks and cellTracks[].full()):
          print("cellTracks overflow\n")

    var idx : Int = first 
    var nt = nCells[]

    while idx  < nt:
        ref thisCell = (cells + idx)[]
        if (thisCell.outerNeighbors().full()) : #++tooManyNeighbors[thisCell.theLayerPairId]
          print("OuterNeighbors overflow ",idx , "in \n", thisCell.theLayerPairId)
        if (thisCell.tracks().full()) : #++tooManyTracks[thisCell.theLayerPairId]
          print("Tracks overflow " , idx , " in \n", thisCell.theLayerPairId)
        if (thisCell.theDoubletId < 0):
          Atomic.fetch_add[ordering = Consistency.SEQUENTIAL](UnsafePointer(to=c.nKilledCells), 1)
        if (0 == thisCell.theUsed):
          Atomic.fetch_add[ordering = Consistency.SEQUENTIAL](UnsafePointer(to=c.nEmptyCells), 1)
        if (thisCell.tracks().empty()):
          Atomic.fetch_add[ordering = Consistency.SEQUENTIAL](UnsafePointer(to=c.nZeroTrackCells), 1)
        idx+=1
        
  
    idx = first
    nt = nHits

    while idx < nt :
        if isOuterHitOfCell[idx].full():
            print("OuterHitOfCell ovberflow " , idx , "\n")

        idx+=1
        

fn kernel_fishboneCleaner():
    var bad = trackQuality.bad
    var first : UInt32 = 0
    var idx : Int = first 
    var nt = nCells[]
    while idx  < nt:
        ref thisCell = (cells + idx)[]
        if thisCell.theDoubletId >= 0:
            continue
        
        for var it : thisCell.tracks():
            quality[it] = bad
        idx+=1
        

fn kernel_earlyDuplicateRemover(
    cells: UnsafePointer[GPUCACell],
    nCells: UnsafePointer[UInt32],
    foundNtuplets: UnsafePointer[HitContainer],
    quality: UnsafePointer[Quality]
    ):

            var dup = trackQuality.dup

            assert nCells != 0
            var first : UInt32= 0
            var idx : Int = first
            nt = nCells[]
            while idx < nt:
                ref thisCell = (cells + idx)[]
                
                if thisCell.tracks().size() < 2 : 
                    continue
                
                var maxNh : UInt32= 0

                for var it in thisCell.tracks():
                    var nh = foundNtuplets[].size(it)
                    maxNh = math.max(nh , maxNh)
                
                for var it in thisCell.tracks():
                    if foundNtuplets[].size(it) != maxNh:
                        quality[it] = dup
                idx+=1
               

fn kernel_fastDuplicateRemover( cells : UnsafePointer[GPUCACell], 
                                 nCells : UnsafePointer[UInt32],
                                 foundNtuplets : UnsafePointer[HitContainer],
                                 tracks : UnsafePointer[TkSoA]) :
    var bad = trackQuality.bad
    var dup = trackQuality.dup
    var loose = trackQuality.loose

    assert nCells != 0

    var first :UInt32 = 0
    while idx  < nt:
        ref thisCell = (cells + idx)[]
        if thisCell.tracks().size() < 2 : 
            continue

        var mc: Float32 = 10000.0
        var im :UInt16= 60000

        fn score(it):
            return math.abs(tracks[].tip(it)) # tip
            # or chi2
        #find min socre
        for var it in thisCell.tracks():
            if tracks[].quality(it) == loose and score(it) < mc :
                mc = score(it)
                im = it 
        #mark all other duplicates
        for var it in thisCell.tracks():
            if tracks[].quality(it) != bad and it != im:
                tracks[].quality(it) = dup # no race:  simple assignment of the same constant
        var score = 
        idx+=1
        
                

fn kernel_connect(
            apc1: UnsafePointer[cms.cuda.AtomicPairCounter],
            apc2: UnsafePointer[cms.cuda.AtomicPairCounter],  # just to zero them
            hhp: UnsafePointer[GPUCACell.Hits],              
            cells: UnsafePointer[GPUCACell],
            nCells: UnsafePointer[UInt32],
            cellNeighbors: UnsafePointer[gpuPixelDoublets.CellNeighborsVector],
            isOuterHitOfCell: UnsafePointer[GPUCACell.OuterHitOfCell],
            hardCurvCut: Float32,
            ptmin: Float32,
            CAThetaCutBarrel: Float32,
            CAThetaCutForward: Float32,
            dcaCutInnerTriplet: Float32,
            dcaCutOuterTriplet: Float32
        ):
    ref hh = hhp[]
    
    var firstCellIndex = 0 + 0 * 1
    var first :UInt32= 0
    var stride  =1

    if(0 == (firstCellIndex + first)):
        apc1[] = 0
        apc2[] = 0

    var idx : Int = firstCellIndex 
    var nt = nCells[]
    #loop on outer cells
    while idx < nt:
        var cellIndex  =idx
        ref thisCell  = (cells + idx)[]

        var innerHitId = thisCell.get_inner_hit_id()
        var numberOfPossibleNeighbors : Int = isOuterHitOfCell[innerHitId].size()
        var vi = isOuterHitOfCell[innerHitId].data()

        var last_bpix11_detIndex :UInt32= 96
        var last_barrel_detIndex :UInt32 = 1184
        var ri = thisCell.get_inner_r(hh)
        var zi = thisCell.get_inner_z(hh)

        var ro = thisCell.get_outer_r(hh)
        var zo = thisCell.get_outer_z(hh)
        var isBarrel = thisCell.get_inner_detIndex(hh) < last_barrel_detIndex
        #loop on inner cells
        for j in range(first , numberOfPossibleNeighbors , stride):
            var otherCell = vi[j]
            var oc = cells[otherCell]

            var r1 = oc.get_inner_r(hh)
            var z1 = oc.get_inner_z(hh)
            
            var aligned : Bool = GPUCACell.areAlignedRZ(
                r1,
                z1,
                ri,
                zi,
                ro,
                zo,
                ptmin,
                CAThetaCutBarrel if isBarrel else  CAThetaCutForward
            )
            if aligned and thisCell.dcaCut(hh ,oc,  dcaCutInnerTriplet if oc.get_inner_detIndex(hh)< last_bpix1_detIndex  else  dcaCutOuterTriplet,
            hardCurvCut):
                oc.addOuterNeighbor(cellIndex , cellNeighbors[])
                thisCell.theUsed |= 1
                oc.theUsed |= 1
        idx += 1

fn kernel_find_ntuplets(
    hpp : UnsafePointer[GPUCACell.Hits],
    cells : UnsafePointer[GPUCACell],
    nCells : UnsafePointer[UInt32],
    cellTracks : UnsafePointer[gpuPixelDoublets.CellTracksVector],
    foundNtuplets : UnsafePointer[HitContainer],
    apc : UnsafePointer[cms.cuda.AtomicPairCounter],
    quality : UnsafePointer[Quality],
    minHitsPerNtuplet : UInt32
    ):

    ref hh = hhp[]

    var first : UInt32 = 0
    var idx : Int = first
    var nt  = nCells[]
    while idx < nt :
        ref thisCell =  (cells + idx)[]
        if thisCell.theDoubletId < 0 :
            continue

        var pid = thisCell.theLayerPairId
        var doit : Bool =  pid < 3 if minHitsPerNtuplet >3 else  pid < 8 or pid > 12
        if(doit):
            GPUCACell.TmpTuple stack
            stack.rest()
            thisCell.find_ntuplets[6](
                hh, cells, cellTracks[], foundNtuplets[], apc[], quality, stack, minHitsPerNtuplet, pid < 3
                )
            
        assert stack.empty()
        idx+=1

fn kernel_mark_used(hhp : UnsafePointer[Hits] , cells : UnsafePointer[GPUCACell] , nCells :UnsafePointer[UInt32]):
    
    var first : UInt32 = 0
    var idx : Int = first
    var nt  = nCells[]
    while idx < nt :
        ref thisCell = (cells + idx)[]
        if not thisCell.tracks().empty():
            thisCell.theUsed |= 2

fn kernel_countMultiplicity(  foundNtuplets : UnsafePointer[HitContainer],
                              quality : UnsafePointer[Quality],
                              tupleMultiplicity : UnsafePointer[CAConstants.TupleMultiplicity ]):
    var first = 0
    for it in range(first , foundNtuplets[].nbins() , 1):
        var nhits = foundNtuplets[].size(it)
        if nhits < 3 :
            continue
        if (quality + it)[] == trackQuality.dup:
            continue
        assert (quality + it)[] == trackQuality.bad
        if nhits  >5 :
            print("wrong mult " , it , " " , nhits , "\n")
        assert nhits < 8
        tupleMultiplicity[].countDirect(nhits)

fn kernel_fillMultiplicity(foundNtuplets : UnsafePointer[HitContainer],
                              quality : UnsafePointer[Quality],
                              tupleMultiplicity : UnsafePointer[CAConstants.TupleMultiplicity ]):
    var first  = 0 
    for it in range(first , foundNtuplets[].nbins() , 1):
        var nhits = foundNtuplets[].size(it)
        if nhits < 3 :
            continue
        if (quality + it)[] == trackQuality.dup
            continue
        assert (quality + it)[] == trackQuality.bad 
        if nhits > 5:
            print("wrong mult " , it , " " , nhits , "\n")
        assert nhits < 8
        tupleMultiplicity[].fillDirect(nhits, it)

fn kernel_classifyTracks(tuples : UnsafePointer[HitContainer] , tracks UnsafePointer[TkSoA] , cuts : CAHitNtupletGeneratorKernelsCPU.QualityCuts , quality : UnsafePointer[Quality]):
    var first : Int = 0
    for it in range(first , tuples[].nbins , 1):
        var nhits = tuples[].size(it)
        if nhits == 0:
            break # guard
        
        #id duplicate : not even fit 
        if (quality + it)[] == trackQuality.dup:
            continue

        assert (quality + it)[] == trackQuality.bad 

        #mark doublets as bad 
        if nhits < 3:
            continue

        #if the fit has my invalid parameters , mark it as bad
        var isNaN : Bool= false 
        for i in range(0 , 5, 1):
            isNaN = isNaN or math.isnan(tracks[].stateAtBS.state(it)[i])

        if isNaN:
            @parameter
            if is_defined["NTUPLE_DEBUG"]():
                print("NaN in fit " , it , " size " , tuples[].size(it)," chi2 \n" , tracks[].chi2(it))
            continue
        # compute a pT-dependent chi2 cut
        # default parameters:
        #   - chi2MaxPt = 10 GeV
        #   - chi2Coeff = { 0.68177776, 0.74609577, -0.08035491, 0.00315399 }
        #   - chi2Scale = 30 for broken line fit, 45 for Riemann fit
        # (see CAHitNtupletGeneratorGPU.cc)
        var pt : Float32 = math.min(tracks[].pt(it) , cuts.chi2MaxPt)
        var chi2Cut :Float32= cuts.chi2Scale * (cuts.chi2Coeff[0] + pt * (cuts.chi2Coeff[1] + pt * (cuts.chi2Coeff[2] + pt * cuts.chi2Coeff[3])))
        # above number were for Quads not normalized so for the time being just multiple by ndof for Quads  (triplets to be understood)
        if 3.0 * tracks[].chi2(it) >= chi2Cut:
            @parameter
            if is_defined["NTUPLE_DEBUG"]():
                print("Bad fit " , it, " size " , tuples[].size(it) , " pt " , tracks[].pt(it), " eta " , tracks[].eta(it) , " chi2 " , 3.0 * tracks[].chi2(it))
            continue
        # impose "region cuts" based on the fit results (phi, Tip, pt, cotan(theta)), Zip)
        # default cuts:
        #   - for triplets:    |Tip| < 0.3 cm, pT > 0.5 GeV, |Zip| < 12.0 cm
        #   - for quadruplets: |Tip| < 0.5 cm, pT > 0.3 GeV, |Zip| < 12.0 cm
        # (see CAHitNtupletGeneratorGPU.cc)  
        ref region = cuts.quadruplet if (nhits > 3)  else  cuts.triplet
        var isOk : Bool = (math.abs(tracks[].tip(it)) < region.maxTip) and  (tracks[].pt(it) > region.minPt) and (math.abs(tracks[].zip(it) < region.maxZip))

        if isOk:
            (quality + it)[] = trackQuality.loose

fn kernel_doStatsForTracks(tuples  : UnsafePointer[HitContainer] , 
                           quality : UnsafePointer[Quality] , 
                           counters : UnsafePointer[CAHitNtupletGeneratorKernelsCPU.Counters] ):
    var first : Int = 0 
    for idx in range(first , tuples[].nbins() , 1):
        if tuples[].size(idx) == 0 :
            break # guard
        if (quality + idx)[]  != trackQuality.loose:
            continue
        Atomic.fetch_add[ordering = Consistency.SEQUENTIAL](UnsafePointer(to=(counters[].nGoodTracks)) , 1)


fn kernel_countHitInTracks(tuples  : UnsafePointer[HitContainer] , 
                           quality : UnsafePointer[Quality] , 
                           hitToTuple : UnsafePointer[CAHitNtupletGeneratorKernelsCPU.HitToTuple] ):
    var first : Int = 0 
    for idx in range(first , tuples[].nbins() , 1):
        if tuples[].size(idx) == 0 :
            break # guard
        if (quality + idx)[]  != trackQuality.loose:
            continue
        var h  = tuples[].begin(idx)
        while h != tuples[].end(idx):
            hitToTuple[].countDirect(h[])
            h+=1

fn kernel_fillHitInTracks(tuples  : UnsafePointer[HitContainer] , 
                           quality : UnsafePointer[Quality] , 
                           hitToTuple : UnsafePointer[CAHitNtupletGeneratorKernelsCPU.HitToTuple] ):
    var first : Int = 0 

    for idx in range(first , tuples[].nbins() , 1):
        if tuples[].size(idx) == 0:
            break #guard
        if (quality + idx)[] != trackQuality.loose:
            continue
        var h  = tuples[].begin(idx)
        while h != tuples[].end(idx):
            hitToTuple[].fillDirect(h[] , idx)
            h+=1

fn kernel_fillHitDetIndices(tuples  : UnsafePointer[HitContainer] , 
                           hpp : UnsafePointer[TrackingRecHit2DSOAView] , 
                           hitDetIndices : UnsafePointer[HitContainer] ):
    var first : Int = 0
    # copy offsets
    for idx in range(first , tuples[].totbins() , 1):
        hitDetIndices[].off[idx] = tuples.off[idx]
    # fill hit indices
    ref hh = hhp[]
    var nhits = hh.nHits()
    for idx in range(first , tuples[].size() , 1):
        assert tuples[].bins[idx] < nhits
        hitDetIndices[].bins[idx] = hh.detectorIndex(tuples[].bins[idx])

fn kernel_doStatsForHitInTracks(hitToTuple: UnsafePointer[CAHitNtupletGeneratorKernelsCPU.HitToTuple] ,counters :  UnsafePointer[CAHitNtupletGeneratorKernelsCPU.Counters]):
    ref c = counters[]
    var first : Int = 0 
    for idx in range(first , hitToTuple[].nbins() , 1):
        if(hitToTuple[].size(idx) == 0 ):
            continue # SHALL NOT BE break
        Atomic.fetch_add[ordering = Consistency.SEQUENTIAL](UnsafePointer(to=c.nUsedHits) , 1)
        if hitToTuple[].size(idx) > 1 :
            Atomic.fetch_add[ordering = Consistency.SEQUENTIAL](UnsafePointer(to=c.nDupHits) , 1)

fn kernel_tripletCleaner(hhp : UnsafePointer[TrackingRecHit2DSOAView] , ptuples : UnsafePointer[HitContainer] , ptracks : UnsafePointer[TkSoA] , quality : UnsafePointer[Quality] , phitToTuple : UnsafePointer[CAHitNtupletGeneratorKernelsCPU.HitToTuple]):
    var bad  = trackQuality.bad
    var dup  = trackQuality.dup

    ref hitToTuple = phitToTuple[]
    ref foundNtuplets = ptuples[]
    ref tracks = ptracks[]

    var first : Int = 0 
    # loop over hits
    for idx in range(first , hitToTuple.nbins() , 1):
        if hitToTuple.size(idx) < 2:
            continue
        
        var mc : Float32 = 10000.0
        var im : UInt16 = 60000
        var maxNh : UInt32 = 0

        # find maxNh 
        var it = hitToTuple.begin(idx)
        while(it != hitToTuple.end(idx)):
            var nh : UInt32 = foundNtuplets.size(it[])
            maxNh = math.max(nh , maxNh)
            it+=1
        
        # kill all tracks shorter than maxHn (only triplets???)
        it = hitToTuple.begin(idx)
        while(it != hitToTuple.end(idx)):
            var nh :UInt32= foundNtuplets.size(it[])
            if maxNh != nh:
                (quality + it[])[] = dup
            it += 1

        if maxNh > 3:
            continue

        # for triplets choose best tip!
        var ip = hitToTuple.begin(idx)
        while ip != hitToTuple.end(idx):
            it = ip[]
            if (quality + it)[] != bad and it != im :
                (quality + it)[] = dup # no race:  simple assignment of the same constant
            ip+=1


fn kernel_print_found_ntuplets(hhp : UnsafePointer[TrackingRecHit2DSOAView] , ptuples : UnsafePointer[HitContainer] , ptracks : UnsafePointer[TkSoA] , quality : UnsafePointer[Quality] , phitToTuple : UnsafePointer[CAHitNtupletGeneratorKernelsCPU.HitToTuple] ,  maxPrint : UInt32  ,  iev : Int):
    ref foundNtuplets = ptuples[]
    ref tracks = ptracks[]

    var first : Int = 0 

    var i : Int = first
    while i < math.min(maxPrint, foundNtuplets.nbins()):
        var nh = foundNtuplets.size(i)
        if nh < 3 : 
            continue
        print(
            "TK: {} {} {} {} {} {} {} {} {} {} {} {} {} {} {}",
            10000 * iev + i,
            Int((quality + i)[]),
            nh,
            tracks.charge(i),
            tracks.pt(i),
            tracks.eta(i),
            tracks.phi(i),
            tracks.tip(i),
            tracks.zip(i),
            tracks.chi2(i),
            (foundNtuplets.begin(i))[],
            (foundNtuplets.begin(i) + 1)[],
            (foundNtuplets.begin(i) + 2)[],
            Int((foundNtuplets.begin(i) + 3)[]) if nh > 3 else -1,
            Int((foundNtuplets.begin(i) + 4)[]) if nh > 4 else -1
        )
        i+=1

fn kernel_printCounters(counters : UnsafePointer[cAHitNtupletGenerator.Counters]):
    ref c = counters[]
    print("||Counters | nEvents | nHits | nCells | nTuples | nFitTacks  |  nGoodTracks | nUsedHits | nDupHits | "
      "nKilledCells | "
      "nEmptyCells | nZeroTrackCells ||\n")
    print("Counters Raw {} {} {} {} {} {} {} {} {} {} {}\n",
         c.nEvents,
         c.nHits,
         c.nCells,
         c.nTuples,
         c.nGoodTracks,
         c.nFitTracks,
         c.nUsedHits,
         c.nDupHits,
         c.nKilledCells,
         c.nEmptyCells,
         c.nZeroTrackCells)
    printf("Counters Norm {} ||  {}|  {}|  {}|  {}|  {}|  {}|  {}|  {}|  {}|  {}||\n",
         c.nEvents,
         c.nHits / double(c.nEvents),
         c.nCells / double(c.nEvents),
         c.nTuples / double(c.nEvents),
         c.nFitTracks / double(c.nEvents),
         c.nGoodTracks / double(c.nEvents),
         c.nUsedHits / double(c.nEvents),
         c.nDupHits / double(c.nEvents),
         c.nKilledCells / double(c.nEvents),
         c.nEmptyCells / double(c.nCells),
         c.nZeroTrackCells / double(c.nCells));