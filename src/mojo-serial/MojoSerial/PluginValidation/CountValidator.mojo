from pathlib import Path
from sys.info import sizeof
from memory import memcpy
from os.atomic import Atomic

from MojoSerial.Framework.EDProducer import EDProducer
from MojoSerial.Framework.ProductRegistry import ProductRegistry
from MojoSerial.Framework.Event import Event
from MojoSerial.Framework.EventSetup import EventSetup
from MojoSerial.Framework.EDGetToken import EDGetTokenT
from MojoSerial.DataFormats.DigiClusterCount import DigiClusterCount
from MojoSerial.DataFormats.TrackCount import TrackCount
from MojoSerial.DataFormats.VertexCount import VertexCount
from MojoSerial.CUDADataFormats.SiPixelDigisSoA import SiPixelDigisSoA
from MojoSerial.CUDADataFormats.SiPixelClustersSoA import SiPixelClustersSoA
from MojoSerial.CUDADataFormats.PixelTrackHeterogeneous import PixelTrackHeterogeneous
#from MojoSerial.CUDADataFormats.ZVertexHeterogeneous import ZVertexHeterogeneous
from MojoSerial.CUDADataFormats.ZVertexSoA import ZVertexSoA

from MojoSerial.MojoBridge.DTypes import Typeable, TypeableOwnedPointer
from MojoSerial.MojoBridge.DTypes import Char, Typeable, UChar
from MojoSerial.MojoBridge.File import read_obj

