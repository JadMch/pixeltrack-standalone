from MojoSerial.Framework.PluginFactory import fwkModule

from MojoSerial.PluginTest2.TestProducer2 import TestProducer2
from MojoSerial.PluginTest2.TestProducer3 import TestProducer3


fn init(
    mut esreg: MojoSerial.Framework.ESPluginFactory.Registry,
    mut edreg: MojoSerial.Framework.PluginFactory.Registry,
):
    fwkModule[TestProducer2](edreg)
    fwkModule[TestProducer3](edreg)
