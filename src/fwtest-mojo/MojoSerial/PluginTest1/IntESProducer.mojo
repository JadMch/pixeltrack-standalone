from pathlib import Path

from MojoSerial.Framework.ESProducer import ESProducer
from MojoSerial.Framework.EventSetup import EventSetup
from MojoSerial.MojoBridge.DTypes import Typeable, TypeableInt


struct IntESProducer(Defaultable, ESProducer, Movable, Typeable):
    # an esproducer cant have null size in memory
    var x: Int

    fn __init__(out self):
        self.x = 0

    fn __moveinit__(out self, var other: Self):
        self.x = other.x

    fn __init__(out self, var path: Path):
        self.x = 0

    fn produce(mut self, mut eventSetup: EventSetup):
        try:
            eventSetup.put[TypeableInt](TypeableInt(42))
        except e:
            print("Error occurred in PluginTest1/IntESProducer.mojo, ", e)

    @always_inline
    @staticmethod
    fn dtype() -> String:
        return "IntESProducer"
