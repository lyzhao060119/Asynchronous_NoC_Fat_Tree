package Router_Architecture.CMR

import org.scalatest.flatspec.AnyFlatSpec

/** TopMesh (2,2) shares PROP (2,2) lane adapters; routing is direction-level. */
class CMRTopMeshGeometrySpec extends AnyFlatSpec {
  "expectedLaneAdapters" should "match the DATE V3 structure freeze table" in {
    assert(CMRParameters.expectedLaneAdapters(1, 1) == 0)
    assert(CMRParameters.expectedLaneAdapters(1, 2) == 4)
    assert(CMRParameters.expectedLaneAdapters(2, 2) == 40)
    assert(CMRParameters.expectedLaneAdapters(2, 4) == 48)
    assert(CMRParameters.expectedLaneAdapters(4, 8) == 96)
  }

  it should "give TopMesh2 the same adapter count as PROP 2x2" in {
    assert(
      CMRParameters.expectedLaneAdapters(2, 2) ==
        CMRParameters.expectedLaneAdapters(2, 2)
    )
    assert(CMRParameters.SupportedLaneGeometries.contains((2, 2)))
  }
}
