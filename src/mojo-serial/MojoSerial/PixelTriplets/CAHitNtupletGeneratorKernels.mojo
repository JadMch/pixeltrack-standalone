use cuda_data_formats.tracking_rec_hit_2d_cuda.TrackingRecHit2DSOAView
use ca_constants.HitToTuple
use ca_constants.TupleMultiplicity
use pixel_track.Quality
use pixel_track.TrackSoA
use pixel_track.HitContainer

alias HitsView = TrackingRecHit2DSOAView
alias HitsOnGPU = TrackingRecHit2DSOAView

alias HitToTuple = HitToTuple
alias TupleMultiplicity = TupleMultiplicity

alias Quality = Quality
alias TkSoA = TrackSoA
alias HitContainer = HitContainer

struct Counters:
    var n_events: UInt64
    var n_hits: UInt64
    var n_cells: UInt64
    var n_tuples: UInt64
    var n_fit_tracks: UInt64
    var n_good_tracks: UInt64
    var n_used_hits: UInt64
    var n_dup_hits: UInt64
    var n_killed_cells: UInt64
    var n_empty_cells: UInt64
    var n_zero_track_cells: UInt64

  struct QualityCuts :
    # chi2 cut = chi2Scale * (chi2Coeff[0] + pT/GeV * (chi2Coeff[1] + pT/GeV * (chi2Coeff[2] + pT/GeV * chi2Coeff[3])))
    float chi2Coeff[4]
    float chi2MaxPt  # GeV
    float chi2Scale

    struct region {
      float maxTip  # cm
      float minPt   # GeV
      float maxZip  # cm
    }

    var triplet : region
    var quadruplet : region


struct Params:
    let on_gpu: Bool
    let min_hits_per_ntuplet: UInt32
    let max_number_of_doublets: UInt32
    let use_riemann_fit: Bool
    let fit_5_as_4: Bool
    let include_jumping_forward_doublets: Bool
    let early_fishbone: Bool
    let late_fishbone: Bool
    let ideal_conditions: Bool
    let do_stats: Bool
    let do_cluster_cut: Bool
    let do_z0_cut: Bool
    let do_pt_cut: Bool
    let ptmin: Float32
    let ca_theta_cut_barrel: Float32
    let ca_theta_cut_forward: Float32
    let hard_curv_cut: Float32
    let dca_cut_inner_triplet: Float32
    let dca_cut_outer_triplet: Float32
    let cuts: QualityCuts

    fn __init__(
        on_gpu: Bool,
        min_hits_per_ntuplet: UInt32,
        max_number_of_doublets: UInt32,
        use_riemann_fit: Bool,
        fit_5_as_4: Bool,
        include_jumping_forward_doublets: Bool,
        early_fishbone: Bool,
        late_fishbone: Bool,
        ideal_conditions: Bool,
        do_stats: Bool,
        do_cluster_cut: Bool,
        do_z0_cut: Bool,
        do_pt_cut: Bool,
        ptmin: Float32,
        ca_theta_cut_barrel: Float32,
        ca_theta_cut_forward: Float32,
        hard_curv_cut: Float32,
        dca_cut_inner_triplet: Float32,
        dca_cut_outer_triplet: Float32,
        cuts: QualityCuts = QualityCuts(
            #polynomial coefficients for the pT-dependent chi2 cut
            chi2_coeffs = [0.68177776, 0.74609577, -0.08035491, 0.00315399],
            #max pT used to determine the chi2 cut
            max_pt = 10.0,
            #chi2 scale factor: 30 for broken line fit, 45 for Riemann fit
            chi2_scale = 30.0,
            #regional cuts for triplets
            triplet_regions = [0.3, 0.5, 12.0],
           #regional cuts for quadruplets
            quadruplet_regions = [0.5, 0.3, 12.0]
        )
    ):
        self.on_gpu = on_gpu
        self.min_hits_per_ntuplet = min_hits_per_ntuplet
        self.max_number_of_doublets = max_number_of_doublets
        self.use_riemann_fit = use_riemann_fit
        self.fit_5_as_4 = fit_5_as_4
        self.include_jumping_forward_doublets = include_jumping_forward_doublets
        self.early_fishbone = early_fishbone
        self.late_fishbone = late_fishbone
        self.ideal_conditions = ideal_conditions
        self.do_stats = do_stats
        self.do_cluster_cut = do_cluster_cut
        self.do_z0_cut = do_z0_cut
        self.do_pt_cut = do_pt_cut
        self.ptmin = ptmin
        self.ca_theta_cut_barrel = ca_theta_cut_barrel
        self.ca_theta_cut_forward = ca_theta_cut_forward
        self.hard_curv_cut = hard_curv_cut
        self.dca_cut_inner_triplet = dca_cut_inner_triplet
        self.dca_cut_outer_triplet = dca_cut_outer_triplet
        self.cuts = cuts

