// lib/services/stockfish_service.dart
import 'dart:async';
import 'package:stockfish/stockfish.dart';
import '../models/chess_app.dart';

class StockfishService {
  Stockfish? _engine;
  bool _isReady = false;
  StreamSubscription? _outputSub;

  final _resultController = StreamController<AnalysisResult>.broadcast();
  Stream<AnalysisResult> get results => _resultController.stream;

  /// Motoru başlat
  Future<void> initialize() async {
    _engine = Stockfish();
    
    _outputSub = _engine!.stdout.listen(_handleOutput);

    // Motor hazır olana kadar bekle
    await _waitForReady();
  }

  Future<void> _waitForReady() async {
    final completer = Completer<void>();
    late StreamSubscription sub;

    sub = _engine!.stdout.listen((line) {
      if (line.contains('readyok') || line.contains('Stockfish')) {
        _isReady = true;
        sub.cancel();
        completer.complete();
      }
    });

    _engine!.stdin = 'uci\n';
    _engine!.stdin = 'isready\n';

    await completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () { _isReady = true; },
    );
  }

  String _currentFen = '';
  String _bestMove = '';
  int _evaluation = 0;
  int _depth = 0;
  List<String> _pv = [];

  void _handleOutput(String line) {
    // info depth 15 score cp 35 ... pv e2e4 e7e5
    if (line.startsWith('info')) {
      final depthMatch = RegExp(r'depth (\d+)').firstMatch(line);
      final cpMatch = RegExp(r'score cp (-?\d+)').firstMatch(line);
      final mateMatch = RegExp(r'score mate (-?\d+)').firstMatch(line);
      final pvMatch = RegExp(r' pv (.+)$').firstMatch(line);

      if (depthMatch != null) _depth = int.parse(depthMatch.group(1)!);
      if (cpMatch != null) _evaluation = int.parse(cpMatch.group(1)!);
      if (mateMatch != null) {
        final mateIn = int.parse(mateMatch.group(1)!);
        _evaluation = mateIn > 0 ? 1000 - mateIn * 10 : -(1000 + mateIn * 10);
      }
      if (pvMatch != null) {
        _pv = pvMatch.group(1)!.trim().split(' ');
      }
    }

    // bestmove e2e4 ponder e7e5
    if (line.startsWith('bestmove')) {
      final parts = line.split(' ');
      if (parts.length >= 2) {
        _bestMove = parts[1];
        _resultController.add(AnalysisResult(
          fen: _currentFen,
          bestMove: _bestMove,
          evaluation: _evaluation,
          depth: _depth,
          pv: _pv,
          timestamp: DateTime.now(),
        ));
      }
    }
  }

  /// FEN pozisyonunu analiz et
  Future<AnalysisResult> analyze(String fen, {int depth = 20, int timeMs = 3000}) async {
    if (!_isReady || _engine == null) {
      await initialize();
    }

    _currentFen = fen;
    _bestMove = '';
    _evaluation = 0;
    _depth = 0;
    _pv = [];

    final completer = Completer<AnalysisResult>();
    late StreamSubscription sub;

    sub = results.listen((result) {
      if (!completer.isCompleted) {
        sub.cancel();
        completer.complete(result);
      }
    });

    _engine!.stdin = 'position fen $fen\n';
    _engine!.stdin = 'go depth $depth movetime $timeMs\n';

    return completer.future.timeout(
      Duration(milliseconds: timeMs + 2000),
      onTimeout: () {
        sub.cancel();
        _engine!.stdin = 'stop\n';
        return AnalysisResult(
          fen: fen,
          bestMove: _bestMove.isEmpty ? 'Bulunamadı' : _bestMove,
          evaluation: _evaluation,
          depth: _depth,
          pv: _pv,
          timestamp: DateTime.now(),
        );
      },
    );
  }

  /// Hamleyi insan okunabilir forma çevir (e2e4 → e4)
  static String moveToAlgebraic(String uciMove) {
    if (uciMove.length < 4) return uciMove;
    // UCI → kısaltılmış gösterim (basit versiyon)
    final to = uciMove.substring(2, 4);
    final promo = uciMove.length > 4 ? '=${uciMove[4].toUpperCase()}' : '';
    return '$to$promo';
  }

  void dispose() {
    _engine?.stdin = 'quit\n';
    _outputSub?.cancel();
    _resultController.close();
  }
}
