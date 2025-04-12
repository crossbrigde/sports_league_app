import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'models/match.dart';

class MatchDetailPage extends StatelessWidget {
  final Match match;
  
  const MatchDetailPage({super.key, required this.match});

  @override
  Widget build(BuildContext context) {
    // 獲取比賽結果
    final redTotal = match.redScores['total'] ?? 0;
    final blueTotal = match.blueScores['total'] ?? 0;
    
    // 確定勝者
    String winnerName = '';
    Color winnerColor = Colors.black;
    String winReason = match.winReason ?? '依分數判定';
    
    if (match.winner == 'red') {
      winnerName = match.redPlayer;
      winnerColor = Colors.red;
    } else if (match.winner == 'blue') {
      winnerName = match.bluePlayer;
      winnerColor = Colors.blue;
    } else {
      winnerName = '平局';
      winReason = '同分';
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('比賽詳情'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMatchHeader(context),
            const Divider(height: 32),
            _buildScoreSection(context, redTotal, blueTotal),
            const Divider(height: 32),
            _buildWinnerSection(context, winnerName, winnerColor, winReason),
            const Divider(height: 32),
            _buildJudgmentsSection(context),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchHeader(BuildContext context) {
    final dateFormat = DateFormat('yyyy/MM/dd HH:mm');
    final startTime = match.startedAt != null 
        ? dateFormat.format(match.startedAt!) 
        : '未記錄';
    final endTime = match.completedAt != null 
        ? dateFormat.format(match.completedAt!) 
        : '未記錄';
    
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              match.name,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text('賽事: ${match.tournamentName}'),
            Text('場次: ${match.matchNumber}'),
            Text('裁判: ${match.refereeNumber}'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '紅方: ${match.redPlayer}',
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    '藍方: ${match.bluePlayer}',
                    style: const TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('開始時間: $startTime'),
            Text('結束時間: $endTime'),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreSection(BuildContext context, int redTotal, int blueTotal) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '比分',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Column(
                  children: [
                    const Text(
                      '紅方',
                      style: TextStyle(color: Colors.red),
                    ),
                    Text(
                      '$redTotal',
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 32),
                const Text(
                  ':',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 32),
                Column(
                  children: [
                    const Text(
                      '藍方',
                      style: TextStyle(color: Colors.blue),
                    ),
                    Text(
                      '$blueTotal',
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWinnerSection(BuildContext context, String winnerName, Color winnerColor, String winReason) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '比賽結果',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Center(
              child: Column(
                children: [
                  const Text('勝者'),
                  Text(
                    winnerName,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: winnerColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('原因: $winReason'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJudgmentsSection(BuildContext context) {
    if (match.judgments.isEmpty) {
      return const Card(
        elevation: 2,
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(
            child: Text('沒有判定記錄'),
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '判定記錄',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: match.judgments.length,
              itemBuilder: (context, index) {
                final judgment = match.judgments[index];
                final timestamp = judgment['timestamp'] != null 
                    ? DateTime.parse(judgment['timestamp'].toString())
                    : DateTime.now();
                final dateFormat = DateFormat('HH:mm:ss');
                final timeString = dateFormat.format(timestamp);
                
                final redPoints = judgment['redPoints'] ?? 0;
                final bluePoints = judgment['bluePoints'] ?? 0;
                
                final redHitLocations = judgment['redHitLocations'] as Map<String, dynamic>? ?? {};
                final blueHitLocations = judgment['blueHitLocations'] as Map<String, dynamic>? ?? {};
                
                return ExpansionTile(
                  title: Text('第${_getChineseNumber(index + 1)}擊 ($timeString)'),
                  subtitle: Text('紅方 +$redPoints, 藍方 +$bluePoints'),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '紅方擊中部位:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                          _buildHitLocations(redHitLocations),
                          const SizedBox(height: 8),
                          const Text(
                            '藍方擊中部位:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                          _buildHitLocations(blueHitLocations),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHitLocations(Map<String, dynamic> hitLocations) {
    if (hitLocations.isEmpty) {
      return const Text('無');
    }

    final List<Widget> items = [];
    
    hitLocations.forEach((key, value) {
      final label = switch (key) {
        'head' => '頭部',
        'body' => '軀幹',
        'leftArm' => '左手',
        'rightArm' => '右手',
        'leftLeg' => '左腳',
        'rightLeg' => '右腳',
        _ => key,
      };
      
      items.add(
        Chip(
          label: Text('$label (+$value)'),
          backgroundColor: Colors.grey.shade200,
        ),
      );
    });
    
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items,
    );
  }
  // 在類的最後添加這個方法
  String _getChineseNumber(int number) {
    const chineseNumbers = ['一', '二', '三', '四', '五', '六', '七', '八', '九', '十'];
    if (number <= 10) {
      return chineseNumbers[number - 1];
    } else if (number <= 19) {
      return '十${chineseNumbers[number - 11]}';
    } else {
      final tens = number ~/ 10;
      final ones = number % 10;
      if (ones == 0) {
        return '${chineseNumbers[tens - 1]}十';
      } else {
        return '${chineseNumbers[tens - 1]}十${chineseNumbers[ones - 1]}';
      }
    }
  }
}