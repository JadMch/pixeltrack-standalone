from pathlib import Path

from MojoSerial.Framework.ProductRegistry import ProductRegistry
from MojoSerial.Framework.EventSetup import EventSetup
from MojoSerial.Framework.ESPluginFactory import ESPluginFactory
from MojoSerial.MojoBridge.DTypes import Typeable
from MojoSerial.Bin.Source import Source
from MojoSerial.Bin.StreamSchedule import StreamSchedule


struct EventProcessor(Defaultable, Typeable):
    # no pluginmanager
    var _registry: ProductRegistry
    var _source: Source
    var _eventSetup: EventSetup
    var _schedule: StreamSchedule
    var _warmupEvents: Int32
    var _maxEvents: Int32
    # no timing information

    @always_inline
    fn __init__(out self):
        self._registry = ProductRegistry()
        self._source = Source()
        self._eventSetup = EventSetup()
        self._schedule = StreamSchedule()
        self._warmupEvents = 0
        self._maxEvents = 0

    fn __init__(
        out self,
        var warmupEvents: Int,
        var maxEvents: Int,
        var path: Path,
        var validation: Bool,
        mut esreg: MojoSerial.Framework.ESPluginFactory.Registry,
        mut edreg: MojoSerial.Framework.PluginFactory.Registry,
    ):
        try:
            self._registry = ProductRegistry()
            self._source = Source(maxEvents, self._registry, path, validation)
            self._eventSetup = EventSetup()
            self._warmupEvents = warmupEvents
            self._maxEvents = maxEvents

            for name in ESPluginFactory.getAll(esreg):
                var esp = ESPluginFactory.create(name, path, esreg)
                esp.produce(self._eventSetup)

            self._schedule = StreamSchedule(
                UnsafePointer(to=self._registry),
                UnsafePointer(to=self._source),
                UnsafePointer(to=self._eventSetup),
                edreg,
            )
        except e:
            print("Error occurred in Bin/EventProcessor.mojo,", e)
            return Self()

    @always_inline
    fn warmUp(mut self):
        if self._warmupEvents <= 0:
            return

        self._source.reconfigure(self._warmupEvents)
        self.process()

    @always_inline
    fn runToCompletion(mut self):
        self._source.reconfigure(self._maxEvents)
        self.process()

    @always_inline
    fn process(mut self):
        self._source.startProcessing()
        self._schedule.run()

    @always_inline
    fn endJob(mut self):
        self._schedule.endJob()

    @always_inline
    fn maxEvents(self) -> Int32:
        return self._maxEvents

    @always_inline
    fn processedEvents(self) -> Int32:
        return self._source.processedEvents()

    @always_inline
    @staticmethod
    fn dtype() -> String:
        return "EventProcessor"
