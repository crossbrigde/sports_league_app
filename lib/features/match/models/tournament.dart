import 'package:cloud_firestore/cloud_firestore.dart';

class Tournament {
  final String id;
  final String name;
  final String type;
  final DateTime createdAt;
  final int? targetPoints;  // 添加這個屬性，使用可空類型
  final int? matchMinutes;  // 添加這個屬性，使用可空類型
  final String status;      // 添加這個屬性

  Tournament({
    required this.id,
    required this.name,
    required this.type,
    required this.createdAt,
    this.targetPoints,      // 可選參數
    this.matchMinutes,      // 可選參數
    this.status = 'active', // 設置默認值
  });
  
  // 添加 fromFirestore 方法
  factory Tournament.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return Tournament(
      id: doc.id,
      name: data['name'] ?? '',
      type: data['type'] ?? '',
      createdAt: data['createdAt'] != null 
          ? (data['createdAt'] as Timestamp).toDate() 
          : DateTime.now(),
      targetPoints: data['targetPoints'] != null 
          ? (data['targetPoints'] as num).toInt() 
          : null,
      matchMinutes: data['matchMinutes'] != null 
          ? (data['matchMinutes'] as num).toInt() 
          : null,
      status: data['status'] ?? 'active',
    );
  }
  
  // 添加 toFirestore 方法以便將來使用
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'type': type,
      'createdAt': Timestamp.fromDate(createdAt),
      if (targetPoints != null) 'targetPoints': targetPoints,
      if (matchMinutes != null) 'matchMinutes': matchMinutes,
      'status': status,
    };
  }
}