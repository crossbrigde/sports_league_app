import 'package:flutter/material.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../models/match.dart';
import 'models/tournament.dart';
import '../tournament/services/tournament_bracket_service.dart';
// 移除這行未使用的導入
// import 'all_ongoing_matches_page.dart'; 

// 將_WinnerResult類移到頂層
class _WinnerResult {
  final String winner;
  final String reason;

  _WinnerResult(this.winner, this.reason);
}

// 將BodyPainter類移到頂層
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
  late final TournamentBracketService _bracketService;
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
    _bracketService = TournamentBracketService();
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
        title: Text('${widget.match.name}'),
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
    
    // 獲取屏幕尺寸
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;
    
    // 設置對話框寬度為屏幕寬度的85%，但不超過500
    final dialogWidth = (screenWidth * 0.85).clamp(0.0, 500.0);
    // 設置對話框高度為屏幕高度的75%，確保不會太高，減少溢出可能性
    final dialogHeight = (screenHeight * 0.75).clamp(0.0, 650.0);
    
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) {
        return StatefulBuilder(
          builder: (context, setState) => Dialog(
            // 設置對話框固定尺寸
            insetPadding: EdgeInsets.symmetric(
              horizontal: (screenWidth - dialogWidth) / 2,
              vertical: (screenHeight - dialogHeight) / 2,
            ),
            child: Container(
              constraints: BoxConstraints(
                maxWidth: dialogWidth,
                maxHeight: dialogHeight,
              ),
              child: Scaffold(
                appBar: AppBar(
                  title: const Text('判定得分'),
                  leading: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      // 取消時也清空臨時得分
                      tempRedPoints.clear();
                      tempBluePoints.clear();
                      // 清空Realtime Database中的臨時得分
                      _realtimeDb.child('temp_scores').child(widget.match.id).set(null);
                      Navigator.pop(context);
                    },
                  ),
                  actions: [
                    MaterialButton(
                      onPressed: () => _confirmJudgment(context),
                      textColor: Colors.black,
                      color: Colors.grey.shade300,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: const Text('確認判定', style: TextStyle(color: Colors.black)),
                    ),
                  ],
                ),
                body: SafeArea(
                  // 使用SafeArea確保內容不會被系統UI遮擋
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // 計算可用高度
                      final availableHeight = constraints.maxHeight;
                      // 根據可用高度計算縮放比例，降低最小縮放比例以適應更小的屏幕
                      final scale = (availableHeight / 600).clamp(0.3, 0.9);
                      
                      return SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(), // 確保始終可滾動
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0), // 減少內邊距
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Transform.scale(
                                scale: scale,
                                alignment: Alignment.topCenter,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: _buildBodyMap('red', setState, context),
                                    ),
                                    const SizedBox(width: 8), // 減少間距
                                    Expanded(
                                      child: _buildBodyMap('blue', setState, context),
                                    ),
                                  ],
                                ),
                              ),
                              // 添加底部間距，確保內容完全可見
                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBodyMap(String player, StateSetter setState, BuildContext context) {
    final color = player == 'red' ? Colors.red : Colors.blue;
    final points = player == 'red' ? tempBluePoints : tempRedPoints;
    final displayPoints = player == 'red' ? tempRedPoints : tempBluePoints;
    final totalPoints = displayPoints.values.fold(0, (sum, points) => sum + points);
    
    // 使用更小的固定寬度計算人形大小，減少溢出可能性
    final bodyWidth = 150.0; // 放大人形寬度從120增加到150
    final bodyHeight = bodyWidth * 1.7; // 保持人形高度比例為1.7
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          player == 'red' ? '紅方' : '藍方',
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18), // 增加字體大小
        ),
        const SizedBox(height: 6), // 適當增加間距
        SizedBox(
          width: bodyWidth,
          height: bodyHeight * 1.1, // 保持整體高度比例為1.1
          child: Stack(
            clipBehavior: Clip.none, // 允許子元素超出Stack邊界
            fit: StackFit.loose, // 使用loose適應策略
            children: [
              CustomPaint(
                size: Size(bodyWidth, bodyHeight),
                painter: BodyPainter(color: color.withAlpha(51)),
              ),
              _buildTouchableArea('head', '頭部', Rect.fromLTWH(bodyWidth * 0.33, 0, bodyWidth * 0.33, bodyHeight * 0.17), points, setState),
              _buildTouchableArea('body', '軀幹', Rect.fromLTWH(bodyWidth * 0.27, bodyHeight * 0.17, bodyWidth * 0.46, bodyHeight * 0.33), points, setState),
              _buildTouchableArea('leftArm', '左手', Rect.fromLTWH(0, bodyHeight * 0.17, bodyWidth * 0.27, bodyHeight * 0.33), points, setState),
              _buildTouchableArea('rightArm', '右手', Rect.fromLTWH(bodyWidth * 0.73, bodyHeight * 0.17, bodyWidth * 0.27, bodyHeight * 0.33), points, setState),
              _buildTouchableArea('leftLeg', '左腳', Rect.fromLTWH(bodyWidth * 0.27, bodyHeight * 0.5, bodyWidth * 0.23, bodyHeight * 0.5), points, setState),
              _buildTouchableArea('rightLeg', '右腳', Rect.fromLTWH(bodyWidth * 0.5, bodyHeight * 0.5, bodyWidth * 0.23, bodyHeight * 0.5), points, setState),
            ],
          ),
        ),
        // 將調整區域移到人形圖下方，並增加其尺寸
        const SizedBox(height: 10), // 增加與人形圖的間距
        SizedBox(
          width: bodyWidth * 1.2, // 增加寬度與人形圖匹配
          height: 45, // 增加高度，使其更容易點擊
          child: _buildAdjustmentArea(
            'adjustment', 
            '±2 調整', 
            Rect.fromLTWH(0, 0, bodyWidth * 1.2, 45), 
            points, 
            setState
          ),
        ),
        const SizedBox(height: 8), // 增加與總分的間距
        if (totalPoints != 0)
          Text(
            totalPoints > 0 ? '+$totalPoints' : '$totalPoints',
            style: TextStyle(
              color: color,
              fontSize: 42,  // 增加字體大小以匹配放大後的人形圖
              fontWeight: FontWeight.bold,
            ),
          ),
      ],
    );
  }

  // 新增調整分數區域的方法
  Widget _buildAdjustmentArea(String part, String label, Rect rect, Map<String, int> points, StateSetter setState) {
    final score = points[part] ?? 0;
    return GestureDetector(
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
        width: rect.width,
        height: rect.height,
        decoration: BoxDecoration(
          border: Border.all(
            color: Colors.black54,
            width: 1.5,
          ),
          color: Colors.grey.withOpacity(0.3), // 增加背景色不透明度
          borderRadius: BorderRadius.circular(12), // 使用較小的圓角
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 18, // 增大字體大小
              ),
            ),
            const SizedBox(width: 8), // 添加間距
            if (score != 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: score > 0 ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  score > 0 ? '+$score' : '$score',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20, // 增大字體大小
                    color: score > 0 ? Colors.green : Colors.red,
                  ),
                ),
              ),
          ],
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
              // 只在右手區域添加浮水印
              if (part == 'rightArm')
                Center(
                  child: Text(
                    'R',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: rect.width * 0.5, // 根據區域寬度調整字體大小
                      color: Colors.black38, // 比背景深一點的顏色
                    ),
                  ),
                ),
              // 分數顯示
              Center(
                child: score > 0 ? FittedBox(
                  fit: BoxFit.scaleDown, // 使用scaleDown確保文字不會溢出
                  child: Padding(
                    padding: const EdgeInsets.all(1.0), // 添加小間距
                    child: Text(
                      '+$score',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18, // 減小字體大小
                      ),
                    ),
                  ),
                ) : null,
              ),
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
    
    // 顯示確認對話框
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('確定勝負'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('紅方總分：$redTotal'),
            Text('藍方總分：$blueTotal'),
            const SizedBox(height: 16),
            const Text('請選擇判定方式：'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final result = await _showManualWinnerSelection('手動判定勝負');
              if (result != null && mounted) {
                _endMatch(result.winner, result.reason);
              }
            },
            child: const Text('手動判定'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              // 根據得分自動判定勝負
              if (redTotal > blueTotal) {
                _endMatch('red', '紅方得分較高：$redTotal vs $blueTotal');
              } else if (blueTotal > redTotal) {
                _endMatch('blue', '藍方得分較高：$blueTotal vs $redTotal');
              } else {
                // 平局情況，顯示手動判定對話框
                _showManualWinnerSelection('平局情況下的判定');
              }
            },
            child: const Text('根據得分判定'),
          ),
        ],
      ),
    );
  }
  
  Future<_WinnerResult?> _showManualWinnerSelection(String title) async {
    return showDialog<_WinnerResult>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('請選擇勝方：'),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () {
                    final controller = TextEditingController();
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('輸入判定原因'),
                        content: TextField(
                          controller: controller,
                          decoration: const InputDecoration(
                            hintText: '例如：技術優勢、犯規過多等',
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('取消'),
                          ),
                          FilledButton(
                            onPressed: () {
                              final reason = controller.text.trim().isNotEmpty
                                  ? controller.text.trim()
                                  : '手動判定';
                              Navigator.pop(context);
                              Navigator.pop(context, _WinnerResult('red', reason));
                            },
                            child: const Text('確認'),
                          ),
                        ],
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('紅方勝'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final controller = TextEditingController();
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('輸入判定原因'),
                        content: TextField(
                          controller: controller,
                          decoration: const InputDecoration(
                            hintText: '例如：技術優勢、犯規過多等',
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('取消'),
                          ),
                          FilledButton(
                            onPressed: () {
                              final reason = controller.text.trim().isNotEmpty
                                  ? controller.text.trim()
                                  : '手動判定';
                              Navigator.pop(context);
                              Navigator.pop(context, _WinnerResult('blue', reason));
                            },
                            child: const Text('確認'),
                          ),
                        ],
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('藍方勝'),
                ),
              ],
            ),
          ],
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
  
  void _endMatch(String winner, String reason) async {
    try {
      setState(() {
        _isMatchEnded = true;
      });
      
      // 更新比賽狀態
      await _firestore.collection('matches').doc(widget.match.id).update({
        'basic_info.status': 'completed',
        'basic_info.winner': winner,
        'basic_info.winReason': reason,
        'timestamps.endTime': FieldValue.serverTimestamp(),
      });
      
      // 處理單淘汰賽的自動晉級邏輯
      if (widget.match.nextMatchId != null && widget.match.slotInNext != null) {
        await _handleTournamentAdvancement(winner);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('比賽已結束，${winner == 'red' ? '紅方' : '藍方'}勝出'),
            backgroundColor: winner == 'red' ? Colors.red : Colors.blue,
          ),
        );
      }
    } catch (e) {
      print('結束比賽時發生錯誤：$e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('結束比賽時發生錯誤：$e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  // 處理單淘汰賽的自動晉級邏輯
  Future<void> _handleTournamentAdvancement(String winner) async {
    try {
      // 更新賽程中的比賽狀態
      final doc = await _firestore.collection('tournaments').doc(widget.match.tournamentId).get();
      if (doc.exists) {
        final tournamentData = doc.data() as Map<String, dynamic>;
        final matches = tournamentData['matches'] as Map<String, dynamic>?;
        
        if (matches != null) {
          // 找到當前比賽
          String? currentMatchId;
          matches.forEach((id, matchData) {
            if (matchData['matchNumber'] == widget.match.matchNumber) {
              currentMatchId = id;
            }
          });
          
          if (currentMatchId != null) {
            // 更新當前比賽狀態
            matches[currentMatchId!]['status'] = 'completed';
            matches[currentMatchId!]['winner'] = winner == 'red' ? widget.match.redPlayer : widget.match.bluePlayer;
            
            // 更新賽程
            await _firestore.collection('tournaments').doc(widget.match.tournamentId).update({
              'matches': matches,
            });
            
            // 使用TournamentBracketService處理自動晉級
            final updatedMatch = widget.match.copyWith(
              status: 'completed',
              winner: winner == 'red' ? 'red' : 'blue',
            );
            await _bracketService.handleMatchCompletion(updatedMatch);
            print('已調用自動晉級邏輯');
          }
        }
      }
    } catch (e) {
      print('處理晉級邏輯時發生錯誤：$e');
    }
  }
}