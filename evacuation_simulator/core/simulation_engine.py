#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""
sim_core.py

- 건물 로딩
- width 기반 service_rate_ps 설정
- 다중 에이전트 시뮬레이션
  (노드 서비스율 + 간선 길이 / 보행 속도 + 혼잡도 기반 속도저하)
- A* 경로 탐색 및 재라우팅 로직은 astar_logic.py 에서 담당:
  - 여기서는 필요할 때 should_reroute(), reroute_agent() 만 호출
"""

import json
import random
from collections import defaultdict
from typing import Dict, List, Callable, Tuple

import numpy as np

# 재라우팅 관련 (옵션)
# 재라우팅 관련 (옵션)
from .astar_logic import (
    AStarConfig,
    apply_rerouting_for_nodes,
)



# --------------------------------------------------------
# 1. 건물 로딩
# --------------------------------------------------------

def load_building(path: str) -> dict:
    """nodes + edges + SUPER_EXIT가 들어있는 JSON 로드"""
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


# --------------------------------------------------------
# 2. 노드 동역학 (width → service_rate_ps)
# --------------------------------------------------------

# 타입별 폭 1m당 기본 처리율(명/초/미터), 필요하면 조정
BASE_RATE_PER_M = {
    "hall": 1.5,   # 복도
    "door": 1.2,   # 출입문 (width 1.8 vs 1.0 차이 반영)
    "exit": 2.0,   # 최종 출구(층 출구)
    "stair": 0.8,  # 계단 (느리게)
}


def build_node_dynamics(building: dict) -> Dict[str, dict]:
    """
    각 노드에 대해 service_rate_ps를 설정.
    - door/exit/stair/hall: width * BASE_RATE_PER_M[type]
    - 그 외 타입은 매우 큰 처리율(= 병목 없음)로 가정
    """
    node_dyn: Dict[str, dict] = {}
    for n in building["nodes"]:
        nid = n["id"]
        ntype = n.get("type", "hall")
        width = float(n.get("width", 1.0))

        if ntype in BASE_RATE_PER_M:
            rate_per_m = BASE_RATE_PER_M[ntype]
            s = width * rate_per_m  # [명/초]
        else:
            s = 1e9  # 병목 없는 노드라고 가정

        node_dyn[nid] = {
            "service_rate_ps": s,
            "type": ntype,
            "width": width,
        }
    return node_dyn


# --------------------------------------------------------
# 3. 시뮬 코어
# --------------------------------------------------------

# 에이전트는 최소한 다음 필드를 가짐:
# {
#   "id": int,
#   "path": [node_id, ...],
#   "pos_idx": 0,              # path 상에서 현재 노드 index
#   "done": False,
#   (옵션) "finish_time": float,
#   (옵션) "speed_mps": float,        # 보행 속도 [m/s]
#   (옵션) "phase": "node" / "edge",  # 현재 상태
#   (옵션) "edge_time_left": float,   # 간선 위에서 남은 이동시간 [s]
#   (옵션) "last_move_time": float,   # 마지막으로 노드/edge 이동이 일어난 시각 [s]
#   (옵션) "goal_id": str,            # 재라우팅 시 사용할 최종 목표 노드 (출구)
# }
#
# - "node" phase: 노드 위에 서 있는 상태 (service_rate_ps 영향을 받음)
# - "edge" phase: 노드 사이 간선을 실제로 이동 중인 상태 (거리 / 속도 + 혼잡 영향)

DynamicHook = Callable[[dict, int, List[dict], Dict[str, dict]], None]
# signature: hook(building, t_step, agents, node_dynamics)


def simulate(
    building: dict,
    agents: List[dict],
    floor: str,
    node_dynamics: Dict[str, dict],
    max_steps: int = 10000,
    rng_seed: int | None = 42,
    dynamic_hook: DynamicHook | None = None,
    default_speed_mps: float = 1.3,
    dt: float = 1.0,
    congestion_alpha: float = 0.5,    # 혼잡 민감도 (0이면 혼잡 효과 없음)
    min_speed_factor: float = 0.2,    # 아무리 막혀도 v_eff ≥ v0 * 이 값
    reroute_policy: dict | None = None,
    reroute_cfg: AStarConfig | None = None,
) -> Tuple[np.ndarray, Dict[str, List[int]]]:
    """
    공통 시뮬 엔진.

    - agents: path가 이미 설정된 에이전트 리스트
    - node_dynamics: node_id -> {"service_rate_ps": ...}
    - dynamic_hook: 매 tick마다 불 번짐, 통로 차단 등 업데이트하고 싶을 때 사용
    - default_speed_mps: agent에 speed_mps가 없을 때 기본 보행 속도 [m/s]
    - dt: 한 tick이 의미하는 실제 시간 [초]
    - congestion_alpha: 간선 위 혼잡도(밀도)에 따른 속도저하 강도 (0.3~1.0 정도 조절)
    - min_speed_factor: 혼잡 시 최소 속도 비율 (예: 0.2 → 최소 v0의 20%)
    - reroute_policy / reroute_cfg:
        * 둘 다 None이면 재라우팅 없음
        * 둘 다 주어지면, 노드 위에서 혼잡·정체 조건을 만족하는 에이전트는
          astar_logic.reroute_agent()로 path를 다시 계산
        * 이때, 현재 간선 위 인원수를 edge_congestion 맵으로 만들어
          A* 비용에 반영 (혼잡한 간선일수록 비용↑)한다.
    """
    if rng_seed is not None:
        random.seed(rng_seed)

    # node id -> node dict (width 등 가져오기 용도)
    node_by_id = {n["id"]: n for n in building["nodes"]}

    # (node_a, node_b) -> edge_length 맵 구성
    edge_length: Dict[Tuple[str, str], float] = {}
    for e in building["edges"]:
        if e.get("state", "open") != "open":
            continue
        a = e["node_a"]
        b = e["node_b"]
        L = float(e["length"])
        # 필요하면 아래 줄을 수정: L = float(e["length"]) / 1000.0
        edge_length[(a, b)] = L
        if e.get("directionality") == "bidirectional":
            edge_length[(b, a)] = L

    # 에이전트에 속도 / phase / edge_time_left / last_move_time 기본값 채우기
    for a in agents:
        if "speed_mps" not in a:
            a["speed_mps"] = float(default_speed_mps)
        if "phase" not in a:
            a["phase"] = "node"
        if "edge_time_left" not in a:
            a["edge_time_left"] = 0.0
        if "edge_total_time" not in a:
            a["edge_total_time"] = 0.0
        if "last_move_time" not in a:
            a["last_move_time"] = 0.0

    # --- 간선 위 혼잡 효과를 반영하기 위한 내부 함수 ---

    def effective_edge_speed(agent: dict, cur: str, nxt: str) -> float:
        """
        현재 cur -> nxt 간선에서의 혼잡도를 보고,
        간선 위에서의 유효 속도 v_eff 를 계산.

        - 간선 위에 같은 cur->nxt 를 지나고 있는 사람 수를 세고,
        - 간선 양 끝 노드의 width (door 폭 등)도 병목으로 반영.
        """
        # cur->nxt 를 실제로 밟고 있는 사람 수 세기
        n_edge = 0
        for other in agents:
            if other.get("done"):
                continue
            if other.get("phase") != "edge":
                continue
            if other.get("pos_idx", 0) >= len(other.get("path", [])) - 1:
                continue
            if (
                other["path"][other["pos_idx"]] == cur
                and other["path"][other["pos_idx"] + 1] == nxt
            ):
                n_edge += 1

        # 간선 양 끝 노드의 width 정보 활용 (door 폭 차이 반영)
        w_start = node_by_id.get(cur, {}).get("width", 1.0)
        w_end = node_by_id.get(nxt, {}).get("width", w_start)
        # 너무 작은 값 방지 + 좁은 쪽이 병목이므로 min 사용
        w_eff = max(0.5, min(w_start, w_end))

        # "유효 밀도" 개념: n_edge / w_eff
        density = n_edge / w_eff  # 단위는 적당한 무차원 값으로 해석

        # v_eff = v0 / (1 + α (density - 1)), density <= 1이면 거의 v0
        alpha = max(congestion_alpha, 0.0)
        v0 = float(agent["speed_mps"])
        if alpha <= 0.0:
            factor = 1.0
        else:
            factor = 1.0 / (1.0 + alpha * max(0.0, density - 1.0))

        factor = max(min_speed_factor, factor)
        return v0 * factor

    done_times: List[float] = []
    congestion_log: Dict[str, List[int]] = defaultdict(list)

    t = 0.0   # 실제 시간 [초]
    step = 0  # tick index

    while any(not a.get("done") for a in agents) and step < max_steps:
        # 0) 시나리오 동적 업데이트 (불 번짐 등)
        if dynamic_hook is not None:
            dynamic_hook(building, step, agents, node_dynamics)

        # 1) edge 위를 이동 중인 에이전트 업데이트
        for a in agents:
            if a.get("done"):
                continue
            if a.get("phase") == "edge":
                a["edge_time_left"] -= dt
                if a["edge_time_left"] <= 0.0:
                    # 간선 이동 완료 → 다음 노드 도착
                    a["phase"] = "node"
                    a["edge_time_left"] = 0.0
                    a["pos_idx"] += 1
                    # 노드/edge에서 실제 위치가 바뀐 시각 기록
                    a["last_move_time"] = t

        # 2) 목표 노드(경로 마지막)에 도착한 에이전트 완료 처리
        for a in agents:
            if a.get("done"):
                continue
            if a.get("phase") == "node" and a.get("pos_idx", 0) >= len(a.get("path", [])) - 1:
                a["done"] = True
                a["finish_time"] = t
                done_times.append(t)

        # 3) 노드별 대기 중인 에이전트 수집 (node phase + 미완료)
        node_to_agent_idxs: Dict[str, List[int]] = defaultdict(list)
        for idx, a in enumerate(agents):
            if a.get("done"):
                continue
            if a.get("phase") != "node":
                continue
            path = a.get("path", [])
            if not path:
                continue
            pos_idx = int(a.get("pos_idx", 0))
            pos_idx = max(0, min(pos_idx, len(path) - 1))
            cur = path[pos_idx]
            node_to_agent_idxs[cur].append(idx)

        # 4) 혼잡 기록 (노드 위 사람 수)
        for nid, idxs in node_to_agent_idxs.items():
            congestion_log[nid].append(len(idxs))

        # 4.5) 🔥 현재 간선 위 사람 수로 edge_congestion 맵 구성
        #       (A* 재계산 시 혼잡한 간선 비용을 높이는 데 사용)
        edge_congestion: Dict[Tuple[str, str], float] = defaultdict(float)
        for a in agents:
            if a.get("done"):
                continue
            if a.get("phase") != "edge":
                continue
            path = a.get("path", [])
            if not path:
                continue
            pos_idx = int(a.get("pos_idx", 0))
            if pos_idx >= len(path) - 1:
                continue
            cur = path[pos_idx]
            nxt = path[pos_idx + 1]
            edge_congestion[(cur, nxt)] += 1.0

        # 4.6) 재라우팅 (옵션: 혼잡 / 정체시간 기준)
        if reroute_policy is not None and reroute_cfg is not None:
            apply_rerouting_for_nodes(
                building=building,
                agents=agents,
                node_to_agent_idxs=node_to_agent_idxs,
                current_time=t,
                policy=reroute_policy,
                cfg=reroute_cfg,
                edge_congestion=edge_congestion,  # 👈 이제 실제 혼잡 맵 전달
            )

        # 5) 각 노드에서 service_rate_ps에 따라 edge로 출발 가능한 인원 계산
        movers: set[int] = set()
        for nid, idxs in node_to_agent_idxs.items():
            occ = len(idxs)
            if occ == 0:
                continue

            s = node_dynamics.get(nid, {}).get("service_rate_ps", 1e9)
            q = s * dt  # dt초 동안 통과 가능한 기대 인원 수

            base = int(q)
            frac = q - base
            max_leavers = base
            if random.random() < frac:
                max_leavers += 1

            if max_leavers > occ:
                max_leavers = occ

            # 누가 먼저 나갈지는 랜덤 (줄 서 있는 느낌)
            random.shuffle(idxs)
            for idx in idxs[:max_leavers]:
                movers.add(idx)

        # 6) 실제로 edge로 진입 (노드 → 간선), 혼잡 기반 v_eff 적용
        for idx in movers:
            a = agents[idx]
            if a.get("done"):
                continue
            if a.get("phase") != "node":
                continue

            path = a.get("path", [])
            if not path:
                continue

            # path 마지막 노드라면 더 이상 나갈 edge 없음
            pos_idx = int(a.get("pos_idx", 0))
            if pos_idx >= len(path) - 1:
                continue

            cur = path[pos_idx]
            nxt = path[pos_idx + 1]

            L = edge_length.get((cur, nxt))
            if L is None:
                raise KeyError(f"Edge length not found for ({cur} -> {nxt})")

            # 혼잡도 + width 반영된 유효 속도
            v_eff = max(effective_edge_speed(a, cur, nxt), 1e-6)
            travel_time = L / v_eff  # [초] = [길이] / [m/s]

            a["phase"] = "edge"
            a["edge_time_left"] = travel_time
            a["edge_total_time"] = travel_time
            # edge 진입 시점에 last_move_time 을 갱신하고 싶으면 여기에 넣어도 됨
            # a["last_move_time"] = t

        # 시간 진행
        step += 1
        t += dt

    return np.array(done_times, dtype=float), congestion_log



# --------------------------------------------------------
# 3+. 시각화를 위한 보조 유틸: 간선 중간 위치 보간
# --------------------------------------------------------

import re as _re_local  # for floor index parsing

def _floor_index_of(node: dict) -> int:
    """
    Infer a floor index from node info.
    Prefers 'floor_index' if present; otherwise parse an integer from 'floor' (e.g., 'F2' -> 2).
    Falls back to 0.
    """
    if node is None:
        return 0
    if "floor_index" in node and node["floor_index"] is not None:
        try:
            return int(node["floor_index"])
        except Exception:
            pass
    floor = node.get("floor")
    if isinstance(floor, str):
        m = _re_local.search(r"(-?\d+)", floor)
        if m:
            try:
                return int(m.group(1))
            except Exception:
                return 0
    return 0


def get_node_pos_map(building: dict):
    """
    Returns: node_id -> {'x','y','z','floor','floor_index'}.
    'z' uses floor_index (1 unit per floor) for simple 3D sketches.
    """
    node_pos = {}
    for n in building.get("nodes", []):
        nid = n.get("id")
        pos = n.get("pos", {}) or {}
        x = float(pos.get("x", 0.0))
        y = float(pos.get("y", 0.0))
        fidx = _floor_index_of(n)
        node_pos[nid] = {"x": x, "y": y, "z": float(fidx), "floor": n.get("floor"), "floor_index": fidx}
    return node_pos


def agent_progress(agent: dict) -> float:
    """
    Normalized progress along current edge in [0,1].
    If at a node, returns 0.0.
    """
    if agent.get("phase") != "edge":
        return 0.0
    ttl = float(agent.get("edge_total_time", 0.0)) or 0.0
    left = float(agent.get("edge_time_left", 0.0)) or 0.0
    if ttl <= 0.0:
        return 1.0 if left <= 0.0 else 0.0
    progress = 1.0 - max(0.0, min(1.0, left / ttl))
    return max(0.0, min(1.0, progress))


def agent_position_xy(building: dict, agent: dict):
    """
    Returns (x, y, floor). If on an edge, linearly interpolates by agent_progress().
    """
    node_pos = building.get("_cached_node_pos_map")
    if node_pos is None:
        node_pos = get_node_pos_map(building)
        building["_cached_node_pos_map"] = node_pos  # cache

    path = agent.get("path", [])
    idx = int(agent.get("pos_idx", 0))
    if not path:
        return (0.0, 0.0, None)

    idx = max(0, min(idx, len(path) - 1))

    if agent.get("phase") != "edge" or idx >= len(path) - 1:
        nid = path[idx]
        p = node_pos.get(nid, {"x": 0.0, "y": 0.0, "floor": None})
        return (p["x"], p["y"], p.get("floor"))
    else:
        cur = path[idx]
        nxt = path[idx + 1]
        p0 = node_pos.get(cur, {"x": 0.0, "y": 0.0, "floor": None})
        p1 = node_pos.get(nxt, {"x": 0.0, "y": 0.0, "floor": None})
        s = agent_progress(agent)
        x = (1.0 - s) * p0["x"] + s * p1["x"]
        y = (1.0 - s) * p0["y"] + s * p1["y"]
        floor = p1.get("floor") if s >= 0.5 else p0.get("floor")
        return (x, y, floor)


def agent_position_xyz(building: dict, agent: dict):
    """
    Returns (x, y, z, floor_index) for 3D plots.
    'z' is floor index interpolated across inter-floor edges.
    """
    node_pos = building.get("_cached_node_pos_map")
    if node_pos is None:
        node_pos = get_node_pos_map(building)
        building["_cached_node_pos_map"] = node_pos

    path = agent.get("path", [])
    idx = int(agent.get("pos_idx", 0))
    if not path:
        return (0.0, 0.0, 0.0, 0)

    idx = max(0, min(idx, len(path) - 1))

    if agent.get("phase") != "edge" or idx >= len(path) - 1:
        nid = path[idx]
        p = node_pos.get(nid, {"x": 0.0, "y": 0.0, "z": 0.0, "floor_index": 0})
        return (p["x"], p["y"], p["z"], p["floor_index"])
    else:
        cur = path[idx]
        nxt = path[idx + 1]
        p0 = node_pos.get(cur, {"x": 0.0, "y": 0.0, "z": 0.0, "floor_index": 0})
        p1 = node_pos.get(nxt, {"x": 0.0, "y": 0.0, "z": 0.0, "floor_index": 0})
        s = agent_progress(agent)
        x = (1.0 - s) * p0["x"] + s * p1["x"]
        y = (1.0 - s) * p0["y"] + s * p1["y"]
        z = (1.0 - s) * p0["z"] + s * p1["z"]
        fidx = int(round((1.0 - s) * p0["floor_index"] + s * p1["floor_index"]))
        return (x, y, z, fidx)
# --------------------------------------------------------
# 4. 간단한 통계 유틸
# --------------------------------------------------------

def compute_stats(times: np.ndarray) -> Tuple[float, float, float]:
    """각 에이전트 완료 시간 배열 → (t50, t80, t99)"""
    if len(times) == 0:
        return float("nan"), float("nan"), float("nan")
    return (
        float(np.percentile(times, 50)),
        float(np.percentile(times, 80)),
        float(np.percentile(times, 99)),
    )
