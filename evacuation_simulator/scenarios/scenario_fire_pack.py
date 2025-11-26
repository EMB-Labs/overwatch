# scenario_fire_pack.py
# - 화재 + block + 혼잡도 급증 시나리오 12개
# - 화재 노드는 closed, 주변 노드는 risk 증가
# - 각 시나리오에 기본 A* / ReroutePolicy 내장
from __future__ import annotations
from typing import List, Dict
from types import SimpleNamespace

import sys
sys.path.append("..")  # 부모 디렉토리를 PYTHONPATH에 추가

from core.astar_logic import AStarConfig
from .scenario_baseline import build_agents as baseline_build_agents


# =========================================================
# 공통 설정: A* / 리라우트
# =========================================================

# 위험 회피 + 약간의 혼잡 가중
DEFAULT_ASTAR_CFG = AStarConfig(
    name="with_risk",
    length_weight=4.0,
    congestion_weight=1.0,
    risk_weight=1.0,
)

# 20초 이상 정체 or 혼잡도 커지면 재라우트
DEFAULT_REROUTE_POLICY = {
    "max_stuck_time": 20.0,
    "congestion_threshold": 30,
}



# 층별 인원 수를 바꿔서 agent를 만드는 헬퍼
def build_agents_with_floor_split(
    building: dict,
    floors: List[str],
    per_floor: Dict[str, int],
    rng_seed: int = 42,
    astar_cfg: AStarConfig | None = None,
    grouping_params: dict | None = None,
) -> List[dict]:
    """
    per_floor = {"F1":300,"F2":300,"F3":300} 이런 식으로 층별 인원 지정
    """
    agents: List[dict] = []
    for fl in floors:
        n = per_floor.get(fl, 0)
        if n <= 0:
            continue
        sub_agents = baseline_build_agents(
            building=building,
            floors=[fl],
            n_agents_per_floor=n,
            rng_seed=rng_seed,
            astar_cfg=astar_cfg,
            grouping_params=grouping_params,
        )
        agents.extend(sub_agents)
    return agents


# =========================================================
# 공통: 화재 / block / risk 헬퍼
# =========================================================

def _iter_edges_touching(building: dict, node_id: str):
    for e in building.get("edges", []):
        if e.get("state", "open") != "open":
            continue
        if e["node_a"] == node_id or e["node_b"] == node_id:
            yield e


def close_node(building: dict, node_id: str):
    """
    화재 노드 자체는 통행 불가 → closed 처리
    (노드 + 그 노드와 연결된 edge 전부)
    """
    for n in building.get("nodes", []):
        if n["id"] == node_id:
            n["state"] = "closed"
    for e in building.get("edges", []):
        if e["node_a"] == node_id or e["node_b"] == node_id:
            e["state"] = "closed"


def increase_risk_around_node(building: dict, node_id: str, risk_value: float):
    """
    화재 노드 주변(연결된 엣지)에 risk 부여
    - 엣지 dict에 e["risk"] 필드를 설정
    """
    for e in _iter_edges_touching(building, node_id):
        # 이미 더 큰 risk가 있으면 유지
        old = float(e.get("risk", 0.0))
        e["risk"] = max(old, risk_value)


def set_fire(building: dict, node_id: str, risk_value: float = 5.0):
    """
    화재 노드: closed + 주변 risk
    """
    close_node(building, node_id)
    increase_risk_around_node(building, node_id, risk_value=risk_value)


def block_node(building: dict, node_id: str):
    """
    명시적인 block 이벤트 (복도/계단/출구 등)
    """
    close_node(building, node_id)


# =========================================================
# 시나리오별 dynamic_hook
# (step = tick index, dt=1이면 초 단위라고 생각)
# =========================================================

# 1) 시나리오1: 비교대조군 (baseline과 동일, 리라우트만 켜진 버전)
def dyn_s1_baseline(building, step, agents, node_dynamics):
    # 아무 이벤트 없음
    return


# 2) 시나리오2: 310 화재 (F3_ROOM_310)
def dyn_s2_310_fire(building, step, agents, node_dynamics):
    if step == 0:
        set_fire(building, "F3_ROOM_310", risk_value=6.0)


# 3) 시나리오3: 206 화재 (F2_ROOM_206)
def dyn_s3_206_fire(building, step, agents, node_dynamics):
    if step == 0:
        set_fire(building, "F2_ROOM_206", risk_value=6.0)


# 4) 시나리오4: 114 화재 (F1_ROOM_114)
def dyn_s4_114_fire(building, step, agents, node_dynamics):
    if step == 0:
        set_fire(building, "F1_ROOM_114", risk_value=6.0)


# 5) 시나리오5: 103 화재 (F1_ROOM_103)
def dyn_s5_103_fire(building, step, agents, node_dynamics):
    if step == 0:
        set_fire(building, "F1_ROOM_103", risk_value=6.0)


# 6) 시나리오6: 114 화재 + 20s 후 113,115 화재
def dyn_s6_114_then_113_115(building, step, agents, node_dynamics):
    if step == 0:
        set_fire(building, "F1_ROOM_114", risk_value=6.0)
    if step == 20:
        set_fire(building, "F1_ROOM_113", risk_value=8.0)
        set_fire(building, "F1_ROOM_115", risk_value=8.0)


# 7) 시나리오7: 306 화재 + 20s 후 3F_HALL_13,14,15 block
def dyn_s7_206_fire_then_3F_hall_block(building, step, agents, node_dynamics):
    if step == 0:
        set_fire(building, "F3_ROOM_306", risk_value=6.0)
    if step == 20:
        for hid in ["F3_HALL_13", "F3_HALL_14", "F3_HALL_15"]:
            block_node(building, hid)


