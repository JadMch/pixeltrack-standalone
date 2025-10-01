from memory import bitcast

from MojoSerial.MojoBridge.DTypes import Typeable


@fieldwise_init
@register_passable("trivial")
struct Counters(Copyable, Defaultable, Movable, Typeable):
    var c: SIMD[DType.uint32, 2]
    # alias n: UInt32 = c[0] # in a "One to Many" association is the number of "One"
    # alias m: UInt32 = c[1] # in a "One to Many" association is the total number of associations
    # alias ac: UInt64 = bitcast[DType.uint64, 1](c)

    @always_inline
    fn __init__(out self):
        self.c = SIMD[DType.uint32, 2]()

    @always_inline
    fn get_ac(self) -> UInt64:
        return bitcast[DType.uint64, 1](self.c)

    @always_inline
    fn set_ac(mut self, var ac: UInt64):
        self.c = bitcast[DType.uint32, 2](ac)

    @always_inline
    fn __getitem__(self) -> UInt64:
        return self.get_ac()

    @always_inline
    fn __getitem__(self, i: Int) -> UInt32:
        return self.c[i]

    @always_inline
    fn __setitem__(mut self, i: Int, val: UInt32):
        self.c[i] = val

    @always_inline
    @staticmethod
    fn dtype() -> String:
        return "Counters"


@fieldwise_init
@register_passable("trivial")
struct AtomicPairCounter(Copyable, Defaultable, Movable, Typeable):
    var counter: Counters
    alias CounterType = UInt64
    alias incr: Self.CounterType = 1 << 32

    @always_inline
    fn __init__(out self):
        self.counter = Counters()

    @always_inline
    fn __init__(out self, i: Self.CounterType):
        self = Self()
        self.counter.set_ac(i)

    @always_inline
    fn get(self) -> Counters:
        return self.counter

    @always_inline
    fn add(mut self, i: UInt32) -> Counters:
        var ret = self.counter
        var c = Self.incr + i.cast[DType.uint64]()
        self.counter.set_ac(self.counter.get_ac() + c)
        return ret

    @always_inline
    @staticmethod
    fn dtype() -> String:
        return "AtomicPairCounter"
