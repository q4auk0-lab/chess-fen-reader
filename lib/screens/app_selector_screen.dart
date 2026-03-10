// lib/screens/app_selector_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/chess_app.dart';
import '../services/app_state.dart';

class AppSelectorScreen extends StatelessWidget {
  const AppSelectorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        title: const Text(
          '♟ Satranç Uygulaması Seç',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Açıklama
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F3460).withOpacity(0.5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Seçtiğiniz uygulamaya göre tahta tespiti optimize edilir.',
                    style: TextStyle(color: Colors.blue, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),

          // Uygulama Listesi
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: kSupportedApps.length,
              itemBuilder: (context, index) {
                final app = kSupportedApps[index];
                final isSelected = state.selectedApp?.id == app.id;
                final isDivider = index == kSupportedApps.length - 2;

                return Column(
                  children: [
                    if (isDivider) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Divider(color: Colors.white24),
                      ),
                    ],
                    _AppTile(
                      app: app,
                      isSelected: isSelected,
                      onTap: () {
                        state.selectApp(app);
                        Navigator.pop(context);
                      },
                    ),
                    const SizedBox(height: 8),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AppTile extends StatelessWidget {
  final ChessApp app;
  final bool isSelected;
  final VoidCallback onTap;

  const _AppTile({
    required this.app,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF0F3460)
              : const Color(0xFF16213E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.green : Colors.white12,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // İkon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  _appEmoji(app.id),
                  style: const TextStyle(fontSize: 24),
                ),
              ),
            ),
            const SizedBox(width: 14),

            // İsim ve paket
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    app.name,
                    style: TextStyle(
                      color: isSelected ? Colors.green : Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  if (app.packageName.isNotEmpty)
                    Text(
                      app.packageName,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 11,
                      ),
                    ),
                  Text(
                    _strategyLabel(app.strategy),
                    style: const TextStyle(
                      color: Colors.amber,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),

            // Seçim göstergesi
            if (isSelected)
              const Icon(Icons.check_circle, color: Colors.green, size: 22),
          ],
        ),
      ),
    );
  }

  String _appEmoji(String id) {
    const map = {
      'chess_com': '♟',
      'lichess': '🐴',
      'chess_kid': '🧒',
      'chessbase': '📊',
      'stockfish_app': '🐟',
      'shredder': '⚔️',
      'chess_tempo': '⏱',
      'follow_chess': '👁',
      'other': '🎯',
    };
    return map[id] ?? '♟';
  }

  String _strategyLabel(BoardDetectionStrategy s) {
    switch (s) {
      case BoardDetectionStrategy.chessCom:
        return '✓ Optimize edilmiş tespit';
      case BoardDetectionStrategy.lichess:
        return '✓ Optimize edilmiş tespit';
      case BoardDetectionStrategy.chessKid:
        return '✓ Optimize edilmiş tespit';
      case BoardDetectionStrategy.chessBase:
        return '✓ Optimize edilmiş tespit';
      default:
        return '○ Genel tahta tespiti';
    }
  }
}
