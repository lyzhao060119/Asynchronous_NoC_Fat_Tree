"""Flit-level DES: 5-slot 1-write/4-read buffer, packet-lifetime grant, no U-turn."""

from __future__ import annotations

import heapq
from collections import defaultdict, deque
from dataclasses import dataclass, field
from random import Random
from typing import Any, Callable

from date_v3.event_record import validate_event_record
from date_v3.route_oracle import pe_xy
from date_v3.tmax import tmax_ns

from . import MODEL_VERSION, PHYSICAL_CLASS
from .route import route_mask
from .timing import DEFAULT_CASE_TICK_NS, TimingTable
from .topology import (
    Network,
    RouterSpec,
    dir_of_phys,
    lanes_of,
    legal_output_directions,
    phys_index,
)

CELL_COUNT = 5
BRANCH_COUNT = 4


def _mix_seed(base: int, text: str) -> int:
    h = base & 0xFFFFFFFF
    for ch in text:
        h = (h * 1664525 + ord(ch) + 1013904223) & 0xFFFFFFFF
    return h


@dataclass
class Flit:
    pkt_seq: int
    packet_id: str
    original_event_id: str
    flit_idx: int
    is_head: bool
    is_tail: bool
    source: int
    rect: tuple[int, int, int, int]
    phase: str = "measurement"
    destinations: list[int] = field(default_factory=list)


@dataclass
class PacketTrace:
    original_event_id: str
    packet_id: str
    pkt_seq: int
    source: int
    destinations: list[int]
    phase: str
    t_offer: float | None = None
    t_head_inject: float | None = None
    t_last_tail: float | None = None
    delivered: set[int] = field(default_factory=set)
    routers: list[str] = field(default_factory=list)
    links: list[str] = field(default_factory=list)
    top_mesh_injection: int = 0
    top_mesh_link_traversal: int = 0
    router_set: set[str] = field(default_factory=set)


class EventQueue:
    def __init__(self) -> None:
        self.pq: list[tuple[float, int, Callable[[], None]]] = []
        self.seq = 0
        self.now = 0.0

    def call_at(self, t: float, fn: Callable[[], None]) -> None:
        if t + 1e-15 < self.now:
            raise RuntimeError("negative time: schedule %.12f before now %.12f" % (t, self.now))
        heapq.heappush(self.pq, (t, self.seq, fn))
        self.seq += 1

    def run(self, t_limit: float) -> None:
        while self.pq:
            t, _seq, fn = heapq.heappop(self.pq)
            if t > t_limit:
                heapq.heappush(self.pq, (t, _seq, fn))
                break
            self.now = t
            fn()


