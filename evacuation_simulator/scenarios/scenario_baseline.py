# scenario_baseline.py

import random
from collections import defaultdict
from typing import List, Dict, Optional

import sys
sys.path.append("..")  # 부모 디렉토리를 PYTHONPATH에 추가
from core.astar_logic import AStarConfig, build_graph, astar_path


SCENARIO_ID = "baseline_F1_F2_F3_uniform"


def build_agents(
    building: dict,
    floors: Optional[List[str]] = None,
    n_agents_per_floor: int = 900,
    rng_seed: Optional[int] = 42,
    astar_cfg: Optional[AStarConfig] = None,
    grouping_params: Optional[dict] = None,
) -> List[dict]:
    """
    - floors 에 지정된 각 층(F1, F2, F3)에 대해 room 목록을 찾고,
    - 층마다 n_agents_per_floor 명을 room에 균등 랜덤 분포
    - room별로 A* 경로 한 번씩 계산해서 path 공유
    - grouping_params 로 그룹핑(같은 방 사람끼리 그룹 등) 옵션 제공

    grouping_params 예시:
      {
        "mode": "none",      # or "by_room"
        "group_size": 3,
      }
    """
    if rng_seed is not None:
        random.seed(rng_seed)

    if floors is None:
        floors = ["F1", "F2", "F3"]

    # ===== 1) A* 설정 =====
    if astar_cfg is None:
        astar_cfg = AStarConfig(
            name="baseline",
            length_weight=1.0,
            congestion_weight=0.0,
            risk_weight=0.0,
        )

    graph, node_by_id = build_graph(building, astar_cfg)
    goal_id = "SUPER_EXIT"

    # ===== 2) 그루핑 파라미터 =====
    grouping_params = grouping_params or {}
    group_mode = grouping_params.get("mode", "none")   # "none" | "by_room"
    group_size = int(grouping_params.get("group_size", 1))
    if group_size < 1:
        group_size = 1

    # ===== 3) 속도 샘플링 =====
    def sample_speed_mps() -> float:
        """보행 속도 샘플링 (평균 1.3 m/s, 약간 분산)"""
        mu, sigma = 1.3, 0.26
        v = random.gauss(mu, sigma)
        return max(0.6, min(2.0, v))

    agents: List[dict] = []
    agent_id = 0
    global_group_id = 0  # 전체에서 유일한 그룹 id

    for floor in floors:
        # 1) 해당 층 room 노드 찾기
        rooms = [
            n["id"]
            for n in building["nodes"]
            if n.get("type") == "room" and n.get("floor") == floor
        ]
        if not rooms:
            continue

        # 2) 인원 방 분포 (층마다 n_agents_per_floor 명)
        room_pop: Dict[str, int] = defaultdict(int)
        for _ in range(n_agents_per_floor):
            r = random.choice(rooms)
            room_pop[r] += 1

        # 3) room 별로 A* 경로 한 번 계산
        room_paths: Dict[str, List[str]] = {}
        for room_id, cnt in room_pop.items():
            if cnt == 0:
                continue
            path = astar_path(graph, node_by_id, room_id, goal_id)
            room_paths[room_id] = path

        # 4) agents 생성 (+ 그룹 id 부여)
        for room_id, cnt in room_pop.items():
            path = room_paths[room_id]
            remaining = cnt

            if group_mode == "by_room" and group_size > 1:
                # 같은 room 안에서 group_size 단위로 그룹 나누기
                while remaining > 0:
                    this_group_size = min(group_size, remaining)
                    group_id = f"G{global_group_id}"
                    global_group_id += 1

                    for _ in range(this_group_size):
                        agents.append(
                            {
                                "id": agent_id,
                                "start_floor": floor,
                                "start_room": room_id,
                                "path": list(path),
                                "pos_idx": 0,
                                "done": False,
                                # 출구 통계용
                                "assigned_exit": path[-2] if len(path) >= 2 else path[-1],
                                # 보행/상태
                                "speed_mps": sample_speed_mps(),
                                "phase": "node",
                                "edge_time_left": 0.0,
                                # 재라우팅용 목표
                                "goal_id": goal_id,
                                "last_move_time": 0.0,
                                # 그룹 정보
                                "group_id": group_id,
                            }
                        )
                        agent_id += 1
                    remaining -= this_group_size
            else:
                # 그룹핑 없음
                for _ in range(remaining):
                    agents.append(
                        {
                            "id": agent_id,
                            "start_floor": floor,
                            "start_room": room_id,
                            "path": list(path),
                            "pos_idx": 0,
                            "done": False,
                            "assigned_exit": path[-2] if len(path) >= 2 else path[-1],
                            "speed_mps": sample_speed_mps(),
                            "phase": "node",
                            "edge_time_left": 0.0,
                            "goal_id": goal_id,
                            "last_move_time": 0.0,
                            "group_id": None,
                        }
                    )
                    agent_id += 1

    return agents


def dynamic_hook(building: dict, t: int, agents: List[dict], node_dynamics: dict) -> None:
    """
    이 시나리오는 불/폐쇄 없음 → 아무 것도 하지 않는 훅.
    """
    return
