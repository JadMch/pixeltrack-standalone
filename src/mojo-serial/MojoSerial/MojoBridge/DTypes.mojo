from memory import bitcast

alias SizeType = UInt32  # size_t
alias Short = Int16  # short
alias Float = Float32  # float
alias Double = Float64  # double
alias Char = Int8  # char
alias UChar = UInt8  # unsigned char


# this trait is essential for supporting the framework
# currently, the framework uses some clever rebind trickery to bypass statically typed objects and store arbitrary objects within a container, but to have the same type flexibility, we must also be able to identify objects by type
trait Typeable:
    @always_inline
    @staticmethod
    fn dtype() -> String:
        ...


fn hex_to_float[fld: Int32]() -> Float:
    return bitcast[src_dtype = DType.int32, src_width=1, DType.float32](fld)


fn signed_to_unsigned[T: DType]() -> DType:
    @parameter
    if T == DType.int8 or T == DType.uint8:
        return DType.uint8
    elif T == DType.int16 or T == DType.uint16:
        return DType.uint16
    elif T == DType.int32 or T == DType.uint32:
        return DType.uint32
    elif T == DType.int64 or T == DType.uint64:
        return DType.uint64
    elif T == DType.int128 or T == DType.uint128:
        return DType.uint128
    elif T == DType.int256 or T == DType.uint256:
        return DType.uint256
    return DType.invalid


@always_inline
fn enumerate[T: Movable & Copyable](K: Span[T]) -> List[Tuple[Int, T]]:
    var L: List[Tuple[Int, T]] = []
    for i in range(len(K)):
        L.append((i, K[i]))
    return L


@fieldwise_init
@register_passable("trivial")
struct TypeableInt(Copyable, Movable, Typeable):
    var val: Int

    @always_inline
    @staticmethod
    fn dtype() -> String:
        return "TypeableInt"


@fieldwise_init
@register_passable("trivial")
struct TypeableUInt(Copyable, Movable, Typeable):
    var val: UInt

    @always_inline
    @staticmethod
    fn dtype() -> String:
        return "TypeableUInt"
