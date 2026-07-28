# أهل الجنة · Ahl Jannah

> **"Convey from me, even if it is only one verse."** — The Messenger of Allah ﷺ

Ahl Jannah is a comprehensive offline Islamic companion app built with Flutter. It provides accurate prayer times, a full Quran reader, Qibla direction finder, Adhkar (remembrances) with a digital Tasbeeh counter, and a Hadith browser — all without requiring an internet connection for daily use.

This application is developed as a continuous charity (صدقة جارية), hoping that its reward extends to all whom Allah has written to enter Paradise, from our father Adam (peace be upon him) until the Day of Resurrection.

## Features

### 🕌 Prayer Times
- Accurate prayer times calculated via the Aladhan API with automatic regional method detection (MWL, ISNA, Umm Al-Qura, Egyptian, Karachi, UOIF, and more)
- Monthly caching so times are available offline after the first fetch
- Adhan notifications with full or short Adhan sound options, including a dedicated Fajr Adhan
- Configurable reminders before each prayer
- Background rescheduling via Workmanager to ensure notifications fire daily
- Hijri date display

### 📖 Quran Reader
- Complete Mushaf with all 604 pages rendered in Uthmani script
- Dual reading modes: Mushaf (continuous flowing text) and Study (per-ayah card layout with translations)
- Portrait paginated mode and landscape infinite scroll
- Full-text search across the entire Quran with diacritic-aware matching
- Page and ayah bookmarks with a dedicated management page
- Automatic reading position tracking — resume exactly where you left off
- Adjustable Arabic font size, translation toggle (English / French)
- Copy, share, and bookmark individual ayahs

### 🧭 Qibla Compass
- Real-time Qibla direction using the device compass and GPS
- Animated compass with Kaaba pointer and accuracy indicator
- Works offline after location is obtained

### 📿 Adhkar & Tasbeeh
- Comprehensive Adhkar catalog (morning, evening, and daily remembrances)
- Digital Tasbeeh counter with multiple counting modes (33, 99, 100, custom, unlimited)
- Haptic feedback on every count
- Session timer, per-dhikr collection management, and daily/lifetime statistics
- Morning and evening Adhkar reminder notifications

### 📚 Hadith Library
- Bundled Hadith collections (Sahih Bukhari, Hadith Qudsi)
- Global search across all collections with debounced input
- Per-collection browsing with infinite scroll pagination

### 🎨 Customization
- Three color palettes: Emerald, Ocean, Desert
- Light, dark, and system theme modes
- Language support: English, العربية, Français
- Multiple calculation methods and Asr madhab options

## Architecture

```
lib/
├── core/                    # Shared infrastructure
│   ├── constants/           # App-wide constants and SP keys
│   ├── di/                  # Dependency injection (get_it + injectable)
│   ├── router/              # GoRouter with stateful shell navigation
│   ├── theme/               # Material 3 theming, palettes, text styles
│   ├── utils/               # BuildContext extensions
│   └── widgets/             # Shared widgets (scaffold, permission prompt)
├── features/
│   ├── adhkar/              # Adhkar catalog, Tasbeeh counter, statistics
│   ├── hadith/              # Hadith browser with bundled collections
│   ├── prayer/              # Prayer times, Adhan, notifications, background
│   ├── qibla/               # Qibla compass with animated UI
│   ├── quran/               # Quran reader, bookmarks, search
│   └── settings/            # Language, theme, appearance preferences
└── l10n/                    # Localization (en, ar, fr)
```

Each feature follows clean architecture with three layers:
- **Domain** — Entities, repository contracts, use cases
- **Data** — Repository implementations, data sources, models
- **Presentation** — BLoC/Cubit state management, pages, widgets

## Tech Stack

| Category          | Technology                                      |
| ----------------- | ----------------------------------------------- |
| Framework         | Flutter (Dart)                                  |
| State Management  | BLoC / Cubit (`flutter_bloc`)                   |
| DI                | `get_it` + `injectable`                         |
| Routing           | `go_router` with `StatefulShellRoute`           |
| Database          | `drift` (SQLite ORM) for Quran data             |
| Storage           | `shared_preferences` for settings and bookmarks |
| Notifications     | `flutter_local_notifications`                   |
| Background Tasks  | `workmanager`                                   |
| Prayer Times      | Aladhan API + local caching                     |
| Localization      | Flutter ARB (`flutter_localizations`)           |

## Getting Started

1. **Prerequisites**: Flutter SDK ^3.11.5
2. **Clone and install**:
   ```bash
   git clone https://github.com/your-username/ahl_jannah.git
   cd ahl_jannah
   flutter pub get
   ```
3. **Generate code**:
   ```bash
   flutter pub run build_runner build --delete-conflicting-outputs
   flutter gen-l10n
   ```
4. **Run**:
   ```bash
   flutter run
   ```

## Acknowledgments

All praise is due to Allah, Lord of the Worlds, for His apparent and hidden blessings. It is by His grace alone that this work was inspired and completed. We ask Him to accept it as a purely sincere deed for His noble face, to make it a cause of guidance and steadfastness for Muslims, and to place it in the scale of good deeds on the Day of Resurrection.

## License

This project is distributed as an open-source initiative, hoping to be a continuous charity. Use it, learn from it, and share it — and may Allah reward you.
