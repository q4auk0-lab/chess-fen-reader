// lib/services/board_detection_service.dart
import 'dart:typed_data';
import 'dart:math';
import 'package:image/image.dart' as img;
import '../models/chess_app.dart';

class BoardDetectionService {
  /// Ana metod: ekran görüntüsünden FEN üretir
  Future<String?> detectFenFromScreenshot(
    Uint8List screenshotBytes,
    BoardDetectionStrategy strategy,
  ) async {
    final image = img.decodeImage(screenshotBytes);
    if (image == null) return null;

    // 1. Tahta alanını bul
    final boardRect = await _findBoardArea(image, strategy);
    if (boardRect == null) return null;

    // 2. Tahtayı kırp ve normalize et
    final boardImage = img.copyCrop(
      image,
      x: boardRect.x,
      y: boardRect.y,
      width: boardRect.width,
      height: boardRect.height,
    );

    // 3. 8x8 karelere böl
    final squares = _splitIntoSquares(boardImage);

    // 4. Her karedeki taşı tanı
    final board = _recognizePieces(squares);

    // 5. FEN'e dönüştür
    return _boardToFen(board);
  }

  /// Ekran görüntüsünde satranç tahtasını bul
  Future<_Rect?> _findBoardArea(
    img.Image image,
    BoardDetectionStrategy strategy,
  ) async {
    switch (strategy) {
      case BoardDetectionStrategy.chessCom:
        return _findChessComBoard(image);
      case BoardDetectionStrategy.lichess:
        return _findLichessBoard(image);
      default:
        return _findGenericBoard(image);
    }
  }

  /// Chess.com tahtası genellikle yeşil/bej renk şemasında
  _Rect? _findChessComBoard(img.Image image) {
    // Chess.com'da tahta merkeze yakın, kare oranlı
    // Yeşil (#769656) ve açık kare (#eeeed2) renkleri ara
    return _findBoardByColors(
      image,
      darkSquareColor: img.ColorRgb8(118, 150, 86),   // #769656
      lightSquareColor: img.ColorRgb8(238, 238, 210),  // #eeeed2
      tolerance: 30,
    );
  }

  /// Lichess tahtası mavi tonlarda
  _Rect? _findLichessBoard(img.Image image) {
    return _findBoardByColors(
      image,
      darkSquareColor: img.ColorRgb8(70, 105, 140),    // #466a8c
      lightSquareColor: img.ColorRgb8(211, 222, 228),   // #d3dee4
      tolerance: 30,
    );
  }

  /// Genel tahta tespiti - grid pattern arar
  _Rect? _findGenericBoard(img.Image image) {
    final width = image.width;
    final height = image.height;

    // Görüntüyü küçült (hız için)
    final small = img.copyResize(image, width: 200);
    final scaleX = width / small.width;
    final scaleY = height / small.height;

    // Alternatif kare pattern ara (checkerboard)
    int bestScore = 0;
    _Rect? bestRect;

    // Farklı konumları dene
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

  /// Renk bazlı tahta tespiti
  _Rect? _findBoardByColors(
    img.Image image, {
    required img.Color darkSquareColor,
    required img.Color lightSquareColor,
    required int tolerance,
  }) {
    int darkCount = 0;
    int lightCount = 0;
    int minX = image.width, minY = image.height;
    int maxX = 0, maxY = 0;

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        if (_colorMatch(pixel, darkSquareColor, tolerance)) {
          darkCount++;
          minX = min(minX, x);
          minY = min(minY, y);
          maxX = max(maxX, x);
          maxY = max(maxY, y);
        } else if (_colorMatch(pixel, lightSquareColor, tolerance)) {
          lightCount++;
          minX = min(minX, x);
          minY = min(minY, y);
          maxX = max(maxX, x);
          maxY = max(maxY, y);
        }
      }
    }

    if (darkCount < 100 || lightCount < 100) return null;

