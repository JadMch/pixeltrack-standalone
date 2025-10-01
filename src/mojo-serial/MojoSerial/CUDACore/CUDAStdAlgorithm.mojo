from sys import sizeof


@nonmaterializable(NoneType)
struct CUDAStdAlgorithm:
    @staticmethod
    fn lower_bound[
        T: DType, //
    ](
        var first: UnsafePointer[Scalar[T]],
        var last: UnsafePointer[Scalar[T]],
        var value: Scalar[T],
    ) -> UnsafePointer[Scalar[T]]:
        var count = (Int(last) - Int(first)) // sizeof[Scalar[T]]()

        while count > 0:
            var it = first
            var step = count // 2
            it += step

            if it[] < value:
                it += 1
                first = it
                count -= step + 1
            else:
                count = step

        return first

    @staticmethod
    fn upper_bound[
        T: DType, //
    ](
        var first: UnsafePointer[Scalar[T]],
        var last: UnsafePointer[Scalar[T]],
        var value: Scalar[T],
    ) -> UnsafePointer[Scalar[T]]:
        var count = (Int(last) - Int(first)) // sizeof[Scalar[T]]()

        while count > 0:
            var it = first
            var step = count // 2
            it += step

            if value >= it[]:
                it += 1
                first = it
                count -= step + 1
            else:
                count = step

        return first

    @staticmethod
    fn binary_find[
        T: DType, //
    ](
        var first: UnsafePointer[Scalar[T]],
        var last: UnsafePointer[Scalar[T]],
        var value: Scalar[T],
    ) -> UnsafePointer[Scalar[T]]:
        first = Self.lower_bound(first, last, value)

        return first if (first != last) and (value >= first[]) else last
