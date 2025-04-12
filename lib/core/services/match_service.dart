import 'package:cloud_firestore/cloud_firestore.dart';
import '../../features/match/models/match.dart';

class MatchService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 獲取所有未完成的比賽
  Stream<List<Match>> getUnfinishedMatches() {
    return _firestore
        .collection('matches')
        .where('basic_info.status', isNotEqualTo: 'completed')  // 修改路径
        .orderBy('timestamps.createdAt', descending: true)      // 修改路径
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Match.fromFirestore(doc))
            .toList());
  }

  // Method to get all ongoing matches
  // 獲取特定賽事的進行中比賽
  Stream<List<Match>> getOngoingMatches(String tournamentId) {
    print('正在查詢賽事 $tournamentId 的進行中比賽');
    return _firestore
        .collection('matches')
        .where('basic_info.tournamentId', isEqualTo: tournamentId)  // 修改路径
        .where('basic_info.status', isEqualTo: 'ongoing')           // 修改路径
        .orderBy('timestamps.createdAt', descending: true)          // 修改路径
        .snapshots()
        .map((snapshot) {
          print('查詢結果數量: ${snapshot.docs.length}');
          return snapshot.docs
              .map((doc) => Match.fromFirestore(doc))
              .toList();
        });
  }

  // 獲取所有進行中的比賽（不限賽事）
  Stream<List<Match>> getAllOngoingMatches() {
    print('正在查詢所有進行中比賽');
    return _firestore
        .collection('matches')
        .where('basic_info.status', isEqualTo: 'ongoing')  // 修改路径
        .orderBy('timestamps.createdAt', descending: true) // 修改路径
        .snapshots()
        .map((snapshot) {
          print('查詢結果數量: ${snapshot.docs.length}');
          return snapshot.docs
              .map((doc) => Match.fromFirestore(doc))
              .toList();
        });
  }

  // 創建新比賽
  Future<String?> createMatch(Match match) async {
    try {
      print('正在創建比賽：${match.name}');
      
      // 使用新的數據結構創建比賽文檔
      final now = DateTime.now();
      final matchData = {
        'basic_info': {
          'name': match.name,
          'matchNumber': match.matchNumber,
          'tournamentId': match.tournamentId,
          'tournamentName': match.tournamentName,
          'redPlayer': match.redPlayer,
          'bluePlayer': match.bluePlayer,
          'refereeNumber': match.refereeNumber,
          'status': match.status,
        },
        'scores': {
          'redScores': match.redScores,
          'blueScores': match.blueScores,
        },
        'sets': {
          'currentSet': match.currentSet,
          'redSetsWon': match.redSetsWon,
          'blueSetsWon': match.blueSetsWon,
          'setResults': match.setResults,
        },
        'judgments': [],
        'timestamps': {
          'createdAt': Timestamp.fromDate(now),
          'startedAt': Timestamp.fromDate(now),
          'lastUpdated': Timestamp.fromDate(now),
        },
      };
      
      final docRef = await _firestore.collection('matches').add(matchData);
      print('比賽創建成功，ID：${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('創建比賽時發生錯誤：$e');
      return null;
    }
  }
}