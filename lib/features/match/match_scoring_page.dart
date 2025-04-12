import 'package:flutter/material.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'models/match.dart';
import 'models/tournament.dart';
// 移除這行未使用的導入
// import 'all_ongoing_matches_page.dart'; 

class MatchScoringPage extends StatefulWidget {
  final Match match;
  final Tournament tournament;

  const MatchScoringPage({
    super.key,
    required this.match,
    required this.tournament,
  });

  @override
  State<MatchScoringPage> createState() => _MatchScoringPageState();
}

class _MatchScoringPageState extends State<MatchScoringPage> {
  late final FirebaseFirestore _firestore;
  late Map<String, int> redScores;
  late Map<String, int> blueScores;
  bool _isMatchEnded = false;
  
  Map<String, int> tempRedPoints = {};
  Map<String, int> tempBluePoints = {};
  
  @override
  void initState() {
    super.initState();
    _firestore = FirebaseFirestore.instance;
    redScores = Map<String, int>.from(widget.match.redScores);
    blueScores = Map<String, int>.from(widget.match.blueScores);
    _isMatchEnded = widget.match.status == 'completed';
  }

  @override
  Widget build(BuildContext context) {
    final redTotal = redScores.values.fold(0, (sum, score) => sum + score);
    final blueTotal = blueScores.values.fold(0, (sum, score) => sum + score);

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.tournament.name} - ${widget.match.name}'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            onPressed: _showDetermineWinnerDialog,
            icon: const Icon(Icons.emoji_events_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildMatchInfo(),
          _buildScoreBoard(redTotal, blueTotal),
          const Spacer(),
          _buildJudgmentButton(),
          // 移除查看進行中比賽的按鈕
        ],
      ),
    );
  }

  Widget _buildMatchInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey.shade100,
      child: Column(
        children: [
          Text(
            widget.match.refereeNumber.isNotEmpty
                ? '裁判：${widget.match.refereeNumber}'
                : '裁判：未指定',
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Text(
                '紅方：${widget.match.redPlayer}',
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '藍方：${widget.match.bluePlayer}',
                style: const TextStyle(
                  color: Colors.blue,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildJudgmentButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ElevatedButton.icon(
        onPressed: _isMatchEnded ? null : _showJudgmentDialog,
        icon: const Icon(Icons.gavel),
        label: const Text('判定得分'),
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 56),
        ),
      ),
    );
  }

  // 移除以下未使用的方法：
  // - _showTimeUpDialog
  // - _showTargetPointsReachedDialog

  void _showJudgmentDialog() {
    // 打開對話框前先清空臨時得分
    tempRedPoints.clear();
    tempBluePoints.clear();
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('判定得分'),
          content: SizedBox(
            width: double.maxFinite,
            child: Row(
              children: [
                Expanded(
                  child: _buildBodyMap('red', setState),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildBodyMap('blue', setState),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                // 取消時也清空臨時得分
                tempRedPoints.clear();
                tempBluePoints.clear();
                Navigator.pop(context);
              },
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => _confirmJudgment(context),
              child: const Text('確認判定'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBodyMap(String player, StateSetter setState) {
    final color = player == 'red' ? Colors.red : Colors.blue;
    final points = player == 'red' ? tempBluePoints : tempRedPoints;
    final displayPoints = player == 'red' ? tempRedPoints : tempBluePoints;
    final totalPoints = displayPoints.values.fold(0, (sum, points) => sum + points);
    
    return Column(
      children: [
        Text(
          player == 'red' ? '紅方' : '藍方',
          style: TextStyle(color: color, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: 150,
          height: 300,
          child: Stack(
            children: [
              CustomPaint(
                size: const Size(150, 300),
                painter: BodyPainter(color: color.withAlpha(51)), // 0.2 * 255 ≈ 51
              ),
              _buildTouchableArea('head', '頭部', const Rect.fromLTWH(50, 0, 50, 50), points, setState),
              _buildTouchableArea('body', '軀幹', const Rect.fromLTWH(40, 50, 70, 100), points, setState),
              _buildTouchableArea('leftArm', '左手', const Rect.fromLTWH(0, 50, 40, 100), points, setState),
              _buildTouchableArea('rightArm', '右手', const Rect.fromLTWH(110, 50, 40, 100), points, setState),
              _buildTouchableArea('leftLeg', '左腳', const Rect.fromLTWH(40, 150, 35, 150), points, setState),
              _buildTouchableArea('rightLeg', '右腳', const Rect.fromLTWH(75, 150, 35, 150), points, setState),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (totalPoints > 0)
          Text(
            '+$totalPoints',
            style: TextStyle(
              color: color,
              fontSize: 72,  // 從 24 改為 72
              fontWeight: FontWeight.bold,
            ),
          ),
      ],
    );
  }

  Widget _buildTouchableArea(String part, String label, Rect rect, Map<String, int> points, StateSetter setState) {
    final score = points[part] ?? 0;
    return Positioned(
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height,
      child: GestureDetector(
        onTap: () {
          setState(() {
            points[part] = (score + 1) % 3;
          });
        },
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: Colors.black26,
              width: 1,
            ),
          ),
          child: Center(
            child: score > 0 ? Text(
              '+$score',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ) : null,
          ),
        ),
      ),
    );
  }

  void _confirmJudgment(BuildContext context) async {
    try {
      // 修正計分邏輯：被擊中方得分
      final redPoints = tempRedPoints.values.fold(0, (sum, points) => sum + points);  // 紅方被擊中的得分
      final bluePoints = tempBluePoints.values.fold(0, (sum, points) => sum + points);  // 藍方被擊中的得分

      print('準備更新得分 - 紅方: $redPoints, 藍方: $bluePoints');
      print('紅方擊中位置: $tempBluePoints');
      print('藍方擊中位置: $tempRedPoints');
      print('比賽ID: ${widget.match.id}');

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('確認得分'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('紅方得分：$redPoints'),
              const SizedBox(height: 8),
              _buildHitSummary('紅方擊中部位', tempBluePoints),
              const SizedBox(height: 16),
              Text('藍方得分：$bluePoints'),
              const SizedBox(height: 8),
              _buildHitSummary('藍方擊中部位', tempRedPoints),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('確認'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        // 創建本次判定的記錄，添加更多詳細信息
        Map<String, dynamic> redHitLocationsMap = {};
        Map<String, dynamic> blueHitLocationsMap = {};
        
        // 手動複製地圖內容，確保類型正確
        tempRedPoints.forEach((key, value) {
          if (value > 0) {
            redHitLocationsMap[key] = value;
          }
        });
        
        tempBluePoints.forEach((key, value) {
          if (value > 0) {
            blueHitLocationsMap[key] = value;
          }
        });
        
        final judgmentRecord = {
          'timestamp': DateTime.now().toIso8601String(),
          'redPoints': redPoints,
          'bluePoints': bluePoints,
          'redHitLocations': redHitLocationsMap,
          'blueHitLocations': blueHitLocationsMap,
          'referee': widget.match.refereeNumber,
          'currentSet': widget.match.currentSet,
        };
        
        print('判定記錄: $judgmentRecord');
        
        // 更新本地狀態 - 修正：只更新總分，不重複更新各部位得分
        setState(() {
          // 更新總分 - 紅方得分來自藍方擊中，藍方得分來自紅方擊中
          redScores['total'] = (redScores['total'] ?? 0) + redPoints;
          blueScores['total'] = (blueScores['total'] ?? 0) + bluePoints;
          
          // 不再更新各部位得分，避免重複計算
          // 清空臨時得分
          tempRedPoints.clear();
          tempBluePoints.clear();
        });

        // 關閉判定對話框
        if (mounted) {
          Navigator.pop(context);
        }

        // 嘗試更新 Firebase，最多重試 3 次
        int retryCount = 0;
        bool updateSuccess = false;
        while (retryCount < 3 && !updateSuccess) {
          try {
            print('嘗試更新 Firebase (嘗試 ${retryCount + 1}/3)');
            print('更新數據: redScores=$redScores, blueScores=$blueScores');
            
            // 檢查 match.id 是否有效
            if (widget.match.id.isEmpty) {
              throw Exception('比賽ID無效: ${widget.match.id}');
            }
            
            // 創建更新數據對象 - 根據新的數據結構
            final updateData = {
              'scores.redScores': redScores,
              'scores.blueScores': blueScores,
              'timestamps.lastUpdated': FieldValue.serverTimestamp(),
              'judgments': FieldValue.arrayUnion([judgmentRecord]),
              // 添加當前局的得分記錄
              'sets.setResults.${widget.match.currentSet}': {
                'redScore': redScores['total'],
                'blueScore': blueScores['total'],
                'lastUpdated': FieldValue.serverTimestamp(),
              }
            };
            
            // 一次性更新所有數據
            await _firestore.collection('matches').doc(widget.match.id).update(updateData);
            print('成功更新所有數據到 Firebase');
            
            updateSuccess = true;
          } catch (e) {
            print('更新 Firebase 失敗，錯誤：$e，重試次數：${retryCount + 1}');
            retryCount++;
            if (retryCount < 3) {
              // 等待一秒後重試
              await Future.delayed(const Duration(seconds: 1));
            }
          }
        }

        if (!updateSuccess && mounted) {
          // 如果更新失敗，顯示錯誤對話框
          final retry = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text('更新失敗'),
              content: const Text('無法將得分更新到伺服器，是否重試？\n\n本地記分已保存。'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('稍後重試'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('立即重試'),
                ),
              ],
            ),
          );

          if (retry == true && mounted) {
            // 用戶選擇立即重試
            _confirmJudgment(context);
            return;
          }
        }

        // 無論是否更新成功，都清空臨時得分
        setState(() {
          tempRedPoints.clear();
          tempBluePoints.clear();
        });
      }
    } catch (e) {
      print('捕獲到錯誤：$e');
      // 確保 widget 仍然掛載
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('更新分數時發生錯誤：$e'),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: '重試',
              onPressed: () => _confirmJudgment(context),
            ),
          ),
        );
      }
    }
  }

  Widget _buildHitSummary(String title, Map<String, int> points) {
    final hits = points.entries.where((e) => e.value > 0).map((e) {
      final label = switch (e.key) {
        'head' => '頭部',
        'body' => '軀幹',
        'leftArm' => '左手',
        'rightArm' => '右手',
        'leftLeg' => '左腳',
        'rightLeg' => '右腳',
        _ => e.key,
      };
      return '$label (+${e.value})';
    }).join('、');
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 14, color: Colors.grey)),
        Text(hits.isEmpty ? '無' : hits),
      ],
    );
  }

  void _showDetermineWinnerDialog() async {
    final redTotal = redScores.values.fold(0, (sum, score) => sum + score);
    final blueTotal = blueScores.values.fold(0, (sum, score) => sum + score);
      
      // 先詢問是否依分數判定
      final useScores = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('判定勝負'),
          content: Text('紅方：$redTotal 分\n藍方：$blueTotal 分\n\n是否依分數判定勝負？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('否'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('是'),
            ),
          ],
        ),
      );
  
      if (!mounted) return;
  
      if (useScores == true) {
        // 依分數判定
        String winner;
        String reason = '依分數判定';
        if (redTotal > blueTotal) {
          winner = 'red';
        } else if (blueTotal > redTotal) {
          winner = 'blue';
        } else {
          // 平分時需要選擇勝方
          final result = await _showManualWinnerSelection('平分，請選擇勝方');
          if (result == null) return;
          winner = result.winner;
          reason = result.reason;
        }
        _updateMatchResult(winner, reason);
      } else {
        // 手動選擇勝方
        final result = await _showManualWinnerSelection('請選擇勝方');
        if (result != null) {
          _updateMatchResult(result.winner, result.reason);
        }
      }
    }

    Future<_WinnerResult?> _showManualWinnerSelection(String title) async {
      String? reason;
      final winner = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text('紅方：${widget.match.redPlayer}'),
                tileColor: Colors.red.withAlpha(51),
                onTap: () => Navigator.pop(context, 'red'),
              ),
              const SizedBox(height: 8),
              ListTile(
                title: Text('藍方：${widget.match.bluePlayer}'),
                tileColor: Colors.blue.withAlpha(51),
                onTap: () => Navigator.pop(context, 'blue'),
              ),
            ],
          ),
        ),
      );
  
      if (winner != null && mounted) {
        // 輸入判定原因
        final textController = TextEditingController();
        reason = await showDialog<String>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('請輸入判定原因'),
            content: TextField(
              controller: textController,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: '例：技術優勢、違規判負等',
              ),
              onSubmitted: (value) => Navigator.pop(context, value),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, textController.text),
                child: const Text('確認'),
              ),
            ],
          ),
        );
        textController.dispose();
      }
  
      if (winner != null && reason != null) {
        return _WinnerResult(winner, reason);
      }
      return null;
    }

    Future<void> _updateMatchResult(String winner, String reason) async {
      try {
        await _firestore.collection('matches').doc(widget.match.id).update({
          'basic_info.winner': winner,
          'basic_info.winReason': reason,
          'basic_info.status': 'completed',
          'timestamps.completedAt': FieldValue.serverTimestamp(),
        });
  
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('更新比賽結果失敗：$e')),
          );
        }
      }
    }
  }

  class _WinnerResult {
    final String winner;
    final String reason;
  
    _WinnerResult(this.winner, this.reason);
  }

  Widget _buildScoreBoard(int redTotal, int blueTotal) {
      return Container(
        padding: const EdgeInsets.all(24),
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withAlpha(77), // 0.3 * 255 ≈ 77
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Column(
              children: [
                const Text('紅方得分', style: TextStyle(color: Colors.red)),
                const SizedBox(height: 8),
                Text(
                  '$redTotal',
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 240,  // 從 48 改為 240
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Container(
              height: 240,  // 調整分隔線高度以配合字體
              width: 2,
              color: Colors.grey.shade400,
            ),
            Column(
              children: [
                const Text('藍方得分', style: TextStyle(color: Colors.blue)),
                const SizedBox(height: 8),
                Text(
                  '$blueTotal',
                  style: const TextStyle(
                    color: Colors.blue,
                    fontSize: 240,  // 從 48 改為 240
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

class BodyPainter extends CustomPainter {
  final Color color;

  BodyPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Draw head
    canvas.drawOval(
      Rect.fromLTWH(size.width * 0.33, 0, size.width * 0.33, size.height * 0.17),
      paint,
    );
    
    // Draw body
    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.27, size.height * 0.17, size.width * 0.46, size.height * 0.33),
      paint,
    );
    
    // Draw arms
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.17, size.width * 0.27, size.height * 0.33),
      paint,
    );
    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.73, size.height * 0.17, size.width * 0.27, size.height * 0.33),
      paint,
    );
    
    // Draw legs
    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.27, size.height * 0.5, size.width * 0.23, size.height * 0.5),
      paint,
    );
    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.5, size.height * 0.5, size.width * 0.23, size.height * 0.5),
      paint,
    );
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
} // Add this missing closing brace
