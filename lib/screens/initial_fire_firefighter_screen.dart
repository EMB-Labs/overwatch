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

  @override
  Widget build(BuildContext context) {
    Size screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Color(0xFF1A1A2E),
      body: SafeArea(
        child: Row(
          children: [
            // 왼쪽 사이드바
            Container(
              width: screenSize.width * 0.10,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFFF6B6B),
                    Color(0xFFFF8A80),
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
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'web/icons/fire_icon.png',
                      width: 36,
                      height: 36,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.local_fire_department,
                          color: Colors.white,
                          size: 36,
                        );
                      },
                    ),
                    SizedBox(height: 16),
                    Text(
                      '화재 진압',
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
              ),
            ),
          ),
          SizedBox(height: 16),
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
