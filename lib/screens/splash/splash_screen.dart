import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../../services/language_service.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../services/update_service.dart';
import 'widgets/update_alert_dialog.dart';
import 'widgets/update_progress_dialog.dart';
//import 'package:shared_preferences/shared_preferences.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final UpdateService _updateService = UpdateService();
  // Theo dõi trạng thái cập nhật để tránh điều hướng sang Login khi đang tải
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    await _checkPermissions();
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    // Kiểm tra cập nhật
    await _checkAndPromptUpdate();

    if (!mounted) return;

    //final prefs = await SharedPreferences.getInstance();
    //final soThe = prefs.getString('soThe');
    // Nếu đang cập nhật (đã chọn "Cập nhật ngay"), KHÔNG điều hướng sang Login
    if (!_isUpdating) {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  Future<void> _checkAndPromptUpdate() async {
    try {
      final versionInfo = await _updateService.checkUpdate();

      if (!mounted) return;

      if (versionInfo.needsUpdate) {
        // Hiển thị dialog thông báo cập nhật
        await _showUpdateDialog(versionInfo);
      }
    } catch (e) {
      // Im lặng nếu lỗi (không ảnh hưởng đến quá trình khởi động)
      debugPrint('❌ Lỗi kiểm tra cập nhật: $e');
    }
  }

  Future<void> _showUpdateDialog(VersionInfo versionInfo) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => UpdateAlertDialog(
        currentVersion: versionInfo.currentVersion,
        latestVersion: versionInfo.latestVersion,
        changelog: versionInfo.changelog,
        onUpdate: () {
          // Đánh dấu đang cập nhật để chặn điều hướng sang Login
          _isUpdating = true;
          Navigator.pop(context);
          _downloadAndInstall(versionInfo.downloadUrl);
        },
        onCancel: () {
          Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _downloadAndInstall(String downloadUrl) async {
    // Hiển thị dialog tải xuống
    if (!mounted) return;

    // Đảm bảo trạng thái cập nhật được bật
    _isUpdating = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => UpdateProgressDialog(
        downloadFuture: (onProgress) => _updateService.downloadUpdate(
          downloadUrl,
          onProgress,
        ),
        onComplete: (apkPath) {
          _installApk(apkPath);
        },
        onError: () {
          _showError('Lỗi tải xuống bản cập nhật');
          // Cho phép tiếp tục vào app nếu tải xuống lỗi
          _isUpdating = false;
        },
      ),
    );
  }

  Future<void> _installApk(String apkPath) async {
    try {
      debugPrint('📦 Cài đặt APK: $apkPath');
      const platform = MethodChannel('com.hc.install.channel');
      await platform.invokeMethod('installApk', {'apkPath': apkPath});
      debugPrint('✅ Đã gọi trình cài đặt');
    } catch (e) {
      debugPrint('❌ Lỗi cài đặt: $e');
      _showError('Lỗi cài đặt bản cập nhật');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _checkPermissions() async {
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final sdkInt = androidInfo.version.sdkInt;
      List<Permission> permissions = [];

      if (sdkInt >= 31) {
        permissions.addAll([
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
          Permission.location,
        ]);
      } else {
        permissions.add(Permission.location);
      }

      if (permissions.isNotEmpty) {
        await permissions.request();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFB0D9F3),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Color.fromARGB(255, 0, 0, 0)),
            const SizedBox(height: 20),
            Text(
              LanguageService().translate('splash_initializing'),
              style: const TextStyle(color: Color.fromARGB(255, 0, 0, 0), fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
