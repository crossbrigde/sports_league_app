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
                    // 移除搶分計時制和計時制選項，保留空間以後可能加回來
                    // const Text('勝負制度', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    // 以下選項已移除，保留空間以後可能加回來
                    /*
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
                    if (isPointTimeSystem) ... [
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
                    */
                    
                    const SizedBox(height: 20),
                    const Text('賽制選擇', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    CheckboxListTile(
                      title: const Text('單淘汰賽'),
                      value: isSingleElimination,
                      onChanged: (bool? value) {
                        setState(() {
                          isSingleElimination = value ?? false;
                        });
                      },
                    ),
                    if (isSingleElimination) ...[  
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('參賽人數 (4-16人)'),
                            const SizedBox(height: 8),
                            TextFormField(
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                hintText: '請輸入4-16之間的數字',
                              ),
                              initialValue: numPlayers.toString(),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return '請輸入參賽人數';
                                }
                                final number = int.tryParse(value);
                                if (number == null) {
                                  return '請輸入有效的數字';
                                }
                                if (number < 4 || number > 16) {
                                  return '參賽人數必須在4到16人之間';
                                }
                                return null;
                              },
                              onSaved: (value) {
                                numPlayers = int.tryParse(value ?? '') ?? 8;
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () async {
                          if (_formKey.currentState!.validate()) {
                            _formKey.currentState!.save();
                            
                            try {
                              if (isSingleElimination) {
                                // 創建單淘汰賽
                                final tournament = await _bracketService.createSingleEliminationTournament(
                                  name: tournamentName,
                                  numPlayers: numPlayers,
                                  targetPoints: isPointTimeSystem ? targetPoints : null,
                                  matchMinutes: (isPointTimeSystem || isTimeSystem) ? matchMinutes : null,
                                );
                                
                                if (!mounted) return;
                                
                                // 顯示成功消息並提供選項
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('單淘汰賽創建成功！'),
                                    content: Text('賽程「$tournamentName」已成功創建'),
                                    actions: [
                                      TextButton(
                                        onPressed: () {
                                          Navigator.pop(context); // 關閉對話框
                                          Navigator.pop(context); // 返回上一頁
                                        },
                                        child: const Text('返回'),
                                      ),
                                      ElevatedButton(
                                        onPressed: () {
                                          Navigator.pop(context); // 關閉對話框
                                          Navigator.pushReplacement(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => TournamentDetailPage(
                                                tournamentId: tournament.id,
                                                tournamentName: tournament.name,
                                              ),
                                            ),
                                          );
                                        },
                                        child: const Text('進入賽程'),
                                      ),
                                    ],
                                  ),
                                );
                              } else {
                                // 創建常規賽程
                                final tournament = Tournament(
                                  id: const Uuid().v4(),
                                  name: tournamentName,
                                  type: 'regular',
                                  createdAt: DateTime.now(),
                                  targetPoints: isPointTimeSystem ? targetPoints : null,
                                  matchMinutes: (isPointTimeSystem || isTimeSystem) ? matchMinutes : null,
                                  status: 'ongoing',
                                );
                                
                                await _tournamentService.saveTournament(tournament);
                                
                                if (!mounted) return;
                                
                                // 顯示成功消息並提供選項
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('常規賽程創建成功！'),
                                    content: Text('賽程「$tournamentName」已成功創建'),
                                    actions: [
                                      TextButton(
                                        onPressed: () {
                                          Navigator.pop(context); // 關閉對話框
                                          Navigator.pop(context); // 返回上一頁
                                        },
                                        child: const Text('返回'),
                                      ),
                                      ElevatedButton(
                                        onPressed: () {
                                          Navigator.pop(context); // 關閉對話框
                                          Navigator.pushReplacement(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => TournamentDetailPage(
                                                tournamentId: tournament.id,
                                                tournamentName: tournament.name,
                                              ),
                                            ),
                                          );
                                        },
                                        child: const Text('進入賽程'),
                                      ),
                                    ],
                                  ),
                                );
                              }
                            } catch (e) {
                              // 顯示錯誤消息
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('創建賽程失敗: $e')),
                              );
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
          ],
        ),
      ),
    );
  }
}