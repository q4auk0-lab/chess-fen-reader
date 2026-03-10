# ♟ Chess FEN Reader — Android APK

Ekrandaki herhangi bir satranç uygulamasını okuyup **FEN string** çıkaran ve **Stockfish** ile otomatik analiz eden Flutter uygulaması.

---

## 🎯 Özellikler

- **9 desteklenen uygulama** (Chess.com, Lichess, ChessKid, ChessBase, vb.)
- **Otomatik tahta tespiti** — her uygulama için optimize renk profili
- **FEN çıktısı** — tek tuşla panoya kopyalama
- **Stockfish entegrasyonu** — en iyi hamle + değerlendirme + derinlik
- **Otomatik mod** — her 2 saniyede bir pozisyonu günceller
- **Koyu tema** — göze dost arayüz

---

## 🏗 Proje Yapısı

```
chess_fen_reader/
├── lib/
│   ├── main.dart                        # Uygulama giriş noktası
│   ├── models/
│   │   └── chess_app.dart               # Desteklenen uygulamalar + modeller
│   ├── services/
│   │   ├── app_state.dart               # Provider state yönetimi
│   │   ├── board_detection_service.dart # Görüntü → FEN dönüşümü
│   │   ├── stockfish_service.dart       # Stockfish motor entegrasyonu
│   │   └── screen_capture_service.dart  # MediaProjection ekran yakalama
│   └── screens/
│       ├── home_screen.dart             # Ana ekran
│       └── app_selector_screen.dart     # Uygulama seçim listesi
├── android/
│   └── app/src/main/
│       ├── kotlin/com/chessfen/app/
│       │   └── MainActivity.kt          # Native MediaProjection kodu
│       └── AndroidManifest.xml          # İzinler
└── pubspec.yaml                         # Bağımlılıklar
```

---

## 🚀 Kurulum & Build

### Gereksinimler
- Flutter 3.19+
- Android Studio veya VS Code
- Android SDK (minSdk 21, targetSdk 34)

### Adımlar

```bash
# 1. Bağımlılıkları yükle
flutter pub get

# 2. Debug APK oluştur
flutter build apk --debug

# 3. Release APK oluştur (imzalama gerekir)
flutter build apk --release

# APK konumu:
# build/app/outputs/flutter-apk/app-release.apk
```

### Cihaza Yükle

```bash
flutter install
# veya
adb install build/app/outputs/flutter-apk/app-release.apk
```

---

## 📱 Kullanım

1. Uygulamayı aç → **"Uygulama Seçilmedi"** kartına dokun
2. Listeden satranç uygulamanı seç (Chess.com, Lichess vb.)
3. Satranç uygulamasına geç → tahtanın tam ekranda göründüğünden emin ol
4. Chess FEN Reader'a geri dön → **"Ekranı Yakala & FEN Üret"** butonuna bas
5. Ekran yakalandıktan birkaç saniye sonra:
   - 🔢 **FEN string** görünür → kopyala butonuyla panoya al
   - 🐟 **Stockfish analizi** görünür → en iyi hamle + skor

### Otomatik Mod
Sağ üstteki **"Oto"** toggle'ı açın → uygulama her 2 saniyede bir pozisyonu günceller.

---

## ⚙️ Nasıl Çalışır?

### 1. Ekran Yakalama (MediaProjection API)
```
Kullanıcı izni → MediaProjection → VirtualDisplay → ImageReader → PNG bytes
```
Android 10+ için `FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION` zorunludur.

### 2. Tahta Tespiti
```
PNG → image paketi ile decode
    → Renk tabanlı tahta alanı tespiti (her uygulama için özel renk profili)
    → 8×8 karelere bölme
    → Her karede parlaklık analizi → taş tipi tahmini
    → FEN string üretimi
```

**Chess.com renkleri:** `#769656` (koyu) / `#eeeed2` (açık)  
**Lichess renkleri:** `#466a8c` (koyu) / `#d3dee4` (açık)

### 3. Stockfish Analizi
```
FEN → "position fen <fen>" → "go depth 20 movetime 3000"
    → UCI çıktısı parse → bestmove + evaluation + PV
```

---

## 🔧 Yeni Uygulama Ekleme

`lib/models/chess_app.dart` dosyasında `kSupportedApps` listesine ekle:

```dart
ChessApp(
  id: 'yeni_uygulama',
  name: 'Yeni Satranç Uygulaması',
  packageName: 'com.yeni.uygulama',
  iconAsset: 'assets/apps/generic.png',
  strategy: BoardDetectionStrategy.generic,
),
```

Özel renk profili eklemek için `BoardDetectionStrategy`'ye yeni enum değeri ekle ve `board_detection_service.dart`'ta `_findBoardArea` metodunu güncelle.

---

## 📋 İzinler (AndroidManifest.xml)

| İzin | Neden |
|------|-------|
| `FOREGROUND_SERVICE` | Ekran yakalama servisi |
| `FOREGROUND_SERVICE_MEDIA_PROJECTION` | Android 10+ zorunlu |
| `SYSTEM_ALERT_WINDOW` | Overlay pencere (opsiyonel) |

---

## 🐛 Bilinen Sınırlamalar

- **Tahta tespiti** renk tabanlıdır; özel tema kullanan uygulamalarda başarı oranı düşebilir
- **Taş tanıma** parlaklık analizi ile çalışır; ML tabanlı tanıma için `google_mlkit_image_labeling` paketi eklenebilir
- **MediaProjection** kullanıcı onayı gerektirir — her uygulama yeniden başlangıcında sorulabilir

---

## 🚀 Gelecek Geliştirmeler

- [ ] ML Kit ile gelişmiş taş tanıma (template matching)
- [ ] Lichess/Chess.com API entegrasyonu (doğrudan FEN çekme)
- [ ] Overlay mod — satranç uygulamasının üstünde sonuç gösterme
- [ ] PGN export
- [ ] Çoklu dil desteği

---

## 📄 Lisans

MIT License
