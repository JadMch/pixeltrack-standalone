from MojoSerial.Framework.ProductRegistry import ProductRegistry

@fieldwise_init
struct CAHitNtupletCUDA(Copyable, Movable):

    var tokenHitCPU_ : EDGetTokenT[TrackingRecHit2DCPU]
    var tokenTrackCPU_ : EDPutTokenT[PixelTrackHeterogeneous]
    var gpu_algo: CAHitNtupletGeneratorOnGPU
    
    fn __init__(out self , ProductRegistry reg):
        self.token_hit_cpu = reg.consumes[TrackingRecHit2DCPU]()
        self.token_track_cpu = reg.produces[PixelTrackHeterogeneous]()
        self.gpu_algo = CAHitNtupletGeneratorOnGPU(reg)