#check these 
use ca_hit_ntuplet_generator.{QualityCuts, Params, Counters}
use ca_constants.{HitToTuple, TupleMultiplicity}
use cuda_data_formats.tracking_rec_hit_2d_cuda.TrackingRecHit2DSOAView
use cuda_data_formats.tracking_rec_hit_2d_heterogeneous.TrackingRecHit2DHeterogeneous
use pixel_track.{Quality, TrackSoA, HitContainer}
use gpu_ca_cell.{GPUCACell}
use atomic_pair_counter
use hip.stream.Stream

trait MemoryTraits:
    fn unique_ptr[T]() -> T*


# --- Main Struct (GPU Kernel Driver) ---
trait CAHitNtupletGeneratorKernels[T: MemoryTraits]:

    # Type aliases (mirroring C++ usings)
    alias HitsView = TrackingRecHit2DSOAView
    alias HitsOnGPU = TrackingRecHit2DSOAView
    alias HitsOnCPU = TrackingRecHit2DHeterogeneous[T]
    alias HitToTuple = HitToTuple
    alias TupleMultiplicity = TupleMultiplicity
    alias Quality = Quality
    alias TkSoA = TrackSoA
    alias HitContainer = HitContainer
    alias unique_ptr[X] = T.unique_ptr[X]

    # Constructor-injected params
    let m_params: Params

    # Runtime members
    var counters: Counters* = None

    # --- Workspace memory ---
    var cellStorage_: unique_ptr[UInt8[]]
    var device_theCellNeighbors_: unique_ptr[CellNeighborsVector]
    var device_theCellNeighborsContainer_: Nullable[CellNeighbors*]
    var device_theCellTracks_: unique_ptr[CellTracksVector]
    var device_theCellTracksContainer_: Nullable[CellTracks*]

    var device_theCells_: unique_ptr[GPUCACell[]]
    var device_isOuterHitOfCell_: unique_ptr[GPUCACell.OuterHitOfCell[]]
    var device_nCells_: Nullable[UnsafePointer[UInt32]] = None

    var device_hitToTuple_: unique_ptr[HitToTuple]
    var device_hitToTuple_apc_: Nullable[AtomicPairCounter*] = None

    var device_hitTuple_apc_: Nullable[AtomicPairCounter*] = None

    var device_tupleMultiplicity_: unique_ptr[TupleMultiplicity]
    var device_storage_: unique_ptr[AtomicPairCounter.c_type[]]

    # Const reference to Params (Mojo version)
    var m_params: borrowed[Params]


    # --- Constructor ---
    fn __init__(params: Params):
        self.m_params = params

    # --- Methods (signatures only for now) ---
    fn tuple_multiplicity(self) -> TupleMultiplicity*:
        return self.device_tuple_multiplicity

    fn launch_kernels(
        self,
        hh: HitsOnCPU,
        tuples_d: TrackSoA*,
        cuda_stream: Stream
    ) raises:
        pass

    fn classify_tuples(
        self,
        hh: HitsOnCPU,
        tuples_d: TrackSoA*,
        cuda_stream: Stream
    ) raises:
        pass

    fn fill_hit_det_indices(
        self,
        hv: HitsView*,
        tuples_d: TrackSoA*,
        cuda_stream: Stream
    ) raises:
        pass

    fn build_doublets(
        self,
        hh: HitsOnCPU,
        stream: Stream
    ) raises:
        pass

    fn allocate_on_gpu(self, stream: Stream) raises:
        pass

    fn cleanup(self, cuda_stream: Stream) raises:
        pass

    @staticmethod
    fn print_counters(counters: Counters*):
        pass

let CAHitNtupletGeneratorKernelsCPU: Type = CAHitNtupletGeneratorKernels[CPUTraits]
let CAHitNtupletGeneratorKernelsGPU: Type = CAHitNtupletGeneratorKernels[GPUTraits]