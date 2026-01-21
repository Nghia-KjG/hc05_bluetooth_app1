# Copilot Instructions for HC-05 Weighing Station App

## Project Overview

**HC-05 Weighing Station** is an offline-capable Flutter app for industrial weight measurements via Bluetooth. It reads real-time data from HC-05 scales, detects weight stability, auto-completes work orders, and syncs data with a backend API when online.

## Architecture Overview

### Core Components

**Services** (Singleton pattern, `lib/services/`)
- `BluetoothService`: Android MethodChannel/EventChannel for HC-05 scan/connect/data streams. Uses `ValueNotifier` for state (`scanResults`, `connectedDevice`, `currentWeight`).
- `WeightStabilityMonitor`: Tracks weight samples; triggers `onStable` callback when readings stabilize within ±20g threshold for configured duration (default 5s).
- `SyncService`: Two-way API sync using HTTP; manages offline `HistoryQueue` table for work orders pending upload.
- `DatabaseHelper` (SQLite): Offline cache via sqflite (`VmlWorkS`, `VmlWork`, `HistoryQueue`, `VmlPersion`, etc.).
- `SettingsService`: Stores user preferences (auto-complete enabled, stabilization delay 3/5/10s, audio feedback).
- `AudioService`: Native Android ToneGenerator via MethodChannel for success beeps + `HapticFeedback` vibration.
- `LanguageService`: Vietnamese/English translations; initialized at app startup.
- `NotificationService`: Toast notifications (info/warning/error types).

**Screens** (MVC pattern, `lib/screens/`)
- `WeighingStationScreen`: Main weighing workflow—scan barcode → load work data → set min/max → receive live weight → auto-complete when stable+in-range.
- `LoginScreen`: Authenticates user offline (queries `VmlPersion` table); requires internet for first sync.
- `HomeScreen`: Navigation hub.
- `DashboardScreen`, `HistoryScreen`, `PendingSyncScreen`: Analytics/history views.
- `SettingsScreen`: Toggles auto-complete, stabilization delay, audio feedback.

### Key Data Flows

1. **Bluetooth Connection**: `BluetoothService` → EventChannel receives `scanResult`/`status`/`weight` events → UI updates via `ValueNotifier`.
2. **Weight Stability Detection**: Real-time samples → `WeightStabilityMonitor._recentWeights` buffer → checks threshold every 500ms → calls `onStable` when stable.
3. **Auto-Complete Workflow**: Weight stable → delay elapsed → `WeighingStationController.completeWork()` → POST to `/api/sync/work` → log to `HistoryQueue` on success.
4. **Offline Sync**: App periodically syncs via `SyncService`; failed requests queued in `HistoryQueue` with exponential backoff retry.

## Critical Patterns

### State Management
- **ValueNotifier** for reactive updates: `BluetoothService.currentWeight`, `BluetoothService.connectedDevice`.
- **ChangeNotifier** in controllers (e.g., `WeighingStationController`) for UI binding.
- No Provider package—direct service access via singletons.

### Error Handling
- Use `mounted` check before `setState()`/`Navigator` after async operations to prevent crashes when screen is popped.
- Bluetooth disconnection handled in `_onConnectionChange()` callback—**shows toast, does NOT auto-navigate**.
- API failures silently queue to `HistoryQueue`; show toast to user only for critical errors.

### UI Patterns
- **Custom Widgets** for reuse: `CurrentWeightCard`, `ActionMinMax`, `ScanInputField`, `WeighingTable` in `weighing_station/widgets/`.
- **Main App Bar** shared across screens via `MainAppBar` widget.
- Screens use `FocusNode` to manage keyboard (scan input field auto-focuses on screen enter).

### Database Schema
- `VmlWorkS`: Work orders (maCode PK, min/max weight thresholds).
- `HistoryQueue`: Failed API uploads (auto-retried with exponential backoff).
- Single DatabaseHelper instance manages all table CRUD.

## Developer Workflows

### Building & Running
```bash
flutter pub get                    # Install dependencies
flutter run -d <device_id>         # Run on device (Android physical preferred for Bluetooth)
```

### Environment Setup
- Create `.env` at project root: `API_BASE_URL=http://192.168.X.X:3636`
- Dart 3.7.2+, Flutter stable (tested on Flutter 3.24+).

### Debugging Bluetooth
- Enable simulation mode in `WeighingStationScreen._startSimulatingWeight()` for testing without hardware.
- Check Android logcat: `adb logcat | grep -i bluetooth` or `adb logcat | grep -i "AudioDebug"` for native audio logs.
- Verify HC-05 device appears in scan results; check device MAC address against `knownDeviceNames` cache.

### Testing Auto-Complete Feature
1. Enable in Settings ("Auto-complete enabled" toggle).
2. Scan barcode to load work order.
3. Place item on scale; monitor weight samples in real-time.
4. After stabilization threshold (5s) + auto-complete delay (2s), work auto-completes.
5. Verify beep + vibration triggers (Android device only, not emulator).

### Database Inspection
```bash
# On device (requires app package name: com.example.hc05_bluetooth_app)
adb shell "run-as com.example.hc05_bluetooth_app cp /data/data/com.example.hc05_bluetooth_app/databases/weighing_app.db /sdcard/"
adb pull /sdcard/weighing_app.db
sqlite3 weighing_app.db ".schema"
```

### API Integration
- All sync endpoints hit `$API_BASE_URL/api/sync/*` (persons, devices, work, history).
- Request format: POST/GET with JSON body.
- On failure: log to `HistoryQueue` with timestamp + retry strategy (exponential backoff, max 5 retries).

## Project-Specific Conventions

