import 'package:flutter/material.dart';
import '../match/create_match_page.dart';
import '../match/all_ongoing_matches_page.dart';
import '../match/match_selection_page.dart';
import '../match/match_history_page.dart';
import '../tournament/tournament_list_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            _buildMainButton(
              context,
              '賽程管理',
              Icons.add_chart,
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CreateMatchPage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            _buildMainButton(
              context,
              '單淘賽',
              Icons.list_alt,
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TournamentListPage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            _buildMainButton(
              context,
              '積分賽',
              Icons.sports_martial_arts,
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MatchSelectionPage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            _buildMainButton(
              context,
              '比賽紀錄',
              Icons.history,
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MatchHistoryPage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            _buildMainButton(
              context,
              '察看所有進行中比賽',
              Icons.sports_score,
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AllOngoingMatchesPage(),
                  ),
                );
              },
            ),
            // 移除重複的按鈕
          ],
        )
    );
  }

  Widget _buildMainButton(
    BuildContext context,
    String text,
    IconData icon,
    VoidCallback onPressed,
  ) {
    return SizedBox(
      width: 200,
      height: 60,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(
          text,
          style: const TextStyle(fontSize: 18),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }
}