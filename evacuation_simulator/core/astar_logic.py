#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
astar_logic.py

- 건물 그래프(JSON)를 이용한 A* 경로 탐색
- 혼잡도 / 위험도 기반 비용 가중
- 에이전트 재라우팅 유틸 (정체 시간 / 혼잡도 기준)
"""

from __future__ import annotations

import json
import heapq
import math
from typing import Dict, List, Tuple, Optional, Iterable, Any
from collections import defaultdict

NodeId = str
Graph = Dict[NodeId, List[Tuple[NodeId, float]]]


# --------------------------------------------------------
# 1. A* 설정 및 비용 함수
# --------------------------------------------------------

class AStarConfig:
    """
    A* 비용 구성용 설정값.
    - length_weight: 기본 거리 기반 비용 비중
    - congestion_weight: 혼잡도 기반 추가 비용 비중
    - risk_weight: 화재/위험도 등 사전 정의된 risk 필드 가중
    """
    def __init__(
        self,
        name: str = "baseline",
        length_weight: float = 1.0,
        congestion_weight: float = 0.0,
        risk_weight: float = 0.0,
    ) -> None:
        self.name = name
        self.length_weight = float(length_weight)
        self.congestion_weight = float(congestion_weight)
        self.risk_weight = float(risk_weight)

    def edge_cost(self, edge: dict, extra_congestion: float = 0.0) -> float:
        """
        edge(dict) + 혼잡도 수치(extra_congestion)를 받아 cost 계산.

        - edge["length"] : 거리 (미터 단위라고 가정; JSON에서 가져온 그대로 사용)
        - edge["weight_factor"] : 계단/복도 등 가중치
        - edge["risk"] : 화재/위험도 (scenario / 이벤트에서 설정)
        - extra_congestion: simulate()가 넘겨주는 현재 간선 위 인원 수
        """
        base_len = float(edge.get("length", 1.0))
        w_fac = float(edge.get("weight_factor", 1.0))
        risk = float(edge.get("risk", 0.0))

        c_len = self.length_weight * base_len * w_fac
        c_cong = self.congestion_weight * max(0.0, extra_congestion)
        c_risk = self.risk_weight * risk
        return c_len + c_cong + c_risk


# --------------------------------------------------------
# 2. 건물 로드 + 그래프 구성
# --------------------------------------------------------

def load_building(path: str) -> dict:
    """JSON 파일에서 building dict 로드."""
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def _node_pos_map(building: dict) -> Dict[NodeId, Tuple[float, float, float]]:
    """
    node_id -> (x, y, z) 매핑.
    - node["pos"] = {"x": float, "y": float}
    - node["floor"] 기준으로 z를 계단식으로 부여
    """
    pos_map: Dict[NodeId, Tuple[float, float, float]] = {}
    floors: Dict[str, int] = {}
    next_floor_idx = 0

    for n in building.get("nodes", []):
        nid = n.get("id")
        if not nid:
            continue
        pos = n.get("pos", {}) or {}
        x = float(pos.get("x", 0.0))
        y = float(pos.get("y", 0.0))
        floor = n.get("floor", "F0")
        if floor not in floors:
            floors[floor] = next_floor_idx
            next_floor_idx += 1
        z = float(floors[floor])
        pos_map[nid] = (x, y, z)
    return pos_map


def build_graph(
    building: dict,
    cfg: AStarConfig,
    edge_congestion: Optional[Dict[Tuple[NodeId, NodeId], float]] = None,
) -> Tuple[Graph, Dict[NodeId, dict]]:
    """
    building JSON에서 A*용 인접 리스트(Graph)를 구성한다.

    - 닫힌 node(state != "open") 에 연결된 모든 edge 는 사용하지 않는다.
      (화재/폐쇄 노드 자동 우회)
    - 닫힌 edge (state != "open") 도 무시.
    - cfg.edge_cost(...) 로 각 edge의 weight 계산.
    - edge_congestion: (node_a, node_b) -> 간선 위 인원 수
    """
    node_by_id: Dict[NodeId, dict] = {n["id"]: n for n in building.get("nodes", [])}
    closed_nodes = {
        n["id"] for n in building.get("nodes", [])
        if n.get("state", "open") != "open"
    }

    graph: Graph = {}
    edge_congestion = edge_congestion or {}
    edges = building.get("edges", [])

    for e in edges:
        if e.get("state", "open") != "open":
            continue

        a = e["node_a"]
        b = e["node_b"]

        # 🔥 닫힌 노드에 붙은 간선은 그래프에서 제외
        if a in closed_nodes or b in closed_nodes:
            continue

        extra_cong_ab = float(edge_congestion.get((a, b), 0.0))
        cost_ab = cfg.edge_cost(e, extra_congestion=extra_cong_ab)
        graph.setdefault(a, []).append((b, cost_ab))

        if e.get("directionality", "bidirectional") == "bidirectional":
            extra_cong_ba = float(edge_congestion.get((b, a), extra_cong_ab))
            cost_ba = cfg.edge_cost(e, extra_congestion=extra_cong_ba)
            graph.setdefault(b, []).append((a, cost_ba))

    return graph, node_by_id


# --------------------------------------------------------
# 3. A* 경로 탐색
# --------------------------------------------------------

def _heuristic(a: NodeId, b: NodeId, pos_map: Dict[NodeId, Tuple[float, float, float]]) -> float:
    """A* 휴리스틱: 3D 유클리드 거리."""
    xa, ya, za = pos_map[a]
    xb, yb, zb = pos_map[b]
    dx = xa - xb
    dy = ya - yb
    dz = za - zb
    return math.sqrt(dx * dx + dy * dy + dz * dz)


def astar_path(
    graph: Graph,
    node_by_id: Dict[NodeId, dict],
    start: NodeId,
    goal: NodeId,
    building: Optional[dict] = None,
) -> List[NodeId]:
    """
    표준 A* 경로 탐색.
    - graph: build_graph() 결과
    - start, goal: node id
    - building: 휴리스틱용 pos_map 계산에 사용 (없으면 node_by_id의 pos 사용)
    """
    if start not in graph and start != goal:
        return []

    # pos_map 구성
    if building is not None:
        pos_map = _node_pos_map(building)
    else:
        # node_by_id 안에 pos 가 있다고 가정
        pos_map = {}
        for nid, n in node_by_id.items():
            pos = n.get("pos", {}) or {}
            x = float(pos.get("x", 0.0))
            y = float(pos.get("y", 0.0))
            floor = n.get("floor", "F0")
            z = float(hash(floor) % 10)  # fallback용 대충 값
            pos_map[nid] = (x, y, z)

    open_set: List[Tuple[float, NodeId]] = []
    heapq.heappush(open_set, (0.0, start))

    came_from: Dict[NodeId, Optional[NodeId]] = {start: None}
    g_score: Dict[NodeId, float] = {start: 0.0}

    while open_set:
        _, current = heapq.heappop(open_set)

        if current == goal:
            # 경로 복원
            path: List[NodeId] = []
            c = current
            while c is not None:
                path.append(c)
                c = came_from[c]
            path.reverse()
            return path

        for neighbor, cost in graph.get(current, []):
            tentative_g = g_score[current] + cost
            if tentative_g < g_score.get(neighbor, float("inf")):
                came_from[neighbor] = current
                g_score[neighbor] = tentative_g
                f = tentative_g + _heuristic(neighbor, goal, pos_map)
                heapq.heappush(open_set, (f, neighbor))

    return []  # no path


# --------------------------------------------------------
# 4. 재라우팅 정책 및 적용
# --------------------------------------------------------

def _has_closed_node_ahead(agent: dict, building: dict) -> bool:
    """
    agent의 남은 path 중에 '닫힌' 노드가 하나라도 있으면 True.
    (node.state != "open")
    """
    path = agent.get("path") or []
    if not path:
        return False

    pos_idx = int(agent.get("pos_idx", 0))
    pos_idx = max(0, min(pos_idx, len(path) - 1))

    closed_nodes = {
        n["id"] for n in building.get("nodes", [])
        if n.get("state", "open") != "open"
    }

    for nid in path[pos_idx + 1:]:
        if nid in closed_nodes:
            return True
    return False


def should_reroute(
    agent: dict,
    current_time: float,
    policy: dict,
    current_congestion: int,
) -> bool:
    """
    단순 재라우트 정책:
    - policy["max_stuck_time"]: last_move_time 이후 경과 시간 >= 이 값이면 재라우트
    - policy["congestion_threshold"]: 현재 노드에 서 있는 사람 수 >= 이 값이면 재라우트
    """
    max_stuck_time = float(policy.get("max_stuck_time", float("inf")))
    cong_thresh = int(policy.get("congestion_threshold", 10))

    last_move = float(agent.get("last_move_time", 0.0))
    stuck_time = current_time - last_move

    if stuck_time >= max_stuck_time:
        return True
    if current_congestion >= cong_thresh:
        return True
    return False


def reroute_agent(
    agent: dict,
    goal_id: NodeId,
    building: dict,
    cfg: AStarConfig,
    current_time: float,
    edge_congestion: Optional[Dict[Tuple[NodeId, NodeId], float]] = None,
) -> None:
    """
    단일 agent에 대해 경로를 재계산.
    - reroute_attempts: A* 재계산 시도 횟수
    - reroute_history: 실제로 path가 바뀐 경우만 기록
      {"time": t, "old_path": [...], "new_path": [...]}
    """
    if agent.get("done"):
        return
    if agent.get("phase") != "node":
        return

    path: List[NodeId] = agent.get("path") or []
    if not path:
        return

    pos_idx = int(agent.get("pos_idx", 0))
    pos_idx = max(0, min(pos_idx, len(path) - 1))
    current_node = path[pos_idx]

    old_path = list(path)
    old_suffix = old_path[pos_idx:]

    # attempt 카운트
    agent.setdefault("reroute_attempts", 0)
    agent["reroute_attempts"] += 1

    graph, node_by_id = build_graph(building, cfg, edge_congestion=edge_congestion)
    new_path = astar_path(graph, node_by_id, current_node, goal_id, building=building)
    if not new_path:
        return

    if new_path[0] != current_node:
        new_path = [current_node] + new_path

    # 현재 이후 루트가 실제로 바뀐 경우만 history에 기록
    if new_path != old_suffix:
        agent.setdefault("reroute_history", []).append(
            {
                "time": float(current_time),
                "old_path": old_suffix,
                "new_path": list(new_path),
            }
        )

    # 경로 업데이트
    agent["path"] = new_path
    agent["pos_idx"] = 0
    agent["phase"] = "node"
    agent["edge_time_left"] = 0.0
    agent["edge_total_time"] = 0.0
    agent["last_move_time"] = float(current_time)


def apply_rerouting_for_nodes(
    building: dict,
    agents: List[dict],
    node_to_agent_idxs: Dict[NodeId, List[int]],
    current_time: float,
    policy: dict,
    cfg: AStarConfig,
    edge_congestion: Optional[Dict[Tuple[NodeId, NodeId], float]] = None,
) -> None:
    """
    node_to_agent_idxs를 돌면서 재라우트 조건이 만족되는 agent에 대해
    reroute_agent() 호출.
    """
    for nid, idxs in node_to_agent_idxs.items():
        current_cong = len(idxs)

        for idx in idxs:
            agent = agents[idx]
            if agent.get("done"):
                continue

            goal_id = agent.get("goal_id")
            if goal_id is None:
                continue

            # 1) 앞 경로에 closed node가 있으면 무조건 재라우트
            if _has_closed_node_ahead(agent, building):
                reroute_agent(
                    agent=agent,
                    goal_id=goal_id,
                    building=building,
                    cfg=cfg,
                    current_time=current_time,
                    edge_congestion=edge_congestion,
                )
                continue

            # 2) 그 외에는 policy 기반
            if should_reroute(
                agent=agent,
                current_time=current_time,
                policy=policy,
                current_congestion=current_cong,
            ):
                reroute_agent(
                    agent=agent,
                    goal_id=goal_id,
                    building=building,
                    cfg=cfg,
                    current_time=current_time,
                    edge_congestion=edge_congestion,
                )


# --------------------------------------------------------
# 5. 화재/위험 이벤트용 유틸
# --------------------------------------------------------

def _build_undirected_adj(building: dict) -> Dict[NodeId, List[NodeId]]:
    """
    (노드 그래프용) 무방향 adjacency 리스트.
    - edge state != "open" 은 무시.
    """
    adj: Dict[NodeId, List[NodeId]] = defaultdict(list)
    for e in building.get("edges", []):
        if e.get("state", "open") != "open":
            continue
        a = e["node_a"]
        b = e["node_b"]
        # 무방향으로 연결
        adj[a].append(b)
        adj[b].append(a)
    return adj


def increase_risk_around_node_radius(
    building: dict,
    node_id: NodeId,
    risk_value: float = 10.0,
    hops: int = 2,
    mode: str = "max",
) -> None:
    """
    특정 노드를 기준으로, hop 거리(hops) 이내에 있는 모든 엣지의 risk를 올린다.

    - 방-문-복도 구조라면:
        ROOM -- DOOR -- HALL -- ...
      에서 ROOM 또는 HALL 쪽에 화재가 나도,
      ROOM-DOOR, DOOR-HALL, HALL-... 방향 엣지까지
      최소 2~3개 엣지가 영향을 받도록 설계.

    - hops:
        1  -> 해당 노드에 직접 붙은 엣지들만
        2  -> 해당 노드 + 인접 노드들의 엣지까지 (기본값: 방-문-복도 커버용)
    - mode:
        "max": edge["risk"] = max(old, risk_value)
        "add": edge["risk"] += risk_value
    """
    if hops <= 0:
        return

    adj = _build_undirected_adj(building)

    # BFS로 node_id 기준 hop 거리 계산
    dist: Dict[NodeId, int] = {node_id: 0}
    queue: List[NodeId] = [node_id]

    while queue:
        cur = queue.pop(0)
        d = dist[cur]
        if d >= hops:
            continue
        for nb in adj.get(cur, []):
            if nb not in dist:
                dist[nb] = d + 1
                queue.append(nb)

    # 모든 엣지에 대해, 끝점 중 하나라도 dist <= hops 이면 risk 증가
    for e in building.get("edges", []):
        a = e.get("node_a")
        b = e.get("node_b")
        da = dist.get(a, None)
        db = dist.get(b, None)

        if da is None and db is None:
            continue
        # 두 끝점 거리 중 최소가 hops 이하면 "영향권"으로 본다
        d_min = min([d for d in (da, db) if d is not None])
        if d_min > hops:
            continue

        old_risk = float(e.get("risk", 0.0))
        if mode == "add":
            new_risk = old_risk + risk_value
        else:  # "max"
            new_risk = max(old_risk, risk_value)
        e["risk"] = new_risk


def mark_node_on_fire(
    building: dict,
    node_id: NodeId,
    close_node: bool = True,
    edge_risk_value: float = 10.0,
    hops: int = 2,
    edge_mode: str = "max",
) -> None:
    """
    'node_id' 에 화재 이벤트가 들어왔을 때 호출하는 헬퍼.

    - close_node=True:
        해당 노드 state 를 "closed" 로 바꿔서
        A* 그래프에서 완전히 제거 (필수 우회).
    - 항상:
        node_id 기준 hop<=hops 인 모든 엣지들의 risk 상승.
        (기본 hops=2 : 방-문-복도 3개 엣지 정도 커버)

    외부 시스템(센서/시나리오)에서는 화재 발생 시:
        mark_node_on_fire(building, "F2_EXIT_B")
    처럼 호출하면, A*는 즉시 그 주변을 "비싸고/막힌 구간"으로 인식하게 된다.
    """
    # 1) 노드 상태 변경 (선택)
    if close_node:
        for n in building.get("nodes", []):
            if n.get("id") == node_id:
                n["state"] = "closed"
                break

    # 2) 주변 엣지 risk 증가 (방-문-복도 구조까지 포함)
    increase_risk_around_node_radius(
        building=building,
        node_id=node_id,
        risk_value=edge_risk_value,
        hops=hops,
        mode=edge_mode,
    )
