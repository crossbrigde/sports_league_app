import 'package:flutter/material.dart';
import 'package:sports_league_app/features/match/models/tournament.dart';
import 'package:uuid/uuid.dart';
import 'services/tournament_service.dart';

class CreateMatchPage extends StatefulWidget {
  const CreateMatchPage({super.key});

  @override
  State<CreateMatchPage> createState() => _CreateMatchPageState();
}

class _CreateMatchPageState extends State<CreateMatchPage> {
  final _tournamentService = TournamentService();
  final _formKey = GlobalKey<FormState>();
  String tournamentName = '';
  bool isPointTimeSystem = false;
  bool isTimeSystem = false;
  int targetPoints = 0;
  int matchMinutes = 0;
  bool isBestOfOne = false;
  bool isBestOfThree = false;
  bool isBestOfFive = false;

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
                    const Text('比賽場次', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    CheckboxListTile(
                      title: const Text('一場決勝'),
                      value: isBestOfOne,
                      onChanged: (bool? value) {
                        setState(() {
                          isBestOfOne = value ?? false;
                          if (isBestOfOne) {
                            isBestOfThree = false;
                            isBestOfFive = false;
                          }
                        });
                      },
                    ),
                    CheckboxListTile(
                      title: const Text('三戰兩勝'),
                      value: isBestOfThree,
                      onChanged: (bool? value) {
                        setState(() {
                          isBestOfThree = value ?? false;
                          if (isBestOfThree) {
                            isBestOfOne = false;
                            isBestOfFive = false;
                          }
                        });
                      },
                    ),
                    CheckboxListTile(
                      title: const Text('五戰三勝'),
                      value: isBestOfFive,
                      onChanged: (bool? value) {
                        setState(() {
                          isBestOfFive = value ?? false;
                          if (isBestOfFive) {
                            isBestOfOne = false;
                            isBestOfThree = false;
                          }
                        });
                      },
                    ),
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
                              } else if (isBestOfThree) {
                                type = 'best_of_three';
                              } else if (isBestOfFive) {
                                type = 'best_of_five';
                              } else {
                                type = 'best_of_one';
                              }
                              
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
                  const Text(
                    '進行中的賽程',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
}