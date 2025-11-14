import cv2
import numpy as np


def decode_yolo_output_npu(output, conf_thres=0.25, iou_thres=0.45, input_size=640):
    try:
        if len(output.shape) == 3:
            output = output[0]
        
        if output.shape[0] == 6:
            output = output.T
        
        boxes = output[:, :4]
        scores = output[:, 4]
        class_ids = output[:, 5] if output.shape[1] > 5 else np.zeros(len(output))
        
        mask = scores > conf_thres
        boxes = boxes[mask]
        scores = scores[mask]
        class_ids = class_ids[mask]
        
        if len(boxes) == 0:
            return []
        
        indices = cv2.dnn.NMSBoxes(
            boxes.tolist(),
            scores.tolist(),
            conf_thres,
            iou_thres
        )
        
        detections = []
        if len(indices) > 0:
            for i in indices.flatten():
                x1, y1, x2, y2 = boxes[i]
                detections.append([
                    float(x1), float(y1), float(x2), float(y2),
                    float(scores[i]), int(class_ids[i])
                ])
        
        return detections
    
    except Exception as e:
        print(f"YOLO 디코딩 오류: {e}")
        return []
