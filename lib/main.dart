import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'screens/role_selection_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await FlutterNaverMap().init(
    clientId: 's3vg1zdnqw',
    onAuthFailed: (ex) {
      print("인증 실패: $ex");
    },
  );

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fire AI',
      theme: ThemeData(primarySwatch: Colors.red),
      home: const RoleSelectionScreen(), // ← 역할 선택이 첫 화면!
      debugShowCheckedModeBanner: false,
    );
  }
}
