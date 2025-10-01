from sys import sizeof

from MojoSerial.CondFormats.PixelCPEforGPU import (
    CommonParams,
    DetParams,
    LayerGeometry,
    AverageGeometry,
    ParamsOnGPU,
)
from MojoSerial.MojoBridge.DTypes import UChar, Typeable
from MojoSerial.CondFormats.PixelGPUDetails import PixelGPUDetails


# WARNING: THIS STRUCT IS 128-ALIGNED
struct SiPixelFedCablingMapGPU(Defaultable, Movable, Typeable):
    alias _U = InlineArray[UInt32, Int(PixelGPUDetails.MAX_SIZE)]
    alias _UD = Self._U(uninitialized=True)
    alias _C = InlineArray[UChar, Int(PixelGPUDetails.MAX_SIZE)]
    alias _CD = Self._C(uninitialized=True)
    var fed: Self._U
    var link: Self._U
    var roc: Self._U
    var RawId: Self._U
    var rocInDet: Self._U
    var moduleId: Self._U
    var badRocs: Self._C
    var size: UInt32
    var __padding: InlineArray[UInt8, 124]

    @always_inline
    fn __init__(out self):
        self.fed = Self._U(fill=0)
        self.link = Self._U(fill=0)
        self.roc = Self._U(fill=0)
        self.RawId = Self._U(fill=0)
        self.rocInDet = Self._U(fill=0)
        self.moduleId = Self._U(fill=0)
        self.badRocs = Self._C(fill=0)
        self.size = 0

        self.__padding = InlineArray[UInt8, 124](fill=0)

    @always_inline
    fn __init__(
        out self,
        var fed: Self._U,
        var link: Self._U,
        var roc: Self._U,
        var RawId: Self._U,
        var rocInDet: Self._U,
        var moduleId: Self._U,
        var badRocs: Self._C,
    ):
        self.fed = fed^
        self.link = link^
        self.roc = roc^
        self.RawId = RawId^
        self.rocInDet = rocInDet^
        self.moduleId = moduleId^
        self.badRocs = badRocs^
        self.size = 0

        self.__padding = InlineArray[UInt8, 124](fill=0)

    @always_inline
    fn __moveinit__(out self, var other: Self):
        self.fed = other.fed^
        self.link = other.link^
        self.roc = other.roc^
        self.RawId = other.RawId^
        self.rocInDet = other.rocInDet^
        self.moduleId = other.moduleId^
        self.badRocs = other.badRocs^
        self.size = other.size

        self.__padding = InlineArray[UInt8, 124](fill=0)

    @always_inline
    @staticmethod
    fn dtype() -> String:
        return "SiPixelFedCablingMapGPU"
