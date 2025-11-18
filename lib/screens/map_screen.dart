import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/fire_check_popup.dart';
import 'evacuation_user_screen.dart';
import 'false_alarm_user_screen.dart';
import 'initial_fire_user_screen.dart';
import 'false_alarm_manager_screen.dart';
import 'initial_fire_manager_screen.dart';
import 'initial_fire_firefighter_screen.dart';
import 'evacuation_dashboard.dart';

// 네이버 지도를 보여주는 메인 화면 (화재 알림 팝업 표시)
class MapScreen extends StatefulWidget {
  final String situationType;
  final Map<String, dynamic>? data;

  const MapScreen({
    Key? key,
    required this.situationType,
    this.data,
  }) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  NaverMapController? _mapController;
  final ajouUniv = NLatLng(37.283, 127.0438);
  bool _showPopup = true;
  String _userRole = 'user';

  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userRole = prefs.getString('user_role') ?? 'user';
    });
  }

  // 위치 권한 요청
  Future<void> _requestLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      return;
    }

    if (permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always) {
      _getCurrentLocation();
    }
  }

  // 현재 위치 가져오기 및 지도 업데이트
  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (_mapController != null) {
        final currentLocation = NLatLng(position.latitude, position.longitude);
        _mapController!.updateCamera(
          NCameraUpdate.fromCameraPosition(
            NCameraPosition(target: currentLocation, zoom: 17),
          ),
        );

        final locationOverlay = await _mapController!.getLocationOverlay();
        locationOverlay.setPosition(currentLocation);
        locationOverlay.setIsVisible(true);
      }
    } catch (e) {
      print('위치 가져오기 실패: $e');
    }
  }

  // 화재 알림 수락 시 상황과 역할에 따라 적절한 화면으로 이동
  Future<void> _handleAccept() async {
    setState(() {
      _showPopup = false;
    });

    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('user_role') ?? 'user';

    switch (widget.situationType) {
      case 'evacuation':
        if (widget.data != null && widget.data!.isNotEmpty) {
          if (role == 'user') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    EvacuationUserScreen(evacuationData: widget.data!),
              ),
            );
          } else if (role == 'manager' || role == 'firefighter') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => EvacuationDashboard(data: widget.data),
              ),
            );
          }
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EvacuationUserScreen(evacuationData: {}),
            ),
          );
        }
        break;

      case 'initial_fire':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => InitialFireUserScreen(),
          ),
        );
        break;

      case 'initial_fire_manager':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => InitialFireManagerScreen(),
          ),
        );
        break;

      case 'initial_fire_firefighter':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => InitialFireFirefighterScreen(),
          ),
        );
        break;

      case 'false_alarm':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FalseAlarmUserScreen(),
          ),
        );
        break;

      case 'false_alarm_manager':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FalseAlarmManagerScreen(),
          ),
        );
        break;

      default:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EvacuationUserScreen(evacuationData: {}),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    String popupTitle;
    String popupMessage;

    // 상황과 역할에 따른 팝업 메시지 설정
    switch (widget.situationType) {
      case 'evacuation':
        popupTitle = '화재 발생';
        if (_userRole == 'manager' || _userRole == 'firefighter') {
          popupMessage = '실시간 화재 상황을 확인해주세요';
        } else {
          popupMessage = '경로를 따라 대피하세요!!';
        }
        break;
      case 'initial_fire':
        popupTitle = '초기 화재 감지';
        popupMessage = '근처 소화기를 들고 진압해주세요';
        break;
      case 'initial_fire_manager':
        popupTitle = '초기 화재 감지';
        popupMessage = '근처 소화기를 들고 진압해주세요';
        break;
      case 'initial_fire_firefighter':
        popupTitle = '초기 화재 신고 접수';
        popupMessage = '화재 발생 위치를 확인하세요';
        break;
      case 'false_alarm':
        popupTitle = '오경보(화재 의심 지역)';
        popupMessage = '화재 의심 지역으로 가서 확인해주세요';
        break;
      case 'false_alarm_manager':
        popupTitle = '오경보(화재 의심 지역)';
        popupMessage = '화재 의심 지역으로 가서 확인해주세요';
        break;
      default:
        popupTitle = '알림';
        popupMessage = '확인해주세요';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Overwatch',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.red,
      ),
      body: Stack(
        children: [
          NaverMap(
            options: NaverMapViewOptions(
              initialCameraPosition: NCameraPosition(
                target: ajouUniv,
                zoom: 15,
              ),
              locationButtonEnable: true,
            ),
            onMapReady: (controller) async {
              _mapController = controller;

              final locationOverlay = await controller.getLocationOverlay();
              locationOverlay.setPosition(ajouUniv);
              locationOverlay.setIsVisible(true);

              _getCurrentLocation();
            },
          ),
          if (_showPopup)
            Positioned(
              bottom: 100,
              left: 0,
              right: 0,
              child: FireCheckPopup(
                title: popupTitle,
                message: popupMessage,
                onAccept: _handleAccept,
                onReject: () {
                  setState(() {
                    _showPopup = false;
                  });
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
              ),
            ),
        ],
      ),
    );
  }
}
