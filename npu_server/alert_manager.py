import subprocess
import sys
import time


class AlertManager:
    
    def __init__(self, script_path, cooldown=30):
        self.script_path = script_path
        self.cooldown = cooldown
        
        self.last_alert_time = 0
        self.alert_count = 0
        self.active = False
    
    def trigger(self, severity, detections_info):
        current_time = time.time()
        
        if current_time - self.last_alert_time < self.cooldown:
            return False
        
        try:
            print(f"화재 알림 발동! 심각도: {severity}")
            
            subprocess.Popen([
                sys.executable,
                self.script_path,
                severity,
                str(detections_info)
            ])
            
            self.last_alert_time = current_time
            self.alert_count += 1
            self.active = True
            
            return True
        
        except Exception as e:
            print(f"알림 스크립트 실행 오류: {e}")
            return False
    
    def reset(self):
        self.active = False
