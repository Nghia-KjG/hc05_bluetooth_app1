import 'package:flutter/material.dart';
import '../models/bluetooth_device.dart';
import '../services/bluetooth_service.dart';
import '../services/notification_service.dart';

class BluetoothStatusAction extends StatelessWidget {
  final BluetoothService bluetoothService;

  const BluetoothStatusAction({super.key, required this.bluetoothService});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<BluetoothDevice?>(
      valueListenable: bluetoothService.connectedDevice,
      builder: (context, device, child) {
        final isConnected = (device != null);

        if (isConnected) {
          // 🔵 TRẠNG THÁI: ĐANG KẾT NỐI
          return Row(
            children: [
              Text(
                ' ${device.name}',
                style: const TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.w500,
                  fontSize: 18,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.link, size: 30.0),
                color: Colors.green.shade700,
                tooltip: 'Ngắt kết nối',
                onPressed: () {
                  bluetoothService.disconnect();
                  NotificationService().showToast(
                    context: context,
                    message: 'Đã ngắt kết nối!',
                    type: ToastType.info,
                  );
                },
              ),
            ],
          );
        } else {
          // 🔴 TRẠNG THÁI: CHƯA KẾT NỐI
          return Row(
            children: [
              const Text(
                'Mất kết nối cân',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w500,
                  fontSize: 18,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.link_off, size: 30.0),
                color: Colors.red,
                tooltip: 'Kết nối lại',
                onPressed: () async {
                  // ⚙️ Bật async để dùng await trong callback
                  if (bluetoothService.lastConnectedDevice != null) {
                    NotificationService().showToast(
                      context: context,
                      message: 'Đang kết nối lại...',
                      type: ToastType.info,
                    );
                    bluetoothService.connectToDevice(
                      bluetoothService.lastConnectedDevice!,
                    );
                  } else {
                    if (!context.mounted) return;
                    NotificationService().showToast(
                      context: context,
                      message:
                          'Không thể kết nối lại, đang chuyển sang trang kết nối cân.',
                      type: ToastType.error,
                    );

                    await Future.delayed(const Duration(seconds: 4));

                    if (!context.mounted) return;
                    Navigator.of(context).pushNamed('/scan');
                  }
                },
              ),
            ],
          );
        }
      },
    );
  }
}
