import 'dart:async';
import 'package:flutter/material.dart';
import 'language_service.dart';

enum ToastType { success, error, info }

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  // --- SỬA LẠI HÀM 'showToast' ---
  void showToast({
    required BuildContext context,
    required String message,
    required ToastType type,
  }) {
    // 1. Tạo một Dialog (giống như trước)
    final Widget dialog = _buildAutoDismissDialog(context, message, type);

    // 2. Hiển thị Dialog
    showDialog(
      context: context,
      barrierDismissible: false, // Không cho bấm ra ngoài để tắt
      builder: (BuildContext dialogContext) {
        return dialog;
      },
    ).then((_) {
      // (Hàm này được gọi khi dialog bị đóng)
    });

    // 3. Tự động đóng Dialog sau 3 giây
    Timer(const Duration(seconds: 3), () {
      // Kiểm tra xem Dialog còn "sống" không trước khi đóng
      if (Navigator.of(context, rootNavigator: true).canPop()) {
         Navigator.of(context, rootNavigator: true).pop();
      }
    });
  }

  // --- HÀM HELPER (ĐÃ XÓA NÚT "OK") ---
  Widget _buildAutoDismissDialog(BuildContext context, String message, ToastType type) {
    IconData iconData;
    String title;
    Color backgroundColor;

    const Color textColor = Colors.white;

    final langService = LanguageService();
    
    switch (type) {
      case ToastType.success:
        iconData = Icons.check_circle_outline;
        backgroundColor = Colors.green.shade600;
        title = langService.translate('notification_success');
        break;
      case ToastType.error:
        iconData = Icons.error_outline;
        backgroundColor = Colors.red.shade600;
        title = langService.translate('notification_error');
        break;
      case ToastType.info:
      iconData = Icons.info_outline;
       backgroundColor = Colors.blue.shade600;
        title = langService.translate('notification_info');
        break;
    }

    return AlertDialog(
      backgroundColor: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      title: Row(
        children: [
          Icon(iconData, color: textColor, size: 28),
          const SizedBox(width: 12),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: textColor,)),
        ],
      ),
      content: Text(
        message,
        style: const TextStyle(fontSize: 16, color: textColor),
      ),
      actions: null, 
    );
  }
}