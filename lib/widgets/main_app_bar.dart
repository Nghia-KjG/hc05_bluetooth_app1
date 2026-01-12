import 'package:flutter/material.dart';
import '../services/bluetooth_service.dart';
import 'bluetooth_status_action.dart';
import '../services/auth_service.dart';
import '../services/server_status_service.dart';
import '../services/language_service.dart';

class MainAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final Widget? leading;
  final BluetoothService bluetoothService;

  const MainAppBar({
    super.key,
    required this.title,
    required this.bluetoothService,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: LanguageService(),
      builder: (context, child) {
        final lang = LanguageService();
        return AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          title: Text(
            title,
            style: const TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
          leading: leading,
          actions: [
            // --- 1. Menu người dùng ---
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'logout') {
                  bluetoothService.disconnect();
                  AuthService().logout();
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    '/login',
                    (Route<dynamic> route) => false,
                  );
                } else if (value == 'settings') {
                  Navigator.of(context).pushNamed('/settings');
                }
              },
              icon: const Icon(Icons.person, color: Colors.black, size: 30.0),
              tooltip: lang.translate('options'),
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                //Cài đặt
                PopupMenuItem<String>(
                  value: 'settings',
                  child: Row(
                    children: [
                      Icon(Icons.settings, color: Colors.blue.shade700),
                      const SizedBox(width: 12),
                      Text(lang.translate('settings')),
                    ],
                  ),
                ),
                //Đăng xuất
                PopupMenuItem<String>(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout, color: Colors.red.shade700),
                      const SizedBox(width: 12),
                      Text(lang.translate('logout')),
                    ],
                  ),
                ),
              ],
            ),

            // --- 2. Tên đăng nhập ---
            AnimatedBuilder(
              animation: AuthService(),
              builder: (context, child) {
                final auth = AuthService();
                if (!auth.isLoggedIn) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Center(
                    child: Text(
                      '${auth.userName} (${auth.mUserID})',
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w500,
                        fontSize: 20,
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(width: 8),

            // --- 3. Bluetooth ---
            BluetoothStatusAction(bluetoothService: bluetoothService),
            const SizedBox(width: 10),

            // --- 4. Server backend ---
            AnimatedBuilder(
              animation: ServerStatusService(),
              builder: (context, child) {
                final server = ServerStatusService();
                final connected = server.isServerConnected;

                return Padding(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: Icon(
                    connected ? Icons.wifi : Icons.wifi_off,
                    color: connected ? Colors.green : Colors.red,
                    size: 28,
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
