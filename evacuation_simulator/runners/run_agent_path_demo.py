# run_agent_path_demo.py
# - 시각화 제거
# - 선택 agent의 경로/리라우트 타임라인 포함
# - 전역 통계(Exit별, 완료시간, 리라우트 통계)
# - reroute_attempts (시도) / reroute_history (실제 변경)
# - 출구 통계: (1) assigned_exit 기준, (2) 실제 사용된 exit 기준 둘 다 출력

from astar_logic import load_building
from scenario_fire_pack import (
    DEFAULT_ASTAR_CFG,
    DEFAULT_REROUTE_POLICY,
    build_agents_with_floor_split,
)
from simulation_engine import build_node_dynamics, simulate, compute_stats
import scenario_fire_pack


def get_agent_paths_with_history(
    scenario_name: str,
    agent_index: int = 0,
    building_path: str = "mockup_building_with_edges.json",
    per_floor=None,
    max_steps: int = 2000,
    dt: float = 1.0,
    rng_seed: int = 42,
):
    """
    단일 에이전트의 초기/최종 경로 + 리라우트 히스토리 + 전체 통계를 모두 계산하는 헬퍼.

    반환 dict 예시:
    {
        "scenario": str,
        "agent_index": int,
        "agent_id": int,

        # 선택된 에이전트 관련
        "initial_path": [...],
        "final_path": [...],
        "finish_time": float,
        "reroute_attempts": int,
        "reroute_history": [
            {
                "time": float,
                "old_path": [...],
                "new_path": [...],
            },
            ...
        ],
        "agent_path_timeline": [
            {
                "time": float,
                "path": [...],
            },
            ...
        ],

        # 공통
        "floors": [...],
        "building": building_dict,
        "node_dyn": node_dynamics_dict,

        # 전체 통계
        "done_times": np.ndarray,
        "global_stats": {...},
        "exit_stats_assigned": {...},   # assigned_exit 기준
        "exit_stats_used": {...},       # 실제 사용한 exit 기준
        "global_reroute": {...},
        "global_reroute_attempts": int,
    }
    """
    # 1) 건물 로드
    building = load_building(building_path)
    floors = building.get("floors")

    # 2) 층별 인원 설정 (기본: 각 층 300명)
    if per_floor is None:
        per_floor = {fl: 300 for fl in floors}

    # 3) 에이전트 생성
    agents = build_agents_with_floor_split(
        building=building,
        floors=floors,
        per_floor=per_floor,
        rng_seed=rng_seed,
        astar_cfg=DEFAULT_ASTAR_CFG,
    )

    if agent_index < 0 or agent_index >= len(agents):
        raise IndexError(f"agent_index {agent_index} is out of range (n_agents={len(agents)})")

    target_agent = agents[agent_index]
    initial_path = list(target_agent.get("path", []))

    # 4) dynamic hook 설정
    if scenario_name in ("baseline", None, ""):
        dynamic_hook = None
        scenario_id = "baseline"
    else:
        if hasattr(scenario_fire_pack, scenario_name):
            dynamic_hook = getattr(scenario_fire_pack, scenario_name)
            scenario_id = scenario_name
        else:
            raise ValueError(f"Scenario '{scenario_name}' not found in scenario_fire_pack.")

    # 5) node dynamics (service rate 등)
    node_dyn = build_node_dynamics(building)

    # 6) 시뮬레이션 실행
    done_times, congestion_log = simulate(
        building=building,
        agents=agents,
        floor=floors[0],
        node_dynamics=node_dyn,
        max_steps=max_steps,
        rng_seed=rng_seed,
        dynamic_hook=dynamic_hook,
        dt=dt,
        reroute_policy=DEFAULT_REROUTE_POLICY,
        reroute_cfg=DEFAULT_ASTAR_CFG,
    )

    # 7) 전체 통계 계산 ------------------------------------------

    # 7-1) 전체 완료 통계 (t50/t80/t99)
    g_t50, g_t80, g_t99 = compute_stats(done_times)
    n_agents = len(agents)
    n_finished = sum(1 for a in agents if a.get("done"))

    global_stats = {
        "n_agents": n_agents,
        "n_finished": n_finished,
        "t50": g_t50,
        "t80": g_t80,
        "t99": g_t99,
    }

    # 7-2-A) Exit별 통계 (assigned_exit 기준, 기존 방식)
    exit_raw_assigned = {}
    for a in agents:
        exit_id = a.get("assigned_exit", "UNKNOWN_EXIT")
        info = exit_raw_assigned.setdefault(exit_id, {"assigned": 0, "finished": 0, "times": []})
        info["assigned"] += 1
        if a.get("done"):
            info["finished"] += 1
            info["times"].append(float(a.get("finish_time", -1)))

    exit_stats_assigned = {}
    for exit_id, info in exit_raw_assigned.items():
        t50, t80, t99 = compute_stats(info["times"])
        exit_stats_assigned[exit_id] = {
            "assigned": info["assigned"],
            "finished": info["finished"],
            "t50": t50,
            "t80": t80,
            "t99": t99,
        }

    # 7-2-B) Exit별 통계 (실제 사용된 exit 기준)
    # - path 마지막이 "SUPER_EXIT"이면, 그 직전 노드를 exit로 간주
    # - 그 외에는 path[-1]을 exit처럼 취급
    exit_raw_used = {}
    for a in agents:
        if not a.get("done"):
            continue
        path = a.get("path", []) or []
        if not path:
            continue

        if len(path) >= 2 and path[-1] == "SUPER_EXIT":
            used_exit = path[-2]
        else:
            used_exit = path[-1]

        info = exit_raw_used.setdefault(used_exit, {"count": 0, "times": []})
        info["count"] += 1
        info["times"].append(float(a.get("finish_time", -1)))

    exit_stats_used = {}
    for exit_id, info in exit_raw_used.items():
        t50, t80, t99 = compute_stats(info["times"])
        exit_stats_used[exit_id] = {
            "count": info["count"],   # 실제 이 exit로 탈출한 인원 수
            "t50": t50,
            "t80": t80,
            "t99": t99,
        }

    # 7-3) 리라우팅 통계 (attempts + actual changes)
    total_attempts = 0
    total_events = 0
    reroutes_per_agent = []

    for a in agents:
        attempts = int(a.get("reroute_attempts", 0))
        changes = len(a.get("reroute_history", []))
        total_attempts += attempts
        total_events += changes
        reroutes_per_agent.append(changes)

    if n_agents > 0:
        avg_per_agent = total_events / n_agents
        max_per_agent = max(reroutes_per_agent)
    else:
        avg_per_agent = 0.0
        max_per_agent = 0

    max_agents = [
        a["id"]
        for a, k in zip(agents, reroutes_per_agent)
        if k == max_per_agent and max_per_agent > 0
    ]

    global_reroute = {
        "total_events": total_events,       # 실제 경로 변경 이벤트 수
        "avg_per_agent": avg_per_agent,
        "max_per_agent": max_per_agent,
        "max_agents": max_agents,
    }

    # 8) 선택된 에이전트 정보 정리 -------------------------------

    final_agent = agents[agent_index]
    selected_reroutes = list(final_agent.get("reroute_history", []))
    selected_attempts = int(final_agent.get("reroute_attempts", 0))

    # "실제 경로 타임라인":
    # - t=0.0 에서 initial_path
    # - 이후 각 reroute 이벤트 time 에서 new_path
    agent_path_timeline = [
        {
            "time": 0.0,
            "path": list(initial_path),
        }
    ]
    for ev in selected_reroutes:
        t_ev = float(ev.get("time", 0.0))
        new_path = list(ev.get("new_path", []))
        agent_path_timeline.append(
            {
                "time": t_ev,
                "path": new_path,
            }
        )
    agent_path_timeline.sort(key=lambda d: d["time"])

    # 최종 결과 dict
    result = {
        "scenario": scenario_id,
        "agent_index": agent_index,
        "agent_id": final_agent["id"],

        # 선택 에이전트
        "initial_path": initial_path,
        "final_path": list(final_agent.get("path", [])),
        "finish_time": float(final_agent.get("finish_time", -1)),
        "reroute_attempts": selected_attempts,
        "reroute_history": selected_reroutes,
        "agent_path_timeline": agent_path_timeline,

        # 공통
        "floors": floors,
        "building": building,
        "node_dyn": node_dyn,

        # 전체 통계
        "done_times": done_times,
        "global_stats": global_stats,
        "exit_stats_assigned": exit_stats_assigned,
        "exit_stats_used": exit_stats_used,
        "global_reroute": global_reroute,
        "global_reroute_attempts": total_attempts,
    }

    return result


