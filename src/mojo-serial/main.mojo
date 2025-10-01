from sys import argv
from sys.terminate import exit
from time import perf_counter_ns
from pathlib import Path

from MojoSerial.Bin.EventProcessor import EventProcessor
from MojoSerial.Bin.PosixClockGettime import (
    PosixClockGettime,
    CLOCK_PROCESS_CPUTIME_ID,
)
from MojoSerial.MojoBridge.DTypes import Double


fn print_help(ref name: String):
    print(
        "Usage:",
        name,
        "[--warmupEvents WE] [--maxEvents ME] [--runForMinutes RM]",
        "[--data PATH] [--validation] [--histogram] [--empty]",
    )
    print(
        r"""(
Options:
  --warmupEvents                Number of events to process before starting the benchmark (default 0).
  --maxEvents                   Number of events to process (default -1 for all events in the input file).
  --runForMinutes               Continue processing the set of 1000 events until this many minutes have passed
                                (default -1 for disabled; conflicts with --maxEvents).
  --data                        Path to the 'data' directory (default 'data' in the directory of the executable).
  --empty                       Ignore all producers (for testing only).
)"""
    )


fn main() raises:
    var args = argv()
    var warmupEvents = 0
    var maxEvents = -1
    var runForMinutes = -1
    var path = Path("")
    var empty = False

    var i = 1
    while i < args.__len__():
        if args[i] == "-h" or args[i] == "--help":
            print_help(args[0])
            exit(0)
        elif args[i] == "--warmupEvents":
            i += 1
            warmupEvents = Int(args[i])
        elif args[i] == "--maxEvents":
            i += 1
            maxEvents = Int(args[i])
        elif args[i] == "--runForMinutes":
            i += 1
            runForMinutes = Int(args[i])
        elif args[i] == "--data":
            i += 1
            path = Path(args[i])
        elif args[i] == "--empty":
            empty = True
        else:
            print("Invalid parameter", args[i])
            print()
            exit(1)
        i += 1

    if maxEvents >= 0 and runForMinutes >= 0:
        print(
            "Got both --maxEvents and --runForMinutes, please give only one of"
            " them"
        )
        exit(1)

    if not path:
        path = Path("data")

    if not path.exists():
        print("Data directory '", path, "' does not exist", sep="")
        exit(1)

    ## Init plugins manually
    var _esreg = MojoSerial.Framework.ESPluginFactory.Registry()
    var _edreg = MojoSerial.Framework.PluginFactory.Registry()
    if not empty:
        MojoSerial.PluginSiPixelClusterizer.init(_esreg, _edreg)

    var processor = EventProcessor(
        warmupEvents, maxEvents, runForMinutes, path, False, _esreg, _edreg
    )
    if runForMinutes < 0:
        print("Processing", processor.maxEvents(), "events", end="")
    else:
        print("Processing for about", runForMinutes, "minutes", end="")
    if warmupEvents > 0:
        print(" after", warmupEvents, "events of warm up", end="")
    print(", with 1 concurrent events and 1 threads.")

    processor.warmUp()
    var cpu_start = PosixClockGettime[CLOCK_PROCESS_CPUTIME_ID].now()
    var start = perf_counter_ns()
    processor.runToCompletion()
    var cpu_stop = PosixClockGettime[CLOCK_PROCESS_CPUTIME_ID].now()
    var stop = perf_counter_ns()
    processor.endJob()

    # Lifetime registry extension
    _ = _esreg^
    _ = _edreg^

    # Work done, report timing
    var diff = stop - start
    # in seconds
    var time: Double = diff / (10**9)
    var cpu_diff = cpu_stop - cpu_start
    var cpu: Double = cpu_diff / (10**9)
    maxEvents = Int(processor.processedEvents())

    print(
        "Processed ",
        maxEvents,
        " events in ",
        time,
        " seconds, throughput ",
        (maxEvents / time),
        " events/s, CPU usage: ",
        round(cpu / time * 100),
        "%",
        sep="",
    )
