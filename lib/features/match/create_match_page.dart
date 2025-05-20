import 'package:flutter/material.dart';
import 'package:sports_league_app/features/match/models/tournament.dart';
import 'package:uuid/uuid.dart';
import 'services/tournament_service.dart';
import '../../features/tournament/services/tournament_bracket_service.dart';
import '../../features/tournament/tournament_detail_page.dart';

class CreateMatchPage extends StatefulWidget {
  const CreateMatchPage({super.key});

  @override
  State<CreateMatchPage> createState() => _CreateMatchPageState();
}

class _CreateMatchPageState extends State<CreateMatchPage> {
  final _tournamentService = TournamentService();
  final _bracketService = TournamentBracketService();
  final _formKey = GlobalKey<FormState>();
  String tournamentName = '';
  bool isPointTimeSystem = false;
  bool isTimeSystem = false;
  int targetPoints = 0;
  int matchMinutes = 0;
  bool isSingleElimination = false;
  int numPlayers = 8; // 預設參賽人數

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('建立賽程'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: '大賽名稱',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '請輸入大賽名稱';
                        }
                        return null;
                      },
                      onSaved: (value) {
                        tournamentName = value ?? '';
                      },
                    ),
                    const SizedBox(height: 20),
                    const Text('勝負制度', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    CheckboxListTile(
                      title: const Text('搶分計時制'),
                      value: isPointTimeSystem,
                      onChanged: (bool? value) {
                        setState(() {
                          isPointTimeSystem = value ?? false;
                          if (isPointTimeSystem) {
                            isTimeSystem = false;
                          }
                        });
                      },
                    ),
                    if (isPointTimeSystem) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                decoration: const InputDecoration(
                                  labelText: '搶幾分',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return '請輸入分數';
                                  }
                                  return null;
                                },
                                onSaved: (value) {
                                  targetPoints = int.tryParse(value ?? '') ?? 0;
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                decoration: const InputDecoration(
                                  labelText: '比賽分鐘數',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return '請輸入時間';
                                  }
                                  return null;
                                },
                                onSaved: (value) {
                                  matchMinutes = int.tryParse(value ?? '') ?? 0;
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    CheckboxListTile(
                      title: const Text('計時制'),
                      value: isTimeSystem,
                      onChanged: (bool? value) {
                        setState(() {
                          isTimeSystem = value ?? false;
                          if (isTimeSystem) {
                            isPointTimeSystem = false;
                          }
                        });
                      },
                    ),
                    if (isTimeSystem)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: TextFormField(
                          decoration: const InputDecoration(
                            labelText: '比賽分鐘數',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return '請輸入時間';
                            }
                            return null;
                          },
                          onSaved: (value) {
                            matchMinutes = int.tryParse(value ?? '') ?? 0;
                          },
                        ),
                      ),
                    const SizedBox(height: 20),
                    // 比賽場次選項已移除

                    const SizedBox(height: 20),
                    const Text('淘汰賽制', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    CheckboxListTile(
                      title: const Text('單淘汰賽'),
                      value: isSingleElimination,
                      onChanged: (bool? value) {
                        setState(() {
                          isSingleElimination = value ?? false;
                          // 移除對未定義變量的引用
                        });
                      },
                    ),
                    if (isSingleElimination) ...[                      
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('參賽人數', style: TextStyle(fontSize: 16)),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: Slider(
                                    value: numPlayers.toDouble(),
                                    min: 4,
                                    max: 32,
                                    divisions: 7,
                                    label: numPlayers.toString(),
                                    onChanged: (double value) {
                                      setState(() {
                                        numPlayers = value.toInt();
                                      });
                                    },
                                  ),
                                ),
                                SizedBox(width: 50, child: Text('$numPlayers 人', textAlign: TextAlign.center)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Center(
                      child: ElevatedButton(
                        onPressed: () async {
                          if (_formKey.currentState!.validate()) {
                            _formKey.currentState!.save();
                            
                            try {
                              print('正在創建賽程...');
                              String type;
                              if (isPointTimeSystem) {
                                type = 'point_time';
                              } else if (isTimeSystem) {
                                type = 'time';
                              } else if (isSingleElimination) {
                                type = 'single_elimination';
                              } else {
                                type = 'best_of_one';
                              }
                              
                              // 處理單淘汰賽
                              if (isSingleElimination) {
                                print('創建單淘汰賽，參賽人數：$numPlayers');
                                final tournament = await _bracketService.createSingleEliminationTournament(
                                  name: tournamentName,
                                  numPlayers: numPlayers,
                                  targetPoints: isPointTimeSystem ? targetPoints : null,
                                  matchMinutes: (isTimeSystem || isPointTimeSystem) ? matchMinutes : null,
                                );
                                
                                print('單淘汰賽創建成功！');
                                
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('單淘汰賽已創建')),
                                  );
                                  // 導航到賽程詳情頁面
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => TournamentDetailPage(
                                        tournamentId: tournament.id,
                                        tournamentName: tournament.name,
                                      ),
                                    ),
                                  );
                                }
                              } else {
                                // 處理一般賽程
                                final tournament = Tournament(
                                  id: const Uuid().v4(),
                                  name: tournamentName,
                                  type: type,
                                  targetPoints: isPointTimeSystem ? targetPoints : null,
                                  matchMinutes: (isTimeSystem || isPointTimeSystem) ? matchMinutes : null,
                                  createdAt: DateTime.now(),
                                  status: 'active',  // 添加狀態字段
                                );

                                print('準備保存賽程：${tournament.id}');
                                await _tournamentService.saveTournament(tournament);
                                print('賽程創建成功！');
                                
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('賽程已創建')),
                                  );
                                  Navigator.pop(context);
                                }
                              }
                            } catch (e) {
                              print('創建賽程時發生錯誤：$e');
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('創建賽程失敗：$e')),
                                );
                              }
                            }
                          }
                        },
                        child: const Text('創建賽程'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '進行中的賽程',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          _showEndTournamentDialog(context);
                        },
                        icon: const Icon(Icons.stop_circle_outlined),
                        label: const Text('結束賽程'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  FutureBuilder<List<Tournament>>(
                    future: _tournamentService.getActiveTournaments(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final tournaments = snapshot.data ?? [];
                      if (tournaments.isEmpty) {
                        return const Center(
                          child: Text('目前沒有進行中的賽程'),
                        );
                      }

                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: tournaments.length,
                        itemBuilder: (context, index) {
                          final tournament = tournaments[index];
                          return Card(
                            child: ListTile(
                              title: Text(tournament.name),
                              subtitle: Text(_buildTournamentInfo(tournament)),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _buildTournamentInfo(Tournament tournament) {
    final List<String> info = [];
    
    switch (tournament.type) {
      case 'point_time':
        if (tournament.targetPoints != null) {
          info.add('搶${tournament.targetPoints}分');
        }
        if (tournament.matchMinutes != null) {
          info.add('${tournament.matchMinutes}分鐘');
        }
        break;
      case 'time':
        if (tournament.matchMinutes != null) {
          info.add('計時${tournament.matchMinutes}分鐘');
        }
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
  
  // 顯示結束賽程的對話框
  void _showEndTournamentDialog(BuildContext context) async {
    final tournaments = await _tournamentService.getActiveTournaments();
    
    if (tournaments.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('目前沒有進行中的賽程')),
        );
      }
      return;
    }
    
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('選擇要結束的賽程'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: tournaments.length,
            itemBuilder: (context, index) {
              final tournament = tournaments[index];
              return ListTile(
                title: Text(tournament.name),
                subtitle: Text(_buildTournamentInfo(tournament)),
                onTap: () {
                  Navigator.pop(context);
                  _showConfirmEndTournamentDialog(context, tournament);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }
  
  // 顯示確認結束賽程的對話框
  void _showConfirmEndTournamentDialog(BuildContext context, Tournament tournament) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('確認結束賽程'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('確定要結束「${tournament.name}」賽程嗎？'),
            const SizedBox(height: 16),
            const Text('• 所有比賽將視為結束'),
            const Text('• 將無法再新增比賽至此賽程'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              try {
                Navigator.pop(context);
                await _tournamentService.updateTournamentStatus(tournament.id, 'ended');
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('已結束「${tournament.name}」賽程')),
                  );
                  // 重新整理頁面
                  setState(() {});
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('結束賽程失敗：$e')),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('結束賽程'),
          ),
        ],
      ),
    );
  }
}