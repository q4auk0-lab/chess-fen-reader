class ChessApp {
  final String id;
  final String name;
  final String packageName;
  final String iconAsset;
  final BoardDetectionStrategy strategy;

  const ChessApp({
    required this.id,
    required this.name,
    required this.packageName,
    required this.iconAsset,
    required this.strategy,
  });
}

enum BoardDetectionStrategy {
  chessCom,
  lichess,
  special,
  chessBase,
  chessKid,
  generic,
}

const List<ChessApp> kSupportedApps = [
  ChessApp(
    id: 'special',
    name: 'special',
    packageName: 'com.gbox.android',
    iconAsset: 'assets/apps/generic.png',
    strategy: BoardDetectionStrategy.special,
  ),
  ChessApp(
    id: 'chess_com',
    name: 'Chess.com',
    packageName: 'com.chess',
    iconAsset: 'assets/apps/generic.png',
    strategy: BoardDetectionStrategy.chessCom,
  ),
  ChessApp(
    id: 'lichess',
    name: 'Lichess',
    packageName: 'org.lichess.mobileapp',
    iconAsset: 'assets/apps/generic.png',
    strategy: BoardDetectionStrategy.lichess,
  ),
  ChessApp(
    id: 'chess_kid',
    name: 'ChessKid',
    packageName: 'com.chess.kid',
    iconAsset: 'assets/apps/generic.png',
    strategy: BoardDetectionStrategy.chessKid,
  ),
  ChessApp(
    id: 'chessbase',
    name: 'ChessBase',
    packageName: 'com.chessbase.android',
    iconAsset: 'assets/apps/generic.png',
    strategy: BoardDetectionStrategy.chessBase,
  ),
  ChessApp(
    id: 'other',
    name: 'Diger (Genel)',
    packageName: '',
    iconAsset: 'assets/apps/generic.png',
    strategy: BoardDetectionStrategy.generic,
  ),
];

class AnalysisResult {
  final String fen;
  final String bestMove;
  final int evaluation;
  final int depth;
  final List<String> pv;
  final DateTime timestamp;

  AnalysisResult({
    required this.fen,
    required this.bestMove,
    required this.evaluation,
    required this.depth,
    required this.pv,
    required this.timestamp,
  });

  String get evalDisplay {
    if (evaluation.abs() > 900) {
      final mateIn = (evaluation > 0 ? 1 : -1) *
          ((1000 - evaluation.abs()) ~/ 100 + 1);
      return 'M$mateIn';
    }
    final pawns = evaluation / 100.0;
    return pawns >= 0
        ? '+${pawns.toStringAsFixed(2)}'
        : pawns.toStringAsFixed(2);
  }
}
