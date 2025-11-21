import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math';

// 오경보 화면 - 관리자용
class FalseAlarmManagerScreen extends StatefulWidget {
  const FalseAlarmManagerScreen({Key? key}) : super(key: key);

  @override
  State<FalseAlarmManagerScreen> createState() =>
      _FalseAlarmManagerScreenState();
}

class _FalseAlarmManagerScreenState extends State<FalseAlarmManagerScreen>
    with SingleTickerProviderStateMixin {
  int _currentStep = 1;
  late String _selectedImage;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _showFireCheckNotification = false;

  @override
  void initState() {
    super.initState();

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 500),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();

    int randomNum = Random().nextInt(3) + 1;
    _selectedImage = 'web/icons/false_alarm_manager_$randomNum.png';

    Timer(Duration(seconds: 10), () {
      if (mounted) {
        setState(() {
          _currentStep = 2;
          _showFireCheckNotification = true;
          _animationController.reset();
          _animationController.forward();
        });
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  Future<void> _handleAppExit() async {
    try {
      if (Platform.isAndroid) {
        await SystemNavigator.pop();
      } else if (Platform.isIOS) {
        exit(0);
      } else {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).popUntil((r) => r.isFirst);
        }
      }
    } catch (_) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).popUntil((r) => r.isFirst);
      }
    }
  }

  void _dismissNotification() {
    setState(() {
      _showFireCheckNotification = false;
    });
  }

  void _handleFireYes() {
    setState(() {
      _showFireCheckNotification = false;
      _currentStep = 3;
      _animationController.reset();
      _animationController.forward();
    });
  }

  void _handleFireNo() {
    _dismissNotification();
    _handleAppExit();
  }

  Widget _buildInfoItem(String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 3),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.black,
          fontSize: 9,
          fontWeight: FontWeight.w600,
          height: 1.3,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Size screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 메인 콘텐츠 영역
          Positioned(
            left: screenSize.width * 0.15,
            top: 60,
            width: screenSize.width * 0.85,
            height: screenSize.height - 60,
            child: Container(
              color: Color(0xFFF5F5F5),
              child: _buildContent(),
            ),
          ),
          // 좌측: 노란색 사이드바 배경
          Positioned(
            left: 0,
            top: 60,
            bottom: 0,
            width: screenSize.width * 0.15,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.yellow[600],
              ),
            ),
          ),
          // 좌측: 사이드바 콘텐츠
          Positioned(
            left: 28,
            top: 60,
            bottom: 0,
            width: screenSize.width * 0.13,
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              child: Column(
                children: [
                  // 상단 여백
                  SizedBox(height: 10),
                  // 중앙 배치를 위한 Spacer
                  Spacer(),
                  // 화재 오경보 박스
                  Container(
                    height: 230,
                    child: Container(
                      padding: EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.yellow[100],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '화재 오경보',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 8),
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 3),
                            child: RichText(
                              textAlign: TextAlign.center,
                              text: TextSpan(
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  height: 1.3,
                                ),
                                children: [
                                  TextSpan(text: "1. "),
                                  TextSpan(
                                    text: "핸드폰",
                                    style: TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  TextSpan(text: "을 들고\n의심지역을 확인한다"),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(height: 4),
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 3),
                            child: RichText(
                              textAlign: TextAlign.center,
                              text: TextSpan(
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  height: 1.3,
                                ),
                                children: [
                                  TextSpan(text: "2. 화재가 맞다면\n"),
                                  TextSpan(
                                    text: "소화기",
                                    style: TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  TextSpan(text: "를 찾아 진압한다"),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(height: 4),
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 3),
                            child: RichText(
                              textAlign: TextAlign.center,
                              text: TextSpan(
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  height: 1.3,
                                ),
                                children: [
                                  TextSpan(text: "3. 화재가 아니라면\n"),
                                  TextSpan(
                                    text: "아니요",
                                    style: TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  TextSpan(text: "를 누른다"),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // 중앙 배치를 위한 Spacer
                  Spacer(),
                  // 카메라 버튼 (뒤로가기)
                  Align(
                    alignment: Alignment.center,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: Icon(Icons.arrow_back_ios,
                            color: Colors.white, size: 18),
                        onPressed: () => Navigator.pop(context),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  SizedBox(height: 10),
                ],
              ),
            ),
          ),
          // 상단 헤더
          Positioned(
            top: 0,
            left: 0,
            width: screenSize.width,
            height: 60,
            child: Container(
              decoration: BoxDecoration(
                color: Color(0xFFFF7043),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  '화재 오심 지역 안내 - 1F',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 4,
                        offset: Offset(2, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // 화재 확인 알림
          if (_showFireCheckNotification)
            Positioned(
              left: screenSize.width * 0.15 + 25,
              top: 70,
              child: Container(
                width: screenSize.width * 0.6,
                child: _buildFireCheckNotification(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return AnimatedSwitcher(
      duration: Duration(milliseconds: 500),
      child: _currentStep == 1
          ? _buildStep1()
          : _currentStep == 2
              ? _buildStep2()
              : _buildStep3(),
    );
  }

  Widget _buildStep1() {
    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            _selectedImage,
            fit: BoxFit.contain,
          ),
        ),
        Positioned(
          top: 15,
          left: 120,
          child: Container(
            width: 400,
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            child: RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
                children: [
                  TextSpan(text: '화재 '),
                  TextSpan(
                    text: '의심',
                    style: TextStyle(color: Color(0xFFEF5350)),
                  ),
                  TextSpan(text: '되는 곳으로 이동해주세요'),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStep2() {
    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            _selectedImage,
            fit: BoxFit.contain,
          ),
        ),
        Positioned(
          top: 15,
          left: 120,
          child: Container(
            width: 400,
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            child: RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
                children: [
                  TextSpan(text: '화재 '),
                  TextSpan(
                    text: '의심',
                    style: TextStyle(color: Color(0xFFEF5350)),
                  ),
                  TextSpan(text: '되는 곳으로 이동해주세요'),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStep3() {
    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            _selectedImage,
            fit: BoxFit.contain,
          ),
        ),
        Positioned(
          top: 15,
          left: 100,
          child: Container(
            width: 300,
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            child: RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
                children: [
                  TextSpan(
                    text: '소화기',
                    style: TextStyle(color: Color(0xFFEF5350)),
                  ),
                  TextSpan(text: '를 들고 화재 장소로 가서 '),
                  TextSpan(
                    text: '진압',
                    style: TextStyle(color: Color(0xFFEF5350)),
                  ),
                  TextSpan(text: '해주세요!'),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFireCheckNotification() {
    return SlideTransition(
      position: Tween<Offset>(
        begin: Offset(0, -1),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      )),
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                offset: Offset(0, 8),
                spreadRadius: 2,
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: Color(0xFFFF6B6B).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFFF6B6B),
                  size: 24,
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '화재 확인',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      '화재가 있었나요?',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF666666),
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _NotificationButton(
                    text: '아니요',
                    color: Color(0xFF4CAF50),
                    onPressed: _handleFireNo,
                  ),
                  SizedBox(width: 8),
                  _NotificationButton(
                    text: '네',
                    color: Color(0xFFFF6B6B),
                    onPressed: _handleFireYes,
                  ),
                ],
              ),
              SizedBox(width: 8),
              IconButton(
                icon: Icon(Icons.close, size: 20),
                onPressed: _dismissNotification,
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 알림 버튼 위젯
class _NotificationButton extends StatelessWidget {
  final String text;
  final Color color;
  final VoidCallback onPressed;

  const _NotificationButton({
    Key? key,
    required this.text,
    required this.color,
    required this.onPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            text,
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
