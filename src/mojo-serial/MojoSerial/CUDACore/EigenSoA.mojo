from layout import Layout, LayoutTensor, IntTuple

from MojoSerial.MojoBridge.DTypes import Typeable


fn isPowerOf2(v: Int32) -> Bool:
    return v and not (v & (v - 1))


# WARNING: THIS STRUCT IS 128-ALIGNED
struct ScalarSoA[T: DType, S: Int](
    Copyable, Defaultable, Movable, Sized, Typeable
):
    alias Scalar = Scalar[T]
    var _data: InlineArray[Self.Scalar, S]

    @always_inline
    fn __init__(out self):
        constrained[isPowerOf2(S), "SoA stride not a power of 2"]()
        constrained[
            S * T.sizeof() % 128 == 0, "SoA size not a multiple of 128"
        ]()
        self._data = InlineArray[Self.Scalar, S](fill=0)

    @always_inline
    fn __init__(out self, var list: InlineArray[Self.Scalar, S]):
        constrained[isPowerOf2(S), "SoA stride not a power of 2"]()
        constrained[
            S * T.sizeof() % 128 == 0, "SoA size not a multiple of 128"
        ]()
        self._data = list^

    @always_inline
    fn __init__(
        out self, var ptr: UnsafePointer[Self.Scalar], *, var cp: Bool = False
    ):
        constrained[isPowerOf2(S), "SoA stride not a power of 2"]()
        constrained[
            S * T.sizeof() % 128 == 0, "SoA size not a multiple of 128"
        ]()

        self._data = InlineArray[Self.Scalar, S](uninitialized=True)

        for i in range(S):
            if cp:
                (self._data.unsafe_ptr() + i).init_pointee_copy((ptr + i)[])
            else:
                (self._data.unsafe_ptr() + i).init_pointee_move(
                    (ptr + i).take_pointee()
                )

    @always_inline
    fn __len__(self) -> Int:
        return S

    @always_inline
    fn __moveinit__(out self, var other: Self):
        self._data = other._data^

    @always_inline
    fn __copyinit__(out self, other: Self):
        self._data = other._data

    @always_inline
    fn data[
        origin: Origin, //
    ](ref [origin]self) -> UnsafePointer[
        Self.Scalar, mut = origin.mut, origin=origin
    ]:
        return self._data.unsafe_ptr()

    @always_inline
    fn __getitem__(ref self, i: Int) -> ref [self._data] Self.Scalar:
        return self._data[i]

    @always_inline
    fn __setitem__(mut self, i: Int, v: Self.Scalar):
        self._data[i] = v

    @always_inline
    @staticmethod
    fn dtype() -> String:
        return "ScalarSoA[" + T.__repr__() + ", " + String(S) + "]"


# WARNING: THIS STRUCT IS 128-ALIGNED
struct MatrixSoA[T: DType, R: Int, C: Int, S: Int](
    Copyable, Defaultable, Movable, Sized, Typeable
):
    alias Scalar = Scalar[T]
    alias _D = InlineArray[Self.Scalar, S * R * C]
    # stride in C++ is coln, row
    alias Map = Layout(IntTuple(R, C), IntTuple(S, R * S))
    var _data: Self._D

    @always_inline
    fn __init__(out self):
        constrained[isPowerOf2(S), "SoA stride not a power of 2"]()
        constrained[
            R * C * S * T.sizeof() % 128 == 0, "SoA size not a multiple of 128"
        ]()
        self._data = Self._D(fill=0)

    @always_inline
    fn __init__(out self, var list: Self._D):
        constrained[isPowerOf2(S), "SoA stride not a power of 2"]()
        constrained[
            R * C * S * T.sizeof() % 128 == 0, "SoA size not a multiple of 128"
        ]()
        self._data = list^

    @always_inline
    fn __init__(
        out self, var ptr: UnsafePointer[Self.Scalar], *, var cp: Bool = False
    ):
        constrained[isPowerOf2(S), "SoA stride not a power of 2"]()
        constrained[
            R * C * S * T.sizeof() % 128 == 0, "SoA size not a multiple of 128"
        ]()

        self._data = Self._D(uninitialized=True)

        for i in range(R * C * S):
            if cp:
                (self._data.unsafe_ptr() + i).init_pointee_copy((ptr + i)[])
            else:
                (self._data.unsafe_ptr() + i).init_pointee_move(
                    (ptr + i).take_pointee()
                )

    @always_inline
    fn __len__(self) -> Int:
        return R * C * S

    @always_inline
    fn __moveinit__(out self, var other: Self):
        self._data = other._data^

    @always_inline
    fn __copyinit__(out self, other: Self):
        self._data = other._data

    @always_inline
    fn __getitem__[
        origin: Origin, //
    ](ref [origin]self, i: Int32) -> LayoutTensor[
        mut = origin.mut, T, Self.Map, origin
    ]:
        return LayoutTensor[mut = origin.mut, T, Self.Map, origin](
            self._data.unsafe_ptr() + i
        )

    @always_inline
    fn __setitem__(mut self, idx: Int32, val: LayoutTensor):
        var dest_slice = self[idx]

        var rows = val.layout.shape[0].value()
        var colns = val.layout.shape[1].value()
        for i in range(rows):
            for j in range(colns):
                dest_slice[i, j] = rebind[Scalar[T]](val[i, j].cast[T]())

    @always_inline
    fn __setitem__(
        mut self,
        idx: Int32,
        first: LayoutTensor,
        second: LayoutTensor,
    ):
        """Eigen::Map::operator<<."""
        var dest_slice = self[idx]

        var dest_rows = dest_slice.layout.shape[0].value()
        var dest_cols = dest_slice.layout.shape[1].value()
        var first_rows = first.layout.shape[0].value()
        var first_cols = first.layout.shape[1].value()
        var second_rows = second.layout.shape[0].value()
        var second_cols = second.layout.shape[1].value()

        var i_first = 0
        var j_first = 0
        var i_second = 0
        var j_second = 0

        for j_dest in range(dest_cols):
            for i_dest in range(dest_rows):
                if j_first < first_cols:
                    dest_slice[i_dest, j_dest] = rebind[Scalar[T]](
                        first[i_first, j_first].cast[T]()
                    )

                    i_first += 1
                    if i_first == first_rows:
                        i_first = 0
                        j_first += 1

                elif j_second < second_cols:
                    dest_slice[i_dest, j_dest] = rebind[Scalar[T]](
                        second[i_second, j_second].cast[T]()
                    )

                    i_second += 1
                    if i_second == second_rows:
                        i_second = 0
                        j_second += 1
                else:
                    return

    @always_inline
    @staticmethod
    fn dtype() -> String:
        return (
            "MatrixSoA["
            + T.__repr__()
            + ", "
            + String(R)
            + ", "
            + String(C)
            + ", "
            + String(S)
            + "]"
        )
