import 'dart:math';

class FireData {
  final String situation;
  final String role;
  final Map<String, dynamic>? evacuationData;

  FireData({
    required this.situation,
    required this.role,
    this.evacuationData,
  });
}

class FireDataService {
  // ==========================================================================
  // 동건이가 할 부분 #1: 메인 함수 (현재는 테스트용, 실제 환경에서 아래 주석 해제)
  // ==========================================================================
  static Future<FireData> waitForSignal(String role) async {
    await Future.delayed(Duration(seconds: 2));

    // TODO: 실제 환경에서는 아래 주석 해제하고 테스트 코드 삭제
    /*
    // Step 1: NPU에서 화재 신호 수신
    final situation = await _receiveFireSignalFromNPU();
    
    // Step 2: evacuate 신호면 시뮬레이션 결과 수신
    if (situation == 'evacuate') {
      final simulationText = await _receiveSimulationResultText();
      return _parseSimulationText(simulationText, role);
    }
    
    // Step 3: false_alarm 또는 initial_fire
    return FireData(situation: situation, role: role);
    */

    // 현재는 테스트용 더미 데이터
    return _generateTestData(role);
  }

  // ==========================================================================
  // 동건이가 구현해야 할 부분 #2: NPU 신호 수신
  // ==========================================================================
  static Future<String> _receiveFireSignalFromNPU() async {
    // TODO: NPU 통신 코드 (HTTP/WebSocket/MQTT 등)
    // 반환값: 'false_alarm' | 'initial_fire' | 'evacuate'
    throw UnimplementedError('NPU 통신 코드 필요');
  }

  // ==========================================================================
  // 동건이가 가 구현해야 할 부분 #3: 시뮬레이션 결과 수신(총 3가지임)
  // ==========================================================================
  static Future<String> _receiveSimulationResultText() async {
    // TODO: 시뮬레이션 서버에서 텍스트 결과 받기
    // 텍스트 그대로 반환하자
    throw UnimplementedError('시뮬레이션 통신 코드 필요');
  }

  // ==========================================================================
  // 시뮬레이션 텍스트 결과 직접 파싱 (자동 처리됨)
  // ==========================================================================
  static FireData _parseSimulationText(String simulationText, String role) {
    // 텍스트에서 필요한 데이터 추출
    final agents = _extractAgentsFromText(simulationText);
    final globalStats = _extractGlobalStatsFromText(simulationText);
    final fireLocation = _extractFireLocationFromText(simulationText);

    if (role == 'manager' || role == 'firefighter') {
      return FireData(
        situation: 'evacuate',
        role: role,
        evacuationData: _buildManagerData(agents, globalStats),
      );
    } else {
      return FireData(
        situation: 'evacuate',
        role: role,
        evacuationData: _buildUserData(agents, fireLocation),
      );
    }
  }

  // 텍스트에서 agent 데이터 추출
  static List<Map<String, dynamic>> _extractAgentsFromText(String text) {
    List<Map<String, dynamic>> agents = [];

    // "[Agent] index=800, id=200" 패턴 찾기
    final agentPattern = RegExp(
      r'\[Agent\] index=(\d+), id=(\d+)[\s\S]*?'
      r'- initial_path \(node list\):\s*\n\s*\[(.*?)\]\s*\n'
      r'- final_path \(node list\):\s*\n\s*\[(.*?)\]\s*\n'
      r'[\s\S]*?- finish_time: ([\d.]+) s',
      multiLine: true,
    );

    for (var match in agentPattern.allMatches(text)) {
      final agentId = int.parse(match.group(2)!);
      final initialPath = match
          .group(3)!
          .split(',')
          .map((e) => e.trim().replaceAll("'", ''))
          .toList();
      final finalPath = match
          .group(4)!
          .split(',')
          .map((e) => e.trim().replaceAll("'", ''))
          .toList();
      final finishTime = double.parse(match.group(5)!);

      // 시작 방 및 출구 추출
      final startRoom = initialPath.first;
      String assignedExit = 'F1_EXIT_A';
      for (var node in finalPath) {
        if (node.contains('EXIT_') && !node.contains('SUPER')) {
          assignedExit = node;
          break;
        }
      }

      agents.add({
        'agent_id': agentId,
        'start_room': startRoom,
        'final_path': finalPath,
        'assigned_exit': assignedExit,
        'finish_time': finishTime,
      });
    }

    return agents;
  }