struct CountValidator (
    Defaultable, EDProducer, Movable, Typeable
):

    var digiClusterCountToken_: EDGetTokenT[DigiClusterCount]
    var trackCountToken_: EDGetTokenT[TrackCount]
    var vertexCountToken_: EDGetTokenT[VertexCount]

    var digiToken_: EDGetTokenT[SiPixelDigisSoA]
    var clusterToken_: EDGetTokenT[SiPixelClustersSoA]
    # cannot implicitly convert 'OwnedPointer[AnyStruct[TrackSoAT[maxNumber().cast[::DType]()]]]' value to 'Typeable' in type parameter
    var trackToken_: EDGetTokenT[PixelTrackHeterogeneous[]]
    var vertexToken_: EDGetTokenT[ZVertexSoA]

    fn __init__(out self):
        self.digiClusterCountToken_ = EDGetTokenT[DigiClusterCount]()
        self.trackCountToken_ = EDGetTokenT[TrackCount]()
        self.vertexCountToken_ = EDGetTokenT[VertexCount]()

        self.digiToken_ = EDGetTokenT[SiPixelDigisSoA]()
        self.clusterToken_ = EDGetTokenT[SiPixelClustersSoA]()
        self.trackToken_ = EDGetTokenT[PixelTrackHeterogeneous[]]()
        self.vertexToken_ = EDGetTokenT[ZVertexSoA]()

    fn __init__(out self, mut reg: ProductRegistry):
        try:
            self.digiClusterCountToken_ = reg.consumes[DigiClusterCount]()
            self.trackCountToken_ = reg.consumes[TrackCount]()
            self.vertexCountToken_ = reg.consumes[VertexCount]()
            self.digiToken_ = reg.consumes[SiPixelDigisSoA]()
            self.clusterToken_ = reg.consumes[SiPixelClustersSoA]()
            self.trackToken_ = reg.consumes[PixelTrackHeterogeneous[]]()
            self.vertexToken_ = reg.consumes[ZVertexSoA]()
        except e:
            print("Handled exception in CountValidator: ", e)
            return Self()

    @staticmethod
    fn addTrackDifference(diff: Float32) ->  Float32: 
        var sum = Atomic[DType.float32](0)
        sum += diff
        return sum.load()

    @staticmethod
    fn addVertexDifference(diff: Int8) ->  Int16:
        var sum = Atomic[DType.int16](0)
        sum += Int16(diff)
        return sum.load()

    @staticmethod
    fn incAllEvents(add: UInt32) -> UInt32:
        var sum = Atomic[DType.uint32](0)
        sum += add
        return sum.load()

    @staticmethod
    fn incGoodEvents(add: UInt32) -> UInt32:
        var sum = Atomic[DType.uint32](0)
        sum += add
        return sum.load()

    @staticmethod
    fn strformat[Ty: Stringable & Representable](str: StringSlice, arg: Ty) -> String:
        # Simple implementation of format function
        try:
            return str.format(arg)
        except e:
            return str + " <== Format error: " + String(e)

    @staticmethod
    fn strformat[Ty: Stringable & Representable](str: StringSlice, arg: Ty, arg1: Ty) -> String:
        # Simple implementation of format function
        try:
            return str.format(arg, arg1)
        except e:
            return str + " <== Format error: " + String(e)

    fn produce(mut self, mut iEvent: Event, ref iSetup: EventSetup):
        var trackTolerance: Float32 = 0.012  # in 200 runs of 1k events all events are withing this tolerance
        var vertexTolerance: Int8 = 1

        var errorMsg: String = Self.strformat("Event {} ", iEvent.eventID())
        var ok: Bool = True

        ref count = iEvent.get(self.digiClusterCountToken_)
        ref digis = iEvent.get(self.digiToken_)
        ref clusters = iEvent.get(self.clusterToken_)

        if digis.nModules() != count.nModules():
            errorMsg += Self.strformat("\n N(modules) is {} expected {}", digis.nModules(), count.nModules())
            ok = False

        if digis.nDigis() != count.nDigis():
            errorMsg += Self.strformat("\n N(digis) is {} expected {}", digis.nDigis(), count.nDigis())
            ok = False
        if clusters.nClusters() != count.nClusters():
            errorMsg += Self.strformat("\n N(clusters) is {} expected {}", clusters.nClusters(), count.nClusters())
            ok = False

        ref trackCount = iEvent.get(self.trackCountToken_)
        ref tracks = iEvent.get(self.trackToken_)

        nTracks: UInt32 = 0
        for i in range(tracks.stride()):
            if tracks.nHits(i) > 0:
                nTracks += 1
        
        rel = abs(Float32(nTracks - trackCount.nTracks())) / Float32(trackCount.nTracks())
        if nTracks != trackCount.nTracks():
            _ = CountValidator.addTrackDifference(rel)
        if rel > trackTolerance:
            errorMsg += Self.strformat(
                "\n N(tracks) is {} expected {}",
                nTracks,
                trackCount.nTracks()
            )
            errorMsg += Self.strformat(", relative difference {} is outside tolerance {}", rel, trackTolerance)
            ok = False

        ref vertexCount = iEvent.get(self.vertexCountToken_)
        ref vertices = iEvent.get(self.vertexToken_)
        diff = abs(Int8(vertices.nvFinal) - Int8(vertexCount.nVertices()))
        if diff != 0:
            _ = CountValidator.addVertexDifference(diff)
        if diff > vertexTolerance:
            errorMsg += Self.strformat(
                "\n N(vertices) is {} expected {}",
                vertices.nvFinal,
                vertexCount.nVertices()
            )
            errorMsg += Self.strformat(", difference {} is outside tolerance {}", diff, vertexTolerance)
            ok = False

        _ = CountValidator.incAllEvents(1)
        if ok:
            _ = CountValidator.incGoodEvents(1)
        else:
            print(errorMsg)

    fn endJob(mut self) raises:
        all = CountValidator.incAllEvents(0)
        good = CountValidator.incGoodEvents(0)
        if all == good:
            print(Self.strformat("CountValidator: all {} events validated successfully!", all))
            trackDiff = CountValidator.addTrackDifference(0.0)
            if trackDiff > 0:
                print(
                    Self.strformat(
                        " Average relative track difference: {} (all within tolerance)",
                        trackDiff / Float32(all)
                    )
                )
            vertexDiff = CountValidator.addVertexDifference(0)
            if vertexDiff > 0:
                print(
                    Self.strformat(
                        " Average absolute vertex difference: {} (all within tolerance)",
                        Float32(vertexDiff) / Float32(all)
                    )
                )
        else:
            print(
                Self.strformat(
                    "CountValidator: {} events failed validation (see details above)",
                    all - good
                )
            )
            raise Error("CountValidator failed")

    @staticmethod
    fn dtype() -> String:
        return "CountValidator"
