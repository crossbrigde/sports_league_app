import 'package:cloud_firestore/cloud_firestore.dart';

class Match {
  final String id;
  
  // 基本信息
  final String name;
  final String matchNumber;
  final String tournamentId;
  final String tournamentName;
  final String redPlayer;
  final String bluePlayer;
  final String refereeNumber;
  final String status;
  
  // 分数
  final Map<String, int> redScores;
  final Map<String, int> blueScores;
  
  // 局相关
  final int currentSet;
  final int redSetsWon;
  final int blueSetsWon;
  final Map<String, dynamic> setResults;
  
  // 时间戳
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? lastUpdated;
  final DateTime? completedAt;
  
  // 判定记录
  final List<Map<String, dynamic>> judgments;
  
  // 比賽結果
  final String? winner;
  final String? winReason;
  
  // 單淘汰賽相關
  final int? round;           // 比賽輪次
  final String? nextMatchId;  // 下一場比賽的ID
  final String? slotInNext;   // 在下一場比賽中的位置（redPlayer或bluePlayer）
  
  Match({
    required this.id,
    required this.name,
    required this.matchNumber,
    required this.tournamentId,
    required this.tournamentName,
    required this.redPlayer,
    required this.bluePlayer,
    required this.refereeNumber,
    required this.status,
    required this.redScores,
    required this.blueScores,
    required this.currentSet,
    required this.redSetsWon,
    required this.blueSetsWon,
    required this.setResults,
    required this.createdAt,
    this.startedAt,
    this.lastUpdated,
    this.completedAt,
    this.judgments = const [],
    this.winner,
    this.winReason,
    this.round,
    this.nextMatchId,
    this.slotInNext,
  });
  
  // 在 fromFirestore 方法中添加 judgments 解析
  factory Match.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    // 获取基本信息
    final basicInfo = data['basic_info'] as Map<String, dynamic>? ?? {};
    
    // 获取分数
    final scores = data['scores'] as Map<String, dynamic>? ?? {};
    final redScores = scores['redScores'] as Map<String, dynamic>? ?? {'total': 0};
    final blueScores = scores['blueScores'] as Map<String, dynamic>? ?? {'total': 0};
    
    // 获取局信息
    final sets = data['sets'] as Map<String, dynamic>? ?? {};
    final setResults = sets['setResults'] as Map<String, dynamic>? ?? {};
    
    // 获取判定记录
    final judgmentsData = data['judgments'] as List<dynamic>? ?? [];
    final judgments = judgmentsData.map((item) => Map<String, dynamic>.from(item as Map)).toList();
    
    // 获取时间戳
    final timestamps = data['timestamps'] as Map<String, dynamic>? ?? {};
    
