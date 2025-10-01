from MojoSerial.DataFormats.SiPixelRawDataError import SiPixelRawDataError
from MojoSerial.MojoBridge.DTypes import Typeable


@fieldwise_init
@register_passable("trivial")
struct PixelErrorCompact(Copyable, Defaultable, Movable, Typeable):
    var raw_id: UInt32
    var word: UInt32
    var error_type: UInt8
    var fed_id: UInt8

    @always_inline
    fn __init__(out self):
        self.raw_id = 0
        self.word = 0
        self.error_type = 0
        self.fed_id = 0

    @always_inline
    @staticmethod
    fn dtype() -> String:
        return "PixelErrorCompact"


alias PixelFormatterErrors = Dict[UInt, List[SiPixelRawDataError]]
