package Router_Architecture.CMR

import Router_Architecture.common.RouterModuleConfig
import org.scalatest.flatspec.AnyFlatSpec

class CMRStaticLaneMappingSpec extends AnyFlatSpec {
  private val c1p4 = RouterModuleConfig(
    childLanes = 1,
    parentLanes = 4,
    fifoDepth = CMRParameters.CellCount,
    vcCount = 1,
    allowSameDirChild = false,
    allowSameDirParent = false
  )

  "Static4 upward mapping" should "map child directions bijectively to parent output lanes" in {
    val mapping = (0 until 4).map { childDirection =>
      val ingress = c1p4.physIndex(childDirection, 0)
      CMRStaticLaneMapping.parentOutputLane(c1p4, ingress)
    }
    assert(mapping == Seq(0, 1, 2, 3))
    assert(mapping.distinct.size == 4)
  }

  it should "never classify a parent ingress as a statically mapped upward input" in {
    for (parentLane <- 0 until 4) {
      val ingress = c1p4.physIndex(c1p4.parentDir, parentLane)
      assertThrows[IllegalArgumentException] {
        CMRStaticLaneMapping.parentOutputLane(c1p4, ingress)
      }
    }
  }

  it should "preserve downward reachability from every parent lane to every child direction" in {
    for {
      parentLane <- 0 until 4
      childDirection <- 0 until 4
    } {
      val parentIngress = c1p4.physIndex(c1p4.parentDir, parentLane)
      val childOutput = c1p4.physIndex(childDirection, 0)
      assert(c1p4.canConnect(parentIngress, childOutput),
        s"parent lane $parentLane cannot reach child direction $childDirection")
      assert(CMRParameters.legalOutputDirections(c1p4, parentIngress).contains(childDirection))
    }
  }

  it should "retain every bidirectional L1-L2 physical connection" in {
    // PROPtemp wiring: L1 parent(k) <-> L2(k) child((~i)&3).
    val links = for {
      l1Index <- 0 until 4
      l2Index <- 0 until 4
    } yield {
      val l1ParentLane = l2Index
      val l2ChildDirection = (~l1Index) & 3
      (l1Index, l1ParentLane, l2Index, l2ChildDirection)
    }
    assert(links.size == 16)
    assert(links.distinct.size == 16)
    for (l2Index <- 0 until 4; l1Index <- 0 until 4) {
      assert(links.exists(link => link._1 == l1Index && link._3 == l2Index))
    }
  }
}
