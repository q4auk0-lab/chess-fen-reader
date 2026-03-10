import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chess_app.dart';
import 'board_detection_service.dart';
import 'stockfish_service.dart';
import 'screen_capture_service.dart';

enum AppStatus { idle, capturing, analyzing, done, error }

class AppState extends ChangeNotifier {
  final _boardDetection = BoardDetectionService();
  final _stockfish = StockfishService();
  final _screenCapture = ScreenCaptureService();

  AppStatus _status = AppStatus.idle;
  ChessApp? _selectedApp;
  String? _currentFen;
  AnalysisResult? _lastResult;
  String? _errorMessage;
  bool _autoCapture = false;
  bool _engineReady = false;

  AppStatus get status => _status;
  ChessApp? get selectedApp => _selectedApp;
  String? get currentFen => _currentFen;
  AnalysisResult? get lastResult => _lastResult;
  String? get errorMessage => _errorMessage;
  bool get autoCapture => _autoCapture;
  bool get engineReady => _engineReady;

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedAppId = prefs.getString('selected_app_id');
      if (savedAppId != null) {
        _selectedApp = kSupportedApps.firstWhere(
          (a) => a.id == savedAppId,
          orElse: () => kSupportedApps.last,
        );
      }
      notifyListeners();

      // Stockfish'i arka planda başlat, crash olursa sessizce geç
      await _stockfish.initialize();
      _engineReady = true;
      notifyListeners();
    } catch (e) {
      _engineReady = false;
      debugPrint('Init error: $e');
      notifyListeners();
    }
  }

  void selectApp(ChessApp app) async {
    _selectedApp = app;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_app_id', app.id);
    notifyListeners();
  }

  Future<void> captureAndAnalyze() async {
    if (_selectedApp == null) {
      _setError('Lütfen önce bir satranç uygulaması seçin.');
      return;
    }

    _setStatus(AppStatus.capturing);

    try {
      final screenshot = await _screenCapture.captureScreen();
      if (screenshot == null) {
        _setError('Ekran yakalama izni verilmedi veya başarısız oldu.');
        return;
      }

      _setStatus(AppStatus.analyzing);

      final fen = await _boardDetection.detectFenFromScreenshot(
        screenshot,
        _selectedApp!.strategy,
      );

      if (fen == null) {
        _setError('Satranç tahtası ekranda bulunamadı.');
        return;
      }

      _currentFen = fen;

      if (_engineReady) {
        final result = await _stockfish.analyze(fen);
        _lastResult = result;
      }

      _setStatus(AppStatus.done);
    } catch (e) {
      _setError('Hata: $e');
    }
  }

  void toggleAutoCapture() {
    _autoCapture = !_autoCapture;
    if (_autoCapture) _startAutoCapture();
    notifyListeners();
  }

  void _startAutoCapture() async {
    await for (final _ in Stream.periodic(const Duration(seconds: 2))) {
      if (!_autoCapture) break;
      if (_status == AppStatus.idle || _status == AppStatus.done) {
        await captureAndAnalyze();
      }
    }
  }

  void reset() {
    _status = AppStatus.idle;
    _currentFen = null;
    _lastResult = null;
    _errorMessage = null;
    notifyListeners();
  }

  void _setStatus(AppStatus s) {
    _status = s;
    _errorMessage = null;
    notifyListeners();
  }

  void _setError(String msg) {
    _status = AppStatus.error;
    _errorMessage = msg;
    notifyListeners();
  }

  @override
  void dispose() {
    _stockfish.dispose();
    super.dispose();
  }
}