class IPM:
    def __init__(self, router: "RouterSim", port: int):
        self.router = router
        self.port = port
        self.ingress_dir = dir_of_phys(router.spec.child_lanes, port)
        self.cells: list[Flit | None] = [None] * CELL_COUNT
        self.readers_left = [0] * CELL_COUNT
        self.write_ptr = 0
        self.read_ptr = [0] * BRANCH_COUNT
        self.busy = [False] * BRANCH_COUNT
        self.enabled = [False] * BRANCH_COUNT
        self.lane = [0] * BRANCH_COUNT
        self.inbox: deque[tuple[Flit, float, Callable[[], None] | None]] = deque()
        self.packet_id: str | None = None
        self.pending_depart: list[tuple | None] = [None] * BRANCH_COUNT
        self.nic_waiters: list[int] = []

    @property
    def occ(self) -> int:
        return sum(1 for cell in self.cells if cell is not None)

    def credit(self) -> bool:
        return self.occ + len(self.inbox) < CELL_COUNT

    def can_write(self, flit: Flit) -> bool:
        if self.occ >= CELL_COUNT or self.cells[self.write_ptr] is not None:
            return False
        if flit.is_head and (any(self.enabled) or any(self.busy)):
            return False
        if (not flit.is_head) and self.packet_id is not None and flit.packet_id != self.packet_id and any(
            self.enabled
        ):
            return False
        return True

    def offer(self, flit: Flit, t: float, ack: Callable[[], None] | None) -> None:
        self.inbox.append((flit, t, ack))
        self.router.sim.kick(self.router)

    def progress(self, t: float) -> None:
        while self.inbox and self.occ < CELL_COUNT:
            flit, _offered, ack = self.inbox[0]
            if not self.can_write(flit):
                break
            slot = self.write_ptr
            if self.cells[slot] is not None:
                break
            self.inbox.popleft()
            if flit.is_head:
                self._arm_head(flit)
            self.cells[slot] = flit
            self.readers_left[slot] = BRANCH_COUNT
            self.write_ptr = (self.write_ptr + 1) % CELL_COUNT
            key = (self.router.spec.id, flit.pkt_seq, flit.flit_idx)
            self.router.sim.flit_in[key] = t
            if flit.is_head:
                pkt = self.router.sim.packets[flit.pkt_seq]
                if pkt.t_head_inject is None:
                    pkt.t_head_inject = t
                if self.router.spec.id not in pkt.router_set:
                    pkt.router_set.add(self.router.spec.id)
                    pkt.routers.append(self.router.spec.id)
            dummy = [i for i in range(BRANCH_COUNT) if not self.enabled[i]]
            for branch in dummy:
                self._complete_reader(branch, slot, t, dummy=True)
            if not flit.is_tail:
                if ack:
                    ack()
            else:
                if self.readers_left[slot] == 0:
                    if ack:
                        ack()
                else:
                    self.router.pending_tail_ack[self.port, slot] = ack
        for branch in range(BRANCH_COUNT):
            self._try_branch(branch, t)
        self._wake_nic()

    def _arm_head(self, flit: Flit) -> None:
        mask = self.router.route_mask(self.ingress_dir, flit.rect)
        dirs = legal_output_directions(self.ingress_dir)
        self.enabled = [False] * BRANCH_COUNT
        self.lane = [0] * BRANCH_COUNT
        self.packet_id = flit.packet_id
        for branch, direction in enumerate(dirs):
            if (mask >> direction) & 1:
                self.enabled[branch] = True
                self.lane[branch] = -1

    def _try_branch(self, branch: int, t: float) -> None:
        if self.pending_depart[branch] is not None:
            payload = self.pending_depart[branch]
            self._depart(*payload)
            return
        if not self.enabled[branch] or self.busy[branch]:
            return
        slot = self.read_ptr[branch]
        flit = self.cells[slot]
        if flit is None:
            return
        dirs = legal_output_directions(self.ingress_dir)
        direction = dirs[branch]
        spec = self.router.spec
        n_lanes = lanes_of(spec.child_lanes, spec.parent_lanes, direction)
        if self.lane[branch] < 0:
            chosen = self.router.pick_lane(direction, n_lanes, flit.packet_id)
            if chosen is None:
                return
            self.lane[branch] = chosen
        out_port = phys_index(spec.child_lanes, direction, self.lane[branch])
        opm = self.router.opms[out_port]
        if not opm.can_accept(self.port, flit.packet_id):
            return
        dest = self.router.sim.downstream(self.router.spec.id, out_port)
        if dest is None:
            self.router.sim.errors.append("no dest %s port %s" % (self.router.spec.id, out_port))
            return
        if not self.router.sim.dest_credit(dest):
            self.router.sim.note_block(self.router.spec.id, dest)
            return
        self.busy[branch] = True
        timing = self.router.timing
        service = timing.service_ns(flit.is_head, flit.is_tail)
        energy = timing.energy_j(flit.is_head, flit.is_tail)
        opm.grant(self.port, flit.packet_id, t)
        self.router.sim.eq.call_at(
            t + service,
            lambda b=branch, s=slot, f=flit, p=out_port, e=energy, d=direction: self._depart(
                b, s, f, p, e, d
            ),
        )

    def _depart(self, branch: int, slot: int, flit: Flit, out_port: int, energy: float, direction: int) -> None:
        t = self.router.sim.eq.now
        dest = self.router.sim.downstream(self.router.spec.id, out_port)
        if dest is None:
            self.busy[branch] = False
            self.pending_depart[branch] = None
            self.router.sim.errors.append("depart no dest %s port %s" % (self.router.spec.id, out_port))
            return
        if not self.router.sim.dest_credit(dest):
            self.pending_depart[branch] = (branch, slot, flit, out_port, energy, direction)
            self.router.sim.note_block(self.router.spec.id, dest)
            return
        self.pending_depart[branch] = None
        self.router.sim.energy_hops += energy
        self.router.sim.n_departs += 1
        self.router.busy_ns += self.router.timing.service_ns(flit.is_head, flit.is_tail)
        pkt = self.router.sim.packets[flit.pkt_seq]
        here = self.router.spec.id
        key = (here, flit.pkt_seq, flit.flit_idx)
        t_in = self.router.sim.flit_in.get(key, t)
        self.router.sim.hop_log.append(
            {
                "pkt_seq": flit.pkt_seq,
                "flit_idx": flit.flit_idx,
                "router": here,
                "out_port": out_port,
                "t_in": t_in,
                "t_out": t,
                "hop_ns": t - t_in,
                "is_head": flit.is_head,
                "is_tail": flit.is_tail,
            }
        )
        if dest[0] == "PE":
            self.router.sim.deliver(dest[1], flit, t)
        elif dest[0] == "SINK":
            self.router.sim.capture_sink(flit, t)
        else:
            dst_id, dst_port = dest
            link = "%s->%s" % (here, dst_id)
            if flit.is_head:
                pkt.links.append(link)
                if here.startswith("L3") and dst_id.startswith("MESH"):
                    pkt.top_mesh_injection += 1
                if here.startswith("MESH") and dst_id.startswith("MESH"):
                    pkt.top_mesh_link_traversal += 1
            delay = self.router.timing.link_ns
            if delay <= 0.0:
                self.router.sim.arrive(dst_id, dst_port, flit)
            else:
                self.router.sim.eq.call_at(
                    t + delay,
                    lambda: self.router.sim.arrive(dst_id, dst_port, flit),
                )
        inject = self.router.sim.net.inject.get(flit.source)
        if inject and inject[0] == here:
            seen = (flit.pkt_seq, flit.flit_idx)
            if seen not in self.router.sim.nic_rx_seen:
                self.router.sim.nic_rx_seen.add(seen)
                self.router.sim._note_rx(flit.source)
        if flit.is_tail:
            self.router.opms[out_port].release(self.port, flit.packet_id)
            self.enabled[branch] = False
            self.lane[branch] = -1
        self._complete_reader(branch, slot, t, dummy=False)
        self.busy[branch] = False
        if not any(self.enabled) and not any(self.busy):
            self.packet_id = None
        self.router.sim.kick(self.router)

    def _complete_reader(self, branch: int, slot: int, t: float, *, dummy: bool) -> None:
        if dummy:
            self.read_ptr[branch] = (self.read_ptr[branch] + 1) % CELL_COUNT
        else:
            self.read_ptr[branch] = (slot + 1) % CELL_COUNT
        if self.readers_left[slot] <= 0:
            return
        self.readers_left[slot] -= 1
        if self.readers_left[slot] == 0:
            self.cells[slot] = None
            ack = self.router.pending_tail_ack.pop((self.port, slot), None)
            if ack:
                ack()
            self.router.sim.wake_waiters((self.router.spec.id, self.port))
            self._wake_nic()

    def _wake_nic(self) -> None:
        waiters = self.nic_waiters
        self.nic_waiters = []
        for src in waiters:
            self.router.sim._nic(src)


