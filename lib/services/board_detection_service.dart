import 'dart:typed_data';
import 'dart:math';
import 'package:image/image.dart' as img;
import '../models/chess_app.dart';

class BoardDetectionService {
  Future<String?> detectFenFromScreenshot(
    Uint8List screenshotBytes,
    BoardDetectionStrategy strategy,
  ) async {
    try {
      final image = img.decodeImage(screenshotBytes);
      if (image == null) return null;

      final boardRect = _findBoardArea(image, strategy);
      if (boardRect == null) return null;

      final boardImage = img.copyCrop(
        image,
        x: boardRect.x,
        y: boardRect.y,
        width: boardRect.width,
        height: boardRect.height,
      );

      final squares = _splitIntoSquares(boardImage);
      final board = _recognizePieces(squares, strategy);
      return _boardToFen(board);
    } catch (e) {
      return null;
    }
  }

  _Rect? _findBoardArea(img.Image image, BoardDetectionStrategy strategy) {
    switch (strategy) {
      case BoardDetectionStrategy.chessCom:
        return _findBoardByColors(image,
          darkR: 118, darkG: 150, darkB: 86,
          lightR: 238, lightG: 238, lightB: 210, tolerance: 30);
      case BoardDetectionStrategy.lichess:
        return _findBoardByColors(image,
          darkR: 70, darkG: 105, darkB: 140,
          lightR: 211, lightG: 222, lightB: 228, tolerance: 30);
      case BoardDetectionStrategy.duolingo:
        // Duolingo: koyu tema - kareler birbirine çok yakın renkte
        // Koyu kare: ~#2a2a2a, Açık kare: ~#3a3a3a
        return _findDuolingoBoard(image);
      default:
        return _findGenericBoard(image);
    }
  }

  // Duolingo tahtası: tüm renkler koyu, grid pattern ile bul
  _Rect? _findDuolingoBoard(img.Image image) {
    // Ekranın ortasını ve alt yarısını tara (tahta genelde altta)
    final w = image.width;
    final h = image.height;

    // Küçük versiyonda ara
    final small = img.copyResize(image, width: 300);
    final scaleX = w / small.width;
    final scaleY = h / small.height;

    int bestScore = 0;
    _Rect? bestRect;

    // Duolingo'da tahta ekranın alt %70'inde
    final startYSearch = (small.height * 0.2).round();

    for (int startX = 0; startX < small.width - 100; startX += 8) {
      for (int startY = startYSearch; startY < small.height - 80; startY += 8) {
        for (int size = 80; size <= min(small.width - startX, small.height - startY); size += 10) {
          final score = _evaluateDuolingoBoard(small, startX, startY, size);
          if (score > bestScore) {
            bestScore = score;
            bestRect = _Rect(
              x: (startX * scaleX).round(),
              y: (startY * scaleY).round(),
              width: (size * scaleX).round(),
              height: (size * scaleY).round(),
            );
          }
        }
      }
    }

    return bestScore > 30 ? bestRect : null;
  }

  int _evaluateDuolingoBoard(img.Image image, int startX, int startY, int size) {
    int score = 0;
    final squareSize = size ~/ 8;
    if (squareSize < 3) return 0;

    for (int row = 0; row < 8; row++) {
      for (int col = 0; col < 8; col++) {
        final x = startX + col * squareSize + squareSize ~/ 2;
        final y = startY + row * squareSize + squareSize ~/ 2;
        if (x >= image.width || y >= image.height) continue;

        final pixel = image.getPixel(x, y);
        final brightness = (pixel.r + pixel.g + pixel.b) / 3;

        // Duolingo'da her kare 20-80 arası parlaklıkta
        // Checker pattern: komşu kareler birbirinden ~10-20 birim farklı
        if (brightness >= 15 && brightness <= 90) score++;
      }
    }
    return score;
  }

  _Rect? _findGenericBoard(img.Image image) {
    final small = img.copyResize(image, width: 200);
    final scaleX = image.width / small.width;
    final scaleY = image.height / small.height;

    int bestScore = 0;
    _Rect? bestRect;

    for (int startX = 0; startX < small.width - 80; startX += 10) {
      for (int startY = 0; startY < small.height - 80; startY += 10) {
        for (int size = 60; size <= min(small.width - startX, small.height - startY); size += 10) {
          final score = _evaluateCheckerboard(small, startX, startY, size);
          if (score > bestScore) {
            bestScore = score;
            bestRect = _Rect(
              x: (startX * scaleX).round(),
              y: (startY * scaleY).round(),
              width: (size * scaleX).round(),
              height: (size * scaleY).round(),
            );
          }
        }
      }
    }
    return bestScore > 50 ? bestRect : null;
  }

