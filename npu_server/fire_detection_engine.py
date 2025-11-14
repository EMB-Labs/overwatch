import cv2
import numpy as np
import time

try:
    import dx_engine
    DX_ENGINE_AVAILABLE = True
except ImportError:
    print("경고: dx_engine을 찾을 수 없습니다.")
    print("Orange Pi NPU 환경에서만 실행하세요.")
    DX_ENGINE_AVAILABLE = False

from temporal_analyzer import TemporalAnalyzerNPU
from yolo_decoder import decode_yolo_output_npu
import config


class FireDetectionEngine:
    
    def __init__(self, model_path):
        if not DX_ENGINE_AVAILABLE:
            raise RuntimeError("dx_engine을 사용할 수 없습니다.")
        
        print(f"NPU 엔진 초기화 중...")
        print(f"모델: {model_path}")
        
        self.engine = dx_engine.InferenceEngine()
        ret = self.engine.init(model_path, dx_engine.ExecutionMode.NPU)
        
        if ret != 0:
            raise RuntimeError(f"NPU 엔진 초기화 실패: {ret}")
        
        print(f"NPU 엔진 초기화 완료")
        
        self.temporal_analyzer = TemporalAnalyzerNPU(
            persistence_threshold=config.PERSISTENCE_THRESHOLD,
            growth_factor=config.GROWTH_FACTOR
        )
        
        self.total_frames = 0
        self.fire_detections = 0
    
    def detect(self, frame):
        self.total_frames += 1
        
        input_frame = cv2.resize(frame, (config.INPUT_SIZE, config.INPUT_SIZE))
        input_frame = cv2.cvtColor(input_frame, cv2.COLOR_BGR2RGB)
        input_data = np.expand_dims(input_frame, axis=0).astype(np.float32) / 255.0
        
        outputs = self.engine.inference(input_data)
        
        if outputs is None or len(outputs) == 0:
            return {
                'fire_detected': False,
                'detections': [],
                'temporal_analysis': None
            }
        
        detections = decode_yolo_output_npu(
            outputs[0],
            conf_thres=config.CONF_THRES,
            iou_thres=config.IOU_THRES,
            input_size=config.INPUT_SIZE
        )
        
        fire_detected = len(detections) > 0
        
        if fire_detected:
            self.fire_detections += 1
            
            temporal_result = self.temporal_analyzer.analyze(
                detections,
                frame_timestamp=time.time()
            )
        else:
            temporal_result = None
        
        return {
            'fire_detected': fire_detected,
            'detections': detections,
            'temporal_analysis': temporal_result
        }
    
    def get_stats(self):
        return {
            'total_frames': self.total_frames,
            'fire_detections': self.fire_detections,
            'detection_rate': self.fire_detections / max(self.total_frames, 1)
        }
    
    def reset(self):
        self.temporal_analyzer.reset()
        self.total_frames = 0
        self.fire_detections = 0