def run_demo_full(
    scenario_name: str,
    agent_index: int = 0,
    building_path: str = "mockup_building_with_edges.json",
    per_floor=None,
    max_steps: int = 2000,
    dt: float = 1.0,
    rng_seed: int = 42,
    verbose: bool = True,
):
    """
    시각화 없이:
      - 시나리오 실행
      - 지정한 에이전트(agent_index)의 경로/리라우트 기록
      - 전체 통계(Exit별, 전체 t50/t80/t99, reroute 통계) 출력
      - 선택 에이전트의 경로 타임라인(agent_path_timeline)과
        reroute_attempts / reroute_history 모두 result에 포함
      - 출구 통계는 (assigned_exit 기준) + (실제 사용 exit 기준) 둘 다 제공
    """
    result = get_agent_paths_with_history(
        scenario_name=scenario_name,
        agent_index=agent_index,
        building_path=building_path,
        per_floor=per_floor,
        max_steps=max_steps,
        dt=dt,
        rng_seed=rng_seed,
    )

    if verbose:
        scenario = result["scenario"]
        agent_id = result["agent_id"]
        finish_time = result["finish_time"]
        reroutes = result["reroute_history"]
        reroute_count = len(reroutes)
        reroute_attempts = int(result.get("reroute_attempts", 0))

        g = result["global_stats"]
        exit_stats_assigned = result["exit_stats_assigned"]
        exit_stats_used = result["exit_stats_used"]
        gr = result["global_reroute"]
        total_attempts = int(result.get("global_reroute_attempts", 0))

        print("=" * 70)
        print(f"[Scenario] {scenario}")
        print(f"[Agent] index={result['agent_index']}, id={agent_id}")

        # 초기 / 최종 경로
        print("- initial_path (node list):")
        print("  ", result["initial_path"])
        print("- final_path (node list):")
        print("  ", result["final_path"])

        # path timeline
        print("- path timeline (time → path):")
        for seg in result["agent_path_timeline"]:
            print(f"  t={seg['time']:.1f}s : {seg['path']}")

        # finish time
        if finish_time >= 0:
            print(f"- finish_time: {finish_time:.1f} s")
        else:
            print("- finish_time: not finished")

        # 에이전트 reroute 정보
        print(f"- reroute_attempts (this agent): {reroute_attempts}")
        print(f"- reroute_count (actual changes for this agent): {reroute_count}")
        if reroute_count > 0:
            print("  reroute events:")
            for i, ev in enumerate(reroutes, start=1):
                t = ev.get("time", 0.0)
                old_path = ev.get("old_path", [])
                new_path = ev.get("new_path", [])
                print(f"    #{i}: t={t:.1f}s")
                print(f"       old: {old_path}")
                print(f"       new: {new_path}")

        print("-" * 70)
        print("[Global completion stats]")
        print(f"  total agents   : {g['n_agents']}")
        print(f"  finished agents: {g['n_finished']}")
        print(f"  t50={g['t50']:.1f}s, t80={g['t80']:.1f}s, t99={g['t99']:.1f}s")

        # --- 출구 통계 출력 ---
        print("-" * 70)
        print("[Per-exit stats]  (assigned_exit 기준)")
        for exit_id in sorted(exit_stats_assigned.keys()):
            st = exit_stats_assigned[exit_id]
            print(
                f"  {exit_id}: "
                f"assigned={st['assigned']}, finished={st['finished']}, "
                f"t50={st['t50']:.1f}s, t80={st['t80']:.1f}s, t99={st['t99']:.1f}s"
            )

        print("-" * 70)
        print("[Per-exit stats]  (실제 사용 exit 기준)")
        if not exit_stats_used:
            print("  (no finished agents?)")
        else:
            for exit_id in sorted(exit_stats_used.keys()):
                st = exit_stats_used[exit_id]
                print(
                    f"  {exit_id}: "
                    f"count={st['count']}, "
                    f"t50={st['t50']:.1f}s, t80={st['t80']:.1f}s, t99={st['t99']:.1f}s"
                )

        print("-" * 70)
        print("[Rerouting stats (global)]")
        print(f"  total reroute attempts : {total_attempts}")
        print(f"  total reroute events   : {gr['total_events']}")
        print(f"  avg reroutes per agent : {gr['avg_per_agent']:.3f}")
        print(f"  max reroutes per agent : {gr['max_per_agent']}")
        if gr["max_agents"]:
            print(f"  agents with max reroutes: {gr['max_agents']}")
        print("=" * 70)

    return result