class OPM:
    def __init__(self, router: "RouterSim", port: int):
        self.router = router
        self.port = port
        self.holder: tuple[int, str] | None = None

    def can_accept(self, src_port: int, packet_id: str) -> bool:
        if self.holder is None:
            return True
        return self.holder == (src_port, packet_id)

    def grant(self, src_port: int, packet_id: str, t: float) -> None:
        self.holder = (src_port, packet_id)

    def release(self, src_port: int, packet_id: str) -> None:
        if self.holder == (src_port, packet_id):
            self.holder = None

    def other_grant(self, ignore_src: int | None = None) -> bool:
        if self.holder is None:
            return False
        if ignore_src is None:
            return True
        return self.holder[0] != ignore_src


class RouterSim:
    def __init__(self, spec: RouterSpec, sim: "Simulator"):
        self.spec = spec
        self.sim = sim
        self.timing = sim.timing.require(spec.primitive_id)
        self.ipms = [IPM(self, port) for port in range(spec.n_ports)]
        self.opms = [OPM(self, port) for port in range(spec.n_ports)]
        self.pending_tail_ack: dict[tuple[int, int], Callable[[], None] | None] = {}
        self.busy_ns = 0.0
        self.rng = Random(_mix_seed(sim.arb_seed, spec.id))
        self.max_occ = 0

    def pick_lane(self, direction: int, n_lanes: int, packet_id: str) -> int | None:
        free = []
        for lane in range(n_lanes):
            port = phys_index(self.spec.child_lanes, direction, lane)
            opm = self.opms[port]
            if opm.holder is None or opm.holder[1] == packet_id:
                free.append(lane)
        if not free:
            return None
        if len(free) == 1:
            return free[0]
        return self.rng.choice(free)

    def route_mask(self, ingress_dir: int, rect: tuple[int, int, int, int]) -> int:
        return route_mask(self.spec, ingress_dir, rect)

    def progress(self, t: float) -> None:
        for ipm in self.ipms:
            ipm.progress(t)
            if ipm.occ > self.max_occ:
                self.max_occ = ipm.occ


