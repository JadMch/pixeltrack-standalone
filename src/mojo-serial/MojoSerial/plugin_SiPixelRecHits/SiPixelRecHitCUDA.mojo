from MojoSerial.Framework.Event import Event
from MojoSerial.Framework.EDProducer import EDProducer
from MojoSerial.Framework.EventSetup import EventSetup
from MojoSerial.Framework.EDGetToken import EDGetTokenT
from MojoSerial.Framework.EDPutToken import EDPutTokenT
from MojoSerial.Framework.ProductRegistry import ProductRegistry

from MojoSerial.DataFormats.BeamSpotPOD import BeamSpotPOD
from MojoSerial.CUDADataFormats.SiPixelClustersSoA import SiPixelClustersSoA
from MojoSerial.CUDADataFormats.SiPixelDigisSoA import SiPixelDigisSoA
from MojoSerial.CondFormats.PixelCPEFast import PixelCPEFast
from MojoSerial.CUDADataFormats.TrackingRecHit2DHeterogeneous import (
    TrackingRecHit2DCPU,
)
from MojoSerial.CUDADataFormats.TrackingRecHit2DSOAView import (
    TrackingRecHit2DSOAView,
)
from MojoSerial.plugin_SiPixelRecHits.PixelRecHits import (
    PixelRecHitGPUKernel,
)  # TODO : spit product from kernel
from MojoSerial.MojoBridge.DTypes import Typeable


struct SiPixelRecHitCUDA(Defaultable, EDProducer, Typeable):
    # The mess with inputs will be cleaned up when migrating to the new framework
    var tBeamSpot: EDGetTokenT[BeamSpotPOD]
    var token_: EDGetTokenT[SiPixelClustersSoA]
    var tokenDigi_: EDGetTokenT[SiPixelDigisSoA]

    var tokenHit_: EDPutTokenT[TrackingRecHit2DCPU]

    var gpuAlgo_: PixelRecHitGPUKernel

    fn __init__(out self):
        self.tBeamSpot = EDGetTokenT[BeamSpotPOD]()
        self.token_ = EDGetTokenT[SiPixelClustersSoA]()
        self.tokenDigi_ = EDGetTokenT[SiPixelDigisSoA]()
        self.tokenHit_ = EDPutTokenT[TrackingRecHit2DCPU]()

        self.gpuAlgo_ = PixelRecHitGPUKernel()

    fn __init__(out self, mut reg: ProductRegistry):
        try:
            self.tBeamSpot = reg.consumes[BeamSpotPOD]()
            self.token_ = reg.consumes[SiPixelClustersSoA]()
            self.tokenDigi_ = reg.consumes[SiPixelDigisSoA]()
            self.tokenHit_ = reg.produces[TrackingRecHit2DCPU]()
        except e:
            print("Handled exception in SiPixelRecHitCUDA, ", e)
            return Self()

        self.gpuAlgo_ = PixelRecHitGPUKernel()

    fn produce(mut self, mut iEvent: Event, ref es: EventSetup):
        ref clusters = iEvent.get(self.token_)
        ref digis = iEvent.get(self.tokenDigi_)
        ref bs = iEvent.get(self.tBeamSpot)

        var nHits = clusters.nClusters()

        if nHits >= TrackingRecHit2DSOAView.maxHits():
            print(
                "Clusters/Hits Overflow ",
                nHits,
                " ]= ",
                TrackingRecHit2DSOAView.maxHits(),
                sep="",
            )

        try:
            var hits = self.gpuAlgo_.makeHits(
                digis,
                clusters,
                bs,
                UnsafePointer(to=es.get[PixelCPEFast]().getCPUProduct()),
            )

            var hv = hits.view()

            var sumXL: Float64 = 0.0
            var sumYL: Float64 = 0.0
            var sumXG: Float64 = 0.0
            var sumYG: Float64 = 0.0
            var sumZG: Float64 = 0.0
            var sumRG: Float64 = 0.0
            var sumCharge: Int64 = 0
            var sumSizeX: Int64 = 0
            var sumSizeY: Int64 = 0
            var sumDet: Int64 = 0
            var sumIphi: Int64 = 0

            for i in range(Int(hv[].nHits())):
                sumXL += Float64(hv[].xLocal(i))
                sumYL += Float64(hv[].yLocal(i))
                sumXG += Float64(hv[].xGlobal(i))
                sumYG += Float64(hv[].yGlobal(i))
                sumZG += Float64(hv[].zGlobal(i))
                sumRG += Float64(hv[].rGlobal(i))
                sumCharge += Int64(hv[].charge(i))
                sumSizeX += Int64(hv[].clusterSizeX(i))
                sumSizeY += Int64(hv[].clusterSizeY(i))
                sumDet += Int64(hv[].detectorIndex(i))
                sumIphi += Int64(hv[].iphi(i))

            print(
                "[mojo-final-summary]",
                " event=", iEvent.eventID(),
                " nDigis=", digis.nDigis(),
                " nClusters=", clusters.nClusters(),
                " nHits=", hv[].nHits(),
                " sumCharge=", sumCharge,
                " sumSizeX=", sumSizeX,
                " sumSizeY=", sumSizeY,
                " sumDet=", sumDet,
                " sumIphi=", sumIphi,
                " sumXL=", sumXL,
                " sumYL=", sumYL,
                " sumXG=", sumXG,
                " sumYG=", sumYG,
                " sumZG=", sumZG,
                " sumRG=", sumRG,
                sep="",
            )

            print("[mojo-final-layerStart]", " event=", iEvent.eventID(), end="", sep="")
            for i in range(11):
                print(" l", i, "=", hv[].hitsLayerStart()[i], end="", sep="")
            print()

            fn printHit(i: Int, label: String, hv: UnsafePointer[TrackingRecHit2DSOAView], eventID: Int32):
                print(
                    "[mojo-final-hit]",
                    " event=", eventID,
                    " ", label,
                    " i=", i,
                    " det=", hv[].detectorIndex(i),
                    " charge=", hv[].charge(i),
                    " sx=", hv[].clusterSizeX(i),
                    " sy=", hv[].clusterSizeY(i),
                    " iphi=", hv[].iphi(i),
                    " xl=", hv[].xLocal(i),
                    " yl=", hv[].yLocal(i),
                    " xg=", hv[].xGlobal(i),
                    " yg=", hv[].yGlobal(i),
                    " zg=", hv[].zGlobal(i),
                    " rg=", hv[].rGlobal(i),
                    sep="",
                )

            if hv[].nHits() > 0:
                printHit(0, "first", hv, iEvent.eventID())
                printHit(Int(hv[].nHits() // 2), "middle", hv, iEvent.eventID())
                printHit(Int(hv[].nHits() - 1), "last", hv, iEvent.eventID())

            iEvent.put(self.tokenHit_, hits^)
        except e:
            print("Error during produce in SiPixelRecHitCUDA, ", e)

    fn endJob(mut self) raises:
        pass

    @staticmethod
    fn dtype() -> String:
        return "SiPixelRecHitCUDA"
