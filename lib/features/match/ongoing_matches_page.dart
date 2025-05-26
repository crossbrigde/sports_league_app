import 'package:flutter/material.dart';
// import '../../core/models/match.dart';  // Remove this
import '../../core/services/match_service.dart';
import 'match_scoring_page.dart';
import 'models/tournament.dart';
import '../../models/match.dart';

class OngoingMatchesPage extends StatelessWidget {
  final String tournamentId;
  final _matchService = MatchService();

  OngoingMatchesPage({
    super.key,
    required this.tournamentId,
  }) {
    print('OngoingMatchesPage 初始化 - tournamentId: $tournamentId');  // 添加調試輸出
  }

  @override
  Widget build(BuildContext context) {
    print('OngoingMatchesPage build - tournamentId: $tournamentId');  // 添加調試輸出
    
    return Column(  // 移除 Scaffold，因為這個頁面是嵌入在其他頁面中的
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            '進行中的比賽',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        Expanded(
          child: StreamBuilder<List<Match>>(
            stream: _matchService.getOngoingMatches(tournamentId),
            builder: (context, snapshot) {
              print('StreamBuilder 狀態 - ${snapshot.connectionState}');
              print('StreamBuilder 數據 - ${snapshot.data?.length ?? 0} 場比賽');

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                print('StreamBuilder 錯誤 - ${snapshot.error}');  // 添加調試輸出
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
                  return Card(
                    margin: const EdgeInsets.all(8),
                    child: ListTile(
                      title: Text('${match.name} - 場次 ${match.matchNumber}'),
                      subtitle: Text('${match.redPlayer} vs ${match.bluePlayer}'),
                      trailing: const Icon(Icons.sports_kabaddi),
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
                                targetPoints: null,  // 添加這個參數
                                matchMinutes: null,  // 添加這個參數
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
