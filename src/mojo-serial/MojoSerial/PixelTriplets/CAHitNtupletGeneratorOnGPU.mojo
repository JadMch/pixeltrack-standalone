
from CAHitNtupletGeneratorKernels import (
    Counters as KernelCounters,
    Params as KernelParams,
    QualityCuts as KernelQualityCuts,
)
from MojoSerial.CUDADataFormats.PixelTrackHeterogeneous import (
    PixelTrack as pixelTrack,
    PixelTrackHeterogeneous,
)
from MojoSerial.CUDADataFormats.TrackingRecHit2DHeterogeneous import (
    TrackingRecHit2DCPU,
)
from MojoSerial.Framework.ProductRegistry import ProductRegistry



trait CAHitNtupletGeneratorOnGPU:

    alias Quality = pixelTrack.Quality
    alias OutputSoA = pixelTrack.TrackSoA
    alias HitContainer = pixelTrack.HitContainer
    alias Tuple = HitContainer

    alias QualityCuts = KernelQualityCuts
    alias Params = KernelParams
    alias Counters = KernelCounters


    fn make_tuples(
        self,
        hits_d: TrackingRecHit2DCPU,
        bfield: Float32
    ) -> PixelTrackHeterogeneous:
        pass
