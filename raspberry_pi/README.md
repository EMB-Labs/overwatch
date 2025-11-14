## 파일 구조

```
raspberry_pi/
├── main.py                    # 메인 실행 파일
├── preprocessing_filters.py   # 전처리 필터 모듈
├── npu_client.py             # NPU 통신 클라이언트
├── config.py                 # 설정 파일
├── requirements.txt          # 의존성
└── README.md                 # 이 파일
```

## 설치 및 실행

### 1. 의존성 설치
```bash
pip3 install -r requirements.txt
```

### 2. 설정 수정
`config.py` 
```python
RTSP_URL = "rtsp://192.168.1.100:8554/stream"  # 카메라 주소
NPU_SERVER_URL = "http://192.168.1.200:5000"   # NPU 서버 주소
FILTER_TYPE = "motion"                          # 필터 타입
```

### 3. 실행
```bash
# 기본 실행
python3 main.py
```


## 주요 설정값

### Motion Filter (config.py)
```python
MOTION_THRESHOLD = 8.0           # 움직임 비율 (%) - 개선: 4.0→8.0
MOTION_DIFF_THRESHOLD = 40       # 프레임 차이 - 개선: 25→40
TEMPORAL_FRAMES = 5              # 시간적 필터링 프레임 수
TEMPORAL_MIN_DETECTIONS = 3      # 최소 감지 횟수
```

### 전송 제어
```python
SEND_INTERVAL = 0.5              # NPU 전송 간격 (초)
MAX_FRAME_SIZE = (640, 480)      # 전송 프레임 크기
```

## 성능 벤치마크

| 필터 | F1-Score | Precision | Recall | NPU 전송률 |
|------|----------|-----------|--------|------------|
| Motion ⭐ | 85.7% | 75% | 99.2% | 50-60% |
| Color | 56% | 100% | 12% | 15-20% |
| Hybrid | 10.5% | 100% | 5.6% | 8-12% |
