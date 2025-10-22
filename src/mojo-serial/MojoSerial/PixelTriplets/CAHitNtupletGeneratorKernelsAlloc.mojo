
use hip.stream.Stream
use cms.cude.AtomicPairCounter
use cms.cuda.launchZero

impl CAHitNtupletGeneratorKernels[CPUTraits]:
    fn allocate_on_gpu(self, stream: Stream):
        #//////////////////////////////////////////////////////////
        #// ALLOCATIONS FOR THE INTERMEDIATE RESULTS (STAYS ON WORKER)
        #//////////////////////////////////////////////////////////
        
        var device_theCellNeighbors_ = CPUTraits.make_unique[CAConstants.CellNeighborsVector](stream)
        var device_theCellTracks_ = CPUTraits.make_unique[CAConstants.CellTracksVector](stream)

        var device_hitToTuple_ = CPUTraits.make_unique[HitToTuple](stream)

        var device_tupleMultiplicity_ = CPUTraits.make_unique[TupleMultiplicity](stream)

        var device_storage_ = CPUTraits.make_unique[AtomicPairCounter.c_type[]](3, stream)

        var device_hitTuple_apc_ = device_storage_[].as_pointer[AtomicPairCounter]()
        var device_hitToTuple_apc_ = (device_storage_[] + 1).as_pointer[AtomicPairCounter]()
        var device_nCells_ = (device_storage_[] + 2).as_pointer[UInt32]()
        
        *device_nCells_ = 0
        launchZero(device_tupleMultiplicity_[])
        launchZero(device_hitToTuple_[]) #we may wish to keep it in the edm...