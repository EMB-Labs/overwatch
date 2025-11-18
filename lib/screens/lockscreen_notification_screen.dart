import 'package:flutter/material.dart';
import 'dart:async';
import 'splash_screen.dart';

class LockscreenNotificationScreen extends StatefulWidget {
  final String situationType;
  final String role;
  final Map<String, dynamic>? data;

  const LockscreenNotificationScreen({
    Key? key,
    required this.situationType,
    required this.role,
    this.data,
  }) : super(key: key);

  @override
  State<LockscreenNotificationScreen> createState() =>
      _LockscreenNotificationScreenState();
}

class _LockscreenNotificationScreenState
    extends State<LockscreenNotificationScreen> {
  String _currentTime = '';
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _updateTime();
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      _updateTime();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _updateTime() {
    final now = DateTime.now();
    setState(() {
      _currentTime = '${now.hour}:${now.minute.toString().padLeft(2, '0')}';
    });
  }

  // 상황에 따른 화재 알림 제목 반환
  String _getFireTitle() {
    if (widget.situationType == 'false_alarm' ||
        widget.situationType == 'false_alarm_manager') {
      return '화재 의심 지역 발생';
    }
    return '화재 발생';
  }

  // 역할과 상황에 따른 화재 알림 메시지 반환
  String _getFireMessage() {
    if (widget.role == 'firefighter' &&
        widget.situationType == 'initial_fire_firefighter') {
      return '초기 화재 발생, 신속히 출동해주세요';
    }

    if (widget.role == 'manager' || widget.role == 'firefighter') {
      return '실시간 화재 대피 상황을 확인해주세요';
    }

    switch (widget.situationType) {
      case 'false_alarm':
      case 'false_alarm_manager':
        return '화재 의심 지역을 확인해주세요';
      case 'initial_fire':
      case 'initial_fire_manager':
      case 'initial_fire_firefighter':
        return '소화기를 들고 화재를 진압해주세요';
      case 'evacuation':
      default:
        return '안내도에 따라 대피해주세요';
    }
  }

  // 화재 알림 클릭 시 스플래시 화면으로 이동
  void _handleFireNotificationTap() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => SplashScreen(
          situationType: widget.situationType,
          data: widget.data,
        ),
      ),
    );
  }

  // 층 번호 추출 (F1, F2, F3 -> 1, 2, 3)
  String _getFloorNumber() {
    if (widget.data == null) return '?';

    if (widget.data!.containsKey('start_floor')) {
      final startFloor = widget.data!['start_floor'] as String?;
      if (startFloor != null && startFloor.startsWith('F')) {
        return startFloor.substring(1);
      }
    }

    if (widget.data!.containsKey('floor')) {
      final floor = widget.data!['floor'];
      return floor.toString();
    }

    return '?';
  }

  // 역할에 따른 배경 이미지 반환
  String _getBackgroundImage() {
    if (widget.role == 'manager') {
      return 'web/icons/manager.png';
    } else if (widget.role == 'firefighter') {
      return 'web/icons/firefighter.png';
    }
    return 'web/icons/dog.jpg';
  }

  // 역할에 따른 카카오톡 알림 내용 반환
  Map<String, String> _getKakaoNotification() {
    if (widget.role == 'manager') {
      return {
        'sender': '건물 관리팀',
        'message': '화재 대피 현황을 확인해주세요',
        'time': '방금 전',
      };
    } else if (widget.role == 'firefighter') {
      final floorNum = _getFloorNumber();
      return {
        'sender': '소방청',
        'message': '원천관 ${floorNum}층 화재 발생, 신속히 이동 부탁드립니다',
        'time': '방금 전',
      };
    }
    return {
      'sender': '희수',
      'message': '오늘 피시방 갈래?',
      'time': '1시간 전',
    };
  }

  @override
  Widget build(BuildContext context) {
    final kakaoNoti = _getKakaoNotification();
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      body: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage(_getBackgroundImage()),
              fit: BoxFit.cover,
            ),
          ),
          child: Stack(
            children: [
              Container(
                color: Colors.black.withOpacity(0.3),
              ),
              SingleChildScrollView(
                child: Container(
                  constraints: BoxConstraints(
                    minHeight: MediaQuery.of(context).size.height -
                        MediaQuery.of(context).padding.top -
                        MediaQuery.of(context).padding.bottom,
                  ),
                  child: Column(
                    children: [
                      SizedBox(height: isLandscape ? 40 : 80),
                      Text(
                        _currentTime,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isLandscape ? 48 : 72,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                      SizedBox(height: isLandscape ? 4 : 8),
                      if (widget.role == 'user')
                        Text(
                          '대학원 탈출 D-23',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isLandscape ? 14 : 16,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      SizedBox(height: isLandscape ? 80 : 140),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          children: [
                            // 카카오톡 알림
                            Container(
                              padding: EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.95),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      image: DecorationImage(
                                        image:
                                            AssetImage('web/icons/kakao.jpg'),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '카카오톡 · ${kakaoNoti['time']}',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 12,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          '${kakaoNoti['sender']} : ${kakaoNoti['message']}',
                                          style: TextStyle(
                                            color: Colors.black87,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.expand_more,
                                    color: Colors.grey,
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 12),
                            // 화재 알림 (클릭하면 다음 화면으로 이동)
                            GestureDetector(
                              onTap: _handleFireNotificationTap,
                              child: Container(
                                padding: EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Color(0xFFFF6B6B),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: Color(0xFFFAE100),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.warning,
                                        color: Colors.black,
                                        size: 24,
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _getFireTitle(),
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            _getFireMessage(),
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: isLandscape ? 60 : 100),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