  // 텍스트에서 전역 통계 추출
  static Map<String, dynamic> _extractGlobalStatsFromText(String text) {
    final totalAgentsMatch =
        RegExp(r'total agents\s*:\s*(\d+)').firstMatch(text);
    final finishedAgentsMatch =
        RegExp(r'finished agents:\s*(\d+)').firstMatch(text);
    final t50Match = RegExp(r't50=([\d.]+)s').firstMatch(text);
    final t80Match = RegExp(r't80=([\d.]+)s').firstMatch(text);
    final t99Match = RegExp(r't99=([\d.]+)s').firstMatch(text);
    final rerouteMatch =
        RegExp(r'total reroute events\s*:\s*(\d+)').firstMatch(text);

    return {
      'total_agents':
          totalAgentsMatch != null ? int.parse(totalAgentsMatch.group(1)!) : 0,
      'finished_agents': finishedAgentsMatch != null
          ? int.parse(finishedAgentsMatch.group(1)!)
          : 0,
      't50': t50Match != null ? double.parse(t50Match.group(1)!) : 0.0,
      't80': t80Match != null ? double.parse(t80Match.group(1)!) : 0.0,
      't99': t99Match != null ? double.parse(t99Match.group(1)!) : 0.0,
      'total_reroute_events':
          rerouteMatch != null ? int.parse(rerouteMatch.group(1)!) : 0,
    };
  }

  // 텍스트에서 화재 위치 추출
  static String _extractFireLocationFromText(String text) {
    // 시나리오 이름에서 화재 위치 추출 (예: "dyn_s9_210_fire_then_stair2_block" → F2_ROOM_210)
    final scenarioMatch =
        RegExp(r'\[Scenario\]\s+\w+_s\d+_(\d+)_fire').firstMatch(text);
    if (scenarioMatch != null) {
      final roomNum = scenarioMatch.group(1)!;
      final floor = roomNum[0]; // 첫 자리가 층
      return 'F${floor}_ROOM_$roomNum';
    }
    return 'F1_ROOM_101'; // 기본값
  }

  // 사용자 개인 대피 데이터 생성
  static Map<String, dynamic> _buildUserData(
    List<Map<String, dynamic>> agents,
    String fireLocation,
  ) {
    // 랜덤 agent 선택 (실제로는 사용자 ID로 매칭)
    final userAgent = agents[Random().nextInt(agents.length)];
    final startRoom = userAgent['start_room'] as String;
    final startFloor = startRoom.substring(0, 2);

    return {
      'start_floor': startFloor,
      'start_room': startRoom,
      'path': userAgent['final_path'],
      'assigned_exit': userAgent['assigned_exit'],
      'fire_location': fireLocation,
      'speed_mps': 1.4,
      'done': false,
    };
  }

