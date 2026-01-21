import 'dart:io';
import 'package:flutter/material.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
//import 'package:shared_preferences/shared_preferences.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    await _checkPermissions();
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    //final prefs = await SharedPreferences.getInstance();
    //final soThe = prefs.getString('soThe');
    Navigator.of(context).pushReplacementNamed('/login');
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
    return const Scaffold(
      backgroundColor: Color(0xFFB0D9F3),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color.fromARGB(255, 0, 0, 0)),
            SizedBox(height: 20),
            Text(
              'Đang khởi tạo ứng dụng...',
              style: TextStyle(color: Color.fromARGB(255, 0, 0, 0), fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