# 8) 시나리오8: 310 화재
def dyn_s8_310_fire(building, step, agents, node_dynamics):
    if step == 0:
        set_fire(building, "F3_ROOM_310", risk_value=6.0)


# 9) 시나리오9: 210 화재 + 10s 후 2F_STAIR2 block
def dyn_s9_210_fire_then_stair2_block(building, step, agents, node_dynamics):
    if step == 0:
        set_fire(building, "F2_ROOM_210", risk_value=6.0)
    if step == 10:
        block_node(building, "F2_STAIR_2")


# 10) 시나리오10: 307 화재 + 20s 후 2F_EXIT_B block
def dyn_s10_307_fire_then_exitB_block(building, step, agents, node_dynamics):
    if step == 0:
        set_fire(building, "F3_ROOM_307", risk_value=6.0)
    if step == 20:
        block_node(building, "F2_EXIT_B")


# 11) 시나리오11: 혼잡도 급증 – 계단1 throughput 급락 → 리라우트 유도
def dyn_s11_congestion_spike_stair1(building, step, agents, node_dynamics):
    # 0초부터는 정상, 40초 이후에 계단1 용량을 20%로 떨어뜨림
    if step == 40:
        target_id = "F2_STAIR_1"  # 또는 "F1_STAIR_1" 건물 정의에 맞게 수정
        dyn = node_dynamics.get(target_id)
        if dyn:
            dyn["service_rate_ps"] *= 0.2  # 처리율 급감 → 혼잡도 증가
            print("[Congestion] stair1 service_rate dropped to 20%")


# 12) 시나리오12: 혼잡도 급증 – EXIT_B throughput 급락 → 리라우트 유도
def dyn_s12_congestion_spike_exitB(building, step, agents, node_dynamics):
    if step == 40:
        for target_id in ["F1_EXIT_B", "F2_EXIT_B", "F3_EXIT_B"]:
            dyn = node_dynamics.get(target_id)
            if dyn:
                dyn["service_rate_ps"] *= 0.2
        print("[Congestion] EXIT_B service_rate dropped to 20%")


# =========================================================
# 시나리오 오브젝트 정의 (SimpleNamespace 사용)
# =========================================================

def _wrap(
    scenario_id: str,
    dynamic_hook,
    floor_split: Dict[str, int] | None = None,
):
    """
    floor_split이 주어지면 층별 인원 분포를 사용하고,
    없으면 baseline의 균등(각 층 n_agents_per_floor 동일)을 사용.
    """
    if floor_split is None:
        # baseline과 동일: 각 층 n_agents_per_floor를 그대로 사용
        def build_agents(building, floors=None, n_agents_per_floor=900,
                         rng_seed=42, astar_cfg=None, grouping_params=None):
            return baseline_build_agents(
                building=building,
                floors=floors,
                n_agents_per_floor=n_agents_per_floor,
                rng_seed=rng_seed,
                astar_cfg=astar_cfg,
                grouping_params=grouping_params,
            )
    else:
        # 층별 분포 고정 버전
        def build_agents(building, floors=None, n_agents_per_floor=0,
                         rng_seed=42, astar_cfg=None, grouping_params=None):
            if floors is None:
                floors_use = ["F1", "F2", "F3"]
            else:
                floors_use = floors
            return build_agents_with_floor_split(
                building=building,
                floors=floors_use,
                per_floor=floor_split,
                rng_seed=rng_seed,
                astar_cfg=astar_cfg,
                grouping_params=grouping_params,
            )

    return SimpleNamespace(
        SCENARIO_ID=scenario_id,
        build_agents=build_agents,
        dynamic_hook=dynamic_hook,
        DEFAULT_ASTAR_CFG=DEFAULT_ASTAR_CFG,
        DEFAULT_REROUTE_POLICY=DEFAULT_REROUTE_POLICY,
    )


SCENARIO_S1 = _wrap("scenario01_baseline", dyn_s1_baseline)
SCENARIO_S2 = _wrap("scenario02_310_fire", dyn_s2_310_fire)
SCENARIO_S3 = _wrap("scenario03_206_fire", dyn_s3_206_fire)
SCENARIO_S4 = _wrap("scenario04_114_fire", dyn_s4_114_fire)
SCENARIO_S5 = _wrap("scenario05_103_fire", dyn_s5_103_fire)
SCENARIO_S6 = _wrap("scenario06_114_113_115_fire", dyn_s6_114_then_113_115)
SCENARIO_S7 = _wrap("scenario07_206_fire_3F_hall_block", dyn_s7_206_fire_then_3F_hall_block)
SCENARIO_S8 = _wrap("scenario08_310_fire_skewed_population",dyn_s8_310_fire)
SCENARIO_S9 = _wrap("scenario09_210_fire_stair2_block", dyn_s9_210_fire_then_stair2_block)
SCENARIO_S10 = _wrap("scenario10_307_fire_exitB_block", dyn_s10_307_fire_then_exitB_block)
SCENARIO_S11 = _wrap("scenario11_congest_stair1", dyn_s11_congestion_spike_stair1)
SCENARIO_S12 = _wrap("scenario12_congest_exitB", dyn_s12_congestion_spike_exitB)

# 편의를 위해 딕셔너리도 제공
SCENARIO_MAP = {
    "s1": SCENARIO_S1,
    "s2": SCENARIO_S2,
    "s3": SCENARIO_S3,
    "s4": SCENARIO_S4,
    "s5": SCENARIO_S5,
    "s6": SCENARIO_S6,
    "s7": SCENARIO_S7,
    "s8": SCENARIO_S8,
    "s9": SCENARIO_S9,
    "s10": SCENARIO_S10,
    "s11": SCENARIO_S11,
    "s12": SCENARIO_S12,
}

