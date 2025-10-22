
use cudacore.cuda_compat
use cudacore.simple_vector
use cuda_data_formats.pixel_track_heterogeneous
use cuda_data_formats.tracking_rec_hit_2d_cuda
use ca_hit_ntuplet_generator_kernels
use gpu_ca_cell
use helix_fit_on_gpu



use ProductRegistry



trait CAHitNtupletGeneratorOnGPU:
    # Type aliases
    alias Quality = pixel_track.Quality
    alias OutputSoA = pixel_track.TrackSoA
    alias HitContainer = pixel_track.HitContainer
    alias Tuple = HitContainer

    alias QualityCuts = ca_hit_ntuplet_generator.QualityCuts
    alias Params = ca_hit_ntuplet_generator.Params
    alias Counters = ca_hit_ntuplet_generator.Counters


    fn make_tuples(
        self,
        hits_d: tracking_rec_hit_2d_cuda.TrackingRecHit2DCPU,
        bfield: Float32
    ) -> pixel_track.PixelTrackHeterogeneous
