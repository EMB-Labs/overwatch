import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';

// 초기 화재 화면 - 소방관용
class InitialFireFirefighterScreen extends StatefulWidget {
  const InitialFireFirefighterScreen({Key? key}) : super(key: key);

  @override
  State<InitialFireFirefighterScreen> createState() =>
      _InitialFireFirefighterScreenState();
}

class _InitialFireFirefighterScreenState
    extends State<InitialFireFirefighterScreen> {
  late String _selectedImage;
  late String _roomNumber;

  @override
  void initState() {
    super.initState();

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    int randomCase = Random().nextInt(3) + 1;
    _selectedImage = 'web/icons/initial_fire_Firefighter_$randomCase.png';

    switch (randomCase) {
      case 1:
        _roomNumber = '127';
        break;
      case 2:
        _roomNumber = '102';
        break;
      case 3:
        _roomNumber = '108';
        break;
      default:
        _roomNumber = '127';
    }
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
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
                  // 소방관 안내 박스
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
                            '화재 진압 안내',
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
                                    text: "안내도",
                                    style: TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  TextSpan(text: " 확인"),
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
                                  TextSpan(text: "2. 안내도에 있는 "),
                                  TextSpan(
                                    text: "빨간색 선",
                                    style: TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  TextSpan(text: "을 따라"),
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
                                  TextSpan(text: "3. 화재를 "),
                                  TextSpan(
                                    text: "진압",
                                    style: TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  TextSpan(text: "해주세요!"),
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
        ],
      ),
    );
  }

  Widget _buildContent() {
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
            width: 350,
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '화재 발생 위치',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 4),
                Text(
                  '${_roomNumber}호실',
                  style: TextStyle(
                    color: Color(0xFFFF6B6B),
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
