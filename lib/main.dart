import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/connect_blu/connect_blu_screen.dart';
import 'screens/weighing_station/weighing_station_screen.dart';
import 'screens/weighing_warehouse/weighing_warehouse_screen.dart';
import 'screens/login/login_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/history/history_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/pending_sync/pending_sync_screen.dart';
import 'services/settings_service.dart';
import 'services/language_service.dart';
import 'screens/settings/settings_screen.dart';
import 'services/database_helper.dart';
/*import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';*/

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  /* này dùng để xóa database cũ khi cần thiết
  final dir = await getApplicationDocumentsDirectory();
  final path = join(dir.path, "weighing_app.db");
  await deleteDatabase(path);
  if (kDebugMode) {
   print('🗑️ Database cũ đã bị xóa.');
  }
  */
  await SettingsService().init();
  await LanguageService().initialize();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // Khi app bị đóng hoàn toàn (paused, detached), xóa state
    if (state == AppLifecycleState.detached ||
        state == AppLifecycleState.paused) {
      _clearWeighingState();
    }
  }

  Future<void> _clearWeighingState() async {
    try {
      final db = await DatabaseHelper().database;
      await db.delete('WeighingState');
    } catch (e) {
      // Ignore errors when clearing state
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Weighing Station App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color.fromARGB(
          255,
          215,
          239,
          255,
        ), // Màu nền
      ),
      debugShowCheckedModeBanner: false,
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
        '/scan': (context) => const ScanScreen(),
        '/weighing_station': (context) => const WeighingStationScreen(),
        '/weighing_warehouse': (context) => const WeighingWarehouseScreen(),
        '/history': (context) => const HistoryScreen(),
        '/dashboard': (context) => const DashboardScreen(),
        '/pending_sync': (context) => const PendingSyncScreen(),
        '/settings': (context) => const SettingsScreen(),
      },
    );
  }
}
