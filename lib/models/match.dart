class Match {
  final String? id;
  final String name;
  final String redPlayer;
  final String bluePlayer;
  final String refereeNumber;
  final String matchNumber;
  final Map<String, int> redScores;  // 移除可空類型
  final Map<String, int> blueScores;  // 移除可空類型
  final String status;
  final int? createdAt;
  final int? lastUpdated;

  Match({
    this.id,
    required this.name,
    required this.redPlayer,
    required this.bluePlayer,
    required this.refereeNumber,
    required this.matchNumber,
    Map<String, int>? redScores,  // 允許構造時為空
    Map<String, int>? blueScores,  // 允許構造時為空
    this.status = 'ongoing',
    this.createdAt,
    this.lastUpdated,
  }) : redScores = redScores ?? {  // 提供預設值
        "leftHand": 0,
        "rightHand": 0,
        "leftLeg": 0,
        "rightLeg": 0,
        "body": 0,
      },
      blueScores = blueScores ?? {  // 提供預設值
        "leftHand": 0,
        "rightHand": 0,
        "leftLeg": 0,
        "rightLeg": 0,
        "body": 0,
      };

  factory Match.fromJson(String id, Map<dynamic, dynamic> json) {
    return Match(
      id: id,
      name: json['name'] ?? '',
      redPlayer: json['redPlayer'] ?? '',
      bluePlayer: json['bluePlayer'] ?? '',
      refereeNumber: json['refereeNumber'] ?? '',
      matchNumber: json['matchNumber'] ?? '',
      redScores: _parseScores(json['redScores']),
      blueScores: _parseScores(json['blueScores']),
      status: json['status'] ?? 'ongoing',
      createdAt: json['createdAt'] as int?,
      lastUpdated: json['lastUpdated'] as int?,
    );
  }

  static Map<String, int> _parseScores(dynamic scores) {
    final defaultScores = {
      "leftHand": 0,
      "rightHand": 0,
      "leftLeg": 0,
      "rightLeg": 0,
      "body": 0,
    };

    if (scores == null) return defaultScores;
    if (scores is! Map) return defaultScores;
    
    final parsedScores = Map<String, int>.from(scores.map((key, value) => 
      MapEntry(key.toString(), (value is int) ? value : 0)
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
    return redScores.values.fold(0, (sum, score) => sum + score);
  }

  int getBlueTotal() {
    return blueScores.values.fold(0, (sum, score) => sum + score);
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'redPlayer': redPlayer,
    'bluePlayer': bluePlayer,
    'refereeNumber': refereeNumber,
    'matchNumber': matchNumber,
    'redScores': redScores,
    'blueScores': blueScores,
    'status': status,
    'createdAt': createdAt,
    'lastUpdated': lastUpdated,
  };

  Match copyWith({
    String? name,
    String? redPlayer,
    String? bluePlayer,
    String? refereeNumber,
    String? matchNumber,
    Map<String, int>? redScores,
    Map<String, int>? blueScores,
    String? status,
    int? createdAt,
    int? lastUpdated,
  }) {
    return Match(
      id: id,
      name: name ?? this.name,
      redPlayer: redPlayer ?? this.redPlayer,
      bluePlayer: bluePlayer ?? this.bluePlayer,
      refereeNumber: refereeNumber ?? this.refereeNumber,
      matchNumber: matchNumber ?? this.matchNumber,
      redScores: redScores ?? this.redScores,
      blueScores: blueScores ?? this.blueScores,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}