    return Match(
      id: doc.id,
      name: basicInfo['name'] ?? '',
      matchNumber: basicInfo['matchNumber'] ?? '',
      tournamentId: basicInfo['tournamentId'] ?? '',
      tournamentName: basicInfo['tournamentName'] ?? '',
      redPlayer: basicInfo['redPlayer'] ?? '',
      bluePlayer: basicInfo['bluePlayer'] ?? '',
      refereeNumber: basicInfo['refereeNumber'] ?? '',
      status: basicInfo['status'] ?? 'pending',
      redScores: Map<String, int>.from(redScores.map((k, v) => MapEntry(k, (v as num).toInt()))),
      blueScores: Map<String, int>.from(blueScores.map((k, v) => MapEntry(k, (v as num).toInt()))),
      currentSet: sets['currentSet'] ?? 1,
      redSetsWon: sets['redSetsWon'] ?? 0,
      blueSetsWon: sets['blueSetsWon'] ?? 0,
      setResults: setResults,
      createdAt: timestamps['createdAt'] != null 
          ? (timestamps['createdAt'] as Timestamp).toDate() 
          : DateTime.now(),
      startedAt: timestamps['startedAt'] != null 
          ? (timestamps['startedAt'] as Timestamp).toDate() 
          : null,
      lastUpdated: timestamps['lastUpdated'] != null 
          ? (timestamps['lastUpdated'] as Timestamp).toDate() 
          : null,
      completedAt: timestamps['completedAt'] != null 
          ? (timestamps['completedAt'] as Timestamp).toDate() 
          : null,
      judgments: judgments,
      winner: basicInfo['winner'],
      winReason: basicInfo['winReason'],
      round: basicInfo['round'] != null ? (basicInfo['round'] as num).toInt() : null,
      nextMatchId: basicInfo['nextMatchId'],
      slotInNext: basicInfo['slotInNext'],
    );
  }

  Map<String, dynamic> toFirestore() => {
    'basic_info': {
      'name': name,
      'matchNumber': matchNumber,
      'tournamentId': tournamentId,
      'tournamentName': tournamentName,
      'redPlayer': redPlayer,
      'bluePlayer': bluePlayer,
      'refereeNumber': refereeNumber,
      'status': status,
      'winner': winner,
      'winReason': winReason,
      'round': round,
      'nextMatchId': nextMatchId,
      'slotInNext': slotInNext,
    },
    'scores': {
      'redScores': redScores,
      'blueScores': blueScores,
    },
    'sets': {
      'currentSet': currentSet,
      'redSetsWon': redSetsWon,
      'blueSetsWon': blueSetsWon,
      'setResults': setResults,
    },
    'judgments': judgments,
    'timestamps': {
      'createdAt': Timestamp.fromDate(createdAt),
      if (startedAt != null) 'startedAt': Timestamp.fromDate(startedAt!),
      if (lastUpdated != null) 'lastUpdated': Timestamp.fromDate(lastUpdated!),
      if (completedAt != null) 'completedAt': Timestamp.fromDate(completedAt!),
    },
  };

  Match copyWith({
    String? id,
    String? name,
    String? matchNumber,
    String? tournamentId,
    String? tournamentName,
    String? redPlayer,
    String? bluePlayer,
    String? refereeNumber,
    String? status,
    Map<String, int>? redScores,
    Map<String, int>? blueScores,
    int? currentSet,
    int? redSetsWon,
    int? blueSetsWon,
    Map<String, dynamic>? setResults,
    List<Map<String, dynamic>>? judgments,
    DateTime? createdAt,
    DateTime? startedAt,
    DateTime? lastUpdated,
    DateTime? completedAt,
    String? winner,
    String? winReason,
    int? round,
    String? nextMatchId,
    String? slotInNext,
  }) => Match(
    id: id ?? this.id,
    name: name ?? this.name,
    matchNumber: matchNumber ?? this.matchNumber,
    tournamentId: tournamentId ?? this.tournamentId,
    tournamentName: tournamentName ?? this.tournamentName,
    redPlayer: redPlayer ?? this.redPlayer,
    bluePlayer: bluePlayer ?? this.bluePlayer,
    refereeNumber: refereeNumber ?? this.refereeNumber,
    status: status ?? this.status,
    redScores: redScores ?? this.redScores,
    blueScores: blueScores ?? this.blueScores,
    currentSet: currentSet ?? this.currentSet,
    redSetsWon: redSetsWon ?? this.redSetsWon,
    blueSetsWon: blueSetsWon ?? this.blueSetsWon,
    setResults: setResults ?? this.setResults,
    judgments: judgments ?? this.judgments,
    createdAt: createdAt ?? this.createdAt,
    startedAt: startedAt ?? this.startedAt,
    lastUpdated: lastUpdated ?? this.lastUpdated,
    completedAt: completedAt ?? this.completedAt,
    winner: winner ?? this.winner,
    winReason: winReason ?? this.winReason,
    round: round ?? this.round,
    nextMatchId: nextMatchId ?? this.nextMatchId,
    slotInNext: slotInNext ?? this.slotInNext,
  );
}