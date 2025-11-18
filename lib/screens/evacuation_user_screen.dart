import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// 대피 화면 - 사용자용
// 층별 평면도에 대피 경로를 표시하고, 화재 위치를 아이콘으로 표시
// 우측에 미니맵으로 전체 대피 경로를 표시 (3층 → 2층 → 1층 → 출구)

// 월드 좌표계 상수 (미터 단위)
const double kWorldWidthM = 78.0;
const double kWorldHeightM = 50.0;

// 평면도 이미지 크기 (픽셀)
const double kFloorPlanWidth = 1920.0;
const double kFloorPlanHeight = 1080.0;

class EvacuationUserScreen extends StatefulWidget {
  final Map<String, dynamic> evacuationData;

  const EvacuationUserScreen({
    Key? key,
    required this.evacuationData,
  }) : super(key: key);

  @override
  State<EvacuationUserScreen> createState() => _EvacuationUserScreenState();
}

class _EvacuationUserScreenState extends State<EvacuationUserScreen> {
  late int floorNumber;
  late String assignedExit;
  late String startRoom;
  List<dynamic>? pathNodes;
  Timer? _dialogTimer;

  String? fireLocation;
  int? fireFloorNumber;

  String _alertState = 'hidden'; // hidden, question, warning

  // 노드 좌표 데이터 (미터 단위) - 1층, 2층, 3층의 방, 문, 복도, 계단, 출구
  final Map<String, Map<String, double>> _nodeCoordinates = {
    // 1층 방들
    'F1_ROOM_101': {'x': 9, 'y': 4},
    'F1_ROOM_102': {'x': 18, 'y': 4},
    'F1_ROOM_103': {'x': 30, 'y': 4},
    'F1_ROOM_104': {'x': 42, 'y': 4},
    'F1_ROOM_105': {'x': 54, 'y': 4},
    'F1_ROOM_106': {'x': 66, 'y': 4},
    'F1_ROOM_WC_W': {'x': 75, 'y': 16},
    'F1_ROOM_107': {'x': 75, 'y': 26},
    'F1_ROOM_108': {'x': 75, 'y': 35},
    'F1_ROOM_109': {'x': 75, 'y': 41},
    'F1_ROOM_110': {'x': 75, 'y': 47},
    'F1_ROOM_111': {'x': 66, 'y': 47},
    'F1_ROOM_112': {'x': 66, 'y': 41},
    'F1_ROOM_113': {'x': 66, 'y': 35},
    'F1_ROOM_114': {'x': 66, 'y': 26},
    'F1_ROOM_115': {'x': 66, 'y': 16},
    'F1_ROOM_116': {'x': 54, 'y': 16},
    'F1_ROOM_117': {'x': 42, 'y': 16},
    'F1_ROOM_118': {'x': 30, 'y': 16},
    'F1_ROOM_119': {'x': 18, 'y': 16},
    'F1_ROOM_120': {'x': 9, 'y': 16},
    'F1_ROOM_WC_M': {'x': 3, 'y': 16},

    // 1층 문들
    'F1_DOOR_101': {'x': 9, 'y': 8},
    'F1_DOOR_102_A': {'x': 13, 'y': 8},
    'F1_DOOR_102_B': {'x': 23, 'y': 8},
    'F1_DOOR_103_A': {'x': 25, 'y': 8},
    'F1_DOOR_103_B': {'x': 35, 'y': 8},
    'F1_DOOR_104_A': {'x': 37, 'y': 8},
    'F1_DOOR_104_B': {'x': 47, 'y': 8},
    'F1_DOOR_105_A': {'x': 49, 'y': 8},
    'F1_DOOR_105_B': {'x': 59, 'y': 8},
    'F1_DOOR_106_A': {'x': 61, 'y': 8},
    'F1_DOOR_106_B': {'x': 71, 'y': 8},
    'F1_DOOR_WC_W': {'x': 72, 'y': 16},
    'F1_DOOR_107_A': {'x': 72, 'y': 21},
    'F1_DOOR_107_B': {'x': 72, 'y': 31},
    'F1_DOOR_108': {'x': 72, 'y': 35},
    'F1_DOOR_109': {'x': 72, 'y': 41},
    'F1_DOOR_110': {'x': 72, 'y': 47},
    'F1_DOOR_111': {'x': 68, 'y': 47},
    'F1_DOOR_112': {'x': 68, 'y': 41},
    'F1_DOOR_113': {'x': 68, 'y': 35},
    'F1_DOOR_114_A': {'x': 68, 'y': 21},
    'F1_DOOR_114_B': {'x': 68, 'y': 31},
    'F1_DOOR_115': {'x': 68, 'y': 16},
    'F1_DOOR_WC_M': {'x': 3, 'y': 12},
    'F1_DOOR_120': {'x': 9, 'y': 12},
    'F1_DOOR_119_A': {'x': 13, 'y': 12},
    'F1_DOOR_119_B': {'x': 23, 'y': 12},
    'F1_DOOR_118_A': {'x': 25, 'y': 12},
    'F1_DOOR_118_B': {'x': 35, 'y': 12},
    'F1_DOOR_117_A': {'x': 37, 'y': 12},
    'F1_DOOR_117_B': {'x': 47, 'y': 12},
    'F1_DOOR_116_A': {'x': 49, 'y': 12},
    'F1_DOOR_116_B': {'x': 59, 'y': 12},

    // 1층 복도
    'F1_HALL_01': {'x': 3, 'y': 10},
    'F1_HALL_02': {'x': 9, 'y': 10},
    'F1_HALL_03': {'x': 13, 'y': 10},
    'F1_HALL_04': {'x': 23, 'y': 10},
    'F1_HALL_05': {'x': 25, 'y': 10},
    'F1_HALL_06': {'x': 35, 'y': 10},
    'F1_HALL_07': {'x': 37, 'y': 10},
    'F1_HALL_08': {'x': 47, 'y': 10},
    'F1_HALL_09': {'x': 49, 'y': 10},
    'F1_HALL_10': {'x': 59, 'y': 10},
    'F1_HALL_11': {'x': 61, 'y': 10},
    'F1_HALL_12': {'x': 71, 'y': 10},
    'F1_HALL_13': {'x': 75, 'y': 10},
    'F1_HALL_14': {'x': 70, 'y': 16},
    'F1_HALL_15': {'x': 70, 'y': 21},
    'F1_HALL_16': {'x': 70, 'y': 31},
    'F1_HALL_17': {'x': 70, 'y': 35},
    'F1_HALL_18': {'x': 70, 'y': 41},
    'F1_HALL_19': {'x': 70, 'y': 47},
    'F1_HALL_20': {'x': 70, 'y': 10},

    // 1층 출구
    'F1_EXIT_A': {'x': 2, 'y': 9},
    'F1_EXIT_B': {'x': 76, 'y': 10},
    'F1_EXIT_C': {'x': 70, 'y': 49},
    'SUPER_EXIT': {'x': 0, 'y': 10},

    // 2층 출구
    'F2_EXIT_B': {'x': 76, 'y': 10},

    // 1층 계단
    'F1_STAIR_1': {'x': 3, 'y': 4},
    'F1_STAIR_2': {'x': 75, 'y': 4},

    // 2층 방들
    'F2_ROOM_201': {'x': 9, 'y': 4},
    'F2_ROOM_202': {'x': 18, 'y': 4},
    'F2_ROOM_203': {'x': 30, 'y': 4},
    'F2_ROOM_204': {'x': 42, 'y': 4},
    'F2_ROOM_205': {'x': 54, 'y': 4},
    'F2_ROOM_206': {'x': 66, 'y': 4},
    'F2_ROOM_WC_W': {'x': 75, 'y': 16},
    'F2_ROOM_207': {'x': 70, 'y': 16},
    'F2_ROOM_208': {'x': 66, 'y': 16},
    'F2_ROOM_209': {'x': 54, 'y': 16},
    'F2_ROOM_210': {'x': 42, 'y': 16},
    'F2_ROOM_211': {'x': 30, 'y': 16},
    'F2_ROOM_212': {'x': 18, 'y': 16},
    'F2_ROOM_213': {'x': 9, 'y': 16},
    'F2_ROOM_WC_M': {'x': 3, 'y': 16},

    // 2층 문들
    'F2_DOOR_201': {'x': 9, 'y': 8},
    'F2_DOOR_202_A': {'x': 13, 'y': 8},
    'F2_DOOR_202_B': {'x': 23, 'y': 8},
    'F2_DOOR_203_A': {'x': 25, 'y': 8},
    'F2_DOOR_203_B': {'x': 35, 'y': 8},
    'F2_DOOR_204_A': {'x': 37, 'y': 8},
    'F2_DOOR_204_B': {'x': 47, 'y': 8},
    'F2_DOOR_205_A': {'x': 49, 'y': 8},
    'F2_DOOR_205_B': {'x': 59, 'y': 8},
    'F2_DOOR_206_A': {'x': 61, 'y': 8},
    'F2_DOOR_206_B': {'x': 71, 'y': 8},
    'F2_DOOR_WC_W': {'x': 75, 'y': 12},
    'F2_DOOR_207': {'x': 70, 'y': 12},
    'F2_DOOR_208': {'x': 64, 'y': 12},
    'F2_DOOR_209_A': {'x': 49, 'y': 12},
    'F2_DOOR_209_B': {'x': 59, 'y': 12},
    'F2_DOOR_210_A': {'x': 37, 'y': 12},
    'F2_DOOR_210_B': {'x': 47, 'y': 12},
    'F2_DOOR_211_A': {'x': 25, 'y': 12},
    'F2_DOOR_211_B': {'x': 35, 'y': 12},
    'F2_DOOR_212_A': {'x': 13, 'y': 12},
    'F2_DOOR_212_B': {'x': 23, 'y': 12},
    'F2_DOOR_213': {'x': 9, 'y': 12},
    'F2_DOOR_WC_M': {'x': 3, 'y': 12},

    // 2층 복도
    'F2_HALL_01': {'x': 3, 'y': 10},
    'F2_HALL_02': {'x': 9, 'y': 10},
    'F2_HALL_03': {'x': 13, 'y': 10},
    'F2_HALL_04': {'x': 23, 'y': 10},
    'F2_HALL_05': {'x': 25, 'y': 10},
    'F2_HALL_06': {'x': 35, 'y': 10},
    'F2_HALL_07': {'x': 37, 'y': 10},
    'F2_HALL_08': {'x': 47, 'y': 10},
    'F2_HALL_09': {'x': 49, 'y': 10},
    'F2_HALL_10': {'x': 59, 'y': 10},
    'F2_HALL_11': {'x': 61, 'y': 10},
    'F2_HALL_12': {'x': 64, 'y': 10},
    'F2_HALL_13': {'x': 70, 'y': 10},
    'F2_HALL_14': {'x': 71, 'y': 10},
    'F2_HALL_15': {'x': 75, 'y': 10},

    // 2층 계단
    'F2_STAIR_1': {'x': 3, 'y': 4},
    'F2_STAIR_2': {'x': 75, 'y': 4},

    // 3층 방들
    'F3_ROOM_301': {'x': 9, 'y': 4},
    'F3_ROOM_302': {'x': 18, 'y': 4},
    'F3_ROOM_303': {'x': 30, 'y': 4},
    'F3_ROOM_304': {'x': 42, 'y': 4},
    'F3_ROOM_305': {'x': 54, 'y': 4},
    'F3_ROOM_306': {'x': 66, 'y': 4},
    'F3_ROOM_WC_W': {'x': 75, 'y': 16},
    'F3_ROOM_307': {'x': 70, 'y': 16},
    'F3_ROOM_308': {'x': 66, 'y': 16},
    'F3_ROOM_309': {'x': 54, 'y': 16},
    'F3_ROOM_310': {'x': 42, 'y': 16},
    'F3_ROOM_311': {'x': 30, 'y': 16},
    'F3_ROOM_312': {'x': 18, 'y': 16},
    'F3_ROOM_313': {'x': 9, 'y': 16},
    'F3_ROOM_WC_M': {'x': 3, 'y': 16},

    // 3층 문들
    'F3_DOOR_301': {'x': 9, 'y': 8},
    'F3_DOOR_302_A': {'x': 13, 'y': 8},
    'F3_DOOR_302_B': {'x': 23, 'y': 8},
    'F3_DOOR_303_A': {'x': 25, 'y': 8},
    'F3_DOOR_303_B': {'x': 35, 'y': 8},
    'F3_DOOR_304_A': {'x': 37, 'y': 8},
    'F3_DOOR_304_B': {'x': 47, 'y': 8},
    'F3_DOOR_305_A': {'x': 49, 'y': 8},
    'F3_DOOR_305_B': {'x': 59, 'y': 8},
    'F3_DOOR_306_A': {'x': 61, 'y': 8},
    'F3_DOOR_306_B': {'x': 71, 'y': 8},
    'F3_DOOR_WC_W': {'x': 75, 'y': 12},
    'F3_DOOR_307': {'x': 70, 'y': 12},
    'F3_DOOR_308': {'x': 64, 'y': 12},
    'F3_DOOR_309_A': {'x': 49, 'y': 12},
    'F3_DOOR_309_B': {'x': 59, 'y': 12},
    'F3_DOOR_310_A': {'x': 37, 'y': 12},
    'F3_DOOR_310_B': {'x': 47, 'y': 12},
    'F3_DOOR_311_A': {'x': 25, 'y': 12},
    'F3_DOOR_311_B': {'x': 35, 'y': 12},
    'F3_DOOR_312_A': {'x': 13, 'y': 12},
    'F3_DOOR_312_B': {'x': 23, 'y': 12},
    'F3_DOOR_313': {'x': 9, 'y': 12},
    'F3_DOOR_WC_M': {'x': 3, 'y': 12},

    // 3층 복도
    'F3_HALL_01': {'x': 3, 'y': 10},
    'F3_HALL_02': {'x': 9, 'y': 10},
    'F3_HALL_03': {'x': 13, 'y': 10},
    'F3_HALL_04': {'x': 23, 'y': 10},
    'F3_HALL_05': {'x': 25, 'y': 10},
    'F3_HALL_06': {'x': 35, 'y': 10},
    'F3_HALL_07': {'x': 37, 'y': 10},
    'F3_HALL_08': {'x': 47, 'y': 10},
    'F3_HALL_09': {'x': 49, 'y': 10},
    'F3_HALL_10': {'x': 59, 'y': 10},
    'F3_HALL_11': {'x': 61, 'y': 10},
    'F3_HALL_12': {'x': 64, 'y': 10},
    'F3_HALL_13': {'x': 70, 'y': 10},
    'F3_HALL_14': {'x': 71, 'y': 10},
    'F3_HALL_15': {'x': 75, 'y': 10},

    // 3층 계단
    'F3_STAIR_1': {'x': 3, 'y': 4},
    'F3_STAIR_2': {'x': 75, 'y': 4},
  };

