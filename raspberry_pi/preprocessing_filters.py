import cv2
import numpy as np
from collections import deque


class ColorFireFilter:
    """
    HSV 색상 기반 화재 감지 필터
    """
    
    def __init__(self, threshold=5.0):
        self.threshold = threshold
        
        self.lower_red1 = np.array([0, 180, 180])    # 낮은 빨강 (S,V 180으로 상향)
        self.upper_red1 = np.array([10, 255, 255])
        
        self.lower_red2 = np.array([160, 180, 180])  # 높은 빨강
        self.upper_red2 = np.array([180, 255, 255])
        
        self.lower_yellow = np.array([15, 180, 180]) # 노랑/주황
        self.upper_yellow = np.array([35, 255, 255])
    
    def detect(self, frame):
        hsv = cv2.cvtColor(frame, cv2.COLOR_BGR2HSV)
        
        mask_red1 = cv2.inRange(hsv, self.lower_red1, self.upper_red1)
        mask_red2 = cv2.inRange(hsv, self.lower_red2, self.upper_red2)
        mask_yellow = cv2.inRange(hsv, self.lower_yellow, self.upper_yellow)
        
        mask = mask_red1 | mask_red2 | mask_yellow
        
        kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (7, 7))
        mask = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, kernel)
        mask = cv2.morphologyEx(mask, cv2.MORPH_OPEN, kernel)
        
        fire_pixels = cv2.countNonZero(mask)
        total_pixels = frame.shape[0] * frame.shape[1]
        fire_percentage = (fire_pixels / total_pixels) * 100
        
        is_detected = fire_percentage >= self.threshold
        
        return is_detected, fire_percentage, mask


class MotionFireFilter:
    """
    프레임 차이 기반 움직임 감지 필터
    """
    
    def __init__(self, threshold=8.0, diff_threshold=40, 
                 temporal_frames=5, temporal_min=3):

        self.threshold = threshold
        self.diff_threshold = diff_threshold
        self.temporal_frames = temporal_frames
        self.temporal_min = temporal_min
        
        self.motion_history = deque(maxlen=temporal_frames)
        self.prev_gray = None
    
    def detect(self, frame):
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        gray = cv2.GaussianBlur(gray, (21, 21), 0)
        
        if self.prev_gray is None:
            self.prev_gray = gray
            return False, 0, None
        
        frame_diff = cv2.absdiff(self.prev_gray, gray)
        
        thresh = cv2.threshold(frame_diff, self.diff_threshold, 255, cv2.THRESH_BINARY)[1]
        
        kernel = np.ones((7, 7), np.uint8)
        thresh = cv2.morphologyEx(thresh, cv2.MORPH_OPEN, kernel)
        thresh = cv2.dilate(thresh, kernel, iterations=2)
        
        motion_pixels = cv2.countNonZero(thresh)
        total_pixels = frame.shape[0] * frame.shape[1]
        motion_percentage = (motion_pixels / total_pixels) * 100
        
        self.motion_history.append(motion_percentage)
        self.prev_gray = gray
        
        if len(self.motion_history) >= self.temporal_min:
            high_motion_count = sum(1 for m in self.motion_history if m >= self.threshold)
            is_detected = high_motion_count >= self.temporal_min
            return is_detected, motion_percentage, thresh
        
        is_detected = motion_percentage >= self.threshold
        return is_detected, motion_percentage, thresh


class HybridFireFilter:
    """
    Color + Motion 조합 필터 
    """
    
    def __init__(self, color_threshold=5.0, motion_threshold=8.0,
                 diff_threshold=40, temporal_frames=5, temporal_min=3):
        self.color_filter = ColorFireFilter(threshold=color_threshold)
        self.motion_filter = MotionFireFilter(
            threshold=motion_threshold,
            diff_threshold=diff_threshold,
            temporal_frames=temporal_frames,
            temporal_min=temporal_min
        )
    
    def detect(self, frame):

        color_detected, color_percentage, color_mask = self.color_filter.detect(frame)
        motion_detected, motion_percentage, motion_mask = self.motion_filter.detect(frame)
        
        is_fire_suspected = False
        
        if color_percentage >= 5.0 and motion_detected:
            is_fire_suspected = True
        
        elif color_percentage >= 8.0:
            is_fire_suspected = True
        
        elif motion_percentage >= 10.0 and color_percentage >= 2.0:
            is_fire_suspected = True
        
        combined_mask = None
        if color_mask is not None and motion_mask is not None:
            combined_mask = cv2.bitwise_and(color_mask, motion_mask)
        
        info = {
            'color_percentage': color_percentage,
            'motion_percentage': motion_percentage,
            'color_detected': color_detected,
            'motion_detected': motion_detected
        }
        
        return is_fire_suspected, info, combined_mask
