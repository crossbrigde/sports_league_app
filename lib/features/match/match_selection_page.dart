import 'package:flutter/material.dart';
import '../../core/services/match_service.dart';
import '../../models/match.dart';
import 'models/tournament.dart';
import 'match_scoring_page.dart';
import 'match_setup_page.dart';

class MatchSelectionPage extends StatefulWidget {
  MatchSelectionPage({super.key});

  @override
  State<MatchSelectionPage> createState() => _MatchSelectionPageState();
}

class _MatchSelectionPageState extends State<MatchSelectionPage> {
  final _matchService = MatchService();
  bool _isLoading = true;
  Map<Tournament, List<Match>> _tournamentMatches = {};
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadActiveTournamentsWithMatches();
  }

  Future<void> _loadActiveTournamentsWithMatches() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final result = await _matchService.getActiveTournamentsWithMatches();
      
      setState(() {
        _tournamentMatches = result;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '載入賽程資料失敗：$e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('選擇賽程'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadActiveTournamentsWithMatches,
            tooltip: '重新載入',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(child: Text(_errorMessage!));
    }

    if (_tournamentMatches.isEmpty) {
      return const Center(child: Text('目前沒有進行中的賽程'));
    }

    return ListView.builder(
      itemCount: _tournamentMatches.length,
      itemBuilder: (context, index) {
        final tournament = _tournamentMatches.keys.elementAt(index);
        final matchList = _tournamentMatches[tournament] ?? [];

              // 排序：越新的比賽在上面
              matchList.sort((a, b) => b.createdAt.compareTo(a.createdAt));

              return Card(
                margin: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 賽程標題（可以點進去創建新比賽）
                    ListTile(
                      title: Text(
                        tournament.name,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      trailing: const Icon(Icons.add_circle_outline),
                      onTap: () {
                        // 導航到比賽設置頁面
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MatchSetupPage(
                              tournament: tournament,
                            ),
                          ),
                        ).then((_) => _loadActiveTournamentsWithMatches());
                      },
                    ),
                    // 最近的幾場比賽（最多顯示 5 場）
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: matchList.take(5).map((match) {
                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => MatchScoringPage(
                                    match: match,
                                    tournament: tournament,
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              width: 150, // 每張卡片寬度
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                children: [
                                  // 場次號碼置中顯示
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text('場次 ${match.matchNumber}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  // 紅方選手
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          match.redPlayer,
                                          style: TextStyle(
                                            fontWeight: match.winner == 'red' ? FontWeight.bold : FontWeight.normal,
                                            color: Colors.red,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                      if (match.winner == 'red') const Icon(Icons.check_circle, color: Colors.green, size: 14),
                                    ],
                                  ),
                                  // V.S. 圖示
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: const [
                                      Icon(Icons.sports_kabaddi, size: 16),
                                      SizedBox(width: 4),
                                      Text('V.S.', style: TextStyle(fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                  // 藍方選手
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          match.bluePlayer,
                                          style: TextStyle(
                                            fontWeight: match.winner == 'blue' ? FontWeight.bold : FontWeight.normal,
                                            color: Colors.blue,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                      if (match.winner == 'blue') const Icon(Icons.check_circle, color: Colors.green, size: 14),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
  }
}
