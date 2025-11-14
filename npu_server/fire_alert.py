import sys
import os
from datetime import datetime


def trigger_alert(severity, detection_info):
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    
    print("\n" + "="*60)
    print("화재 경보 발동!")
    print("="*60)
    print(f"시간: {timestamp}")
    print(f"심각도: {severity.upper()}")
    print(f"감지 정보: {detection_info}")
    print("="*60)
    
    log_file = "fire_alerts.log"
    try:
        with open(log_file, 'a', encoding='utf-8') as f:
            f.write(f"{timestamp} | {severity} | {detection_info}\n")
        print(f"로그 저장: {log_file}")
    except Exception as e:
        print(f"로그 저장 실패: {e}")
    
    print("알림 발송 완료")
    print("="*60 + "\n")


def main():
    if len(sys.argv) >= 3:
        severity = sys.argv[1]
        detection_info = sys.argv[2]
    else:
        severity = "severe"
        detection_info = "Test alert"
    
    trigger_alert(severity, detection_info)


if __name__ == "__main__":
    main()
