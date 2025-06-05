import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/match.dart';
import '../models/tournament.dart';

class MatchService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // 公開firestore實例，供其他類訪問
  FirebaseFirestore get firestore => _firestore;

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
  
  // 獲取已完成的比賽
  Stream<List<Match>> getCompletedMatches() {
    print('正在查詢已完成比賽');
    return _firestore
        .collection('matches')
        .where('basic_info.status', isEqualTo: 'completed')
        .orderBy('timestamps.createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          print('已完成比賽數量: ${snapshot.docs.length}');
          return snapshot.docs
              .map((doc) => Match.fromFirestore(doc))
              .toList();
        });
  }
  
  // 獲取最近的比賽（包含進行中和已完成的）
  Stream<List<Match>> getRecentMatches({int limit = 5}) {
    print('正在查詢最近的比賽，限制 $limit 場');
    return _firestore
        .collection('matches')
        .orderBy('timestamps.createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          print('最近比賽數量: ${snapshot.docs.length}');
          return snapshot.docs
              .map((doc) => Match.fromFirestore(doc))
              .toList();
        });
  }
  
  // 獲取所有比賽
  Stream<List<Match>> getAllMatches() {
    print('正在查詢所有比賽');
    return _firestore
        .collection('matches')
        .orderBy('timestamps.createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          print('所有比賽數量: ${snapshot.docs.length}');
          return snapshot.docs
              .map((doc) => Match.fromFirestore(doc))
              .toList();
        });
  }
  
  // 獲取活躍賽程及其比賽
  Future<Map<Tournament, List<Match>>> getActiveTournamentsWithMatches() async {
    print('正在查詢活躍賽程及其比賽');
    
    // 獲取所有活躍賽程
    final tournamentsSnapshot = await _firestore
        .collection('tournaments')
        .where('status', isEqualTo: 'active')
        .orderBy('createdAt', descending: true)
        .get();
    
    final Map<Tournament, List<Match>> result = {};
    
    // 如果沒有活躍賽程，返回空結果
    if (tournamentsSnapshot.docs.isEmpty) {
      print('沒有找到活躍賽程');
      return result;
    }
    
    // 獲取所有活躍賽程的ID
    final tournamentIds = tournamentsSnapshot.docs.map((doc) => doc.id).toList();
    print('找到 ${tournamentIds.length} 個活躍賽程');
    
    // 將賽程轉換為Tournament對象
    final tournaments = tournamentsSnapshot.docs
        .map((doc) => Tournament.fromFirestore(doc))
        .toList();
    
    // 獲取這些賽程的所有比賽
    // 注意：這裡需要創建複合索引 basic_info.tournamentId 和 timestamps.createdAt
    // 索引鏈接：https://console.firebase.google.com/v1/r/project/sports-league-app-d25e2/firestore/indexes?
    List<QueryDocumentSnapshot<Map<String, dynamic>>> matchDocs = [];
    
    try {
      final matchesSnapshot = await _firestore
          .collection('matches')
          .where('basic_info.tournamentId', whereIn: tournamentIds)
          .orderBy('timestamps.createdAt', descending: true)
          .get();
      
      matchDocs = matchesSnapshot.docs;
      print('找到 ${matchDocs.length} 場比賽');
    } catch (e) {
      print('查詢出錯，可能是索引問題：$e');
      print('嘗試使用備用查詢方法（不使用排序）...');
      
      // 備用查詢方法：不使用排序，避免需要複合索引
      try {
        final matchesSnapshot = await _firestore
            .collection('matches')
            .where('basic_info.tournamentId', whereIn: tournamentIds)
            .get();
        
        matchDocs = matchesSnapshot.docs;
        print('備用查詢找到 ${matchDocs.length} 場比賽');
      } catch (e) {
        print('備用查詢也失敗：$e');
        throw Exception('載入賽程資料失敗：$e');
      }
    }
    
    // 將比賽按賽程分組
    final allMatches = matchDocs
        .map((doc) => Match.fromFirestore(doc))
        .toList();
    
    // 如果使用了備用查詢（沒有排序），手動按創建時間排序
    if (allMatches.isNotEmpty) {
      allMatches.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    
    // 將比賽分配到對應的賽程中
    for (final tournament in tournaments) {
      result[tournament] = allMatches
          .where((match) => match.tournamentId == tournament.id)
          .toList();
    }
    
    // 顯示索引創建提示
    print('注意：為了更好的性能，請創建 basic_info.tournamentId 和 timestamps.createdAt 的複合索引');
    print('索引創建鏈接：https://console.firebase.google.com/v1/r/project/sports-league-app-d25e2/firestore/indexes?');
    
    return result;
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
          // 添加單淘汰賽晉級相關字段
          if (match.nextMatchId != null) 'nextMatchId': match.nextMatchId,
          if (match.slotInNext != null) 'slotInNext': match.slotInNext,
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