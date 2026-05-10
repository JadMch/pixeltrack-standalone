#include "CUDADataFormats/SiPixelClustersSoA.h"
#include "CUDADataFormats/SiPixelDigisSoA.h"
#include "CUDADataFormats/TrackingRecHit2DHeterogeneous.h"
#include "DataFormats/BeamSpotPOD.h"
#include "Framework/EventSetup.h"
#include "Framework/Event.h"
#include "Framework/PluginFactory.h"
#include "Framework/EDProducer.h"
#include "CondFormats/PixelCPEFast.h"

#include "PixelRecHits.h"  // TODO : spit product from kernel

class SiPixelRecHitCUDA : public edm::EDProducer {
public:
  explicit SiPixelRecHitCUDA(edm::ProductRegistry& reg);
  ~SiPixelRecHitCUDA() override = default;

private:
  void produce(edm::Event& iEvent, const edm::EventSetup& iSetup) override;

  // The mess with inputs will be cleaned up when migrating to the new framework
  edm::EDGetTokenT<BeamSpotPOD> tBeamSpot;
  edm::EDGetTokenT<SiPixelClustersSoA> token_;
  edm::EDGetTokenT<SiPixelDigisSoA> tokenDigi_;

  edm::EDPutTokenT<TrackingRecHit2DCPU> tokenHit_;

  pixelgpudetails::PixelRecHitGPUKernel gpuAlgo_;
};

SiPixelRecHitCUDA::SiPixelRecHitCUDA(edm::ProductRegistry& reg)
    : tBeamSpot(reg.consumes<BeamSpotPOD>()),
      token_(reg.consumes<SiPixelClustersSoA>()),
      tokenDigi_(reg.consumes<SiPixelDigisSoA>()),
      tokenHit_(reg.produces<TrackingRecHit2DCPU>()) {}

void SiPixelRecHitCUDA::produce(edm::Event& iEvent, const edm::EventSetup& es) {
  PixelCPEFast const& fcpe = es.get<PixelCPEFast>();

  auto const& clusters = iEvent.get(token_);
  auto const& digis = iEvent.get(tokenDigi_);
  auto const& bs = iEvent.get(tBeamSpot);

  auto nHits = clusters.nClusters();
  if (nHits >= TrackingRecHit2DSOAView::maxHits()) {
    std::cout << "Clusters/Hits Overflow " << nHits << " >= " << TrackingRecHit2DSOAView::maxHits() << std::endl;
  }

  auto hits = gpuAlgo_.makeHits(digis, clusters, bs, &fcpe.getCPUProduct());
  auto const* hv = hits.view();

  double sumXL = 0.0;
  double sumYL = 0.0;
  double sumXG = 0.0;
  double sumYG = 0.0;
  double sumZG = 0.0;
  double sumRG = 0.0;
  long long sumCharge = 0;
  long long sumSizeX = 0;
  long long sumSizeY = 0;
  long long sumDet = 0;
  long long sumIphi = 0;

  for (uint32_t i = 0; i < hv->nHits(); ++i) {
    sumXL += hv->xLocal(i);
    sumYL += hv->yLocal(i);
    sumXG += hv->xGlobal(i);
    sumYG += hv->yGlobal(i);
    sumZG += hv->zGlobal(i);
    sumRG += hv->rGlobal(i);
    sumCharge += hv->charge(i);
    sumSizeX += hv->clusterSizeX(i);
    sumSizeY += hv->clusterSizeY(i);
    sumDet += hv->detectorIndex(i);
    sumIphi += hv->iphi(i);
  }

  std::cout << "[serial-final-summary]"
            << " event=" << iEvent.eventID()
            << " nDigis=" << digis.nDigis()
            << " nClusters=" << clusters.nClusters()
            << " nHits=" << hv->nHits()
            << " sumCharge=" << sumCharge
            << " sumSizeX=" << sumSizeX
            << " sumSizeY=" << sumSizeY
            << " sumDet=" << sumDet
            << " sumIphi=" << sumIphi
            << " sumXL=" << sumXL
            << " sumYL=" << sumYL
            << " sumXG=" << sumXG
            << " sumYG=" << sumYG
            << " sumZG=" << sumZG
            << " sumRG=" << sumRG
            << std::endl;

  std::cout << "[serial-final-layerStart]"
            << " event=" << iEvent.eventID();

  for (int i = 0; i < 11; ++i) {
    std::cout << " l" << i << "=" << hv->hitsLayerStart()[i];
  }

  std::cout << std::endl;

  auto printHit = [&](uint32_t i, char const* label) {
    std::cout << "[serial-final-hit]"
              << " event=" << iEvent.eventID()
              << " " << label
              << " i=" << i
              << " det=" << hv->detectorIndex(i)
              << " charge=" << hv->charge(i)
              << " sx=" << hv->clusterSizeX(i)
              << " sy=" << hv->clusterSizeY(i)
              << " iphi=" << hv->iphi(i)
              << " xl=" << hv->xLocal(i)
              << " yl=" << hv->yLocal(i)
              << " xg=" << hv->xGlobal(i)
              << " yg=" << hv->yGlobal(i)
              << " zg=" << hv->zGlobal(i)
              << " rg=" << hv->rGlobal(i)
              << std::endl;
  };

  if (hv->nHits() > 0) {
    printHit(0, "first");
    printHit(hv->nHits() / 2, "middle");
    printHit(hv->nHits() - 1, "last");
  }

  iEvent.emplace(tokenHit_, std::move(hits));
}
DEFINE_FWK_MODULE(SiPixelRecHitCUDA);
