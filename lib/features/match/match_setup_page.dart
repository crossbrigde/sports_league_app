import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
// 移除未使用的導入
import 'models/tournament.dart';
import 'models/match.dart';
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
  // 移除未使用的 _firestore 变量
  String refereeId = '';
  String redPlayerId = '';
  String bluePlayerId = '';
  String matchNumber = '';

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
                decoration: const InputDecoration(
                  labelText: '裁判',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '請輸入裁判名稱';
                  }
                  return null;
                },
                onSaved: (value) => refereeId = value ?? '',
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: '紅方選手',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person, color: Colors.red),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '請輸入紅方選手名稱';
                  }
                  return null;
                },
                onSaved: (value) => redPlayerId = value ?? '',
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: '藍方選手',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person, color: Colors.blue),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '請輸入藍方選手名稱';
                  }
                  return null;
                },
                onSaved: (value) => bluePlayerId = value ?? '',
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: '場次',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '請輸入場次';
                  }
                  return null;
                },
                onSaved: (value) => matchNumber = value ?? '',
              ),
              const SizedBox(height: 32),
              Center(
                child: ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      _formKey.currentState!.save();
                      _showConfirmationDialog();
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
}