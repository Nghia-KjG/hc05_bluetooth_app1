import 'package:flutter/material.dart';
import '../../../services/language_service.dart';

class UpdateAlertDialog extends StatelessWidget {
  final String currentVersion;
  final String latestVersion;
  final String changelog;
  final VoidCallback onUpdate;
  final VoidCallback onCancel;

  const UpdateAlertDialog({
    super.key,
    required this.currentVersion,
    required this.latestVersion,
    required this.changelog,
    required this.onUpdate,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService();
    return AlertDialog(
      title: Text(lang.translate('update_available')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Phiên bản mới: $latestVersion (Hiện tại: $currentVersion)',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Thay đổi:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(changelog),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: onCancel,
          child: Text(lang.translate('later')),
        ),
        ElevatedButton(
          onPressed: onUpdate,
          child: Text(lang.translate('update_now')),
        ),
      ],
    );
  }
}
