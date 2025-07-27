import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
// 移除未使用的導入
import '../../core/models/tournament.dart';
import '../../core/models/match.dart';
import 'match_scoring_page.dart';
import '../../core/services/match_service.dart';

class MatchSetupPage extends StatefulWidget {
  final Tournament tournament;

  const MatchSetupPage({super.key, required this.tournament});

  @override
  State<MatchSetupPage> createState() => _MatchSetupPageState();
}

class _MatchSetupPageState extends State<MatchSetupPage> {
  final _formKey = GlobalKey<FormState>();
  final _matchService = MatchService();
  String refereeId = '';
  String redPlayerId = '';
  String bluePlayerId = '';
  String matchNumber = '';
  bool _isLoadingMatchNumber = true;
  
  // 判斷是否為單淘汰賽
  bool get isSingleElimination => widget.tournament.type == 'single_elimination';
  
  @override
  void initState() {
    super.initState();
    _generateNextMatchNumber();
  }
  
  // 自動生成下一個場次號碼
  Future<void> _generateNextMatchNumber() async {
    try {
      // 查詢該賽程下的所有比賽，獲取最大的場次號碼
      final matchesSnapshot = await _matchService.firestore
          .collection('matches')
          .where('basic_info.tournamentId', isEqualTo: widget.tournament.id)
          .get();
      
      int maxMatchNumber = 0;
      
      for (final doc in matchesSnapshot.docs) {
        final data = doc.data();
        final matchNumberStr = data['basic_info']?['matchNumber'] ?? '0';
        final currentMatchNumber = int.tryParse(matchNumberStr.toString()) ?? 0;
        if (currentMatchNumber > maxMatchNumber) {
          maxMatchNumber = currentMatchNumber;
        }
      }
      
      setState(() {
        matchNumber = (maxMatchNumber + 1).toString();
        _isLoadingMatchNumber = false;
      });
    } catch (e) {
      print('生成場次號碼時發生錯誤: $e');
      setState(() {
        matchNumber = '1'; // 默認從1開始
        _isLoadingMatchNumber = false;
      });
    }
  }
  