  _Rect? _findBoardByColors(img.Image image, {
    required int darkR, required int darkG, required int darkB,
    required int lightR, required int lightG, required int lightB,
    required int tolerance,
  }) {
    int minX = image.width, minY = image.height, maxX = 0, maxY = 0;
    int matchCount = 0;

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final p = image.getPixel(x, y);
        final isDark = (p.r - darkR).abs() < tolerance &&
                       (p.g - darkG).abs() < tolerance &&
                       (p.b - darkB).abs() < tolerance;
        final isLight = (p.r - lightR).abs() < tolerance &&
                        (p.g - lightG).abs() < tolerance &&
                        (p.b - lightB).abs() < tolerance;
        if (isDark || isLight) {
          matchCount++;
          minX = min(minX, x); minY = min(minY, y);
          maxX = max(maxX, x); maxY = max(maxY, y);
        }
      }
    }

    if (matchCount < 100) return null;
    final size = max(maxX - minX, maxY - minY);
    return _Rect(x: minX, y: minY, width: size, height: size);
  }

  int _evaluateCheckerboard(img.Image image, int startX, int startY, int size) {
    int score = 0;
    final squareSize = size ~/ 8;
    if (squareSize < 2) return 0;

    for (int row = 0; row < 8; row++) {
      for (int col = 0; col < 8; col++) {
        final x = startX + col * squareSize + squareSize ~/ 2;
        final y = startY + row * squareSize + squareSize ~/ 2;
        if (x >= image.width || y >= image.height) continue;
        final pixel = image.getPixel(x, y);
        final brightness = (pixel.r + pixel.g + pixel.b) / 3;
        final isDark = (row + col) % 2 == 1;
        if (isDark && brightness < 150) score++;
        if (!isDark && brightness > 150) score++;
      }
    }
    return score;
  }

  List<List<img.Image>> _splitIntoSquares(img.Image board) {
    final squareSize = board.width ~/ 8;
    return List.generate(8, (row) =>
      List.generate(8, (col) =>
        img.copyCrop(board,
          x: col * squareSize, y: row * squareSize,
          width: squareSize, height: squareSize)));
  }

  List<List<String>> _recognizePieces(
    List<List<img.Image>> squares,
    BoardDetectionStrategy strategy,
  ) {
    final board = List.generate(8, (r) => List.generate(8, (c) => '.'));
    for (int row = 0; row < 8; row++) {
      for (int col = 0; col < 8; col++) {
        board[row][col] = _identifyPiece(
          squares[row][col],
          (row + col) % 2 == 1,
          strategy,
        );
      }
    }
    return board;
  }

  String _identifyPiece(img.Image square, bool isDarkSquare, BoardDetectionStrategy strategy) {
    final size = square.width;
    final cx = size ~/ 2, cy = size ~/ 2;
    final radius = size ~/ 3;

    // Duolingo için özel eşikler (koyu tema)
    final isDuolingo = strategy == BoardDetectionStrategy.duolingo;
    final bgBrightness = isDuolingo
        ? (isDarkSquare ? 35.0 : 50.0)   // Duolingo çok koyu
        : (isDarkSquare ? 80.0 : 200.0);  // Normal temalar

    int darkPixels = 0, lightPixels = 0, totalPixels = 0;

    for (int y = cy - radius; y < cy + radius; y++) {
      for (int x = cx - radius; x < cx + radius; x++) {
        if (x < 0 || x >= size || y < 0 || y >= size) continue;
        final pixel = square.getPixel(x, y);
        final brightness = (pixel.r + pixel.g + pixel.b) / 3;
        if ((brightness - bgBrightness).abs() > (isDuolingo ? 20 : 40)) {
          if (brightness < (isDuolingo ? 60 : 100)) darkPixels++;
          if (brightness > (isDuolingo ? 120 : 180)) lightPixels++;
        }
        totalPixels++;
      }
    }

    if (totalPixels == 0) return '.';
    final darkRatio = darkPixels / totalPixels;
    final lightRatio = lightPixels / totalPixels;
    if (darkRatio < 0.04 && lightRatio < 0.04) return '.';

    final isBlack = darkRatio > lightRatio;
    final pieceArea = (darkPixels + lightPixels) / totalPixels;

    if (isBlack) {
      if (pieceArea > 0.35) return 'q';
      if (pieceArea > 0.28) return 'r';
      if (pieceArea > 0.22) return 'b';
      if (pieceArea > 0.15) return 'n';
      if (pieceArea > 0.08) return 'p';
      return 'k';
    } else {
      if (pieceArea > 0.35) return 'Q';
      if (pieceArea > 0.28) return 'R';
      if (pieceArea > 0.22) return 'B';
      if (pieceArea > 0.15) return 'N';
      if (pieceArea > 0.08) return 'P';
      return 'K';
    }
  }

  String _boardToFen(List<List<String>> board) {
    final rows = <String>[];
    for (int row = 0; row < 8; row++) {
      final sb = StringBuffer();
      int empty = 0;
      for (int col = 0; col < 8; col++) {
        final piece = board[row][col];
        if (piece == '.') {
          empty++;
        } else {
          if (empty > 0) { sb.write(empty); empty = 0; }
          sb.write(piece);
        }
      }
      if (empty > 0) sb.write(empty);
      rows.add(sb.toString());
    }
    return '${rows.join('/')} w KQkq - 0 1';
  }
}

class _Rect {
  final int x, y, width, height;
  const _Rect({required this.x, required this.y, required this.width, required this.height});
}
