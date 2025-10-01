from time import sleep

from MojoSerial.DataFormats.FEDRawDataCollection import FEDRawDataCollection
from MojoSerial.Framework.EDProducer import EDProducer
from MojoSerial.Framework.EDGetToken import EDGetTokenT
from MojoSerial.Framework.EDPutToken import EDPutTokenT
from MojoSerial.Framework.EventSetup import EventSetup
from MojoSerial.Framework.ProductRegistry import ProductRegistry
from MojoSerial.Framework.Event import Event
from MojoSerial.MojoBridge.DTypes import Typeable, TypeableUInt, TypeableInt


struct TestProducer(Defaultable, EDProducer, Typeable):
    var _rawGetToken: EDGetTokenT[FEDRawDataCollection]
    var _putToken: EDPutTokenT[TypeableUInt]

    @always_inline
    fn __init__(out self):
        self._rawGetToken = EDGetTokenT[FEDRawDataCollection]()
        self._putToken = EDPutTokenT[TypeableUInt]()

    fn __init__(out self, mut reg: ProductRegistry):
        try:
            self._rawGetToken = reg.consumes[FEDRawDataCollection]()
            self._putToken = reg.produces[TypeableUInt]()
        except e:
            print("Error occurred in PluginTest1/TestProducer.mojo, ", e)
            return Self()

    fn produce(mut self, mut event: Event, ref eventSetup: EventSetup):
        try:
            var value = (
                event.get[FEDRawDataCollection](self._rawGetToken)
                .FEDData(1200)
                .size()
            )
            print(
                "TestProducer  Event ",
                event.eventID(),
                " stream ",
                event.streamID(),
                " ES int ",
                eventSetup.get[TypeableInt]().val,
                " FED 1200 size ",
                value,
                sep="",
            )
            sleep(0.01)
            event.put[TypeableUInt](
                self._putToken,
                TypeableUInt(UInt(event.eventID() + 10 * event.streamID() + 100)),
            )
        except e:
            print("Error occurred in PluginTest1/TestProducer.mojo, ", e)

    @always_inline
    @staticmethod
    fn dtype() -> String:
        return "TestProducer"

    fn endJob(mut self):
        pass
