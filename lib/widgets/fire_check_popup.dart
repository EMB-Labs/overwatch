import 'package:flutter/material.dart';

class FireCheckPopup extends StatelessWidget {
  final String title; // 제목 (화재 발생, 초기 화재 감지, 오경보)
  final String message; // 메시지
  final VoidCallback? onAccept;
  final VoidCallback? onReject;

  const FireCheckPopup({
    Key? key,
    required this.title,
    required this.message,
    this.onAccept,
    this.onReject,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title, // 동적!
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 5),
          Text(
            message, // 동적!
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          SizedBox(height: 20),
          Row(
            children: [
              // 거절 버튼
              Expanded(
                child: ElevatedButton(
                  onPressed: onReject,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[700],
                    padding: EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text('거절', style: TextStyle(color: Colors.white)),
                ),
              ),
              SizedBox(width: 10),
              // 수락 버튼
              Expanded(
                child: ElevatedButton(
                  onPressed: onAccept,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text('수락', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
