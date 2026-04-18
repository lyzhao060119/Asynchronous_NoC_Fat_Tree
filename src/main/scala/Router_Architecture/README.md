# Router_Architecture Layout

This directory is organized from top-level shells down to leaf modules:

```text
Router_Architecture/
├─ algorithm/
│  ├─ RoutingLogic_quadtree.scala
│  └─ RoutingLogic_top_layer.scala
├─ common/
│  ├─ async/
│  │  ├─ AsyncArbiter.scala
│  │  ├─ AsyncArbiterRequestSelector.scala
│  │  ├─ AsyncFifo.scala
│  │  ├─ AsyncFork.scala
│  │  ├─ AsyncForkAckJoinBlock.scala
│  │  ├─ AsyncForkRequestBlock.scala
│  │  ├─ AsyncOutputBuffer.scala
│  │  └─ AsyncStage.scala
│  └─ config/
│     ├─ RouterDirGroupedHSIO.scala
│     └─ RouterModuleConfig.scala
├─ core/
│  ├─ RouterCoreModule.scala
│  ├─ RouterTop_Module.scala
│  └─ RouterTree_Module.scala
├─ instantiation/
│  ├─ RouterL1.scala
│  ├─ RouterL2.scala
│  ├─ RouterL3.scala
│  └─ RouterTop.scala
├─ ipm/
│  ├─ RouterIPM.scala
│  ├─ InputControlModule.scala
│  ├─ InputPortModule.scala
│  ├─ control/
│  │  ├─ LaneReservation.scala
│  │  ├─ PacketRouteSelector.scala
│  │  └─ RouterMulticastRequestMaskModule.scala
│  ├─ datapath/
│  │  ├─ InputBuffer.scala
│  │  ├─ RouterInputDatapathModule.scala
│  │  └─ RouterInputRequestGeneratorModule.scala
│  └─ state/
│     └─ RouterPacketContextModule.scala
└─ opm/
   ├─ RouterOPM.scala
   ├─ control/
   │  └─ RouterOutputRequestSelectorModule.scala
   ├─ port/
   │  └─ RouterOutputPortModule.scala
   └─ state/
      └─ RouterOutputPathStateModule.scala
```

Reading order:

1. `core/` and `instantiation/` describe how routers are assembled and instantiated.
2. `ipm/` and `opm/` describe the two halves of one router.
3. `control/`, `datapath/`, and `state/` split each half into decision logic, flit movement, and packet ownership state.
4. `common/async/` contains reusable asynchronous handshake primitives.
