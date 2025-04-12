import 'package:flutter/material.dart';
import '../match/match_setup_page.dart';
import '../match/ongoing_matches_page.dart';
import '../match/models/tournament.dart';

class TournamentDetailPage extends StatelessWidget {
  final String tournamentId;
  final String tournamentName;

  const TournamentDetailPage({
    super.key,
    required this.tournamentId,
    required this.tournamentName,
  });

  @override
  Widget build(BuildContext context) {
    final tournament = Tournament(
      id: tournamentId,
      name: tournamentName,
      type: 'regular',
      createdAt: DateTime.now(),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(tournamentName),
      ),
      body: Column(
        children: [
          // 上半部：進行中賽程
          Expanded(
            flex: 1,
            child: OngoingMatchesPage(tournamentId: tournamentId),  // 添加 tournamentId 參數
          ),
          // 下半部：比賽設置
          Expanded(
            flex: 1,
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '創建新比賽',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MatchSetupPage(
                              tournament: tournament,
                            ),
                          ),
                        );
                      },
                      child: const Text('設置新比賽'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}