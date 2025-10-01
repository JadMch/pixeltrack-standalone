from MojoSerial.Framework.EDProducer import EDProducer
from MojoSerial.Framework.EDGetToken import EDGetTokenT
from MojoSerial.Framework.EventSetup import EventSetup
from MojoSerial.Framework.ProductRegistry import ProductRegistry
from MojoSerial.Framework.Event import Event
from MojoSerial.MojoBridge.DTypes import Typeable, TypeableUInt


struct TestProducer3(Defaultable, EDProducer, Typeable):
    var _getToken: EDGetTokenT[TypeableUInt]

    fn __init__(out self):
        self._getToken = EDGetTokenT[TypeableUInt]()

    fn __init__(out self, mut reg: ProductRegistry):
        try:
            self._getToken = reg.consumes[TypeableUInt]()
        except e:
            print("Error occurred in PluginTest2/TestProducer3.mojo, ", e)
            return Self()

    fn produce(mut self, mut event: Event, ref eventSetup: EventSetup):
        var value = event.get[TypeableUInt](self._getToken).val
        print(
            "TestProducer3 Event ",
            event.eventID(),
            " stream ",
            event.streamID(),
            " value ",
            value,
            sep="",
        )

    @always_inline
    @staticmethod
    fn dtype() -> String:
        return "TestProducer3"

    fn endJob(mut self):
        pass