### Naming & File Structure
- Services: Lower camelCase + `_service.dart` (e.g., `bluetooth_service.dart`).
- Screens: Folder-per-screen with `_screen.dart` + `controller/` + `widgets/` subdirs (e.g., `lib/screens/weighing_station/weighing_station_screen.dart`).
- Models: One class per file in `lib/models/` (e.g., `bluetooth_device.dart`).

### Localization
- Use `LanguageService().translate('key')` for all user-facing text; avoid hardcoded strings.
- Translations stored in `LanguageService` class as maps (Vietnamese + English).

### Audio & Haptics
- `AudioService.playSuccessBeep()` calls `HapticFeedback.heavyImpact()` + MethodChannel `playTone()` + `HapticFeedback.mediumImpact()` in sequence.
- Android MainKotlin.kt: Receives "playTone" MethodChannel call → ToneGenerator(STREAM_NOTIFICATION) plays CDMA_CONFIRM tone for 200ms.

### Native Integration
- Android: Bluetooth via MethodChannel `'com.hc.bluetooth.method_channel'` + EventChannel `'com.hc.bluetooth.event_channel'`.
- Android: Audio via MethodChannel `'com.hc.audio.channel'` (ToneGenerator in MainActivity.kt).
- iOS: Bluetooth not yet implemented (HC-05 is Android-specific).

## Key Files to Know

| File | Purpose |
|------|---------|
| [lib/main.dart](lib/main.dart) | App entry; initializes `.env`, SettingsService, LanguageService. |
| [lib/services/bluetooth_service.dart](lib/services/bluetooth_service.dart) | Singleton for HC-05 scan/connect/data. |
| [lib/services/weight_stability_monitor.dart](lib/services/weight_stability_monitor.dart) | Detects weight stability via buffer + threshold. |
| [lib/services/sync_service.dart](lib/services/sync_service.dart) | Manages API sync + offline HistoryQueue. |
| [lib/services/settings_service.dart](lib/services/settings_service.dart) | Stores user preferences (auto-complete, delays, audio). |
| [lib/screens/weighing_station/weighing_station_screen.dart](lib/screens/weighing_station/weighing_station_screen.dart) | Main workflow UI; uses WeighingStationController. |
| [lib/screens/weighing_station/controllers/weighing_station_controller.dart](lib/screens/weighing_station/controllers/weighing_station_controller.dart) | Orchestrates scan → load → weigh → complete. |
| [lib/services/database_helper.dart](lib/services/database_helper.dart) | SQLite schema + CRUD for all tables. |
| [README.md](README.md) | High-level feature overview + architecture summary. |

## Common Development Tasks

### Adding a New Setting
1. Add field to `SettingsService._settings` dict + getter/setter.
2. Add toggle/slider UI to `SettingsScreen`.
3. Bind to controller via `_onSettingsChanged()` listener if reactive (e.g., auto-complete toggle).

### Modifying Weight Stability Logic
1. Edit `WeightStabilityMonitor._checkStability()` in [lib/services/weight_stability_monitor.dart](lib/services/weight_stability_monitor.dart).
2. Adjust `_stabilityThreshold` (0.02 = ±20g) or `_stabilizationDelay` as needed.
3. Test via `_startSimulatingWeight()` simulation in WeighingStationScreen.

### Adding API Endpoints
1. Create sync method in `SyncService` (e.g., `syncNewTable()`).
2. On failure, insert record into `HistoryQueue` with retry logic.
3. Call from appropriate screen's `initState()` or periodic timer.

### Fixing Bluetooth Data Parsing
1. Check Android native side: `MainActivity.kt` EventChannel sends raw data.
2. Debug Dart: inspect `_onEvent()` switch case in `BluetoothService`.
3. Verify data format: weight values arrive as strings; parse with `double.parse()`.

## Testing Notes

- **Unit tests**: Run with `flutter test` (test/ folder).
- **Integration**: Test on physical Android device; Bluetooth + vibration unavailable in emulator.
- **Offline mode**: Kill internet → verify HistoryQueue captures failed API calls → restore internet → verify auto-retry.

## Dependencies to Know

| Package | Usage |
|---------|-------|
| `sqflite` | SQLite database. |
| `http` | HTTP requests for API sync. |
| `permission_handler` | Runtime permissions (Bluetooth, location on Android 12+). |
| `device_info_plus` | Detect Android SDK version for SDK-specific permissions. |
| `connectivity_plus` | Check online/offline status. |
| `audioplayers` | Audio playback (currently not heavily used; ToneGenerator on Android preferred). |
| `fl_chart` | Chart visualizations in Dashboard. |
| `provider` | State management (imported but minimal usage; singletons dominate). |
| `flutter_dotenv` | Load `.env` for API_BASE_URL. |

## When Stuck

- **Bluetooth not connecting?** Check Android permissions (Bluetooth scan/connect for SDK 31+), verify HC-05 address in `_knownDeviceNames` cache, inspect logcat for native errors.
- **Weight values not updating?** Verify EventChannel subscription in `BluetoothService.initialize()` is active; check simulated weight trigger in `WeighingStationScreen`.
- **Auto-complete not firing?** Confirm `SettingsService.autoCompleteEnabled == true`, verify weight samples reach `WeightStabilityMonitor` via `addWeightSample()`, check if stabilization delay elapsed.
- **API sync fails silently?** Inspect `HistoryQueue` table; check `_apiBaseUrl` from `.env` is reachable; verify request/response JSON format matches backend expectations.

---

**Last Updated:** Jan 2026 | **Dart:** 3.7.2 | **Flutter:** 3.24+ | **Target:** Android (iOS pending).
