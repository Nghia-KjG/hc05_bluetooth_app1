import 'package:flutter/material.dart';
import '../models/bluetooth_device.dart';
import '../services/bluetooth_service.dart';
import '../services/notification_service.dart';
import '../services/language_service.dart';

class BluetoothStatusAction extends StatelessWidget {
  final BluetoothService bluetoothService;
  final LanguageService _languageService = LanguageService();

  BluetoothStatusAction({super.key, required this.bluetoothService});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _languageService,
      builder: (context, child) {
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
                    tooltip: _languageService.translate('disconnect_tooltip'),
                    onPressed: () async {
                      // Hiển thị hộp thoại xác nhận
                      final bool? confirmed = await showDialog<bool>(
                        context: context,
                        builder: (BuildContext dialogContext) {
                          return AlertDialog(
                            title: Text(_languageService.translate('confirm_disconnect_title')),
                            content: Text('${_languageService.translate('confirm_disconnect_message')} "${device.name}"?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(dialogContext).pop(false),
                                child: Text(_languageService.translate('cancel')),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.of(dialogContext).pop(true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                ),
                                child: Text(_languageService.translate('disconnect_button')),
                              ),
                            ],
                          );
                        },
                      );

                      // Nếu người dùng xác nhận, thực hiện ngắt kết nối
                      if (confirmed == true && context.mounted) {
                        bluetoothService.disconnect();
                        NotificationService().showToast(
                          context: context,
                          message: _languageService.translate('disconnected_success'),
                          type: ToastType.info,
                        );
                      }
                    },
                  ),
                ],
              );
            } else {
          // 🔴 TRẠNG THÁI: CHƯA KẾT NỐI
          return Row(
            children: [
              Text(
                _languageService.translate('connection_lost_text'),
                style: const TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w500,
                  fontSize: 18,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.link_off, size: 30.0),
                color: Colors.red,
                tooltip: _languageService.translate('reconnect_tooltip'),
                onPressed: () async {
                  // ⚙️ Bật async để dùng await trong callback
                  if (bluetoothService.lastConnectedDevice != null) {
                    NotificationService().showToast(
                      context: context,
                      message: _languageService.translate('reconnecting'),
                      type: ToastType.info,
                    );
                    bluetoothService.connectToDevice(
                      bluetoothService.lastConnectedDevice!,
                    );
                  } else {
                    if (!context.mounted) return;
                    NotificationService().showToast(
                      context: context,
                      message: _languageService.translate('cannot_reconnect'),
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
      },
    );
  }
}