  // 通用名稱驗證函數
  String? validateName(String? value, String role) {
    if (value == null || value.isEmpty) {
      return '請輸入$role名稱';
    }
    final pattern = RegExp(r"^[\u4e00-\u9fa5a-zA-Z0-9]{1,8}$");
    if (!pattern.hasMatch(value)) {
      return '$role名稱僅限中英文或數字，最多8個字';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('比賽設置'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.tournament.name,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 24),
              TextFormField(
                maxLength: 8,
                decoration: const InputDecoration(
                  labelText: '裁判',
                  border: OutlineInputBorder(),
                  helperText: '最多8個字，僅限中英文或數字',
                ),
                validator: (value) => validateName(value, '裁判'),
                onSaved: (value) => refereeId = value ?? '',
              ),
              const SizedBox(height: 16),
              TextFormField(
                maxLength: 8,
                decoration: const InputDecoration(
                  labelText: '紅方選手',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person, color: Colors.red),
                  helperText: '最多8個字，僅限中英文或數字',
                ),
                validator: (value) => validateName(value, '紅方選手'),
                onSaved: (value) => redPlayerId = value ?? '',
              ),
              const SizedBox(height: 16),
              TextFormField(
                maxLength: 8,
                decoration: const InputDecoration(
                  labelText: '藍方選手',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person, color: Colors.blue),
                  helperText: '最多8個字，僅限中英文或數字',
                ),
                validator: (value) => validateName(value, '藍方選手'),
                onSaved: (value) => bluePlayerId = value ?? '',
              ),
              const SizedBox(height: 16),
              // 自動生成的場次顯示
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4.0),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '場次',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    _isLoadingMatchNumber
                        ? const Row(
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              SizedBox(width: 8),
                              Text('生成中...'),
                            ],
                          )
                        : Text(
                            matchNumber,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Center(
                child: ElevatedButton(
                  onPressed: _isLoadingMatchNumber ? null : () {
                    if (_formKey.currentState!.validate()) {
                      _formKey.currentState!.save();
                      if (isSingleElimination) {
                        _updateTournamentMatch();
                      } else {
                        _showConfirmationDialog();
                      }
                    }
                  },
                  child: const Text('開始比賽'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('確認比賽資訊'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('裁判：$refereeId'),
            const SizedBox(height: 8),
            Text('紅方：$redPlayerId'),
            const SizedBox(height: 8),
            Text('藍方：$bluePlayerId'),
            const SizedBox(height: 8),
            Text('場次：$matchNumber'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('修改'),
          ),
          FilledButton(
            onPressed: () async {
              final now = DateTime.now();
              final match = Match(
                id: const Uuid().v4(),
                tournamentId: widget.tournament.id,
                tournamentName: widget.tournament.name,
                name: '${widget.tournament.name} - 場次 $matchNumber',
                redPlayer: redPlayerId,
                bluePlayer: bluePlayerId,
                refereeNumber: refereeId,
                matchNumber: matchNumber,
                redScores: {'total': 0},
                blueScores: {'total': 0},
                createdAt: now,
                status: 'ongoing',
                currentSet: 1,
                setResults: {},
                redSetsWon: 0,
                blueSetsWon: 0,
              );

              // 使用 _matchService 创建比赛
              try {
                // 直接使用 _matchService 创建比赛，不需要额外的 matchData 变量
                final matchId = await _matchService.createMatch(match);
                
                if (matchId != null && mounted) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MatchScoringPage(
                        match: match.copyWith(id: matchId),
                        tournament: widget.tournament,
                      ),
                    ),
                  );
                } else {
                  throw Exception('創建比賽失敗：未獲得有效的比賽ID');
                }
              } catch (e) {
                // 顯示錯誤訊息
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('創建比賽失敗：$e')),
                  );
                }
              }
            },
            child: const Text('確認'),
          ),
        ],
      ),
    );
  }

  // 更新單淘汰賽比賽
  Future<void> _updateTournamentMatch() async {
    try {
      // 顯示加載指示器
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // 獲取賽程數據
      final tournamentDoc = await _matchService.firestore
          .collection('tournaments')
          .doc(widget.tournament.id)
          .get();

      if (!tournamentDoc.exists) {
        Navigator.pop(context); // 關閉加載指示器
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('找不到賽程數據')),
        );
        return;
      }

      final tournamentData = tournamentDoc.data() as Map<String, dynamic>;
      final matches = tournamentData['matches'] as Map<String, dynamic>?;

      if (matches == null) {
        Navigator.pop(context); // 關閉加載指示器
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('賽程結構數據不完整')),
        );
        return;
      }

      // 查找進行中的比賽
      final ongoingMatches = <String, Map<String, dynamic>>{};
      matches.forEach((id, matchData) {
        if (matchData['status'] == 'ongoing') {
          ongoingMatches[id] = matchData;
        }
      });

      if (ongoingMatches.isEmpty) {
        Navigator.pop(context); // 關閉加載指示器
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('沒有可進行的比賽')),
        );
        return;
      }

      // 查詢是否已經有這場比賽的記錄
      final existingMatchesSnapshot = await _matchService.firestore
          .collection('matches')
          .where('basic_info.tournamentId', isEqualTo: widget.tournament.id)
          .where('basic_info.status', isEqualTo: 'ongoing')
          .get();

      // 如果已經有比賽記錄，則更新它
      if (existingMatchesSnapshot.docs.isNotEmpty) {
        for (final doc in existingMatchesSnapshot.docs) {
          final matchData = doc.data();
          final matchNumber = matchData['matchNumber'];
          
          // 找到對應的賽程比賽
          String? matchId;
          matches.forEach((id, data) {
            if (data['matchNumber'] == matchNumber) {
              matchId = id;
            }
          });
          
          if (matchId != null) {
            // 更新比賽信息
            await doc.reference.update({
              'basic_info.refereeNumber': refereeId,
              'basic_info.redPlayer': redPlayerId,
              'basic_info.bluePlayer': bluePlayerId,
            });
            
            // 更新賽程中的比賽信息
            matches[matchId!]['redPlayer'] = redPlayerId;
            matches[matchId!]['bluePlayer'] = bluePlayerId;
            
            await _matchService.firestore
                .collection('tournaments')
                .doc(widget.tournament.id)
                .update({
              'matches': matches,
            });
            
            Navigator.pop(context); // 關閉加載指示器
            
            // 導航到比賽計分頁面
            if (mounted) {
              final match = Match.fromFirestore(doc);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => MatchScoringPage(
                    match: match,
                    tournament: widget.tournament,
                  ),
                ),
              );
            }
            
            return;
          }
        }
      }
      
      // 如果沒有現有記錄，創建新的比賽記錄
      final firstOngoingMatch = ongoingMatches.entries.first;
      final matchId = firstOngoingMatch.key;
      final matchData = firstOngoingMatch.value;
      
      final match = Match(
        id: const Uuid().v4(),
        name: '${widget.tournament.name} - 第${matchData['round']}輪 #${matchData['matchNumber']}',
        matchNumber: matchData['matchNumber'],
        redPlayer: redPlayerId,
        bluePlayer: bluePlayerId,
        refereeNumber: refereeId,
        status: 'ongoing',
        createdAt: DateTime.now(),
        tournamentId: widget.tournament.id,
        tournamentName: widget.tournament.name,
        round: matchData['round'],
        nextMatchId: matchData['nextMatchId'],
        slotInNext: matchData['slotInNext'],
        redScores: {'total': 0},
        blueScores: {'total': 0},
        currentSet: 1,
        setResults: {},
        redSetsWon: 0,
        blueSetsWon: 0,
      );
      
      // 使用 _matchService 创建比赛
      final createdMatchId = await _matchService.createMatch(match);
      
      if (createdMatchId == null) {
        throw Exception('創建比賽失敗：未獲得有效的比賽ID');
      }
      
      // 更新賽程中的比賽信息
      matches[matchId]['redPlayer'] = redPlayerId;
      matches[matchId]['bluePlayer'] = bluePlayerId;
      
      await _matchService.firestore
          .collection('tournaments')
          .doc(widget.tournament.id)
          .update({
        'matches': matches,
      });
      
      Navigator.pop(context); // 關閉加載指示器
      
      // 導航到比賽計分頁面
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => MatchScoringPage(
              match: match.copyWith(id: createdMatchId),
              tournament: widget.tournament,
            ),
          ),
        );
      }
    } catch (e) {
      print('更新單淘汰賽比賽時發生錯誤: $e');
      Navigator.pop(context); // 關閉加載指示器
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('更新比賽失敗: $e')),
        );
      }
    }
  }
}