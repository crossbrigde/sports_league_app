import 'package:cloud_firestore/cloud_firestore.dart';

class Tournament {
  final String id;
  final String name;
  final String type; // 'regular', 'single_elimination', 'double_elimination', 'round_robin'
  final DateTime createdAt;
  final int? targetPoints;  // 添加這個屬性，使用可空類型
  final int? matchMinutes;  // 添加這個屬性，使用可空類型
  final String status;      // 'setup', 'ongoing', 'finished'
  final int? numPlayers;    // 參賽人數
  final List<Map<String, dynamic>>? participants; // 參賽者信息
  final Map<String, dynamic>? matches; // 賽程結構數據

  Tournament({
    required this.id,
    required this.name,
    required this.type,
    required this.createdAt,
    this.targetPoints,      // 可選參數
    this.matchMinutes,      // 可選參數
    this.status = 'setup',  // 設置默認值
    this.numPlayers,        // 參賽人數
    this.participants,      // 參賽者信息
    this.matches,           // 賽程結構數據
  });

  
  // 添加 fromFirestore 方法
  factory Tournament.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return Tournament(
      id: doc.id,
      name: (data['name'] as String?) ?? '未命名賽程',
      type: (data['type'] as String?) ?? 'regular',
      createdAt: data['createdAt'] != null 
          ? (data['createdAt'] as Timestamp).toDate() 
          : DateTime.now(),
      targetPoints: data['targetPoints'] != null 
          ? (data['targetPoints'] as num).toInt() 
          : null,
      matchMinutes: data['matchMinutes'] != null 
          ? (data['matchMinutes'] as num).toInt() 
          : null,
      status: (data['status'] as String?) ?? 'setup',
      numPlayers: data['numPlayers'] != null 
          ? (data['numPlayers'] as num).toInt() 
          : null,
      participants: data['participants'] != null 
          ? List<Map<String, dynamic>>.from(data['participants']) 
          : null,
      matches: data['matches'] != null 
          ? Map<String, dynamic>.from(data['matches']) 
          : null,
    );
  }
  
  // 添加 toFirestore 方法以便將來使用
  Map<String, dynamic> toFirestore() {
    // 添加詳細日誌以檢查序列化過程
    print('Tournament.toFirestore() - 序列化賽程: $id, $name');
    print('Tournament.toFirestore() - 檢查關鍵字段: targetPoints=$targetPoints, matchMinutes=$matchMinutes');
    print('Tournament.toFirestore() - 檢查 matches 字段: ${matches != null ? 'matches 不為 null' : 'matches 為 null'}');
    
    return {
      'name': name,
      'type': type,
      'createdAt': Timestamp.fromDate(createdAt),
      if (targetPoints != null) 'targetPoints': targetPoints,
      if (matchMinutes != null) 'matchMinutes': matchMinutes,
      'status': status,
      if (numPlayers != null) 'numPlayers': numPlayers,
      if (participants != null) 'participants': participants,
      if (matches != null) 'matches': matches,
    };
  }
}