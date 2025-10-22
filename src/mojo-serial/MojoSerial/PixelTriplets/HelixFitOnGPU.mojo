import CAConstants
import FitResult
from CUDADataFormats import TrackingRecHit2DCUDA
from CUDADataFormats import PixelTrackHeterogeneous

struct Rfit:
    #in case of memory issue can be made smaller 
    @staticmethod
    fn maxNumberOfConcurrentFits() -> UInt32:
        return CAConstants.maxNumberOfTuples()

    @staticmethod
    fn stride(self) -> UInt32:
        return self.maxNumberOfConcurrentFits()
    
    alias Matrix3x4d = Eigen.Matrix[Float64 , 3 , 4]
    alias Map3x4d = Eigen.Map[Matrix3x4f , 0 , Eigen.stride[3 * self.stride() , self.stride()]]
    alias Matrix6x4f = Eigen.Matrix[Float32 , 6 , 4]
    alias Map6x4f = Eigen.Map[Matrix6x4f , 0 , Eigen.stride[6 * self.stride() , self.stride()]]

    #hits
    alias Matrix3xNd[N  :Int ] = Eigen.Matrix[float64 , 3 , N]
    alias Map3xNd[N : Int] = Eigen.Map[Matrix3xNd[N] , 0 , Eigen.Stride[3 * self.stride() , stride()]]

    #errors
    alias Matrix6xNf[N :Int] = Eigen.Matrix[Float32, 6  N]
    alias Map6xNf =  Eigen.Map[Matrix6xNf[N] , 0 , Eigen.Stride[6 * self.stride() , self.stride()]]

    #fast fit 
    alias Map4d = Eigen.Map[Vector4d , 0 , Eigen.InnerStride[self.stride()]]


trait HelixFitOnGPU:
    alias hitsView = TrackingRecHit2DSOAView
    
    alias Tuples = pixelTrack.HitContainer
    alias OutputSoA = pixelTrack.TrackSoA

    alias TupleMultiplicity = CAConstants.TupleMultiplicity

    
    var tuples_d: UnsafePointer[Tuples]
    var tupleMultiplicity_d: UnsafePointer[TupleMultiplicity]
    var outputSoa_d: UnsafePointer[OutputSoA]
    
    
    var bField_: Float32
    var fit5as4_: Bool

    alias maxNumberOfConcurrentFits_ = Rfit.maxNumberOfConcurrentFits()
    
    fn setBField(mut self, bField: Float64): ...
    
    fn launchRiemannKernels(
        self,
        hv: UnsafePointer[HitsView],
        nhits: UInt32,
        maxNumberOfTuples: UInt32,
        cudaStream: cudaStream_t
    ): ...
    
    fn launchBrokenLineKernels(
        self,
        hv: UnsafePointer[HitsView],
        nhits: UInt32,
        maxNumberOfTuples: UInt32,
        cudaStream: cudaStream_t
    ): ...
    
    fn launchRiemannKernelsOnCPU(
        self,
        hv: UnsafePointer[HitsView],
        nhits: UInt32,
        maxNumberOfTuples: UInt32
    ): ...
    
    fn launchBrokenLineKernelsOnCPU(
        self,
        hv: UnsafePointer[HitsView],
        nhits: UInt32,
        maxNumberOfTuples: UInt32
    ): ...
    
    fn allocateOnGPU(
        mut self,
        tuples: UnsafePointer[Tuples],
        tupleMultiplicity: UnsafePointer[TupleMultiplicity],
        outputSoA: UnsafePointer[OutputSoA]
    ): ...
    
    fn deallocateOnGPU(mut self): ...

