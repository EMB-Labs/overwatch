import cv2
import time
import argparse
from preprocessing_filters import ColorFireFilter, MotionFireFilter, HybridFireFilter
from npu_client import NPUClient
import config


class FirePreprocessor:
    """화재 감지 전처리"""
    
    def __init__(self, rtsp_url, npu_server_url, filter_type="motion"):
        """
        Args:
            rtsp_url (str): RTSP 스트림 URL
            npu_server_url (str): NPU 서버 URL
            filter_type (str): 필터 타입 (motion/color/hybrid)
        """
        self.rtsp_url = rtsp_url
        self.npu_client = NPUClient(npu_server_url)
        self.filter_type = filter_type
        
        # 필터 초기화
        if filter_type == "color":
            self.filter = ColorFireFilter(threshold=config.COLOR_THRESHOLD)
        elif filter_type == "motion":
            self.filter = MotionFireFilter(
                threshold=config.MOTION_THRESHOLD,
                diff_threshold=config.MOTION_DIFF_THRESHOLD,
                temporal_frames=config.TEMPORAL_FRAMES,
                temporal_min=config.TEMPORAL_MIN_DETECTIONS
            )
        else:
            self.filter = HybridFireFilter(
                color_threshold=config.COLOR_THRESHOLD,
                motion_threshold=config.MOTION_THRESHOLD,
                diff_threshold=config.MOTION_DIFF_THRESHOLD,
                temporal_frames=config.TEMPORAL_FRAMES,
                temporal_min=config.TEMPORAL_MIN_DETECTIONS
            )
        
        self.last_send_time = 0
        self.frame_count = 0
        self.detection_count = 0
    
    def run(self):
        """메인 처리"""
        print(f"RTSP 스트림 연결 중: {self.rtsp_url}")
        cap = cv2.VideoCapture(self.rtsp_url)
        
        if not cap.isOpened():
            print(f"RTSP 스트림을 열 수 없습니다: {self.rtsp_url}")
            return
        
        print(f"RTSP 스트림 연결 성공")
        print(f"필터 타입: {self.filter_type}")
        print(f"NPU 서버: {self.npu_client.server_url}")
        
        health = self.npu_client.check_health()
        if health:
            print(f"NPU 서버 상태: {health}")
        else:
            print(f"NPU 서버 상태 확인 실패")
        
        print(f"{'='*60}\n")
        
        try:
            while True:
                ret, frame = cap.read()
                if not ret:
                    print("프레임 읽기 실패. 재연결 시도...")
                    time.sleep(1)
                    cap.release()
                    cap = cv2.VideoCapture(self.rtsp_url)
                    continue
                
                self.frame_count += 1
                current_time = time.time()
                
                # 전처리 필터 적용
                if isinstance(self.filter, HybridFireFilter):
                    is_suspected, info, mask = self.filter.detect(frame)
                elif isinstance(self.filter, MotionFireFilter):
                    is_suspected, percentage, mask = self.filter.detect(frame)
                    info = {'motion_percentage': f'{percentage:.2f}%'}
                else:  # ColorFireFilter
                    is_suspected, percentage, mask = self.filter.detect(frame)
                    info = {'color_percentage': f'{percentage:.2f}%'}
                
                # 화재 의심 프레임 감지 시
                if is_suspected:
                    self.detection_count += 1
                    
                    # 전송 간격 체크
                    if current_time - self.last_send_time >= config.SEND_INTERVAL:
                        # 프레임 리사이즈
                        resized_frame = cv2.resize(frame, config.MAX_FRAME_SIZE)
                        
                        # 메타데이터 구성
                        metadata = {
                            'frame_number': self.frame_count,
                            'timestamp': current_time,
                            'filter_type': self.filter_type,
                            'filter_info': info
                        }
                        
                        print(f"화재 의심 프레임 감지 (#{self.frame_count})")
                        print(f"필터 정보: {info}")
                        print(f"NPU 서버로 전송 중...")
                        
                        # NPU 서버로 전송
                        result = self.npu_client.send_frame(resized_frame, metadata)
                        
                        if result:
                            print(f"NPU 응답: {result}")
                        
                        self.last_send_time = current_time
                
                
                # 알림 체크
                if self.frame_count % config.ALERT_CHECK_INTERVAL == 0:
                    alert = self.npu_client.check_alert()
                    if alert and alert.get('active'):
                        print(f"NPU 알림: {alert}")
        
        except KeyboardInterrupt:
            print("\n\n사용자 중단")
        
        finally:
            cap.release()


def main():
    parser = argparse.ArgumentParser(
        description='라즈베리파이 화재 전처리 서버',
        formatter_class=argparse.RawDescriptionHelpFormatter,)
    
    parser.add_argument('--rtsp', type=str, default=config.RTSP_URL,
                       help='RTSP 스트림 URL')
    parser.add_argument('--npu', type=str, default=config.NPU_SERVER_URL,
                       help='NPU 서버 URL')
    parser.add_argument('--filter', type=str, default=config.FILTER_TYPE,
                       choices=['color', 'motion', 'hybrid'],
                       help='필터 타입')
    
    args = parser.parse_args()   
    preprocessor = FirePreprocessor(
        rtsp_url=args.rtsp,
        npu_server_url=args.npu,
        filter_type=args.filter
    )
    
    preprocessor.run()


if __name__ == "__main__":
    main()
