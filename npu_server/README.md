## 파일 구조

```
npu_server/
├── server.py                   # Flask 서버 메인
├── fire_detection_engine.py    # NPU 추론 엔진
├── temporal_analyzer.py        # 시간적 분석기
├── yolo_decoder.py             # YOLO 출력 디코더
├── alert_manager.py            # 알림 관리자
├── fire_alert.py               # 알림 스크립트
├── config.py                   # 설정 파일
├── requirements.txt            # 의존성
├── fire.dxnn                   # YOLO 모델 (별도 배치)
└── README.md                   # 이 파일
```

## 설치 및 실행

### 1. 의존성 설치
```bash
pip3 install -r requirements.txt
# dx_engine는 Orange Pi에 이미 설치되어 있어야 함
```

### 2. 모델 파일 배치
```bash
# fire.dxnn 파일을 이 디렉토리에 복사
cp /path/to/fire.dxnn .
ls fire.dxnn  # 확인
```

### 3. 설정 수정
`config.py` 
```python
MODEL_PATH = "./fire.dxnn"       # 모델 경로
PORT = 5000                       # 서버 포트
PERSISTENCE_THRESHOLD = 10.0      # 지속성 판단 (초)
GROWTH_FACTOR = 1.5              # 확산 판단 배율
ALERT_COOLDOWN = 30               # 알림 간격 (초)
```

### 4. 실행
```bash
# 포그라운드 실행
python3 server.py

# 백그라운드 실행
nohup python3 server.py > npu_server.log 2>&1 &

# 프로세스 확인
ps aux | grep server.py

# 종료
pkill -f server.py
```

## API 엔드포인트

### POST /detect
화재 감지 요청
```bash
curl -X POST -F "frame=@test_frame.jpg" http://NPU_IP:5000/detect
```

### GET /health
서버 상태 확인
```bash
curl http://NPU_IP:5000/health
```

### GET /stats
통계 정보 조회
```bash
curl http://NPU_IP:5000/stats
```

**응답 예시:**
```json
{
  "total_frames": 1500,
  "fire_detections": 450,
  "detection_rate": 0.3,
  "alert_count": 5
}
```

### GET /alert
알림 상태 확인
```bash
curl http://NPU_IP:5000/alert
```

### POST /reset
상태 초기화
```bash
curl -X POST http://NPU_IP:5000/reset
```

## 모듈 설명

### fire_detection_engine.py
- **FireDetectionEngine**: NPU 추론 및 Temporal Analyzer 통합
- dx_engine 초기화 및 추론 수행
- 프레임 전처리 (resize, normalize)
- YOLO 디코딩 및 위험도 평가

### temporal_analyzer.py
- **TemporalAnalyzerNPU**: 화재의 시간적 특성 분석
- 지속성 판단: 10초 이상 지속되는 화재 추적
- 확산 판단: 초기 대비 1.5배 이상 커진 화재 감지
- 위험도 평가: trivial / moderate / severe

### yolo_decoder.py
- **decode_yolo_output_npu**: NPU 출력 디코딩
- 바운딩 박스 변환
- NMS (Non-Maximum Suppression) 적용
- 신뢰도 필터링

### alert_manager.py
- **AlertManager**: 화재 알림 관리
- 외부 스크립트 (fire_alert.py) 실행
- Cooldown 관리 (30초 간격)
- 알림 상태 추적

### fire_alert.py
- 화재 경보 발동 스크립트
- 로그 파일 기록 (fire_alerts.log)

### server.py
- Flask HTTP 서버
- 모든 API 엔드포인트 구현

## 주요 설정값

### YOLO 설정 (config.py)
```python
INPUT_SIZE = 640        # 입력 이미지 크기
CONF_THRES = 0.25      # 신뢰도 임계값
IOU_THRES = 0.45       # NMS IOU 임계값
```

### Temporal Analyzer 설정
```python
PERSISTENCE_THRESHOLD = 10.0   # 지속성 판단 시간 (초)
GROWTH_FACTOR = 1.5           # 확산 판단 배율
```

### Alert 설정
```python
ALERT_SCRIPT = "./fire_alert.py"   # 알림 스크립트
ALERT_COOLDOWN = 30                 # 알림 간격 (초)
```

### 리소스 사용량
```bash
# CPU, 메모리 모니터링
top -p $(pgrep -f server.py)

# NPU 사용률 (Orange Pi 전용)
#deepx sdk 이용
```
