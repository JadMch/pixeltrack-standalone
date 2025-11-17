from MojoSerial.MojoBridge.DTypes import Typeable


@fieldwise_init
@register_passable("trivial")
struct VertexCount(Copyable, Defaultable, Movable, Typeable):
    var _vertices: UInt32

    @always_inline
    fn __init__(out self):
        self._vertices = 0

    @always_inline
    fn nVertices(self) -> UInt32:
        return self._vertices

    @always_inline
    @staticmethod
    fn dtype() -> String:
        return "VertexCount"
