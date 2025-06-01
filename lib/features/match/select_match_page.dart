import 'package:flutter/material.dart';
import 'package:sports_league_app/core/models/tournament.dart';
import 'package:sports_league_app/core/services/tournament_service.dart';
import 'package:sports_league_app/features/match/match_setup_page.dart';  // 添加這行

class SelectMatchPage extends StatefulWidget {
  const SelectMatchPage({super.key});

  @override
  State<SelectMatchPage> createState() => _SelectMatchPageState();
}

class _SelectMatchPageState extends State<SelectMatchPage> {
  final _tournamentService = TournamentService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('進行比賽'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: FutureBuilder<List<Tournament>>(
        future: _tournamentService.getActiveTournaments(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('錯誤：${snapshot.error}'));
          }

          final tournaments = snapshot.data ?? [];

          if (tournaments.isEmpty) {
            return const Center(child: Text('目前沒有進行中的賽程'));
          }

          return ListView.builder(
            itemCount: tournaments.length,
            itemBuilder: (context, index) {
              final tournament = tournaments[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(tournament.name),
                  subtitle: Text(_buildTournamentInfo(tournament)),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MatchSetupPage(tournament: tournament),
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

  String _buildTournamentInfo(Tournament tournament) {
    final List<String> info = [];
    
    switch (tournament.type) {
      case 'point_time':
        info.add('搶${tournament.targetPoints}分');
        info.add('${tournament.matchMinutes}分鐘');
        break;
      case 'time':
        info.add('計時${tournament.matchMinutes}分鐘');
        break;
      case 'best_of_one':
        info.add('一場決勝');
        break;
      case 'best_of_three':
        info.add('三戰兩勝');
        break;
      case 'best_of_five':
        info.add('五戰三勝');
        break;
    }

    return info.join(' • ');
  }
}