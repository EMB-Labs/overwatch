import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math';

// 초기 화재 화면 - 관리자용
class InitialFireManagerScreen extends StatefulWidget {
  const InitialFireManagerScreen({Key? key}) : super(key: key);

  @override
  State<InitialFireManagerScreen> createState() =>
      _InitialFireManagerScreenState();
}

class _InitialFireManagerScreenState extends State<InitialFireManagerScreen>
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
    _selectedImage = 'web/icons/initial_fire_Manager_${randomNum}_suppress.png';

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
    int randomNum = int.parse(_selectedImage.split('_')[3]);
    _selectedImage = 'web/icons/initial_fire_Manager_${randomNum}_evacuate.png';

    setState(() {
      _showSuppressionNotification = false;
      _currentStep = 3;
      _animationController.reset();
      _animationController.forward();
    });
  }

  @override
  Widget build(BuildContext context) {
    Size screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Color(0xFF1A1A2E),
      body: SafeArea(
        child: Stack(
          children: [
            Row(
              children: [
                // 왼쪽 사이드바
                Container(
                  width: screenSize.width * 0.10,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: _currentStep == 3
                          ? [
                              Color(0xFF4CAF50),
                              Color(0xFF66BB6A),
                            ]
                          : [
                              Color(0xFFEF5350),
                              Color(0xFFE57373),
                            ],
                    ),
                  ),
                  child: _buildLeftSidebar(),
                ),
                // 메인 콘텐츠 영역
                Expanded(
                  child: Container(
                    color: Color(0xFFF5F5F5),
                    child: _buildContent(),
                  ),
                ),
              ],
            ),
            // 진압 확인 알림
            if (_showSuppressionNotification)
              Positioned(
                top: 16,
                left: screenSize.width * 0.10 + 40,
                right: 245,
                child: _buildSuppressionNotification(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeftSidebar() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Center(
              child: _buildLeftSidebarContent(),
            ),
          ),
          SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildLeftSidebarContent() {
    if (_currentStep == 1 || _currentStep == 2) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'web/icons/fire_extinguisher.png',
              width: 36,
              height: 36,
              errorBuilder: (context, error, stackTrace) {
                return Icon(
                  Icons.fire_extinguisher,
                  color: Colors.white,
                  size: 36,
                );
              },
            ),
            SizedBox(height: 16),
            Text(
              '초기 진압',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                height: 1.3,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'web/icons/exit.png',
              width: 36,
              height: 36,
              errorBuilder: (context, error, stackTrace) {
                return Icon(
                  Icons.exit_to_app,
                  color: Colors.white,
                  size: 36,
                );
              },
            ),
            SizedBox(height: 16),
            Text(
              '신속 대피',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                height: 1.3,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
  }

  Widget _buildContent() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: switch (_currentStep) {
        1 => _buildStep1(),
        2 => _buildStep2(),
        3 => _buildStep3(),
        _ => _buildStep1(),
      },
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
