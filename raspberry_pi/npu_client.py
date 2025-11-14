import requests
import cv2
import json


class NPUClient:
    """NPU 서버와의 HTTP 통신 담당"""
    
    def __init__(self, server_url):
        """
        Args:
            server_url (str): NPU 서버 URL
        """
        self.server_url = server_url
        self.detect_url = f"{server_url}/detect"
        self.alert_url = f"{server_url}/alert"
        self.health_url = f"{server_url}/health"
        self.stats_url = f"{server_url}/stats"
        
        self.session = requests.Session()
    
    def send_frame(self, frame, metadata=None):
        """
        화재 의심 프레임을 NPU 서버로 전송
        """
        try:

            _, buffer = cv2.imencode('.jpg', frame, [cv2.IMWRITE_JPEG_QUALITY, 85])
            
            files = {'frame': ('frame.jpg', buffer.tobytes(), 'image/jpeg')}
            data = {'metadata': json.dumps(metadata)} if metadata else {}
            
            response = self.session.post(
                self.detect_url,
                files=files,
                data=data,
                timeout=5
            )
            
            if response.status_code == 200:
                return response.json()
            else:
                print(f"NPU 서버 응답 오류: {response.status_code}")
                return None
        
        except requests.exceptions.RequestException as e:
            print(f"NPU 서버 통신 오류: {e}")
            return None
    
    def check_alert(self):
        """
        NPU 서버의 알림 상태 확인
        """
        try:
            response = self.session.get(self.alert_url, timeout=2)
            return response.json() if response.status_code == 200 else None
        except:
            return None
    
    def check_health(self):
        """
        NPU 서버 상태 확인
        """
        try:
            response = self.session.get(self.health_url, timeout=2)
            return response.json() if response.status_code == 200 else None
        except:
            return None
    
    def get_stats(self):
        """
        NPU 서버 통계 정보 조회
        """
        try:
            response = self.session.get(self.stats_url, timeout=2)
            return response.json() if response.status_code == 200 else None
        except:
            return None
