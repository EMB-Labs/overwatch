import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math';

// 초기 화재 화면 - 사용자용
class InitialFireUserScreen extends StatefulWidget {
  const InitialFireUserScreen({Key? key}) : super(key: key);

  @override
  State<InitialFireUserScreen> createState() => _InitialFireUserScreenState();
}

class _InitialFireUserScreenState extends State<InitialFireUserScreen>
    with SingleTickerProviderStateMixin {
  int _currentStep = 1;
  late String _selectedImage;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _showSuppressionNotification = false;

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
    _selectedImage = 'web/icons/initial_fire_${randomNum}_suppress.png';

    Timer(Duration(seconds: 10), () {
      if (mounted) {
        setState(() {
          _currentStep = 2;
          _showSuppressionNotification = true;
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
      _showSuppressionNotification = false;
    });
  }

  void _handleSuppressionYes() {
    _dismissNotification();
    _handleAppExit();
  }

  void _handleSuppressionNo() {
    int randomNum = int.parse(_selectedImage.split('_')[2]);
    _selectedImage = 'web/icons/initial_fire_${randomNum}_evacuate.png';

    setState(() {
      _showSuppressionNotification = false;
      _currentStep = 3;
      _animationController.reset();
      _animationController.forward();
    });
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
                  // 소화기 사용법 박스
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
                            '소화기 사용법',
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
                                  TextSpan(text: "1. 소화기를 바닥에 내려두고, 손잡이의 "),
                                  TextSpan(
                                    text: "안전핀",
                                    style: TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  TextSpan(text: "을 뽑는다"),
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
                                  TextSpan(text: "2. 한손은 "),
                                  TextSpan(
                                    text: "손잡이",
                                    style: TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  TextSpan(text: ", 다른한손은 "),
                                  TextSpan(
                                    text: "호스",
                                    style: TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  TextSpan(text: "를 잡는다"),
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
                                  TextSpan(text: "3. "),
                                  TextSpan(
                                    text: "손잡이",
                                    style: TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  TextSpan(text: "를 힘껏 누르고 빗자루로 쓸듯이 방사한다"),
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
                  '화재 초기 - 1F',
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
          // 진압 확인 알림
          if (_showSuppressionNotification)
            Positioned(
              left: screenSize.width * 0.15 + 25,
              top: 70,
              child: Container(
                width: screenSize.width * 0.55,
                child: _buildSuppressionNotification(),
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
            width: 350,
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
                  TextSpan(text: '대피 안내도에 '),
                  TextSpan(
                    text: '신속히 대피',
                    style: TextStyle(color: Color(0xFF4CAF50)),
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

  Widget _buildSuppressionNotification() {
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
                  Icons.check_circle_outline,
                  color: Color(0xFF4CAF50),
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
                      '진압 확인',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      '화재 진압에 성공하셨나요?',
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
                    color: Color(0xFFFF6B6B),
                    onPressed: _handleSuppressionNo,
                  ),
                  SizedBox(width: 8),
                  _NotificationButton(
                    text: '예',
                    color: Color(0xFF4CAF50),
                    onPressed: _handleSuppressionYes,
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
