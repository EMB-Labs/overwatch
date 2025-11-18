import 'package:flutter/material.dart';
import 'dart:async';
import 'map_screen.dart';

// 로딩 화면 (2초 후 MapScreen으로 이동)
class SplashScreen extends StatefulWidget {
  final String situationType;
  final Map<String, dynamic>? data;

  const SplashScreen({
    Key? key,
    required this.situationType,
    this.data,
  }) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // 2초 후 메인 화면으로 이동
    Timer(const Duration(seconds: 2), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => MapScreen(
            situationType: widget.situationType,
            data: widget.data,
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Text(
              '🔥',
              style: TextStyle(fontSize: 120),
            ),
            SizedBox(height: 24),
            Text(
              'Overwatch',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
