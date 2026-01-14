
import CAConstants
alias HitToTuple = CAConstants.HitToTuple
alias TupleMultiplicity = CAConstants.TupleMultiplicity
use hip.stream.Stream
use cms.cuda.{AtomicPairCounter, launchZero}

impl CAHitNtupletGeneratorKernels[CPUTraits]:
    fn allocate_on_gpu(self, stream: Stream):
        #//////////////////////////////////////////////////////////
        #// ALLOCATIONS FOR THE INTERMEDIATE RESULTS (STAYS ON WORKER)
        #//////////////////////////////////////////////////////////
        
        self.device_theCellNeighbors_ = CPUTraits.make_unique[CAConstants.CellNeighborsVector](stream)
        self.device_theCellTracks_ = CPUTraits.make_unique[CAConstants.CellTracksVector](stream)

        self.device_hitToTuple_ = CPUTraits.make_unique[HitToTuple](stream)

        self.device_tupleMultiplicity_ = CPUTraits.make_unique[TupleMultiplicity](stream)

        self.device_storage_ = CPUTraits.make_unique[AtomicPairCounter.c_type[]](3, stream)

        self.device_hitTuple_apc_ = self.device_storage_[].as_pointer[AtomicPairCounter]()
        self.device_hitToTuple_apc_ = (self.device_storage_[] + 1).as_pointer[AtomicPairCounter]()
        self.device_nCells_ = (self.device_storage_[] + 2).as_pointer[UInt32]()
        
        *self.device_nCells_ = 0
        launchZero(self.device_tupleMultiplicity_[])
        launchZero(self.device_hitToTuple_[]) # we may wish to keep it in the edm...
