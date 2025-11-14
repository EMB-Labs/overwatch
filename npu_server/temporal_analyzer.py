import time


class TemporalAnalyzerNPU:
    
    def __init__(self, persistence_threshold=10.0, growth_factor=1.5):
        self.persistence_threshold = persistence_threshold
        self.growth_factor = growth_factor
        
        self.fire_history = {}
        self.last_detections = {}
    
    def analyze(self, detections, frame_timestamp):
        current_detections = []
        persistent_fires = []
        spreading_fires = []
        
        for det in detections:
            x1, y1, x2, y2, conf, cls = det
            
            if cls != 0:
                continue
            
            fire_id = self._get_fire_id(x1, y1, x2, y2)
            bbox_area = (x2 - x1) * (y2 - y1)
            
            current_detections.append({
                'id': fire_id,
                'bbox': (x1, y1, x2, y2),
                'confidence': conf,
                'area': bbox_area,
                'timestamp': frame_timestamp
            })
            
            if fire_id in self.fire_history:
                history = self.fire_history[fire_id]
                duration = frame_timestamp - history['first_seen']
                
                if duration >= self.persistence_threshold:
                    persistent_fires.append(fire_id)
                
                initial_area = history['initial_area']
                if bbox_area > initial_area * self.growth_factor:
                    spreading_fires.append(fire_id)
                
                history['last_seen'] = frame_timestamp
                history['last_area'] = bbox_area
                history['detection_count'] += 1
            
            else:
                self.fire_history[fire_id] = {
                    'first_seen': frame_timestamp,
                    'last_seen': frame_timestamp,
                    'initial_area': bbox_area,
                    'last_area': bbox_area,
                    'detection_count': 1
                }
        
        self.last_detections = {det['id']: det for det in current_detections}
        
        is_dangerous = len(persistent_fires) > 0 or len(spreading_fires) > 0
        
        if len(spreading_fires) > 0:
            severity = 'severe'
        elif len(persistent_fires) > 0:
            severity = 'moderate'
        else:
            severity = 'trivial'
        
        return {
            'is_dangerous': is_dangerous,
            'severity': severity,
            'persistent_fires': persistent_fires,
            'spreading_fires': spreading_fires,
            'statistics': {
                'total_detections': len(current_detections),
                'tracked_fires': len(self.fire_history),
                'persistent_count': len(persistent_fires),
                'spreading_count': len(spreading_fires)
            }
        }
    
    def _get_fire_id(self, x1, y1, x2, y2):
        cx = int((x1 + x2) / 2 / 50) * 50
        cy = int((y1 + y2) / 2 / 50) * 50
        return f"fire_{cx}_{cy}"
    
    def reset(self):
        self.fire_history = {}
        self.last_detections = {}
