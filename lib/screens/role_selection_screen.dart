import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/fire_data_service.dart';
import 'lockscreen_notification_screen.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({Key? key}) : super(key: key);

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  bool _isWaitingForSignal = false;

  Future<void> _selectRole(String role, String roleDisplayName) async {
    setState(() {
      _isWaitingForSignal = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_role', role);

      // 화재 신호 대기
      FireData fireData = await FireDataService.waitForSignal(role);

      if (!mounted) return;

      String situationType = _getSituationType(role, fireData.situation);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LockscreenNotificationScreen(
            situationType: situationType,
            role: role,
            data: fireData.evacuationData,
          ),
        ),
      );
    } catch (e) {
      print('신호 수신 오류: $e');
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('신호 수신 실패: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isWaitingForSignal = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.all(isLandscape ? 20.0 : 40.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '역할을 선택하세요',
                        style: TextStyle(
                          fontSize: isLandscape ? 24 : 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: isLandscape ? 30 : 60),
                      _buildRoleButton(
                        role: 'user',
                        displayName: '일반 사용자',
                        icon: Icons.person,
                        color: Colors.blue,
                        isLandscape: isLandscape,
                      ),
                      SizedBox(height: isLandscape ? 12 : 24),
                      _buildRoleButton(
                        role: 'manager',
                        displayName: '건물 관리자',
                        icon: Icons.admin_panel_settings,
                        color: Colors.orange,
                        isLandscape: isLandscape,
                      ),
                      SizedBox(height: isLandscape ? 12 : 24),
                      _buildRoleButton(
                        role: 'firefighter',
                        displayName: '소방관',
                        icon: Icons.local_fire_department,
                        color: Colors.red,
                        isLandscape: isLandscape,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_isWaitingForSignal)
              Container(
                color: Colors.black54,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                      SizedBox(height: 20),
                      Text(
                        '화재 신호 대기 중...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleButton({
    required String role,
    required String displayName,
    required IconData icon,
    required Color color,
    required bool isLandscape,
  }) {
    return SizedBox(
      width: double.infinity,
      height: isLandscape ? 60 : 80,
      child: ElevatedButton(
        onPressed:
            _isWaitingForSignal ? null : () => _selectRole(role, displayName),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          disabledBackgroundColor: Colors.grey,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 4,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: isLandscape ? 28 : 36, color: Colors.white),
            SizedBox(width: isLandscape ? 12 : 16),
            Text(
              displayName,
              style: TextStyle(
                fontSize: isLandscape ? 20 : 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 역할과 상황에 따라 적절한 화면 타입 반환
  String _getSituationType(String role, String situation) {
    if (situation == 'evacuate') {
      return 'evacuation';
    } else if (situation == 'false_alarm') {
      if (role == 'manager') {
        return 'false_alarm_manager';
      } else {
        return 'false_alarm';
      }
    } else if (situation == 'initial_fire') {
      if (role == 'manager') {
        return 'initial_fire_manager';
      } else if (role == 'firefighter') {
        return 'initial_fire_firefighter';
      } else {
        return 'initial_fire';
      }
    }
    return 'evacuation';
  }
}
