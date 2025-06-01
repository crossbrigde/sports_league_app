import 'package:flutter/material.dart';
import '../../core/models/match.dart';

class MatchStatisticsPage extends StatelessWidget {
  final List<Match> matches;
  final String tournamentName;

  const MatchStatisticsPage({
    super.key,
    required this.matches,
    required this.tournamentName,
  });

  @override
  Widget build(BuildContext context) {
    // 計算統計數據
    final statistics = _calculateStatistics();

    return Scaffold(
      appBar: AppBar(
        title: Text('$tournamentName 統計'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatisticsCard(
              context,
              '最常被打部位',
              statistics['mostHitPosition'] as Map<String, dynamic>,
              icon: Icons.accessibility_new,
            ),
            const SizedBox(height: 16),
            _buildPlayersWithAllLimbsHitCard(
              context,
              statistics['playersHitAllLimbs'] as List<String>,
            ),
            const SizedBox(height: 16),
            _buildLeastPointsLostCard(
              context,
              statistics['leastPointsLostPlayers'] as List<Map<String, dynamic>>,
            ),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _calculateStatistics() {
    print('開始計算統計數據，比賽數量: ${matches.length}');
    
    // 初始化統計數據 - 修正部位名稱以匹配實際數據格式
    Map<String, int> positionHits = {
      'head': 0,
      'body': 0,
      'leftHand': 0,  // 修正：使用leftHand而不是leftArm
      'rightHand': 0, // 修正：使用rightHand而不是rightArm
      'leftLeg': 0,
      'rightLeg': 0,
    };
    
    // 玩家失分記錄
    Map<String, List<int>> playerPointsLost = {};
    
    // 在單場比賽中打中對手四肢的選手
    List<String> playersHitAllLimbs = [];

    // 遍歷所有比賽的判斷記錄
    for (var match in matches) {
      print('處理比賽: ${match.name}, 紅方: ${match.redPlayer}, 藍方: ${match.bluePlayer}');
      print('比賽狀態: ${match.status}, 判斷記錄數量: ${match.judgments.length}');
      print('紅方總分: ${match.getRedTotal()}, 藍方總分: ${match.getBlueTotal()}');
      // 初始化玩家記錄
      if (!playerPointsLost.containsKey(match.redPlayer)) {
        playerPointsLost[match.redPlayer] = [];
      }
      if (!playerPointsLost.containsKey(match.bluePlayer)) {
        playerPointsLost[match.bluePlayer] = [];
      }

      // 記錄失分 - 使用Match模型的方法獲取正確的總分
      playerPointsLost[match.redPlayer]!.add(match.getBlueTotal());
      playerPointsLost[match.bluePlayer]!.add(match.getRedTotal());
      
      // 單場比賽中玩家打中對手的部位記錄
      Map<String, Set<String>> matchPlayerHitPositions = {
        match.redPlayer: {},
        match.bluePlayer: {},
      };

      // 分析判斷記錄
      for (var judgment in match.judgments) {
        print('處理判斷記錄: $judgment');
        
        // 處理第一種格式：使用 position 和 player
        final position = judgment['position'] as String?;
        final player = judgment['player'] as String?;
        final points = judgment['points'] as int? ?? 0;

        if (position != null && points > 0) {
          print('第一種格式命中: position=$position, player=$player, points=$points');
          // 增加部位命中計數
          positionHits[position] = (positionHits[position] ?? 0) + 1;

          // 記錄玩家在本場比賽中打中對手的部位
          if (player == 'red') {
            matchPlayerHitPositions[match.redPlayer]!.add(position);
          } else if (player == 'blue') {
            matchPlayerHitPositions[match.bluePlayer]!.add(position);
          }
        }
        
        // 處理第二種格式：使用 redHitLocations 和 blueHitLocations
        final redHitLocations = judgment['redHitLocations'] as Map<String, dynamic>?;
        final blueHitLocations = judgment['blueHitLocations'] as Map<String, dynamic>?;
        
        if (redHitLocations != null) {
          print('紅方命中位置: $redHitLocations');
          redHitLocations.forEach((position, value) {
            if (value is int && value > 0 && positionHits.containsKey(position)) {
              print('紅方命中 $position: $value 次');
              positionHits[position] = (positionHits[position] ?? 0) + 1;
              matchPlayerHitPositions[match.redPlayer]!.add(position);
            }
          });
        }
        
        if (blueHitLocations != null) {
          print('藍方命中位置: $blueHitLocations');
          blueHitLocations.forEach((position, value) {
            if (value is int && value > 0 && positionHits.containsKey(position)) {
              print('藍方命中 $position: $value 次');
              positionHits[position] = (positionHits[position] ?? 0) + 1;
              matchPlayerHitPositions[match.bluePlayer]!.add(position);
            }
          });
        }
        
        // 處理第三種格式：使用 redHits 和 blueHits
        final redHits = judgment['redHits'] as Map<String, dynamic>?;
        final blueHits = judgment['blueHits'] as Map<String, dynamic>?;
        
        if (redHits != null) {
          redHits.forEach((position, value) {
            if (value is int && value > 0 && positionHits.containsKey(position)) {
              positionHits[position] = (positionHits[position] ?? 0) + 1;
              matchPlayerHitPositions[match.redPlayer]!.add(position);
            }
          });
        }
        
        if (blueHits != null) {
          blueHits.forEach((position, value) {
            if (value is int && value > 0 && positionHits.containsKey(position)) {
              positionHits[position] = (positionHits[position] ?? 0) + 1;
              matchPlayerHitPositions[match.bluePlayer]!.add(position);
            }
          });
        }
      }
      
      // 檢查在這場比賽中是否有選手打中對手的四肢 - 修正部位名稱
      matchPlayerHitPositions.forEach((player, positions) {
        if (positions.contains('leftHand') &&   // 修正：使用leftHand
            positions.contains('rightHand') &&  // 修正：使用rightHand
            positions.contains('leftLeg') &&
            positions.contains('rightLeg')) {
          if (!playersHitAllLimbs.contains(player)) {
            playersHitAllLimbs.add(player);
          }
        }
      });
    }

    // 找出最常被打的部位
    String mostHitPosition = '';
    int maxHits = 0;
    positionHits.forEach((position, hits) {
      if (hits > maxHits) {
        mostHitPosition = position;
        maxHits = hits;
      }
    });

    // 轉換部位名稱為中文 - 修正部位名稱映射
    final positionNameMap = {
      'head': '頭部',
      'body': '身體',
      'leftHand': '左手',  // 修正：使用leftHand
      'rightHand': '右手', // 修正：使用rightHand
      'leftLeg': '左腳',
      'rightLeg': '右腳',
    };

    // 計算平均失分最少的選手
    List<Map<String, dynamic>> leastPointsLostPlayers = [];
    Map<String, double> averagePointsLost = {};

    playerPointsLost.forEach((player, points) {
      if (points.isNotEmpty) {
        double average = points.reduce((a, b) => a + b) / points.length;
        averagePointsLost[player] = average;
      }
    });

    // 排序並取前三名
    var sortedPlayers = averagePointsLost.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    for (var i = 0; i < sortedPlayers.length && i < 3; i++) {
      leastPointsLostPlayers.add({
        'name': sortedPlayers[i].key,
        'average': sortedPlayers[i].value,
      });
    }

    print('統計計算完成:');
    print('部位命中統計: $positionHits');
    print('最常被打部位: $mostHitPosition ($maxHits 次)');
    print('打中四肢的選手: $playersHitAllLimbs');
    print('平均失分統計: $averagePointsLost');
    print('失分最少選手: $leastPointsLostPlayers');
    
    return {
      'mostHitPosition': {
        'position': mostHitPosition,
        'positionName': positionNameMap[mostHitPosition] ?? mostHitPosition,
        'count': maxHits,
      },
      'playersHitAllLimbs': playersHitAllLimbs,
      'leastPointsLostPlayers': leastPointsLostPlayers,
    };
  }

  Widget _buildStatisticsCard(BuildContext context, String title, Map<String, dynamic> data, {IconData? icon}) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) Icon(icon, color: Theme.of(context).primaryColor),
                if (icon != null) const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),
            Center(
              child: Column(
                children: [
                  Text(
                    data['positionName'],
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '共被打中 ${data['count']} 次',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayersWithAllLimbsHitCard(BuildContext context, List<String> players) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.sports_kabaddi, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  '單場比賽中有打中對手四肢的選手',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),
            players.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('沒有選手在單場比賽中打中對手四肢'),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: players.length,
                    itemBuilder: (context, index) {
                      return ListTile(
                        leading: const Icon(Icons.person),
                        title: Text(players[index]),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
    }
  
  Widget _buildLeastPointsLostCard(BuildContext context, List<Map<String, dynamic>> players) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.shield, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  '平均失分最少的選手',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),
            players.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('沒有足夠數據'),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: players.length,
                    itemBuilder: (context, index) {
                      final player = players[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(context).primaryColor,
                          child: Text('${index + 1}'),
                        ),
                        title: Text(player['name']),
                        subtitle: Text('平均失分: ${player['average'].toStringAsFixed(1)}'),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }
}