  @override
  void initState() {
    super.initState();

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // 대피 데이터 파싱 (층, 출구, 경로, 화재 위치)
    if (widget.evacuationData.isNotEmpty) {
      String startFloor = widget.evacuationData['start_floor'] ?? 'F1';
      floorNumber = int.parse(startFloor.replaceAll('F', ''));

      assignedExit = widget.evacuationData['assigned_exit'] ?? 'F1_EXIT_A';
      startRoom = widget.evacuationData['start_room'] ?? '';
      pathNodes = widget.evacuationData['path'] ?? [];

      // 화재 위치 파싱 (F1_ROOM_101 → 1층)
      fireLocation = widget.evacuationData['fire_location'];
      if (fireLocation != null && fireLocation!.startsWith('F')) {
        fireFloorNumber =
            int.parse(fireLocation!.split('_')[0].replaceAll('F', ''));
      }
    } else {
      floorNumber = 1;
      assignedExit = 'F1_EXIT_A';
      startRoom = '';
      pathNodes = [];
    }

    // 10초 후 화재 진압 성공 여부 알림 표시
    _dialogTimer = Timer(Duration(seconds: 10), () {
      if (mounted) {
        setState(() {
          _alertState = 'question';
        });
      }
    });
  }

  @override
  void dispose() {
    _dialogTimer?.cancel();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  void _showEmergencySnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.phone_in_talk, color: Colors.white, size: 24),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                '소방관에게 자동 신고중...',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(16),
      ),
    );
  }

  // 화재 진압 성공 여부 질문 알림
  Widget _buildQuestionAlert() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.purple.shade300, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '화재 진압 성공하셨나요?',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 36,
            child: ElevatedButton(
              onPressed: () {
                SystemNavigator.pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                padding: EdgeInsets.symmetric(horizontal: 8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, color: Colors.white, size: 16),
                  SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      '네, 화재 진압 완료입니다',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 36,
            child: ElevatedButton(
              onPressed: () {
                setState(() {
                  _alertState = 'warning';
                });
                _showEmergencySnackBar();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                padding: EdgeInsets.symmetric(horizontal: 8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.warning, color: Colors.white, size: 16),
                  SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      '아니요, 화재 진압 실패했습니다',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 경고 문구 알림 (화재 진압 실패 시)
  Widget _buildWarningAlert() {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50.withOpacity(0.98),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, size: 24, color: Colors.orange),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  '긴급 상황',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade900,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          _buildWarningItem('1. 자세를 낮추세요!'),
          SizedBox(height: 6),
          _buildWarningItem('2. 수건으로 코와 입을 막으세요'),
          SizedBox(height: 6),
          _buildWarningItem('3. 소방관이 올 때까지 안전하게 대피해주세요'),
        ],
      ),
    );
  }

  Widget _buildWarningItem(String text, {String? highlight}) {
    return Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        children: [
          Icon(Icons.circle, size: 5, color: Colors.orange),
          SizedBox(width: 8),
          Expanded(
            child: highlight != null
                ? RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      children: [
                        TextSpan(text: text),
                        TextSpan(
                          text: ' $highlight',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ],
                    ),
                  )
                : Text(
                    text,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // 미터 좌표를 화면 픽셀 좌표로 변환
  Offset? _meterToPixel(double meterX, double meterY, Size screenSize) {
    double leftMargin = screenSize.width * 0.15;
    double mapWidth = screenSize.width * 0.70;

    double pixelX = leftMargin + (meterX / kWorldWidthM) * mapWidth;
    double pixelY =
        screenSize.height - (meterY / kWorldHeightM) * screenSize.height;
    return Offset(pixelX, pixelY);
  }

  Offset? _getCoordinate(String nodeId, Size screenSize) {
    if (_nodeCoordinates.containsKey(nodeId)) {
      final coord = _nodeCoordinates[nodeId]!;
      return _meterToPixel(coord['x']!, coord['y']!, screenSize);
    }
    return null;
  }

  // 현재 층의 대피 경로만 필터링
  List<String> _getCurrentFloorPath() {
    if (pathNodes == null || pathNodes!.isEmpty) return [];

    List<String> currentFloorPath = [];
    for (var node in pathNodes!) {
      String nodeStr = node.toString();
      if (nodeStr.startsWith('F$floorNumber')) {
        currentFloorPath.add(nodeStr);
      }
    }
    return currentFloorPath;
  }

  // 화재 위치 아이콘 (메인 맵에 표시, 펄스 애니메이션)
  Widget _buildFireLocationIcon(Size screenSize) {
    if (fireLocation == null) return SizedBox.shrink();

    final fireCoord = _getCoordinate(fireLocation!, screenSize);
    if (fireCoord == null) return SizedBox.shrink();

    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 1.0, end: 1.3),
      duration: Duration(milliseconds: 800),
      curve: Curves.easeInOut,
      builder: (context, double scale, child) {
        return Positioned(
          left: fireCoord.dx - 20,
          top: fireCoord.dy - 20,
          child: Transform.scale(
            scale: scale,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.6),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Image.asset(
                'web/icons/fire_icon.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
        );
      },
      onEnd: () {
        if (mounted) {
          Future.delayed(Duration(milliseconds: 100), () {
            if (mounted) setState(() {});
          });
        }
      },
    );
  }

  // 화재 위치 아이콘 (미니맵에 표시, 펄스 애니메이션)
  Widget _buildFireIconOnMinimap(double minimapWidth, double minimapHeight) {
    if (fireLocation == null) return SizedBox.shrink();
    int? fireFloor;
    if (fireLocation!.startsWith('F1')) {
      fireFloor = 1;
    } else if (fireLocation!.startsWith('F2')) {
      fireFloor = 2;
    } else if (fireLocation!.startsWith('F3')) {
      fireFloor = 3;
    }

    if (fireFloor == null) return SizedBox.shrink();

    // 미니맵 층별 Y 좌표 계산
    double floorHeight = minimapHeight / 3.0;
    double floor3Y = minimapHeight * 0.10;
    double floor2Y = floor3Y + floorHeight;
    double floor1Y = floor2Y + floorHeight;

    double fireY;
    if (fireFloor == 3) {
      fireY = floor3Y;
    } else if (fireFloor == 2) {
      fireY = floor2Y;
    } else {
      fireY = floor1Y;
    }

    // 화재 위치 X 좌표 (방 번호로 좌/우 판단)
    double centerX = minimapWidth / 2;
    double fireX = centerX - 25;
    if (fireLocation!.contains('_110') ||
        fireLocation!.contains('_115') ||
        fireLocation!.contains('_210') ||
        fireLocation!.contains('_215') ||
        fireLocation!.contains('_310') ||
        fireLocation!.contains('_313')) {
      fireX = centerX + 25;
    }

    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 1.0, end: 1.4),
      duration: Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      builder: (context, double scale, child) {
        return Positioned(
          left: fireX - 8,
          top: fireY + 8 - 8,
          child: Transform.scale(
            scale: scale,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.5),
                    blurRadius: 8,
                    spreadRadius: 3,
                  ),
                ],
              ),
              child: Image.asset(
                'web/icons/fire_icon.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
        );
      },
      onEnd: () {
        if (mounted) {
          Future.delayed(Duration(milliseconds: 100), () {
            if (mounted) setState(() {});
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    List<String> currentFloorPath = _getCurrentFloorPath();
    Size screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 중앙: 층별 평면도 (70% 너비)
          Positioned(
            left: screenSize.width * 0.15,
            top: 0,
            width: screenSize.width * 0.70,
            height: screenSize.height,
            child: Image.asset(
              'web/icons/floor_${floorNumber}_plan.png',
              fit: BoxFit.fill,
              errorBuilder: (context, error, stackTrace) {
                return Center(
                  child: Text(
                    '도면 이미지를 불러올 수 없습니다\nfloor_${floorNumber}_plan.png',
                    style: TextStyle(color: Colors.red, fontSize: 18),
                    textAlign: TextAlign.center,
                  ),
                );
              },
            ),
          ),
          // 대피 경로 그리기 (CustomPaint)
          if (currentFloorPath.isNotEmpty)
            Positioned.fill(
              child: CustomPaint(
                painter: EvacuationPathPainter(
                  path: currentFloorPath,
                  getCoordinate: (nodeId) => _getCoordinate(nodeId, screenSize),
                  startRoom: startRoom,
                  screenSize: screenSize,
                ),
              ),
            ),
          // 화재 위치 아이콘 (현재 층인 경우만 표시)
          if (fireLocation != null && fireFloorNumber == floorNumber)
            _buildFireLocationIcon(screenSize),
          // 좌측: 빨간색 사이드바 배경
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: screenSize.width * 0.15,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFEF5350),
                    Color(0xFFE57373),
                  ],
                ),
              ),
            ),
          ),
          // 좌측: 사이드바 콘텐츠 (화재 발생, 즉시 대피, 뒤로가기)
          Positioned(
            left: 60,
            top: 0,
            bottom: 0,
            width: screenSize.width * 0.15 - 60,
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 20, horizontal: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SizedBox(height: 20),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade700,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 8,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(Icons.local_fire_department,
                              color: Colors.white, size: 28),
                        ),
                        SizedBox(height: 10),
                        Text(
                          '화재\n발생',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            height: 1.15,
                            shadows: [
                              Shadow(
                                color: Colors.black26,
                                blurRadius: 4,
                                offset: Offset(2, 2),
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 18),
                        Container(
                          padding: EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: Colors.yellow.shade700,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 8,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(Icons.warning_amber_rounded,
                              color: Colors.white, size: 22),
                        ),
                        SizedBox(height: 10),
                        Text(
                          '즉시\n대피하세요',
                          style: TextStyle(
                            color: Colors.yellow.shade100,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                            height: 1.15,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.5), width: 2),
                    ),
                    child: IconButton(
                      icon: Icon(Icons.arrow_back_ios,
                          color: Colors.white, size: 26),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 우측: 전체 대피 경로 미니맵
          if (pathNodes != null && pathNodes!.isNotEmpty)
            Positioned(
              right: screenSize.width * 0.01,
              top: 20,
              bottom: 20,
              child: Container(
                width: screenSize.width * 0.13,
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      '전체 대피 경로',
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 12),
                    Expanded(
                      child: Center(
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            CustomPaint(
                              size: Size(
                                screenSize.width * 0.10,
                                screenSize.height * 0.65,
                              ),
                              painter: OverallPathPainter(
                                pathNodes: pathNodes!,
                                fireLocation: null,
                                assignedExit: assignedExit,
                              ),
                            ),
                            if (fireLocation != null)
                              _buildFireIconOnMinimap(
                                screenSize.width * 0.10,
                                screenSize.height * 0.65,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // 화재 진압 성공/실패 알림
          if (_alertState != 'hidden')
            Positioned(
              left: screenSize.width * 0.15 + 25,
              top: 20,
              child: Container(
                width: screenSize.width * 0.42,
                child: _alertState == 'question'
                    ? _buildQuestionAlert()
                    : _buildWarningAlert(),
              ),
            ),
          // 층수 표시 (2층, 3층만)
          if (floorNumber >= 2)
            Positioned(
              right: screenSize.width * 0.15 + 30,
              top: 30,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade400, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  '${floorNumber}F',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// 대피 경로 그리기 Painter (현재 층의 경로를 빨간 선으로 표시)
class EvacuationPathPainter extends CustomPainter {
  final List<String> path;
  final Offset? Function(String) getCoordinate;
  final String startRoom;
  final Size screenSize;

  EvacuationPathPainter({
    required this.path,
    required this.getCoordinate,
    required this.startRoom,
    required this.screenSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (path.isEmpty) return;

    // 경로 노드들의 좌표 수집
    List<Offset> coords = [];
    for (var nodeId in path) {
      Offset? coord = getCoordinate(nodeId);
      if (coord != null) {
        coords.add(coord);
      }
    }

    if (coords.isEmpty) return;

    double mapWidth = screenSize.width * 0.70;
    double scaleX = mapWidth / kFloorPlanWidth;
    double scaleY = screenSize.height / kFloorPlanHeight;

    // 경로 선 그리기
    Paint pathPaint = Paint()
      ..color = Colors.red.withOpacity(0.9)
      ..strokeWidth = 8 * scaleX
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    Path pathLine = Path();
    pathLine.moveTo(coords[0].dx, coords[0].dy);

    double threshold = 30 * scaleX;

    // 직각으로 꺾어서 경로 그리기
    for (int i = 1; i < coords.length; i++) {
      Offset current = coords[i - 1];
      Offset next = coords[i];

      double dx = (next.dx - current.dx).abs();
      double dy = (next.dy - current.dy).abs();

      if (dx < threshold) {
        pathLine.lineTo(current.dx, next.dy);
        coords[i] = Offset(current.dx, next.dy);
      } else if (dy < threshold) {
        pathLine.lineTo(next.dx, current.dy);
        coords[i] = Offset(next.dx, current.dy);
      } else {
        pathLine.lineTo(next.dx, current.dy);
        pathLine.lineTo(next.dx, next.dy);
      }
    }
    canvas.drawPath(pathLine, pathPaint);

    // 시작점 (초록색 원)
    Paint startPaint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.fill;
    canvas.drawCircle(coords[0], 12 * scaleX, startPaint);

    // 종료점 (빨간색 원)
    Paint endPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;
    canvas.drawCircle(coords[coords.length - 1], 12 * scaleX, endPaint);

    // 중간 노드 (작은 빨간색 점)
    Paint nodePaint = Paint()
      ..color = Colors.red.withOpacity(0.5)
      ..style = PaintingStyle.fill;
    for (int i = 1; i < coords.length - 1; i++) {
      canvas.drawCircle(coords[i], 4 * scaleX, nodePaint);
    }
  }

  @override
  bool shouldRepaint(EvacuationPathPainter oldDelegate) {
    return oldDelegate.path != path || oldDelegate.startRoom != startRoom;
  }
}

// 전체 대피 경로 Painter (미니맵에 3층 → 2층 → 1층 → 출구를 표시)
class OverallPathPainter extends CustomPainter {
  final List<dynamic> pathNodes;
  final String? fireLocation;
  final String assignedExit;

  OverallPathPainter({
    required this.pathNodes,
    this.fireLocation,
    required this.assignedExit,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 층별로 노드 필터링
    List<String> floor3Nodes = [];
    List<String> floor2Nodes = [];
    List<String> floor1Nodes = [];

    for (var node in pathNodes) {
      String nodeStr = node.toString();
      if (nodeStr.startsWith('F3')) {
        floor3Nodes.add(nodeStr);
      } else if (nodeStr.startsWith('F2')) {
        floor2Nodes.add(nodeStr);
      } else if (nodeStr.startsWith('F1')) {
        floor1Nodes.add(nodeStr);
      }
    }

    // 시작 층 판단
    String startFloor = '';
    if (floor3Nodes.isNotEmpty) {
      startFloor = 'F3';
    } else if (floor2Nodes.isNotEmpty) {
      startFloor = 'F2';
    } else if (floor1Nodes.isNotEmpty) {
      startFloor = 'F1';
    }

    // 좌측/우측 경로 판단 (EXIT_A는 left, EXIT_B/C는 right)
    bool isRightPath = false;
    for (var node in pathNodes) {
      String nodeStr = node.toString();
      if (nodeStr.contains('EXIT_B') ||
          nodeStr.contains('EXIT_C') ||
          nodeStr.contains('STAIR_2')) {
        isRightPath = true;
        break;
      }
      if (nodeStr.contains('EXIT_A') || nodeStr.contains('STAIR_1')) {
        isRightPath = false;
        break;
      }
    }

    // 층별 Y 좌표 계산
    double floorHeight = size.height / 3.0;
    double floor3Y = size.height * 0.10;
    double floor2Y = floor3Y + floorHeight;
    double floor1Y = floor2Y + floorHeight;
    double centerX = size.width / 2;

    double pathX = isRightPath ? centerX + 35 : centerX - 25;

    // 3층 레이블 및 경로
    _drawFloorLabel(canvas, '3F', centerX - 50, floor3Y,
        startFloor == 'F3' ? Colors.red : Colors.grey);
    if (startFloor == 'F3' && floor3Nodes.isNotEmpty) {
      _drawFloorPathWithLine(
          canvas, floor3Nodes.length, pathX, floor3Y, Colors.red);
    }

    // 2층 레이블 및 경로
    _drawFloorLabel(canvas, '2F', centerX - 50, floor2Y,
        startFloor == 'F2' ? Colors.red : Colors.grey);
    if (startFloor == 'F2' && floor2Nodes.isNotEmpty) {
      _drawFloorPathWithLine(
          canvas, floor2Nodes.length, pathX, floor2Y, Colors.red);
    }

    // 3층 → 2층 계단 연결선 (파란색)
    if (floor3Nodes.isNotEmpty && floor2Nodes.isNotEmpty) {
      Paint linePaint = Paint()
        ..color = Colors.blue
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke;
      canvas.drawLine(
        Offset(pathX, floor3Y + 8),
        Offset(pathX, floor2Y + 4),
        linePaint,
      );
    }

    // 1층 레이블
    _drawFloorLabel(canvas, '1F', centerX - 50, floor1Y,
        startFloor == 'F1' ? Colors.red : Colors.grey);

    // 2층 → 1층 계단 연결선 (파란색)
    if (floor2Nodes.isNotEmpty && floor1Nodes.isNotEmpty) {
      Paint linePaint = Paint()
        ..color = Colors.blue
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke;
      canvas.drawLine(
        Offset(pathX, floor2Y + 8),
        Offset(pathX, floor1Y + 4),
        linePaint,
      );
    }

    // 출구 표시 (초록색 점)
    _drawExitIndicator(canvas, size, startFloor, pathX, floor1Y, floor2Y,
        floor3Y, isRightPath);
  }

  // 출구 표시 로직 (초록색 점 + 빨간색 점 연결)
  void _drawExitIndicator(
    Canvas canvas,
    Size size,
    String startFloor,
    double pathX,
    double floor1Y,
    double floor2Y,
    double floor3Y,
    bool isRightPath,
  ) {
    // 출구 층 판단
    String exitFloor = 'F1';
    if (assignedExit == 'F2_EXIT_B') {
      exitFloor = 'F2';
    } else if (assignedExit.startsWith('F1_')) {
      exitFloor = 'F1';
    }

    // 출구 방향 판단
    bool exitOnRight = false;
    if (assignedExit.contains('EXIT_B') || assignedExit.contains('EXIT_C')) {
      exitOnRight = true;
    } else if (assignedExit.contains('EXIT_A')) {
      exitOnRight = false;
    }

    double exitY = exitFloor == 'F2' ? floor2Y : floor1Y;

    // 시작 층과 출구 층이 같은 경우 (빨간색 점 + 초록색 점)
    if (startFloor == exitFloor) {
      List<String> floorNodes = [];
      for (var node in pathNodes) {
        if (node.toString().startsWith(exitFloor)) {
          floorNodes.add(node.toString());
        }
      }

      double exitX = exitOnRight ? pathX + 16 : pathX - 2;
      double lastRedX = exitX;

      if (floorNodes.isNotEmpty) {
        // 노드 개수에 따라 점 개수 결정 (최대 3개)
        int dotCount;
        if (floorNodes.length <= 4) {
          dotCount = 1;
        } else if (floorNodes.length <= 8) {
          dotCount = 2;
        } else {
          dotCount = 3;
        }

        double spacing = 8.0;
        double finalSpacing = 10.0;

        // 출구에서 역방향으로 점 배치
        double startX = exitOnRight
            ? exitX - finalSpacing - (dotCount - 1) * spacing
            : exitX + finalSpacing + (dotCount - 1) * spacing;

        lastRedX = exitOnRight ? exitX - finalSpacing : exitX + finalSpacing;

        _drawFloorPathCustom(
            canvas, floorNodes.length, startX, exitY, Colors.red, exitOnRight);
      }

      // 마지막 빨간 점 → 초록 점 연결선
      Paint linePaint = Paint()
        ..color = Colors.grey
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      canvas.drawLine(
        Offset(lastRedX, exitY + 8),
        Offset(exitX, exitY + 8),
        linePaint,
      );

      // 초록색 출구 점
      Paint exitPaint = Paint()
        ..color = Colors.green
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(exitX, exitY + 8), 4, exitPaint);
    } else {
      // 시작 층과 출구 층이 다른 경우 (초록색 점만)
      double exitX = pathX;
      Paint exitPaint = Paint()
        ..color = Colors.green
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(exitX, exitY + 8), 4, exitPaint);
    }
  }

  // 빨간색 점들을 그리기 (노드 개수에 따라 1~3개)
  void _drawFloorPathCustom(
    Canvas canvas,
    int nodeCount,
    double startX,
    double y,
    Color color,
    bool goingRight,
  ) {
    int dotCount;
    if (nodeCount <= 4) {
      dotCount = 1;
    } else if (nodeCount <= 8) {
      dotCount = 2;
    } else {
      dotCount = 3;
    }

    Paint dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    Paint linePaint = Paint()
      ..color = color.withOpacity(0.5)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    List<Offset> points = [];
    for (int i = 0; i < dotCount; i++) {
      double xOffset = goingRight ? i * 8 : -i * 8;
      Offset point = Offset(startX + xOffset, y + 8);
      points.add(point);
      canvas.drawCircle(point, 3, dotPaint);
    }

    // 점들 사이 연결선
    for (int i = 0; i < points.length - 1; i++) {
      canvas.drawLine(points[i], points[i + 1], linePaint);
    }
  }

  void _drawFloorLabel(
      Canvas canvas, String label, double x, double y, Color color) {
    TextPainter textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: color,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(x, y));
  }

  void _drawFloorPath(
      Canvas canvas, int nodeCount, double startX, double y, Color color) {
    int dotCount;

    if (nodeCount <= 4) {
      dotCount = 1;
    } else if (nodeCount <= 8) {
      dotCount = 2;
    } else {
      dotCount = 3;
    }

    Paint dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (int i = 0; i < dotCount; i++) {
      canvas.drawCircle(Offset(startX + i * 10, y + 8), 3, dotPaint);
    }
  }

  // 층별 경로 그리기 (선으로 연결)
  void _drawFloorPathWithLine(
      Canvas canvas, int nodeCount, double endX, double y, Color color) {
    int dotCount;
    if (nodeCount <= 4) {
      dotCount = 1;
    } else if (nodeCount <= 8) {
      dotCount = 2;
    } else {
      dotCount = 3;
    }

    double startX = endX - (dotCount - 1) * 10;

    if (dotCount > 1) {
      Paint linePaint = Paint()
        ..color = color.withOpacity(0.5)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;

      for (int i = 0; i < dotCount - 1; i++) {
        canvas.drawLine(
          Offset(startX + i * 10, y + 8),
          Offset(startX + (i + 1) * 10, y + 8),
          linePaint,
        );
      }
    }

    Paint dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (int i = 0; i < dotCount; i++) {
      canvas.drawCircle(Offset(startX + i * 10, y + 8), 3, dotPaint);
    }
  }

  int min(int a, int b) => a < b ? a : b;

  @override
  bool shouldRepaint(OverallPathPainter oldDelegate) {
    return oldDelegate.pathNodes != pathNodes;
  }
}
