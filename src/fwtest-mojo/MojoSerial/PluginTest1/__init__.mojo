from MojoSerial.Framework.ESPluginFactory import fwkEventSetupModule
from MojoSerial.Framework.PluginFactory import fwkModule

from MojoSerial.PluginTest1.IntESProducer import IntESProducer
from MojoSerial.PluginTest1.TestProducer import TestProducer


fn init(
    mut esreg: MojoSerial.Framework.ESPluginFactory.Registry,
    mut edreg: MojoSerial.Framework.PluginFactory.Registry,
):
    fwkEventSetupModule[IntESProducer](esreg)
    fwkModule[TestProducer](edreg)
