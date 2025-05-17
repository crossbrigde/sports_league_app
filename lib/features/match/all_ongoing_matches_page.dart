import 'package:flutter/material.dart';
import '../../core/services/match_service.dart';
import 'models/match.dart';
import 'models/tournament.dart';
import 'match_scoring_page.dart';

class AllOngoingMatchesPage extends StatelessWidget {
  final _matchService = MatchService();

  AllOngoingMatchesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('所有進行中比賽'),
      ),
      body: StreamBuilder<List<Match>>(
        stream: _matchService.getAllOngoingMatches(),
        builder: (context, snapshot) {
          print('StreamBuilder 狀態 - ${snapshot.connectionState}');
          print('StreamBuilder 數據 - ${snapshot.data?.length ?? 0} 場比賽');

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            print('StreamBuilder 錯誤 - ${snapshot.error}');
            return Center(child: Text('錯誤：${snapshot.error}'));
          }

          final matches = snapshot.data ?? [];

          if (matches.isEmpty) {
            return const Center(child: Text('目前沒有進行中的比賽'));
          }

          return ListView.builder(
            itemCount: matches.length,
            itemBuilder: (context, index) {
              final match = matches[index];
              // 使用更直觀的卡片設計
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MatchScoringPage(
                          match: match,
                          tournament: Tournament(
                            id: match.tournamentId,
                            name: match.tournamentName,
                            type: 'regular',
                            createdAt: DateTime.now(),
                          ),
                        ),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '場次 ${match.matchNumber}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text('進行中', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // 裁判信息移到中間上方
                        if (match.refereeNumber.isNotEmpty)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: Text('裁判: ${match.refereeNumber}', 
                                  style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w500)),
                              ),
                            ),
                          ),
                        Row(
                          children: [
                            Expanded(
                              child: _buildPlayerInfo(match.redPlayer, Colors.red),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              child: Text('VS', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                            Expanded(
                              child: _buildPlayerInfo(match.bluePlayer, Colors.blue),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // 賽程名稱添加到中間下方
                        Center(
                          child: Container(
                            margin: const EdgeInsets.only(top: 4.0),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.blue.shade100),
                            ),
                            child: Text(match.tournamentName, 
                              style: TextStyle(color: Colors.blue.shade800, fontSize: 13)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
  
  // 新增輔助方法來構建選手信息
  Widget _buildPlayerInfo(String playerName, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(Icons.person, color: color),
          const SizedBox(height: 4),
          Text(
            playerName,
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}