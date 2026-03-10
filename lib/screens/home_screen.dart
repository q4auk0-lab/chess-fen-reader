// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../models/chess_app.dart';
import 'app_selector_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        title: const Row(
          children: [
            Text('♟', style: TextStyle(fontSize: 22)),
            SizedBox(width: 8),
            Text(
              'Chess FEN Reader',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        actions: [
          // Otomatik mod toggle
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              children: [
                Text(
                  'Oto',
                  style: TextStyle(
                    color: state.autoCapture ? Colors.green : Colors.white54,
                    fontSize: 12,
                  ),
                ),
                Switch(
                  value: state.autoCapture,
                  onChanged: (_) => state.toggleAutoCapture(),
                  activeColor: Colors.green,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Uygulama seçici kart
            _AppSelectorCard(state: state),
            const SizedBox(height: 16),

            // Ana yakalama butonu
            _CaptureButton(state: state),
            const SizedBox(height: 16),

            // Sonuç kartları
            if (state.currentFen != null) ...[
              _FenCard(fen: state.currentFen!),
              const SizedBox(height: 12),
            ],
            if (state.lastResult != null) ...[
              _AnalysisCard(result: state.lastResult!),
              const SizedBox(height: 12),
            ],

            // Hata mesajı
            if (state.status == AppStatus.error && state.errorMessage != null)
              _ErrorCard(message: state.errorMessage!),

            // Nasıl kullanılır
            if (state.status == AppStatus.idle && state.lastResult == null)
              _HowToUse(),
          ],
        ),
      ),
    );
  }
}

// ─── App Selector Card ───────────────────────────────────────────────────────
class _AppSelectorCard extends StatelessWidget {
  final AppState state;
  const _AppSelectorCard({required this.state});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AppSelectorScreen()),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF16213E),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: state.selectedApp != null ? Colors.green.withOpacity(0.5) : Colors.white12,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  state.selectedApp != null ? '♟' : '➕',
                  style: const TextStyle(fontSize: 26),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    state.selectedApp?.name ?? 'Uygulama Seçilmedi',
                    style: TextStyle(
                      color: state.selectedApp != null ? Colors.white : Colors.white54,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    state.selectedApp != null
                        ? 'Dokunarak değiştir'
                        : 'Satranç uygulamasını seçin',
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white38),
          ],
        ),
      ),
    );
  }
}

// ─── Capture Button ──────────────────────────────────────────────────────────
class _CaptureButton extends StatelessWidget {
  final AppState state;
  const _CaptureButton({required this.state});

  @override
  Widget build(BuildContext context) {
    final isLoading = state.status == AppStatus.capturing ||
                      state.status == AppStatus.analyzing;

    return GestureDetector(
      onTap: isLoading ? null : () => state.captureAndAnalyze(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: 64,
        decoration: BoxDecoration(
          gradient: isLoading
              ? null
              : const LinearGradient(
                  colors: [Color(0xFF2ECC71), Color(0xFF27AE60)],
                ),
          color: isLoading ? Colors.white12 : null,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isLoading
              ? null
              : [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Center(
          child: isLoading
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      state.status == AppStatus.capturing
                          ? 'Ekran yakalanıyor...'
                          : 'Stockfish analiz ediyor...',
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                )
              : const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.photo_camera, color: Colors.white, size: 22),
                    SizedBox(width: 10),
                    Text(
                      'Ekranı Yakala & FEN Üret',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ─── FEN Card ────────────────────────────────────────────────────────────────
class _FenCard extends StatelessWidget {
  final String fen;
  const _FenCard({required this.fen});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '🔢 FEN String',
                style: TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: fen));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('FEN kopyalandı! 📋'),
                      duration: Duration(seconds: 2),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.copy, color: Colors.blue, size: 14),
                      SizedBox(width: 4),
                      Text('Kopyala', style: TextStyle(color: Colors.blue, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              fen,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'monospace',
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Analysis Card ───────────────────────────────────────────────────────────
class _AnalysisCard extends StatelessWidget {
  final AnalysisResult result;
  const _AnalysisCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final evalColor = result.evaluation > 0 ? Colors.green : 
                      result.evaluation < 0 ? Colors.red : Colors.white;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.amber.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🐟 Stockfish Analizi',
            style: TextStyle(
              color: Colors.amber,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 14),

          // En iyi hamle
          _InfoRow(
            label: 'En İyi Hamle',
            value: result.bestMove.toUpperCase(),
            valueColor: Colors.green,
            isLarge: true,
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: _InfoRow(
                  label: 'Değerlendirme',
                  value: result.evalDisplay,
                  valueColor: evalColor,
                ),
              ),
              Expanded(
                child: _InfoRow(
                  label: 'Derinlik',
                  value: 'D${result.depth}',
                  valueColor: Colors.white70,
                ),
              ),
            ],
          ),

          if (result.pv.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'Ana Varyasyon',
              style: TextStyle(color: Colors.white38, fontSize: 11),
            ),
            const SizedBox(height: 4),
            Text(
              result.pv.take(8).join(' '),
              style: const TextStyle(
                color: Colors.white54,
                fontFamily: 'monospace',
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  final bool isLarge;

  const _InfoRow({
    required this.label,
    required this.value,
    required this.valueColor,
    this.isLarge = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: isLarge ? 24 : 16,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }
}

// ─── Error Card ──────────────────────────────────────────────────────────────
class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.red, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── How To Use ──────────────────────────────────────────────────────────────
class _HowToUse extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Nasıl Kullanılır?',
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          for (final step in [
            ('1', 'Yukarıdan satranç uygulamanızı seçin'),
            ('2', 'Satranç uygulamasına geçin ve tahtanın tam görünmesini sağlayın'),
            ('3', 'Geri dönüp "Ekranı Yakala" butonuna basın'),
            ('4', 'FEN otomatik çıkarılır ve Stockfish\'e gönderilir'),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22, height: 22,
                    decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Center(
                      child: Text(
                        step.$1,
                        style: const TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      step.$2,
                      style: const TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
