# 화재 감지 시스템 - 모듈화 구조
```
├── raspberry_pi/              # 라즈베리파이 
│   ├── main.py                   # 메인 실행 파일
│   ├── preprocessing_filters.py  # 전처리 필터
│   ├── npu_client.py            # NPU 통신 클라이언트
│   ├── config.py                # 설정 파일
│   ├── requirements.txt         # 의존성
│   └── README.md                
│
├── npu_server/                # Orange Pi (NPU 추론 서버)
│   ├── server.py                 # Flask HTTP 서버
│   ├── fire_detection_engine.py  # NPU 추론 엔진
│   ├── temporal_analyzer.py      # 시간적 분석기
│   ├── yolo_decoder.py          # YOLO 디코더
│   ├── alert_manager.py         # 알림 관리자
│   ├── fire_alert.py            # 알림 스크립트
│   ├── config.py                # 설정 파일
│   ├── requirements.txt         # 의존성
│   ├── fire.dxnn                # YOLO 모델 (별도)
│   └── README.md                
│
└── README.md                
```



### Orange Pi NPU 서버 

```bash
cd npu_server/
pip3 install -r requirements.txt
python3 server.py
```



## 설정 수정

### 라즈베리파이 (raspberry_pi/config.py)
```python
RTSP_URL = "rtsp://192.168.1.100:8554/stream"
NPU_SERVER_URL = "http://192.168.1.200:5000"
FILTER_TYPE = "motion"                # motion/color/hybrid
MOTION_THRESHOLD = 8.0                # 움직임 임계값 (%)
SEND_INTERVAL = 0.5                   # 전송 간격 (초)
```

### NPU 서버 (npu_server/config.py)
```python
MODEL_PATH = "./fire.dxnn"
PORT = 5000
PERSISTENCE_THRESHOLD = 10.0          # 지속성 판단 (초)
GROWTH_FACTOR = 1.5                   # 확산 판단 배율
ALERT_COOLDOWN = 30                   # 알림 간격 (초)
```

## 트러블슈팅

### RTSP 연결 실패
```bash
# 카메라 연결 확인
ping 카메라IP
ffplay rtsp://카메라IP:8554/stream
```

### NPU 서버 통신 오류
```bash
# NPU 서버 상태 확인
curl http://NPU_IP:5000/health
```

### 프레임 전송
```python
# raspberry_pi/config.py 수정
MOTION_THRESHOLD = 10.0  # 8.0에서 증가
SEND_INTERVAL = 1.0      # 0.5에서 증가
```

### 로그 모니터링
```bash
# 라즈베리파이
tail -f raspberry_pi/preprocess.log

# NPU 서버
tail -f npu_server/npu_server.log
tail -f npu_server/fire_alerts.log
```


### Flutter 기반 화재 대피 안내 앱 구조
```
├── lib/
│   ├── screens/                      # 상황별 UI 화면
│   │   ├── role_selection_screen.dart          # 역할 선택 화면
│   │   ├── lockscreen_notification_screen.dart # 신호 수신 후 상황 안내
│   │   ├── splash_screen.dart                 # 지도 로딩 화면
│   │   ├── map_screen.dart                    # 층별 안내도 & 대피 경로 표시
│   │   ├── evacuation_dashboard.dart          # 관리자 전체 대피 현황
│   │   ├── evacuation_user_screen.dart        # 사용자 대피 안내 화면
│   │   ├── false_alarm_manager_screen.dart    # 관리자 오경보 처리
│   │   ├── false_alarm_user_screen.dart       # 사용자 오경보 안내
│   │   ├── initial_fire_firefighter_screen.dart # 소방관 초기 화재 대응
│   │   ├── initial_fire_manager_screen.dart   # 관리자 초기 화재 대응
│   │   └── initial_fire_user_screen.dart      # 사용자 초기 화재 안내
│   │
│   ├── services/
│   │   └── fire_data_service.dart     # Raspberry Pi → NPU → 앱으로 신호 전달 처리
│   │
│   ├── widgets/                       # 공통 UI 위젯
│   └── main.dart                      # 앱 진입점
```
