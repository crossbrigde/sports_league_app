import 'package:flutter/material.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
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
  late final DatabaseReference _realtimeDb;
  late Map<String, int> redScores;
  late Map<String, int> blueScores;
  bool _isMatchEnded = false;
  
  Map<String, int> tempRedPoints = {};
  Map<String, int> tempBluePoints = {};
  
  @override
  void initState() {
    super.initState();
    _firestore = FirebaseFirestore.instance;
    _realtimeDb = FirebaseDatabase.instance.ref();
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
          _buildScoreBoard(context, redTotal, blueTotal),
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
    
    // 清空Realtime Database中的臨時得分
    _realtimeDb.child('temp_scores').child(widget.match.id).set(null);
    
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
                  child: _buildBodyMap('red', setState, context),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildBodyMap('blue', setState, context),
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
                // 清空Realtime Database中的臨時得分
                _realtimeDb.child('temp_scores').child(widget.match.id).set(null);
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

  Widget _buildBodyMap(String player, StateSetter setState, BuildContext context) {
    final color = player == 'red' ? Colors.red : Colors.blue;
    final points = player == 'red' ? tempBluePoints : tempRedPoints;
    final displayPoints = player == 'red' ? tempRedPoints : tempBluePoints;
    final totalPoints = displayPoints.values.fold(0, (sum, points) => sum + points);
    
    // 獲取屏幕尺寸
    final screenWidth = MediaQuery.of(context).size.width;
    final bodyWidth = screenWidth * 0.35; // 人形寬度為屏幕寬度的35%
    final bodyHeight = bodyWidth * 2; // 人形高度為寬度的2倍，保持比例
    
    return Column(
      children: [
        Text(
          player == 'red' ? '紅方' : '藍方',
          style: TextStyle(color: color, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        // 使用SingleChildScrollView包裹Stack，解決溢出問題
        SingleChildScrollView(
          child: SizedBox(
            width: bodyWidth,
            height: bodyHeight * 1.25, // 稍微減小高度比例，從1.3降到1.25
            child: Stack(
              children: [
                CustomPaint(
                  size: Size(bodyWidth, bodyHeight),
                  painter: BodyPainter(color: color.withAlpha(51)), // 0.2 * 255 ≈ 51
                ),
                _buildTouchableArea('head', '頭部', Rect.fromLTWH(bodyWidth * 0.33, 0, bodyWidth * 0.33, bodyHeight * 0.17), points, setState),
                _buildTouchableArea('body', '軀幹', Rect.fromLTWH(bodyWidth * 0.27, bodyHeight * 0.17, bodyWidth * 0.46, bodyHeight * 0.33), points, setState),
                _buildTouchableArea('leftArm', '左手', Rect.fromLTWH(0, bodyHeight * 0.17, bodyWidth * 0.27, bodyHeight * 0.33), points, setState),
                _buildTouchableArea('rightArm', '右手', Rect.fromLTWH(bodyWidth * 0.73, bodyHeight * 0.17, bodyWidth * 0.27, bodyHeight * 0.33), points, setState),
                _buildTouchableArea('leftLeg', '左腳', Rect.fromLTWH(bodyWidth * 0.27, bodyHeight * 0.5, bodyWidth * 0.23, bodyHeight * 0.5), points, setState),
                _buildTouchableArea('rightLeg', '右腳', Rect.fromLTWH(bodyWidth * 0.5, bodyHeight * 0.5, bodyWidth * 0.23, bodyHeight * 0.5), points, setState),
                // 調整區域位置，稍微上移
                _buildAdjustmentArea('adjustment', '調整', Rect.fromLTWH(bodyWidth * 0.35, bodyHeight * 1.0, bodyWidth * 0.3, bodyHeight * 0.08), points, setState),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (totalPoints != 0)
          Text(
            totalPoints > 0 ? '+$totalPoints' : '$totalPoints',
            style: TextStyle(
              color: color,
              fontSize: 48,  // 調整為更合適的大小
              fontWeight: FontWeight.bold,
            ),
          ),
      ],
    );
  }

  // 新增調整分數區域的方法
  Widget _buildAdjustmentArea(String part, String label, Rect rect, Map<String, int> points, StateSetter setState) {
    final score = points[part] ?? 0;
    return Positioned(
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height,
      child: GestureDetector(
        onTap: () {
          setState(() {
            // 在 -2, -1, 0, +1, +2 之間循環
            if (score >= 2) {
              points[part] = -2; // 從+2變成-2
            } else {
              points[part] = score + 1; // 正常遞增
            }
            
            // 更新即時資料庫中的臨時得分
            _realtimeDb.child('temp_scores').child(widget.match.id).update({
              'red_temp': tempRedPoints,
              'blue_temp': tempBluePoints,
              'last_updated': ServerValue.timestamp,
            });
          });
        },
        // 長按減分
        onLongPress: () {
          setState(() {
            // 在 -2, -1, 0, +1, +2 之間循環（反向）
            if (score <= -2) {
              points[part] = 2; // 從-2變成+2
            } else {
              points[part] = score - 1; // 正常遞減
            }
            
            // 更新即時資料庫中的臨時得分
            _realtimeDb.child('temp_scores').child(widget.match.id).update({
              'red_temp': tempRedPoints,
              'blue_temp': tempBluePoints,
              'last_updated': ServerValue.timestamp,
            });
          });
        },
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: Colors.black26,
              width: 1,
            ),
            color: Colors.grey.withOpacity(0.2), // 調整區域背景色
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                if (score != 0)
                  Text(
                    score > 0 ? '+$score' : '$score',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: score > 0 ? Colors.green : Colors.red,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
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
            // 更新即時資料庫中的臨時得分
            _realtimeDb.child('temp_scores').child(widget.match.id).update({
              'red_temp': tempRedPoints,
              'blue_temp': tempBluePoints,
              'last_updated': ServerValue.timestamp,
            });
          });
        },
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: Colors.black26,
              width: 1,
            ),
          ),
          child: Stack(
            children: [
              // 顯示得分
              Center(
                child: score > 0 ? FittedBox(
                  fit: BoxFit.contain,
                  child: Text(
                    '+$score',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ) : null,
              ),
              // 移除頭部區域顯示「掉棍」文字
            ],
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
          
          // 清空Realtime Database中的臨時得分
          _realtimeDb.child('temp_scores').child(widget.match.id).set(null);
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

  Widget _buildScoreBoard(BuildContext context, int redTotal, int blueTotal) {
      // 獲取屏幕尺寸
      final screenWidth = MediaQuery.of(context).size.width;
      // 計算適合的字體大小，根據屏幕寬度調整
      final scoreFontSize = screenWidth * 0.18; // 屏幕寬度的18%
      final dividerHeight = scoreFontSize * 1.2; // 分隔線高度與字體大小成比例
      
      return Container(
        padding: const EdgeInsets.all(16),
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
            Expanded(
              child: Column(
                children: [
                  const Text('紅方得分', style: TextStyle(color: Colors.red)),
                  const SizedBox(height: 8),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '$redTotal',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: scoreFontSize,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              height: dividerHeight,
              width: 2,
              color: Colors.grey.shade400,
            ),
            Expanded(
              child: Column(
                children: [
                  const Text('藍方得分', style: TextStyle(color: Colors.blue)),
                  const SizedBox(height: 8),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '$blueTotal',
                      style: TextStyle(
                        color: Colors.blue,
                        fontSize: scoreFontSize,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
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

    // Draw head - 使用相對尺寸繪製
    canvas.drawOval(
      Rect.fromLTWH(size.width * 0.33, 0, size.width * 0.33, size.height * 0.17),
      paint,
    );
    
    // Draw body - 使用相對尺寸繪製
    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.27, size.height * 0.17, size.width * 0.46, size.height * 0.33),
      paint,
    );
    
    // Draw arms - 使用相對尺寸繪製
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.17, size.width * 0.27, size.height * 0.33),
      paint,
    );
    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.73, size.height * 0.17, size.width * 0.27, size.height * 0.33),
      paint,
    );
    
    // Draw legs - 使用相對尺寸繪製
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
}