    final size = max(maxX - minX, maxY - minY);
    return _Rect(x: minX, y: minY, width: size, height: size);
  }

  bool _colorMatch(img.Color pixel, img.Color target, int tolerance) {
    return (pixel.r - target.r).abs() < tolerance &&
           (pixel.g - target.g).abs() < tolerance &&
           (pixel.b - target.b).abs() < tolerance;
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

        // Checkerboard pattern match
        if (isDark && brightness < 150) score++;
        if (!isDark && brightness > 150) score++;
      }
    }
    return score;
  }

  /// Tahtayı 64 kareye böl
  List<List<img.Image>> _splitIntoSquares(img.Image board) {
    final squareSize = board.width ~/ 8;
    final squares = List.generate(8, (row) {
      return List.generate(8, (col) {
        return img.copyCrop(
          board,
          x: col * squareSize,
          y: row * squareSize,
          width: squareSize,
          height: squareSize,
        );
      });
    });
    return squares;
  }

  /// Her karede taş tanıma (renk analizi + template matching)
  List<List<String>> _recognizePieces(List<List<img.Image>> squares) {
    final board = List.generate(8, (r) => List.generate(8, (c) => '.'));

    for (int row = 0; row < 8; row++) {
      for (int col = 0; col < 8; col++) {
        final square = squares[row][col];
        board[row][col] = _identifyPiece(square, (row + col) % 2 == 1);
      }
    }

    return board;
  }

  /// Tek karede taş analizi
  String _identifyPiece(img.Image square, bool isDarkSquare) {
    // Merkez bölgeyi al
    final size = square.width;
    final centerX = size ~/ 2;
    final centerY = size ~/ 2;
    final radius = size ~/ 3;

    int darkPixels = 0;
    int lightPixels = 0;
    int totalPixels = 0;

    // Kare rengi (beklenen arka plan)
    final bgBrightness = isDarkSquare ? 80.0 : 200.0;

    for (int y = centerY - radius; y < centerY + radius; y++) {
      for (int x = centerX - radius; x < centerX + radius; x++) {
        if (x < 0 || x >= size || y < 0 || y >= size) continue;
        final pixel = square.getPixel(x, y);
        final brightness = (pixel.r + pixel.g + pixel.b) / 3;

        // Arka plandan sapma
        if ((brightness - bgBrightness).abs() > 40) {
          if (brightness < 100) darkPixels++;
          if (brightness > 200) lightPixels++;
        }
        totalPixels++;
      }
    }

    final darkRatio = darkPixels / totalPixels;
    final lightRatio = lightPixels / totalPixels;

    // Taş yok
    if (darkRatio < 0.05 && lightRatio < 0.05) return '.';

    // Siyah taş (koyu piksel yoğunluğu)
    final isBlack = darkRatio > lightRatio;

    // Taş tipini boyuta göre tahmin et
    final pieceArea = (darkPixels + lightPixels) / totalPixels;

    if (isBlack) {
      if (pieceArea > 0.35) return 'q'; // Vezir - büyük
      if (pieceArea > 0.28) return 'r'; // Kale
      if (pieceArea > 0.22) return 'b'; // Fil
      if (pieceArea > 0.15) return 'n'; // At
      if (pieceArea > 0.08) return 'p'; // Piyon
      return 'k';                        // Şah
    } else {
      if (pieceArea > 0.35) return 'Q';
      if (pieceArea > 0.28) return 'R';
      if (pieceArea > 0.22) return 'B';
      if (pieceArea > 0.15) return 'N';
      if (pieceArea > 0.08) return 'P';
      return 'K';
    }
  }

  /// 8x8 board array'ini FEN string'ine çevir
  String _boardToFen(List<List<String>> board) {
    final rows = <String>[];

    for (int row = 0; row < 8; row++) {
      final sb = StringBuffer();
      int emptyCount = 0;

      for (int col = 0; col < 8; col++) {
        final piece = board[row][col];
        if (piece == '.') {
          emptyCount++;
        } else {
          if (emptyCount > 0) {
            sb.write(emptyCount);
            emptyCount = 0;
          }
          sb.write(piece);
        }
      }

      if (emptyCount > 0) sb.write(emptyCount);
      rows.add(sb.toString());
    }

    // FEN: piece placement + turn + castling + en passant + halfmove + fullmove
    final piecePlacement = rows.join('/');
    return '$piecePlacement w KQkq - 0 1';
  }
}

class _Rect {
  final int x, y, width, height;
  const _Rect({required this.x, required this.y, required this.width, required this.height});
}
