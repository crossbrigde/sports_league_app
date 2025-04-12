import 'package:flutter/material.dart';
import '../../core/services/match_service.dart';
import 'models/match.dart';
import 'models/tournament.dart';  // Ensure this import is present
import 'match_scoring_page.dart';

class MatchSelectionPage extends StatelessWidget {
  final _matchService = MatchService();

  MatchSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('選擇賽程'),
      ),
      body: StreamBuilder<List<Match>>(
        stream: _matchService.getUnfinishedMatches(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('錯誤：${snapshot.error}'));
          }

          final matches = snapshot.data ?? [];

          if (matches.isEmpty) {
            return const Center(child: Text('目前沒有未完成的比賽'));
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
                          tournament: Tournament(  // Ensure this constructor is correct
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