alias CUDAStreamType = OpaquePointer
alias cudaStreamDefault: OpaquePointer = OpaquePointer()


@nonmaterializable(NoneType)
@deprecated(
    "Any methods using CUDACompat should be redirected to perform the regular"
    " operations since we are not in a CUDA environment."
)
struct CUDACompat:
    @staticmethod
    @deprecated(
        "Any methods using CUDACompat should be redirected to perform the"
        " regular operations since we are not in a CUDA environment."
    )
    fn atomicCAS[
        T1: Copyable & EqualityComparable, //
    ](address: UnsafePointer[T1, mut=True], compare: T1, val: T1) -> T1:
        var old = address[]
        address[] = val if old == compare else old
        return old

    @staticmethod
    @deprecated(
        "Any methods using CUDACompat should be redirected to perform the"
        " regular operations since we are not in a CUDA environment."
    )
    fn atomicInc[
        T1: DType, //
    ](a: UnsafePointer[Scalar[T1], mut=True], b: Scalar[T1]) -> Scalar[T1]:
        var ret = a[]
        if a[] < b:
            a[] += 1
        return ret

    @staticmethod
    @deprecated(
        "Any methods using CUDACompat should be redirected to perform the"
        " regular operations since we are not in a CUDA environment."
    )
    fn atomicAdd[
        T1: DType, //
    ](a: UnsafePointer[Scalar[T1], mut=True], b: Scalar[T1]) -> Scalar[T1]:
        var ret = a[]
        a[] += b
        return ret

    @staticmethod
    @deprecated(
        "Any methods using CUDACompat should be redirected to perform the"
        " regular operations since we are not in a CUDA environment."
    )
    fn atomicSub[
        T1: DType, //
    ](a: UnsafePointer[Scalar[T1], mut=True], b: Scalar[T1]) -> Scalar[T1]:
        var ret = a[]
        a[] -= b
        return ret

    @staticmethod
    @deprecated(
        "Any methods using CUDACompat should be redirected to perform the"
        " regular operations since we are not in a CUDA environment."
    )
    fn atomicMin[
        T1: Copyable & Comparable, //
    ](a: UnsafePointer[T1, mut=True], b: T1) -> T1:
        var ret = a[]
        a[] = min(a[], b)
        return ret

    @staticmethod
    @deprecated(
        "Any methods using CUDACompat should be redirected to perform the"
        " regular operations since we are not in a CUDA environment."
    )
    fn atomicMax[
        T1: Copyable & Comparable, //
    ](a: UnsafePointer[T1, mut=True], b: T1) -> T1:
        var ret = a[]
        a[] = max(a[], b)
        return ret