  // 관리자 전체 통계 데이터 생성
  static Map<String, dynamic> _buildManagerData(
    List<Map<String, dynamic>> agents,
    Map<String, dynamic> globalStats,
  ) {
    // 층별/출구별 통계 집계
    int floor1Total = 0, floor1Evacuated = 0;
    int floor2Total = 0, floor2Evacuated = 0;
    int floor3Total = 0, floor3Evacuated = 0;

    int f1_exitA = 0, f1_exitA_done = 0;
    int f1_exitB = 0, f1_exitB_done = 0;
    int f1_exitC = 0, f1_exitC_done = 0;
    int f2_exitB_direct = 0, f2_exitB_done = 0;
    int f2_stairLeft = 0, f2_stairLeft_done = 0;
    int f2_stairRight = 0, f2_stairRight_done = 0;
    int f3_stairLeft = 0, f3_stairLeft_done = 0;
    int f3_stairRight = 0, f3_stairRight_done = 0;

    for (var agent in agents) {
      final startRoom = agent['start_room'] as String;
      final assignedExit = agent['assigned_exit'] as String;
      final isFinished = agent['finish_time'] != null;

      if (startRoom.startsWith('F1')) {
        floor1Total++;
        if (isFinished) floor1Evacuated++;

        if (assignedExit == 'F1_EXIT_A') {
          f1_exitA++;
          if (isFinished) f1_exitA_done++;
        } else if (assignedExit == 'F1_EXIT_B') {
          f1_exitB++;
          if (isFinished) f1_exitB_done++;
        } else if (assignedExit == 'F1_EXIT_C') {
          f1_exitC++;
          if (isFinished) f1_exitC_done++;
        }
      } else if (startRoom.startsWith('F2')) {
        floor2Total++;
        if (isFinished) floor2Evacuated++;

        if (assignedExit == 'F2_EXIT_B') {
          f2_exitB_direct++;
          if (isFinished) f2_exitB_done++;
        } else if (assignedExit == 'F1_EXIT_A') {
          f2_stairLeft++;
          if (isFinished) f2_stairLeft_done++;
        } else if (assignedExit == 'F1_EXIT_B') {
          f2_stairRight++;
          if (isFinished) f2_stairRight_done++;
        }
      } else if (startRoom.startsWith('F3')) {
        floor3Total++;
        if (isFinished) floor3Evacuated++;

        final path = agent['final_path'] as List;
        if (path.any((node) => node.toString().contains('STAIR_1'))) {
          f3_stairLeft++;
          if (isFinished) f3_stairLeft_done++;
        } else {
          f3_stairRight++;
          if (isFinished) f3_stairRight_done++;
        }
      }
    }

    return {
      'floor': 1,
      'people_data': {
        'floor_1': {
          'total': floor1Total,
          'evacuated': floor1Evacuated,
          'remaining': floor1Total - floor1Evacuated,
          'exit_left': f1_exitA,
          'exit_left_done': f1_exitA_done,
          'exit_right': f1_exitB,
          'exit_right_done': f1_exitB_done,
          'exit_top': f1_exitC,
          'exit_top_done': f1_exitC_done,
        },
        'floor_2': {
          'total': floor2Total,
          'evacuated': floor2Evacuated,
          'remaining': floor2Total - floor2Evacuated,
          'exit_right': f2_exitB_direct,
          'exit_right_done': f2_exitB_done,
          'stair_left': f2_stairLeft,
          'stair_left_done': f2_stairLeft_done,
          'stair_right': f2_stairRight,
          'stair_right_done': f2_stairRight_done,
        },
        'floor_3': {
          'total': floor3Total,
          'evacuated': floor3Evacuated,
          'remaining': floor3Total - floor3Evacuated,
          'stair_left': f3_stairLeft,
          'stair_left_done': f3_stairLeft_done,
          'stair_right': f3_stairRight,
          'stair_right_done': f3_stairRight_done,
        }
      },
      'global_stats': {
        'total_agents': globalStats['total_agents'],
        'finished_agents': globalStats['finished_agents'],
        't50': globalStats['t50'],
        't80': globalStats['t80'],
        't99': globalStats['t99'],
        'reroute_events': globalStats['total_reroute_events'],
      }
    };
  }

  // ==========================================================================
  // 테스트용 더미 데이터 (개발 중에만 사용)
  // ==========================================================================
  static FireData _generateTestData(String role) {
    // 테스트 상황 선택
    // final situation = 'false_alarm';
    final situation = 'evacuate';
    // final situation = 'initial_fire';

    if (situation == 'false_alarm' || situation == 'initial_fire') {
      return FireData(situation: situation, role: role);
    }

    return FireData(
      situation: situation,
      role: role,
      evacuationData: (role == 'manager' || role == 'firefighter')
          ? _generateTestManagerData()
          : _generateTestEvacuationData(),
    );
  }

