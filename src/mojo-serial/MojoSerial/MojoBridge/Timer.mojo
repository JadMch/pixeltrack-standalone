from memory import OwnedPointer
from time import perf_counter_ns


@register_passable("trivial")
struct Timer(Copyable, Defaultable, Movable, Stringable):
    var _start: UInt
    var _time: UInt

    @always_inline
    fn __init__(out self):
        self._start = 0
        self._time = 0

    @always_inline
    fn __init__(out self, var start: UInt):
        self._start = start
        self._time = 0

    @always_inline
    fn start(mut self):
        self._start = perf_counter_ns()

    @always_inline
    fn finish(mut self):
        self._time += perf_counter_ns() - self._start

    @always_inline
    fn get(self) -> UInt:
        return self._time

    @always_inline
    fn finalize(self, var name: String):
        print(
            "[" + name + "] completed in ",
            self._time // (10**6),
            "ms",
            sep="",
        )

    @always_inline
    fn __str__(self) -> String:
        return (
            "Timer(" + self._start.__str__() + ", " + self._time.__str__() + ")"
        )


struct TimerManager(Defaultable, Movable, Sized):
    var _storage: OwnedPointer[Dict[String, Timer]]
    # a stack
    var _cur: OwnedPointer[List[String]]

    @always_inline
    fn __init__(out self):
        self._storage = OwnedPointer[Dict[String, Timer]](Dict[String, Timer]())
        self._cur = OwnedPointer[List[String]](List[String]())

    @always_inline
    fn __moveinit__(out self, var other: Self):
        self._storage = other._storage^
        self._cur = other._cur^

    @always_inline
    fn __enter__(ref self):
        if not self.empty():
            if self.top() not in self._storage.unsafe_ptr()[]:
                self._storage.unsafe_ptr()[][self.top()] = Timer()
            try:
                self._storage.unsafe_ptr()[][self.top()].start()
            except e:
                print(e)

    @always_inline
    fn __exit__(ref self):
        try:
            self._storage.unsafe_ptr()[][self.top()].finish()
        except e:
            print(e)
        self.pop()

    @always_inline
    fn configure(ref self, var name: String):
        self._cur.unsafe_ptr()[].append(name)

    @always_inline
    fn start(ref self, var name: String = ""):
        if name:
            self.configure(name)
        self.__enter__()

    @always_inline
    fn stop(ref self):
        self.__exit__()

    @always_inline
    fn clear(ref self):
        self._storage.unsafe_ptr()[].clear()
        self._cur.unsafe_ptr()[].clear()

    @always_inline
    fn empty(self) -> Bool:
        return self._cur.unsafe_ptr()[].__len__() == 0

    @always_inline
    fn top(ref self) -> ref [self._cur] String:
        return self._cur.unsafe_ptr()[][-1]

    @always_inline
    fn pop(ref self):
        _ = self._cur.unsafe_ptr()[].pop()

    @always_inline
    fn __len__(self) -> Int:
        return self._storage.unsafe_ptr()[].__len__()

    @always_inline
    fn finalize(ref self):
        try:
            while not self.empty():
                self.stop()
            for k in self._storage.unsafe_ptr()[].keys():
                self._storage.unsafe_ptr()[][k].finalize(k)
        except e:
            print(e)
