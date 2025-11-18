import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 대피 현황 대시보드 - 관리자/소방관용
// 층별 대피 인원 현황, 출구별 배정, 진행률을 실시간으로 표시

// 월드 좌표계 상수
const double kWorldWidthPx = 800;
const double kWorldHeightPx = 500;

// 층별 스케일 맵 (2층, 3층은 1.2배 확대)
const Map<int, double> kFloorScaleMap = {
  1: 1.0,
  2: 1.20,
  3: 1.20,
};

double getFloorScale(int floor) => kFloorScaleMap[floor] ?? 1.0;

class EvacuationDashboard extends StatefulWidget {
  final Map<String, dynamic>? data;

  const EvacuationDashboard({
    Key? key,
    required this.data,
  }) : super(key: key);

  @override
  State<EvacuationDashboard> createState() => _EvacuationDashboardState();
}

class _EvacuationDashboardState extends State<EvacuationDashboard> {
  int _currentFloor = 1;
  String _userRole = 'manager';

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    if (widget.data != null) {
      _currentFloor = widget.data!['floor'] ?? 1;
    }
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userRole = prefs.getString('user_role') ?? 'manager';
    });
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  // 층별 대피 데이터 추출 (총 인원, 탈출 완료, 잔여, 출구별/계단별 배정 등)
  Map<String, dynamic> _getFloorData(int floor) {
    final peopleData = widget.data?['people_data'] as Map<String, dynamic>?;
    final floorKey = 'floor_$floor';
    final data = peopleData?[floorKey] as Map<String, dynamic>?;

    return {
      'total': data?['total'] ?? 0,
      'evacuated': data?['evacuated'] ?? 0,
      'remaining': data?['remaining'] ?? 0,
      'exit_left': data?['exit_left'] ?? 0,
      'exit_left_done': data?['exit_left_done'] ?? 0,
      'exit_right': data?['exit_right'] ?? 0,
      'exit_right_done': data?['exit_right_done'] ?? 0,
      'exit_top': data?['exit_top'] ?? 0,
      'exit_top_done': data?['exit_top_done'] ?? 0,
      'stair_left': data?['stair_left'] ?? 0,
      'stair_left_done': data?['stair_left_done'] ?? 0,
      'stair_right': data?['stair_right'] ?? 0,
      'stair_right_done': data?['stair_right_done'] ?? 0,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            _buildFloorTabs(),
            Expanded(child: _buildFloorView()),
          ],
        ),
      ),
    );
  }

  // 상단 헤더 (뒤로가기, 제목, 메뉴)
  Widget _buildHeader(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFF6B6B),
            const Color(0xFFEE5A6F),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          Text(
            _userRole == 'firefighter' ? '대피 현황 (소방관)' : '대피 현황 (관리자)',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.menu, color: Colors.white, size: 24),
            onPressed: () {},
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  // 층별 탭 (1층, 2층, 3층)
  Widget _buildFloorTabs() {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildFloorTab(1, '1층'),
          _buildFloorTab(2, '2층'),
          _buildFloorTab(3, '3층'),
        ],
      ),
    );
  }

  Widget _buildFloorTab(int floor, String label) {
    final isSelected = _currentFloor == floor;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentFloor = floor),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
                    colors: [
                      const Color(0xFFFF6B6B),
                      const Color(0xFFEE5A6F),
                    ],
                  )
                : null,
            color: isSelected ? null : Colors.transparent,
            border: Border(
              bottom: BorderSide(
                color:
                    isSelected ? const Color(0xFFFFD93D) : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }

  // 층별 뷰 (출구 카드 그리드 + 요약 바 + 층별 인원 분포)
  Widget _buildFloorView() {
    final floorData = _getFloorData(_currentFloor);
    final total = floorData['total'] as int;
    final evacuated = floorData['evacuated'] as int;
    final remaining = floorData['remaining'] as int;
    final progress = total > 0 ? (evacuated / total) : 0.0;

    return Container(
      color: const Color(0xFFF5F5F5),
      child: Row(
        children: [
          // 좌측: 출구/계단 카드 그리드 + 요약 바
          Expanded(
            flex: 65,
            child: Container(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _buildExitCards(floorData),
                  ),
                  const SizedBox(height: 10),
                  _buildSummaryBar(
                    total: total,
                    evacuated: evacuated,
                    remaining: remaining,
                    progress: progress,
                  ),
                ],
              ),
            ),
          ),
          // 우측: 층별 인원 분포
          Expanded(
            flex: 35,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(-2, 0),
                  ),
                ],
              ),
              child: _buildFloorDistribution(),
            ),
          ),
        ],
      ),
    );
  }

  // 출구/계단 카드 그리드 (층별로 다른 출구/계단 표시)
  Widget _buildExitCards(Map<String, dynamic> floorData) {
    final cards = <Map<String, dynamic>>[];

    // 1층: 좌측, 우측, 위쪽 출구
    if (_currentFloor == 1) {
      final exitLeft = floorData['exit_left'] as int;
      final exitLeftDone = floorData['exit_left_done'] as int;
      final exitRight = floorData['exit_right'] as int;
      final exitRightDone = floorData['exit_right_done'] as int;
      final exitTop = floorData['exit_top'] as int;
      final exitTopDone = floorData['exit_top_done'] as int;

      if (exitLeft > 0) {
        cards.add({
          'type': 'exit',
          'label': '좌측 출구',
          'assigned': exitLeft,
          'done': exitLeftDone,
          'color': const Color(0xFF4ECDC4),
          'icon': Icons.logout,
        });
      }
      if (exitRight > 0) {
        cards.add({
          'type': 'exit',
          'label': '우측 출구',
          'assigned': exitRight,
          'done': exitRightDone,
          'color': const Color(0xFF9B59B6),
          'icon': Icons.logout,
        });
      }
      if (exitTop > 0) {
        cards.add({
          'type': 'exit',
          'label': '위쪽 출구',
          'assigned': exitTop,
          'done': exitTopDone,
          'color': const Color(0xFFF39C12),
          'icon': Icons.logout,
        });
      }
    }
    // 2층: 우측 출구 + 좌측/우측 계단
    else if (_currentFloor == 2) {
      final exitRight = floorData['exit_right'] as int;
      final exitRightDone = floorData['exit_right_done'] as int;
      final stairLeft = floorData['stair_left'] as int;
      final stairLeftDone = floorData['stair_left_done'] as int;
      final stairRight = floorData['stair_right'] as int;
      final stairRightDone = floorData['stair_right_done'] as int;

      if (exitRight > 0) {
        cards.add({
          'type': 'exit',
          'label': '우측 출구',
          'assigned': exitRight,
          'done': exitRightDone,
          'color': const Color(0xFF9B59B6),
          'icon': Icons.logout,
        });
      }
      if (stairLeft > 0) {
        cards.add({
          'type': 'stair',
          'label': '좌측 계단',
          'assigned': stairLeft,
          'done': stairLeftDone,
          'color': const Color(0xFF3498DB),
          'icon': Icons.stairs,
        });
      }
      if (stairRight > 0) {
        cards.add({
          'type': 'stair',
          'label': '우측 계단',
          'assigned': stairRight,
          'done': stairRightDone,
          'color': const Color(0xFF3498DB),
          'icon': Icons.stairs,
        });
      }
    }
    // 3층: 좌측/우측 계단만
    else if (_currentFloor == 3) {
      final stairLeft = floorData['stair_left'] as int;
      final stairLeftDone = floorData['stair_left_done'] as int;
      final stairRight = floorData['stair_right'] as int;
      final stairRightDone = floorData['stair_right_done'] as int;

      if (stairLeft > 0) {
        cards.add({
          'type': 'stair',
          'label': '좌측 계단',
          'assigned': stairLeft,
          'done': stairLeftDone,
          'color': const Color(0xFF3498DB),
          'icon': Icons.stairs,
        });
      }
      if (stairRight > 0) {
        cards.add({
          'type': 'stair',
          'label': '우측 계단',
          'assigned': stairRight,
          'done': stairRightDone,
          'color': const Color(0xFF3498DB),
          'icon': Icons.stairs,
        });
      }
    }

    if (cards.isEmpty) {
      return Center(
        child: Text(
          '대피 인원이 없습니다',
          style: const TextStyle(
            fontSize: 16,
            color: Colors.grey,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.30,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: cards.length,
      itemBuilder: (context, index) {
        final card = cards[index];
        return _buildExitCard(
          type: card['type'] as String,
          label: card['label'] as String,
          assigned: card['assigned'] as int,
          done: card['done'] as int,
          color: card['color'] as Color,
          icon: card['icon'] as IconData,
        );
      },
    );
  }

  // 출구/계단 카드 (배정 인원, 완료 인원, 진행률, 혼잡도 표시)
  Widget _buildExitCard({
    required String type,
    required String label,
    required int assigned,
    required int done,
    required Color color,
    required IconData icon,
  }) {
    final remaining = assigned - done;
    final progressPercent = assigned > 0 ? (done / assigned * 100).toInt() : 0;

    // 혼잡도 판단 (배정 인원 기준)
    String status = '원활';
    Color statusColor = const Color(0xFF2ECC71);
    if (assigned > 200) {
      status = '혼잡';
      statusColor = const Color(0xFFE74C3C);
    } else if (assigned > 100) {
      status = '보통';
      statusColor = const Color(0xFFF39C12);
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '배정 $assigned명',
            style: TextStyle(
              fontSize: 8,
              color: Colors.grey.shade600,
            ),
          ),
          Text(
            '완료 $done명',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: statusColor,
            ),
          ),
          const SizedBox(height: 2),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: assigned > 0 ? (done / assigned) : 0,
              minHeight: 4,
              backgroundColor: Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
          ),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '$status ($progressPercent%)',
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 요약 바 (총 인원, 완료, 잔여, 진행률)
  Widget _buildSummaryBar({
    required int total,
    required int evacuated,
    required int remaining,
    required double progress,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryItem(
              '총 인원', '$total명', const Color(0xFF3498DB), Icons.people),
          _buildSummaryItem(
              '완료', '$evacuated명', const Color(0xFF2ECC71), Icons.check_circle),
          _buildSummaryItem(
              '잔여',
              '$remaining명',
              remaining > 0 ? const Color(0xFFE74C3C) : Colors.grey,
              Icons.warning),
          _buildSummaryItem('진행률', '${(progress * 100).toInt()}%',
              const Color(0xFF9B59B6), Icons.trending_up),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(
      String label, String value, Color color, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 1),
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            color: Colors.black54,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  // 층별 인원 분포 (3층, 2층, 1층 순서로 표시)
  Widget _buildFloorDistribution() {
    final floor1Data = _getFloorData(1);
    final floor2Data = _getFloorData(2);
    final floor3Data = _getFloorData(3);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '층별 인원 분포',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          _buildFloorBar(
              '3F', floor3Data['remaining'] as int, floor3Data['total'] as int),
          const SizedBox(height: 12),
          _buildFloorBar(
              '2F', floor2Data['remaining'] as int, floor2Data['total'] as int),
          const SizedBox(height: 12),
          _buildFloorBar(
              '1F', floor1Data['remaining'] as int, floor1Data['total'] as int),
        ],
      ),
    );
  }

  // 층별 인원 바 (잔여/총 인원 + 진행률 바)
  Widget _buildFloorBar(String floor, int remaining, int total) {
    final percentage = total > 0 ? (remaining / total) : 0.0;
    Color barColor = const Color(0xFF2ECC71);
    if (percentage > 0.6) {
      barColor = const Color(0xFFE74C3C);
    } else if (percentage > 0.3) {
      barColor = const Color(0xFFF39C12);
    }

    final isCurrentFloor = (_currentFloor == 1 && floor == '1F') ||
        (_currentFloor == 2 && floor == '2F') ||
        (_currentFloor == 3 && floor == '3F');

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color:
            isCurrentFloor ? barColor.withOpacity(0.1) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isCurrentFloor ? barColor : Colors.grey.shade300,
          width: isCurrentFloor ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: isCurrentFloor ? barColor : Colors.grey,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                floor,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$remaining / $total명',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: barColor,
                  ),
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: percentage,
                    minHeight: 6,
                    backgroundColor: Colors.grey.shade300,
                    valueColor: AlwaysStoppedAnimation<Color>(barColor),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 출구 오버레이 박스 (맵 위에 표시할 때 사용, 현재는 미사용)
  List<Widget> _buildExitOverlaysOutside(
    int exitLeft,
    int exitRight,
    int exitTop,
    BoxConstraints constraints,
  ) {
    final List<Widget> overlays = [];

    if (_currentFloor == 1) {
      if (exitLeft > 0) {
        overlays.add(
          Positioned(
            left: 0,
            bottom: 10,
            child: _buildExitBox('좌측 출구', exitLeft, const Color(0xFF4ECDC4)),
          ),
        );
      }

      if (exitRight > 0) {
        overlays.add(
          Positioned(
            right: 2,
            bottom: 10,
            child: _buildExitBox('우측 출구', exitRight, const Color(0xFF9B59B6)),
          ),
        );
      }

      if (exitTop > 0) {
        overlays.add(
          Positioned(
            top: 8,
            left: constraints.maxWidth * 0.50,
            child: _buildExitBox('위쪽 출구', exitTop, const Color(0xFFF39C12)),
          ),
        );
      }
    } else {
      if (exitLeft > 0) {
        overlays.add(
          Positioned(
            left: 15,
            bottom: 15,
            child: _buildExitBox('좌측 출구', exitLeft, const Color(0xFF4ECDC4)),
          ),
        );
      }

      if (exitRight > 0) {
        overlays.add(
          Positioned(
            right: 15,
            bottom: 15,
            child: _buildExitBox('우측 출구', exitRight, const Color(0xFF9B59B6)),
          ),
        );
      }
    }

    return overlays;
  }

  Widget _buildExitBox(String label, int count, Color color) {
    Color bgColor = color;
    if (count > 200) {
      bgColor = const Color(0xFFE74C3C);
    } else if (count > 100) {
      bgColor = const Color(0xFFF39C12);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor.withOpacity(0.95),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.exit_to_app,
            color: Colors.white,
            size: 14,
          ),
          const SizedBox(width: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '$count명',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 층별 평면도 (스케일 적용, 현재는 미사용)
  Widget _buildScaledFloorPlan(int floor) {
    final scale = getFloorScale(floor);
    final alignment =
        (floor == 2 || floor == 3) ? Alignment.bottomCenter : Alignment.center;
    final imagePath = 'web/icons/floor_${floor}_plan.png';

    return Transform.scale(
      scale: scale,
      alignment: alignment,
      child: Image.asset(
        imagePath,
        fit: BoxFit.contain,
        alignment: alignment,
        errorBuilder: (context, error, stackTrace) {
          return Center(
            child: Text(
              '평면도를 불러올 수 없습니다\n($imagePath)',
              style: const TextStyle(color: Colors.red, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          );
        },
      ),
    );
  }

  // 통계 카드 (현재는 미사용)
  Widget _buildStatsCard({
    required int total,
    required int evacuated,
    required int remaining,
    required int exitLeft,
    required int exitRight,
    required int exitTop,
    required double progress,
  }) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 350),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '대피 현황',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '대피 진행률',
                    style: TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                  Text(
                    '${(progress * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFCA6668),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    progress >= 0.8
                        ? const Color(0xFF2ECC71)
                        : progress >= 0.5
                            ? const Color(0xFFF39C12)
                            : const Color(0xFFE74C3C),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildStatRow(
              '총 인원', '$total명', Icons.people, const Color(0xFF3498DB)),
          const SizedBox(height: 8),
          _buildStatRow('탈출 완료', '$evacuated명', Icons.check_circle,
              const Color(0xFF2ECC71)),
          const SizedBox(height: 8),
          _buildStatRow('잔여 인원', '$remaining명', Icons.warning,
              remaining > 0 ? const Color(0xFFE74C3C) : Colors.grey),
          const SizedBox(height: 8),
          _buildStatRow(
              '예상 완료',
              remaining > 0 ? '약 ${(remaining * 0.5).toInt()}초' : '완료',
              Icons.timer,
              remaining > 0
                  ? const Color(0xFFF39C12)
                  : const Color(0xFF2ECC71)),
          const Divider(height: 24, thickness: 1),
          const Text(
            '출구별 대피 현황',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          _buildExitRow('좌측 출구', exitLeft, const Color(0xFF4ECDC4)),
          const SizedBox(height: 10),
          _buildExitRow('우측 출구', exitRight, const Color(0xFF9B59B6)),
          if (_currentFloor == 1 && exitTop > 0) ...[
            const SizedBox(height: 10),
            _buildExitRow('위쪽 출구', exitTop, const Color(0xFFF39C12)),
          ],
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 14, color: Colors.black87),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildExitRow(String label, int count, Color color) {
    String status = '원활';
    Color statusColor = const Color(0xFF2ECC71);
    if (count > 200) {
      status = '혼잡';
      statusColor = const Color(0xFFE74C3C);
    } else if (count > 100) {
      status = '보통';
      statusColor = const Color(0xFFF39C12);
    }

    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: statusColor,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1.5),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                status,
                style: TextStyle(
                  fontSize: 10,
                  color: statusColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Text(
          '$count명',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: statusColor,
          ),
        ),
        const SizedBox(width: 6),
        Icon(Icons.exit_to_app, size: 18, color: statusColor),
      ],
    );
  }
}
