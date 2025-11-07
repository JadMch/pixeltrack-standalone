from MojoSerial.Framework.ESPluginFactory import fwkEventSetupModule
from MojoSerial.Framework.PluginFactory import fwkModule

from MojoSerial.PluginBeamSpotProducer.BeamSpotESProducer import (
    BeamSpotESProducer,
)
from MojoSerial.PluginBeamSpotProducer.BeamSpotToPOD import (
    BeamSpotToPOD,
)


fn init(
    mut esreg: MojoSerial.Framework.ESPluginFactory.Registry,
    mut edreg: MojoSerial.Framework.PluginFactory.Registry,
):
    fwkEventSetupModule[BeamSpotESProducer](esreg)
    fwkModule[BeamSpotToPOD](edreg)
