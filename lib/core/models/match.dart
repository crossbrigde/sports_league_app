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
  
  // 雙淘汰賽相關
  final String? loserNextMatchId; // 敗者組下一場比賽的ID
  final String? bracket;          // 所屬組別 (winner, loser, final)
  final bool isGrandFinal;        // 是否為總決賽
  final bool isGrandFinalRematch; // 是否為總決賽重賽
  final String? loserSlotInNext;  // 敗者在下一場比賽中的位置
  
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
    this.loserNextMatchId,
    this.bracket,
    this.isGrandFinal = false,
    this.isGrandFinalRematch = false,
    this.loserSlotInNext,
  });
  
  // 從舊版本的數據創建Match對象的工廠方法
  factory Match.fromLegacyData({
    String? id,
    required String name,
    required String redPlayer,
    required String bluePlayer,
    required String refereeNumber,
    required String matchNumber,
    Map<String, int>? redScores,
    Map<String, int>? blueScores,
    String status = 'ongoing',
    dynamic createdAt,
    dynamic lastUpdated,
    String tournamentId = '',
    String tournamentName = '',
  }) {
    // 處理默認值
    final defaultScores = {
      "leftHand": 0,
      "rightHand": 0,
      "leftLeg": 0,
      "rightLeg": 0,
      "body": 0,
    };
    
    // 處理時間戳
    DateTime createdAtDateTime;
    if (createdAt is DateTime) {
      createdAtDateTime = createdAt;
    } else if (createdAt is Timestamp) {
      createdAtDateTime = createdAt.toDate();
    } else if (createdAt is int) {
      createdAtDateTime = DateTime.fromMillisecondsSinceEpoch(createdAt);
    } else {
      createdAtDateTime = DateTime.now();
    }
    
    DateTime? lastUpdatedDateTime;
    if (lastUpdated is DateTime) {
      lastUpdatedDateTime = lastUpdated;
    } else if (lastUpdated is Timestamp) {
      lastUpdatedDateTime = lastUpdated.toDate();
    } else if (lastUpdated is int) {
      lastUpdatedDateTime = DateTime.fromMillisecondsSinceEpoch(lastUpdated);
    }
    
    return Match(
      id: id ?? '',
      name: name,
      matchNumber: matchNumber,
      tournamentId: tournamentId,
      tournamentName: tournamentName,
      redPlayer: redPlayer,
      bluePlayer: bluePlayer,
      refereeNumber: refereeNumber,
      status: status,
      redScores: redScores ?? Map<String, int>.from(defaultScores),
      blueScores: blueScores ?? Map<String, int>.from(defaultScores),
      currentSet: 1,
      redSetsWon: 0,
      blueSetsWon: 0,
      setResults: {},
      createdAt: createdAtDateTime,
      lastUpdated: lastUpdatedDateTime,
      judgments: [],
    );
  }
  
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
      loserNextMatchId: basicInfo['loserNextMatchId'],
      bracket: basicInfo['bracket'],
      isGrandFinal: basicInfo['isGrandFinal'] ?? false,
      isGrandFinalRematch: basicInfo['isGrandFinalRematch'] ?? false,
      loserSlotInNext: basicInfo['loserSlotInNext'],
    );
  }

  // 兼容舊版本的fromJson方法
  factory Match.fromJson(String id, Map<dynamic, dynamic> json) {
    // 檢查是否為新格式的數據
    if (json.containsKey('basic_info')) {
      // 使用新格式解析
      final basicInfo = json['basic_info'] as Map<dynamic, dynamic>? ?? {};
      final scores = json['scores'] as Map<dynamic, dynamic>? ?? {};
      final sets = json['sets'] as Map<dynamic, dynamic>? ?? {};
      final timestamps = json['timestamps'] as Map<dynamic, dynamic>? ?? {};
      final judgmentsData = json['judgments'] as List<dynamic>? ?? [];
      
      return Match(
        id: id,
        name: basicInfo['name'] ?? '',
        matchNumber: basicInfo['matchNumber'] ?? '',
        tournamentId: basicInfo['tournamentId'] ?? '',
        tournamentName: basicInfo['tournamentName'] ?? '',
        redPlayer: basicInfo['redPlayer'] ?? '',
        bluePlayer: basicInfo['bluePlayer'] ?? '',
        refereeNumber: basicInfo['refereeNumber'] ?? '',
        status: basicInfo['status'] ?? 'pending',
        redScores: _parseScores(scores['redScores']),
        blueScores: _parseScores(scores['blueScores']),
        currentSet: sets['currentSet'] ?? 1,
        redSetsWon: sets['redSetsWon'] ?? 0,
        blueSetsWon: sets['blueSetsWon'] ?? 0,
        setResults: sets['setResults'] ?? {},
        createdAt: _parseDateTime(timestamps['createdAt']),
        startedAt: _parseDateTime(timestamps['startedAt']),
        lastUpdated: _parseDateTime(timestamps['lastUpdated']),
        completedAt: _parseDateTime(timestamps['completedAt']),
        judgments: judgmentsData.map((item) => Map<String, dynamic>.from(item as Map)).toList(),
        winner: basicInfo['winner'],
        winReason: basicInfo['winReason'],
        round: basicInfo['round'],
        nextMatchId: basicInfo['nextMatchId'],
        slotInNext: basicInfo['slotInNext'],
      );
    } else {
      // 使用舊格式解析
      return Match.fromLegacyData(
        id: id,
        name: json['name'] ?? '',
        redPlayer: json['redPlayer'] ?? '',
        bluePlayer: json['bluePlayer'] ?? '',
        refereeNumber: json['refereeNumber'] ?? '',
        matchNumber: json['matchNumber'] ?? '',
        redScores: _parseScores(json['redScores']),
        blueScores: _parseScores(json['blueScores']),
        status: json['status'] ?? 'ongoing',
        createdAt: json['createdAt'],
        lastUpdated: json['lastUpdated'],
        tournamentId: json['tournamentId'] ?? '',
        tournamentName: json['tournamentName'] ?? '',
      );
    }
  }

  static DateTime _parseDateTime(dynamic timestamp) {
    if (timestamp == null) return DateTime.now();
    if (timestamp is Timestamp) return timestamp.toDate();
    if (timestamp is DateTime) return timestamp;
    if (timestamp is int) return DateTime.fromMillisecondsSinceEpoch(timestamp);
    if (timestamp is String) {
      try {
        return DateTime.parse(timestamp);
      } catch (e) {
        return DateTime.now();
      }
    }
    return DateTime.now();
  }

  static Map<String, int> _parseScores(dynamic scores) {
    final defaultScores = {
      "leftHand": 0,
      "rightHand": 0,
      "leftLeg": 0,
      "rightLeg": 0,
      "body": 0,
      "total": 0,
    };

    if (scores == null) return Map<String, int>.from(defaultScores);
    if (scores is! Map) return Map<String, int>.from(defaultScores);
    
    final parsedScores = Map<String, int>.from(scores.map((key, value) => 
      MapEntry(key.toString(), (value is num) ? value.toInt() : 0)
    ));

    // 確保所有必要的鍵都存在
    defaultScores.forEach((key, value) {
      if (!parsedScores.containsKey(key)) {
        parsedScores[key] = 0;
      }
    });

    return parsedScores;
  }

  int getRedTotal() {
    return redScores['total'] ?? redScores.values.fold(0, (sum, score) => sum + score);
  }

  int getBlueTotal() {
    return blueScores['total'] ?? blueScores.values.fold(0, (sum, score) => sum + score);
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
      'loserNextMatchId': loserNextMatchId,
      'bracket': bracket,
      'isGrandFinal': isGrandFinal,
      'loserSlotInNext': loserSlotInNext,
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

  // 兼容舊版本的toJson方法
  Map<String, dynamic> toJson() {
    // 添加詳細日誌以檢查序列化過程
    print('Match.toJson() - 序列化比賽: $id, $name');
    print('Match.toJson() - 檢查單淘汰賽相關字段: round=$round, nextMatchId=$nextMatchId, slotInNext=$slotInNext');
    
    return toFirestore();
  }

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
    String? loserNextMatchId, // Added
    String? bracket,          // Added
    bool? isGrandFinal,       // Added
    bool? isGrandFinalRematch, // Added
    String? loserSlotInNext,  // Added
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
    createdAt: createdAt ?? this.createdAt,
    startedAt: startedAt ?? this.startedAt,
    lastUpdated: lastUpdated ?? this.lastUpdated,
    completedAt: completedAt ?? this.completedAt,
    judgments: judgments ?? this.judgments,
    winner: winner ?? this.winner,
    winReason: winReason ?? this.winReason,
    round: round ?? this.round,
    nextMatchId: nextMatchId ?? this.nextMatchId,
    slotInNext: slotInNext ?? this.slotInNext,
    loserNextMatchId: loserNextMatchId ?? this.loserNextMatchId, // Added
    bracket: bracket ?? this.bracket,                            // Added
    isGrandFinal: isGrandFinal ?? this.isGrandFinal,              // Added
    isGrandFinalRematch: isGrandFinalRematch ?? this.isGrandFinalRematch, // Added
    loserSlotInNext: loserSlotInNext ?? this.loserSlotInNext,      // Added
  );
  
  bool get isOngoing => status == 'ongoing';
}