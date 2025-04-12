import 'package:cloud_firestore/cloud_firestore.dart';

class Match {
  final String id;
  final String name;
  final String matchNumber;
  final String redPlayer;
  final String bluePlayer;
  final String refereeNumber;
  final String status;
  final Map<String, int> redScores;
  final Map<String, int> blueScores;
  final DateTime createdAt;
  final int? currentSet;  // 新增
  final Map<String, String>? setResults;  // 新增
  final int? redSetsWon;  // 新增
  final int? blueSetsWon;  // 新增

  final String tournamentId;  // Add this field
  final String tournamentName;  // Add this field

  Match({
    required this.id,
    required this.name,
    required this.matchNumber,
    required this.redPlayer,
    required this.bluePlayer,
    required this.refereeNumber,
    required this.status,
    required this.createdAt,
    required this.tournamentId,  // Add this
    required this.tournamentName,  // Add this
    Map<String, int>? redScores,
    Map<String, int>? blueScores,
    this.currentSet,  // 新增
    this.setResults,  // 新增
    this.redSetsWon,  // 新增
    this.blueSetsWon,  // 新增
  })  : redScores = redScores ?? {},
        blueScores = blueScores ?? {};

  factory Match.fromJson(String id, Map<dynamic, dynamic> json) {
    return Match(
      id: id,
      name: json['name'] as String? ?? '',
      matchNumber: json['matchNumber'] as String? ?? '',
      redPlayer: json['redPlayer'] as String? ?? '',
      bluePlayer: json['bluePlayer'] as String? ?? '',
      refereeNumber: json['refereeNumber'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      tournamentId: json['tournamentId'] as String? ?? '',
      tournamentName: json['tournamentName'] as String? ?? '',
      redScores: Map<String, int>.from(json['redScores'] as Map? ?? {}),
      blueScores: Map<String, int>.from(json['blueScores'] as Map? ?? {}),
    );
  }

  factory Match.fromFirestore(DocumentSnapshot doc) {
      final data = doc.data() as Map<String, dynamic>;
      final defaultScores = {
        'leftHand': 0,
        'rightHand': 0,
        'leftLeg': 0,
        'rightLeg': 0,
        'body': 0,
      };
  
      return Match(
        id: doc.id,
        name: data['name'] ?? '',
        redPlayer: data['redPlayer'] ?? '',
        bluePlayer: data['bluePlayer'] ?? '',
        refereeNumber: data['refereeNumber'] ?? '',
        matchNumber: data['matchNumber'],
        tournamentId: data['tournamentId'] ?? '',
        tournamentName: data['tournamentName'] ?? '',
        redScores: Map<String, int>.from(data['redScores'] ?? defaultScores),
        blueScores: Map<String, int>.from(data['blueScores'] ?? defaultScores),
        createdAt: (data['createdAt'] as Timestamp).toDate(),
        status: data['status'] ?? 'pending',
        currentSet: data['currentSet'],
        setResults: data['setResults'] != null 
            ? Map<String, String>.from(data['setResults'])
            : null,
        redSetsWon: data['redSetsWon'],
        blueSetsWon: data['blueSetsWon'],
      );
    }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'matchNumber': matchNumber,
      'redPlayer': redPlayer,
      'bluePlayer': bluePlayer,
      'refereeNumber': refereeNumber,
      'status': status,
      'tournamentId': tournamentId,
      'tournamentName': tournamentName,
      'redScores': redScores,
      'blueScores': blueScores,
      'createdAt': Timestamp.fromDate(createdAt),
      'currentSet': currentSet,
      'setResults': setResults,
      'redSetsWon': redSetsWon,
      'blueSetsWon': blueSetsWon,
    };
  }

  bool get isOngoing => status == 'ongoing';
}