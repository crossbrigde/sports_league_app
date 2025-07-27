import 'package:flutter/material.dart';
import '../../core/services/match_service.dart';
import '../../core/models/match.dart';
import '../../core/models/tournament.dart';
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
    _loadRegularTournamentsWithMatches(); // 修改方法名
  }

  // 修改為只載入 regular 類型的賽程
  Future<void> _loadRegularTournamentsWithMatches() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // 載入所有活躍賽程
      final allTournamentMatches = await _matchService.getActiveTournamentsWithMatches();
      
      print('載入到 ${allTournamentMatches.length} 個活躍賽程'); // 添加調試
      
      // 過濾出 type 為 "regular" 的賽程
      final regularTournamentMatches = <Tournament, List<Match>>{};
      
      allTournamentMatches.forEach((tournament, matches) {
        print('賽程: ${tournament.name}, 類型: ${tournament.type}, 狀態: ${tournament.status}'); // 添加調試
        if (tournament.type == 'regular') {
          regularTournamentMatches[tournament] = matches;
          print('找到積分賽: ${tournament.name}'); // 添加調試
        }
      });
      
      print('過濾後找到 ${regularTournamentMatches.length} 個積分賽'); // 添加調試
      
      setState(() {
        _tournamentMatches = regularTournamentMatches;
        _isLoading = false;
      });
    } catch (e) {
      print('載入錯誤: $e'); // 添加調試
      setState(() {
        _errorMessage = '載入積分賽資料失敗：$e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('積分賽選擇'), // 修改標題
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRegularTournamentsWithMatches, // 修改方法名
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
      return const Center(child: Text('目前沒有進行中的積分賽')); // 修改提示文字
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
                subtitle: Text('包含 ${matchList.length} 場比賽'), // 顯示比賽數量
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
                  ).then((_) => _loadRegularTournamentsWithMatches());
                },
              ),
              // 顯示所有比賽（不限制數量）
              if (matchList.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: matchList.map((match) {
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
              if (matchList.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('此賽程尚無比賽，點擊上方按鈕新增比賽'),
                ),
            ],
          ),
        );
      },
    );
  }
}
