import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/tournament.dart';

class TournamentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> saveTournament(Tournament tournament) async {
    try {
      print('正在保存賽程到 Firestore：${tournament.id}');
      
      await _firestore.collection('tournaments').doc(tournament.id).set({
        'id': tournament.id,
        'name': tournament.name,
        'type': tournament.type,
        'targetPoints': tournament.targetPoints,
        'matchMinutes': tournament.matchMinutes,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'active',
      });
      
      print('賽程保存成功！');
    } catch (e) {
      print('保存賽程時發生錯誤：$e');
      throw '保存賽程失敗：$e';
    }
  }

  Future<List<Tournament>> getAllTournaments() async {
    try {
      print('正在獲取所有賽程...');
      
      final snapshot = await _firestore
          .collection('tournaments')
          .orderBy('createdAt', descending: true)
          .get();

      final tournaments = snapshot.docs.map((doc) {
        final data = doc.data();
        return Tournament(
          id: data['id'],
          name: data['name'],
          type: data['type'],
          targetPoints: data['targetPoints'],
          matchMinutes: data['matchMinutes'],
          createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          status: data['status'] ?? 'active',
        );
      }).toList();

      print('成功獲取 ${tournaments.length} 個賽程');
      return tournaments;
    } catch (e) {
      print('獲取賽程列表時發生錯誤：$e');
      throw '獲取賽程列表失敗：$e';
    }
  }

  Future<List<Tournament>> getActiveTournaments() async {
    try {
      print('正在獲取進行中的賽程...');
      
      final snapshot = await _firestore
          .collection('tournaments')
          .where('status', isEqualTo: 'active')
          .orderBy('createdAt', descending: true)
          .get();

      final tournaments = snapshot.docs.map((doc) {
        final data = doc.data();
        return Tournament(
          id: data['id'],
          name: data['name'],
          type: data['type'],
          targetPoints: data['targetPoints'],
          matchMinutes: data['matchMinutes'],
          createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          status: data['status'] ?? 'active',
        );
      }).toList();

      print('成功獲取 ${tournaments.length} 個進行中的賽程');
      return tournaments;
    } catch (e) {
      print('獲取進行中賽程列表時發生錯誤：$e');
      throw '獲取進行中賽程列表失敗：$e';
    }
  }
}