class Simulator:
    def __init__(
        self,
        net: Network,
        timing: TimingTable,
        *,
        arb_seed: int = 1,
        case_tick_ns: float = DEFAULT_CASE_TICK_NS,
        wait_rx: bool = False,
        t_limit: float = 1e9,
    ):
        self.net = net
        self.timing = timing
        self.arb_seed = arb_seed
        self.case_tick_ns = case_tick_ns
        self.wait_rx = wait_rx
        self.t_limit = t_limit
        self.eq = EventQueue()
        self.routers = {rid: RouterSim(spec, self) for rid, spec in net.routers.items()}
        self.packets: dict[int, PacketTrace] = {}
        self.errors: list[str] = []
        self.energy_hops = 0.0
        self.n_departs = 0
        self.kick_set: set[str] = set()
        self.nic_wait_rx: dict[int, int] = {}
        self.nic_rx_seen: set[tuple[int, int]] = set()
        self.flit_in: dict[tuple[int, int], float] = {}
        self.hop_log: list[dict[str, Any]] = []
        self.blocked: dict[tuple, set[str]] = defaultdict(set)
        self.src_q: dict[int, deque] = defaultdict(deque)
        self._kicking = False
        self._kick_steps = 0

    def kick(self, router: RouterSim) -> None:
        self.kick_set.add(router.spec.id)
        if self._kicking:
            return
        self._kicking = True
        try:
            while self.kick_set:
                self._kick_steps += 1
                if self._kick_steps > 5_000_000:
                    self.errors.append("kick_livelock")
                    self.kick_set.clear()
                    break
                rid = min(self.kick_set)
                self.kick_set.remove(rid)
                self.routers[rid].progress(self.eq.now)
        finally:
            self._kicking = False

    def downstream(self, router_id: str, port: int) -> tuple | None:
        key = (router_id, port)
        if key in self.net.eject:
            return ("PE", self.net.eject[key])
        if key in self.net.links:
            dst = self.net.links[key]
            return dst
        if key in self.net.dangling:
            return ("SINK", 0)
        return None

    def dest_credit(self, dest: tuple) -> bool:
        if dest[0] in ("PE", "SINK"):
            return True
        dst_id, dst_port = dest
        ipm = self.routers[dst_id].ipms[dst_port]
        return ipm.credit()

    def note_block(self, router_id: str, dest: tuple) -> None:
        self.blocked[dest].add(router_id)

    def wake_waiters(self, dest: tuple | None) -> None:
        if dest is None:
            return
        waiters = self.blocked.pop(dest, set())
        for rid in sorted(waiters):
            self.kick(self.routers[rid])

    def arrive(self, router_id: str, port: int, flit: Flit) -> None:
        def ack() -> None:
            return None

        self.routers[router_id].ipms[port].offer(flit, self.eq.now, ack)
        self.kick(self.routers[router_id])

    def deliver(self, pe: int, flit: Flit, t: float) -> None:
        pkt = self.packets[flit.pkt_seq]
        if flit.is_tail:
            if pe in pkt.delivered:
                self.errors.append("duplicate:%s:%s" % (pkt.packet_id, pe))
            pkt.delivered.add(pe)
            pkt.t_last_tail = t if pkt.t_last_tail is None else max(pkt.t_last_tail, t)

    def capture_sink(self, flit: Flit, t: float) -> None:
        pkt = self.packets[flit.pkt_seq]
        if flit.is_tail and pkt.t_last_tail is None:
            pkt.t_last_tail = t

    def _note_rx(self, source: int) -> None:
        if self.wait_rx:
            self.nic_wait_rx[source] = self.nic_wait_rx.get(source, 0) + 1
            self._nic(source)

    def grants_leaked(self) -> list[str]:
        leaked = []
        for router in self.routers.values():
            for opm in router.opms:
                if opm.holder is not None:
                    leaked.append("%s opm %s" % (router.spec.id, opm.port))
            for ipm in router.ipms:
                if ipm.occ or ipm.inbox or any(ipm.busy) or any(ipm.enabled):
                    leaked.append("%s ipm %s occ=%s" % (router.spec.id, ipm.port, ipm.occ))
        return leaked

    def load_packets(self, packets: list[dict[str, Any]]) -> None:
        for row in packets:
            pkt_seq = int(row["pkt_seq"])
            rect = tuple(int(v) for v in row["rect"])
            dests = list(row.get("destinations") or row.get("intended_destinations") or [])
            self.packets[pkt_seq] = PacketTrace(
                original_event_id=str(row["original_event_id"]),
                packet_id=str(row.get("packet_id") or ("%s#%s" % (row["original_event_id"], pkt_seq))),
                pkt_seq=pkt_seq,
                source=int(row["source"]),
                destinations=dests,
                phase=str(row.get("phase") or "measurement"),
            )
            ready = int(row["ready_cycle"])
            source = int(row["source"])
            n_flits = len(row.get("flits") or [0] * 5)
            for idx in range(n_flits):
                flit = Flit(
                    pkt_seq=pkt_seq,
                    packet_id=self.packets[pkt_seq].packet_id,
                    original_event_id=self.packets[pkt_seq].original_event_id,
                    flit_idx=idx,
                    is_head=(idx == 0),
                    is_tail=(idx == n_flits - 1),
                    source=source,
                    rect=rect,  # type: ignore[arg-type]
                    phase=self.packets[pkt_seq].phase,
                    destinations=dests,
                )
                due = (ready + idx) * self.case_tick_ns
                self.src_q[source].append((due, pkt_seq, flit))
        for source, queue in list(self.src_q.items()):
            # One NIC per PE: keep a packet's flits contiguous.  Do not
            # interleave later Heads in front of an earlier packet's Body.
            ordered = deque(sorted(queue, key=lambda item: (item[1], item[2].flit_idx)))
            self.src_q[source] = ordered
            if ordered:
                self.eq.call_at(ordered[0][0], lambda src=source: self._nic(src))

    def _nic(self, source: int) -> None:
        queue = self.src_q.get(source)
        if not queue:
            return
        due, _seq, flit = queue[0]
        now = self.eq.now
        if now + 1e-15 < due:
            self.eq.call_at(due, lambda: self._nic(source))
            return
        if source not in self.net.inject:
            self.errors.append("no inject port for PE %s" % source)
            return
        if self.wait_rx and flit.flit_idx > 0 and self.nic_wait_rx.get(source, 0) < flit.flit_idx:
            return
        rid, port = self.net.inject[source]
        ipm = self.routers[rid].ipms[port]
        if not ipm.credit():
            if source not in ipm.nic_waiters:
                ipm.nic_waiters.append(source)
            return
        pkt = self.packets[flit.pkt_seq]
        if pkt.t_offer is None:
            pkt.t_offer = due
        queue.popleft()

        def ack() -> None:
            nxt = self.src_q.get(source)
            if nxt:
                ndue = nxt[0][0]
                self.eq.call_at(max(self.eq.now, ndue), lambda: self._nic(source))

        ipm.offer(flit, self.eq.now, ack)
        self.kick(self.routers[rid])

    def run(self) -> dict[str, Any]:
        last_due = 0.0
        if self.eq.pq:
            last_due = max(t for t, _s, _f in self.eq.pq)
        self.eq.run(min(self.t_limit, last_due + 5e6))
        leaked = self.grants_leaked()
        if leaked:
            self.errors.extend("grant_leak:" + item for item in leaked[:8])
        return self.result()

    def result(self) -> dict[str, Any]:
        records = []
        by_event: dict[str, list[PacketTrace]] = defaultdict(list)
        for pkt in self.packets.values():
            by_event[pkt.original_event_id].append(pkt)
        for event_id, group in sorted(by_event.items()):
            dests = []
            delivered = set()
            routers: list[str] = []
            links: list[str] = []
            heads = []
            tails = []
            offers = []
            top_inj = 0
            top_links = 0
            packet_ids = []
            source = group[0].source
            phase = group[0].phase
            for pkt in group:
                dests.extend(pkt.destinations)
                delivered |= pkt.delivered
                for router in pkt.routers:
                    if router not in routers:
                        routers.append(router)
                links.extend(pkt.links)
                if pkt.t_head_inject is not None:
                    heads.append(pkt.t_head_inject)
                if pkt.t_last_tail is not None:
                    tails.append(pkt.t_last_tail)
                if pkt.t_offer is not None:
                    offers.append(pkt.t_offer)
                top_inj += pkt.top_mesh_injection
                top_links += pkt.top_mesh_link_traversal
                packet_ids.append(pkt.packet_id)
            intended = sorted(set(dests))
            t_head = min(heads) if heads else None
            t_last = max(tails) if tails else None
            missing = [d for d in intended if d not in delivered]
            rec = {
                "original_event_id": event_id,
                "packet_id": packet_ids[0] if len(packet_ids) == 1 else packet_ids,
                "source": source,
                "destination_set": intended,
                "t_offer": min(offers) if offers else None,
                "t_head_inject": t_head,
                "t_last_tail": t_last,
                "delivered_destinations": sorted(delivered),
                "router_traversal": routers,
                "link_traversal": links,
                "top_mesh_injection": top_inj,
                "top_mesh_link_traversal": top_links,
                "queue_occupancy": {
                    rid: router.max_occ for rid, router in self.routers.items() if router.max_occ
                },
                "errors": list(self.errors) + ["missing_dest:%s" % d for d in missing],
                "phase": phase,
                "tmax_ns": tmax_ns(t_last, t_head) if t_head is not None and t_last is not None else None,
            }
            validate_event_record(rec, label=event_id)
            records.append(rec)
        idle = 0.0
        sim_t = self.eq.now
        for router in self.routers.values():
            idle += router.timing.idle_power_w * sim_t * 1e-9
        return {
            "schema": "date-v3-des-result-v1",
            "model_version": MODEL_VERSION,
            "physical_class": PHYSICAL_CLASS,
            "calibration_hash": self.timing.file_hash,
            "design_id": self.net.design_id,
            "arb_seed": self.arb_seed,
            "errors": list(self.errors),
            "n_departs": self.n_departs,
            "energy_hop_j": self.energy_hops,
            "energy_idle_j": idle,
            "energy_total_j": self.energy_hops + idle,
            "sim_ns": sim_t,
            "records": records,
        }


def packets_from_unicast(
    source: int,
    dest: int,
    width: int,
    *,
    pkt_seq: int = 0,
    ready_cycle: int = 0,
    flits: int = 5,
) -> list[dict[str, Any]]:
    dx, dy = pe_xy(dest, width)
    return [
        {
            "pkt_seq": pkt_seq,
            "original_event_id": "e%06d" % pkt_seq,
            "packet_id": "e%06d#0" % pkt_seq,
            "phase": "measurement",
            "source": source,
            "destinations": [dest],
            "rect": [dx, dy, dx, dy],
            "ready_cycle": ready_cycle,
            "flits": ["0"] * flits,
        }
    ]
