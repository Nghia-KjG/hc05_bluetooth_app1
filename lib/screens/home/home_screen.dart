import 'package:flutter/material.dart';
import '../../services/bluetooth_service.dart';
import '../../widgets/main_app_bar.dart';
import '../../services/notification_service.dart';
import '../../services/server_status_service.dart';
import '../../services/language_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // HomeScreen cũng cần service để truyền cho AppBar
  final BluetoothService _bluetoothService = BluetoothService();

  @override
  void initState() {
    super.initState();
    _initServerMonitoring(); // 👈 Gọi hàm khởi động kiểm tra server
  }

  Future<void> _initServerMonitoring() async {
    try {
      await ServerStatusService().startMonitoring();
    } catch (e) {
      // Có thể log hoặc hiển thị toast nếu muốn
      debugPrint('Lỗi khi khởi động theo dõi server: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: LanguageService(),
      builder: (context, child) {
        final lang = LanguageService();
        return Scaffold(
          // 1. Tái sử dụng MainAppBar
          appBar: MainAppBar(
            title: lang.translate('weighing_program'),
            bluetoothService: _bluetoothService,
            // Không truyền 'leading', AppBar sẽ không có nút back
          ),
          
          // 2. Màu nền xanh nhạt
          backgroundColor: const Color(0xFFBCE0F5), // Màu xanh từ ảnh
          
          body: Column(
            children: [
              Expanded(
                child: Center(
                  // 3. Hàng chứa 3 nút chức năng
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildMenuButton(
                        context: context,
                        iconPath: 'lib/assets/images/weight-scale.png', 
                        label: lang.translate('weighing_station'),
                        onPressed: () async {
                          if (_bluetoothService.connectedDevice.value != null) {
                            Navigator.of(context).pushNamed('/weighing_station');
                          } else {
                            NotificationService().showToast(
                              context: context,
                              message: lang.translate('not_connected'),
                              type: ToastType.info,
                            );

                            await Future.delayed(const Duration(seconds: 3));

                            if (context.mounted) {
                              Navigator.of(context).pushNamed('/scan');
                            }
                          }
                        },
                      ),
                      _buildMenuButton(
                        context: context,
                        iconPath: 'lib/assets/images/dashboard.png',
                        label: lang.translate('dashboard'),
                        onPressed: () {
                          Navigator.of(context).pushNamed('/dashboard');
                        },
                      ),
                      _buildMenuButton(
                        context: context,
                        iconPath: 'lib/assets/images/history.png',
                        label: lang.translate('history'),
                        onPressed: () {
                          Navigator.of(context).pushNamed('/history');
                        },
                      ),
                      _buildMenuButton(
                        context: context,
                        iconPath: 'lib/assets/images/sync.png',
                        label: lang.translate('pending_data'),
                        onPressed: () {
                          // Đi đến trang PendingSyncScreen
                          Navigator.of(context).pushNamed('/pending_sync');
                        },
                  ),
                ],
              ),
            ),
          ),
          
              // Footer
              InkWell(
                onTap: () {
                  Navigator.of(context).pushNamed('/weighing_station');
                },
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text(
                    '${lang.translate('app_version')} 0.0.0',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[800],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Helper tạo nút chức năng
  Widget _buildMenuButton({
    required BuildContext context,
    required String iconPath,
    required String label,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              iconPath,
              width: 100,
              height: 100,
            ),
            const SizedBox(height: 16),
            Text(
              label,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF333333),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