  static Map<String, dynamic> _generateTestEvacuationData() {
    final random = Random();

    // 테스트 시나리오
    final startFloor = 'F1';
    final fireLocation = 'F1_ROOM_110';

    String assignedExit;
    List<String> path;
    String startRoom;

    if (startFloor == 'F3') {
      final floor3Rooms = [
        {
          'room': 'F3_ROOM_313',
          'door': 'F3_DOOR_313',
          'exit': 'F1_EXIT_B',
          'halls': [
            'F3_HALL_02',
            'F3_HALL_03',
            'F3_HALL_04',
            'F3_HALL_05',
            'F3_HALL_06',
            'F3_HALL_07',
            'F3_HALL_08',
            'F3_HALL_09',
            'F3_HALL_10',
            'F3_HALL_11',
            'F3_HALL_12',
            'F3_HALL_13'
          ],
          'stair': 'F3_STAIR_2'
        },
      ];

      final selectedRoom = floor3Rooms[random.nextInt(floor3Rooms.length)];
      startRoom = selectedRoom['room'] as String;
      assignedExit = selectedRoom['exit'] as String;
      final halls = selectedRoom['halls'] as List<String>;
      final stairPath = selectedRoom['stair'] as String;
      final f1Hall = stairPath == 'F3_STAIR_1' ? 'F1_HALL_01' : 'F1_HALL_15';

      path = [
        startRoom,
        selectedRoom['door'] as String,
        ...halls,
        stairPath,
        stairPath.replaceFirst('F3', 'F2'),
        stairPath.replaceFirst('F3', 'F1'),
        f1Hall,
        assignedExit,
        'SUPER_EXIT',
      ];
    } else if (startFloor == 'F2') {
      final floor2Rooms = [
        {
          'room': 'F2_ROOM_204',
          'door': 'F2_DOOR_204_A',
          'exit': 'F2_EXIT_B',
          'halls': [
            'F2_HALL_07',
            'F2_HALL_08',
            'F2_HALL_09',
            'F2_HALL_10',
            'F2_HALL_11',
            'F2_HALL_20',
            'F2_HALL_13'
          ],
          'direct': true
        },
      ];

      final selectedRoom = floor2Rooms[random.nextInt(floor2Rooms.length)];
      startRoom = selectedRoom['room'] as String;
      assignedExit = selectedRoom['exit'] as String;
      final halls = selectedRoom['halls'] as List<String>;

      path = [
        startRoom,
        selectedRoom['door'] as String,
        ...halls,
        assignedExit,
        'SUPER_EXIT',
      ];
    } else {
      final floor1Rooms = [
        {
          'room': 'F1_ROOM_101',
          'door': 'F1_DOOR_101',
          'exit': 'F1_EXIT_A',
          'halls': ['F1_HALL_02', 'F1_HALL_01'],
        },
        {
          'room': 'F1_ROOM_116',
          'door': 'F1_DOOR_116_A',
          'exit': 'F1_EXIT_B',
          'halls': [
            'F1_HALL_09',
            'F1_HALL_10',
            'F1_HALL_11',
            'F1_HALL_20',
            'F1_HALL_12',
            'F1_HALL_13'
          ],
        },
      ];

      final selectedRoom = floor1Rooms[random.nextInt(floor1Rooms.length)];
      startRoom = selectedRoom['room'] as String;
      assignedExit = selectedRoom['exit'] as String;
      final halls = selectedRoom['halls'] as List<String>;

      path = [
        startRoom,
        selectedRoom['door'] as String,
        ...halls,
        assignedExit,
        'SUPER_EXIT',
      ];
    }

    return {
      'start_floor': startFloor,
      'start_room': startRoom,
      'path': path,
      'assigned_exit': assignedExit,
      'fire_location': fireLocation,
      'speed_mps': 1.4,
      'done': false,
    };
  }

  static Map<String, dynamic> _generateTestManagerData() {
    return {
      'floor': 1,
      'people_data': {
        'floor_1': {
          'total': 350,
          'evacuated': 245,
          'remaining': 105,
          'exit_left': 180,
          'exit_left_done': 135,
          'exit_right': 120,
          'exit_right_done': 85,
          'exit_top': 50,
          'exit_top_done': 25,
        },
        'floor_2': {
          'total': 320,
          'evacuated': 160,
          'remaining': 160,
          'exit_right': 200,
          'exit_right_done': 110,
          'stair_left': 60,
          'stair_left_done': 25,
          'stair_right': 60,
          'stair_right_done': 25,
        },
        'floor_3': {
          'total': 180,
          'evacuated': 75,
          'remaining': 105,
          'stair_left': 80,
          'stair_left_done': 35,
          'stair_right': 100,
          'stair_right_done': 40,
        }
      },
      'global_stats': {
        'total_agents': 850,
        'finished_agents': 480,
        't50': 95.5,
        't80': 165.8,
        't99': 285.0,
        'reroute_events': 85,
      }
    };
  }
}
