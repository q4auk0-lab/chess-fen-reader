// lib/services/screen_capture_service.dart
import 'dart:typed_data';
import 'package:flutter/services.dart';

class ScreenCaptureService {
  static const _channel = MethodChannel('com.chessfen.app/screen_capture');
  bool _hasPermission = false;

  /// MediaProjection izni iste
  Future<bool> requestPermission() async {
    try {
      final granted = await _channel.invokeMethod<bool>('requestPermission');
      _hasPermission = granted ?? false;
      return _hasPermission;
    } catch (e) {
      return false;
    }
  }

  /// Mevcut ekranın görüntüsünü al
  Future<Uint8List?> captureScreen() async {
    if (!_hasPermission) {
      final granted = await requestPermission();
      if (!granted) return null;
    }

    try {
      final bytes = await _channel.invokeMethod<Uint8List>('captureScreen');
      return bytes;
    } on PlatformException catch (e) {
      print('Screen capture error: ${e.message}');
      return null;
    }
  }

  /// Sürekli yakalama başlat (her N milisaniyede bir)
  Stream<Uint8List> continuousCapture({int intervalMs = 1000}) async* {
    while (true) {
      final screenshot = await captureScreen();
      if (screenshot != null) yield screenshot;
      await Future.delayed(Duration(milliseconds: intervalMs));
    }
  }

  bool get hasPermission => _hasPermission;
}
