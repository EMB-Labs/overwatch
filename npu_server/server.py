from flask import Flask, request, jsonify
import cv2
import numpy as np
import sys
from datetime import datetime

from fire_detection_engine import FireDetectionEngine
from alert_manager import AlertManager
import config


app = Flask(__name__)

engine = None
alert_manager = None


@app.route('/health', methods=['GET'])
def health():
    return jsonify({
        'status': 'running',
        'model_loaded': engine is not None,
        'timestamp': datetime.now().isoformat()
    })


@app.route('/stats', methods=['GET'])
def stats():
    if engine is None:
        return jsonify({'error': 'Engine not initialized'}), 500
    
    stats = engine.get_stats()
    stats['alert_count'] = alert_manager.alert_count if alert_manager else 0
    
    return jsonify(stats)


@app.route('/detect', methods=['POST'])
def detect():
    if engine is None:
        return jsonify({'error': 'Engine not initialized'}), 500
    
    try:
        if 'frame' not in request.files:
            return jsonify({'error': 'No frame provided'}), 400
        
        file = request.files['frame']
        npimg = np.frombuffer(file.read(), np.uint8)
        frame = cv2.imdecode(npimg, cv2.IMREAD_COLOR)
        
        if frame is None:
            return jsonify({'error': 'Invalid frame'}), 400
        
        result = engine.detect(frame)
        
        if result['fire_detected'] and result['temporal_analysis']:
            temporal = result['temporal_analysis']
            
            if temporal['is_dangerous']:
                alert_manager.trigger(
                    severity=temporal['severity'],
                    detections_info=temporal['statistics']
                )
        
        return jsonify({
            'fire_detected': result['fire_detected'],
            'num_detections': len(result['detections']),
            'severity': result['temporal_analysis']['severity'] if result['temporal_analysis'] else None,
            'is_dangerous': result['temporal_analysis']['is_dangerous'] if result['temporal_analysis'] else False,
            'statistics': result['temporal_analysis']['statistics'] if result['temporal_analysis'] else {},
            'timestamp': datetime.now().isoformat()
        })
    
    except Exception as e:
        print(f"감지 오류: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/alert', methods=['GET'])
def get_alert():
    if alert_manager is None:
        return jsonify({'error': 'Alert manager not initialized'}), 500
    
    return jsonify({
        'active': alert_manager.active,
        'alert_count': alert_manager.alert_count,
        'last_alert': alert_manager.last_alert_time
    })


@app.route('/reset', methods=['POST'])
def reset():
    if engine:
        engine.reset()
    if alert_manager:
        alert_manager.reset()
    
    return jsonify({'status': 'reset complete'})


def main():
    global engine, alert_manager
    
    print("="*60)
    print("Orange Pi NPU 화재 감지 서버")
    print("="*60)
    print(f"버전: v2.0 (모듈화)")
    print(f"모델: {config.MODEL_PATH}")
    print(f"포트: {config.PORT}")
    print(f"알림 스크립트: {config.ALERT_SCRIPT}")
    print("="*60)
    
    try:
        engine = FireDetectionEngine(config.MODEL_PATH)
        
        alert_manager = AlertManager(
            script_path=config.ALERT_SCRIPT,
            cooldown=config.ALERT_COOLDOWN
        )
        
        print(f"\n서버 초기화 완료")
        print(f"서버 시작: http://0.0.0.0:{config.PORT}")
        print(f"\n엔드포인트:")
        print(f"  POST /detect  - 화재 감지")
        print(f"  GET  /health  - 서버 상태")
        print(f"  GET  /stats   - 통계 정보")
        print(f"  GET  /alert   - 알림 상태")
        print(f"  POST /reset   - 초기화")
        print("="*60)
        
        app.run(
            host='0.0.0.0',
            port=config.PORT,
            debug=config.DEBUG,
            threaded=True
        )
    
    except Exception as e:
        print(f"\n서버 시작 오류: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
