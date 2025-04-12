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
    );
  }
}