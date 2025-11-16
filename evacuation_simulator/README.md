# Smart Fire Evacuation Simulation Platform

멀티 층 실내 건물을 대상으로, **화재·혼잡·폐쇄 이벤트**를 반영한 **동적 대피 경로 시뮬레이션 플랫폼**입니다.  
각 에이전트는 A* 기반 초기 경로를 따르되, 시간에 따라 변하는 **혼잡도(congestion)** 및 **위험도(risk)** 를 반영하여 **재라우팅(rerouting)** 할 수 있습니다.

---

## ✨ Key Features

- **Building Graph + JSON 구성**
  - `floors`, `nodes`, `edges`, `SUPER_EXIT`까지 포함한 빌딩 그래프를 JSON으로 정의  
  - 노드는 `room / hall / door / exit / stair` 타입을 갖고, 위치(pos), 폭(width), 상태(state) 등의 메타데이터를 포함합니다. :contentReference[oaicite:0]{index=0}  

- **A* Path Finding with Custom Cost**
  - `AStarConfig` 를 통해 거리, 혼잡, 위험도 가중치를 조절하며,  
    `edge_cost()` 에서 하나의 통합 비용으로 계산합니다. :contentReference[oaicite:1]{index=1}  

- **Congestion-aware Simulation Engine**
  - 노드 타입별 `width`에 따라 `service_rate_ps`(명/초)를 설정하여 병목 현상을 모델링합니다. :contentReference[oaicite:2]{index=2}  
  - 에이전트는 `node` / `edge` phase를 가지며, 간선 위 인원 수에 따라 **유효 속도(effective speed)** 가 감소합니다.

- **Dynamic Scenarios (Fire / Block / Risk)**
  - 화재 발생 시 특정 노드를 `closed` 처리하고, 인접 간선에 `risk`를 부여하여 경로 비용을 동적으로 변화시킵니다. :contentReference[oaicite:3]{index=3}  
  - 복도/계단/출구를 시간에 따라 `block`하는 시나리오를 정의할 수 있습니다.

- **Multi-floor Agent Population**
  - 층별 인원 수를 설정하고, 각 층의 `room`에 균등 분포로 사람을 배치합니다. :contentReference[oaicite:4]{index=4}  
  - 방 단위 그룹핑(by_room) 옵션으로, 같은 방에서 나온 사람들을 하나의 그룹으로 묶을 수 있습니다.

- **Statistics & Rerouting Analysis**
  - 전체 완료 시간 분포에서 `t50`, `t80`, `t99`를 계산합니다. :contentReference[oaicite:5]{index=5}  
  - **배정된 출구(assigned_exit)** vs **실제 사용한 출구(used exit)** 기준으로 출구별 통계를 분리하여 관리합니다.  
  - 에이전트별 `reroute_attempts`, `reroute_history`를 집계하여 재라우팅 전략의 효과를 분석할 수 있습니다.

---

## 📁 Project Structure

```text
evacuation-simulator/
│
├── README.md
├── requirements.txt
│
├── config/
│   └── mockup_building_with_edges.json   # Building graph JSON
│
├── core/
│   ├── astar_logic.py                    # A* + graph builder + reroute utils
│   └── simulation_engine.py              # Simulation core (multi-agent, congestion, reroute)
│
├── scenarios/
│   ├── scenario_baseline.py              # Uniform population, no fire/block (baseline)
│   └── scenario_fire_pack.py             # Fire / block / risk scenario pack (12+ cases)
│
├── runners/
│   ├── run_agent_path_demo.py            # Single-agent + global stats demo runner
│   └── run.ipynb                         # (optional) Jupyter notebook for experiments
│
├── results/                              # Simulation outputs (times, logs, etc.)
└── assets/                               # Maps, figures, diagrams
