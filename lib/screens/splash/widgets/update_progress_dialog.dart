import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:ota_update/ota_update.dart';
import '../../../services/language_service.dart';

class UpdateProgressDialog extends StatefulWidget {
  // Legacy: custom download function
  final Future<String> Function(void Function(int, int) onProgress)? downloadFuture;
  final void Function(String apkPath)? onComplete;
  // New: use ota_update directly via URL
  final String? otaUrl;
  final VoidCallback? onInstallTriggered;
  final VoidCallback onError;

  const UpdateProgressDialog({
    super.key,
    this.downloadFuture,
    this.onComplete,
    this.otaUrl,
    this.onInstallTriggered,
    required this.onError,
  });

  @override
  State<UpdateProgressDialog> createState() => _UpdateProgressDialogState();
}

class _UpdateProgressDialogState extends State<UpdateProgressDialog> {
  double? _progress = 0.0;
  String _progressText = '0%';

  @override
  void initState() {
    super.initState();
    if (widget.otaUrl != null && widget.otaUrl!.isNotEmpty) {
      _startOtaUpdate();
    } else if (widget.downloadFuture != null) {
      _startDownload();
    }
  }

  Future<void> _startDownload() async {
    try {
      final apkPath = await widget.downloadFuture!((downloaded, total) {
        if (!mounted) return;
        setState(() {
          if (total > 0) {
            _progress = downloaded / total;
            final percent = ((_progress! * 100)).clamp(0, 100).toStringAsFixed(0);
            _progressText = '$percent%';
          } else {
            _progress = null; // indeterminate
            _progressText = 'Đang tải...';
          }
        });
      });
      if (mounted) {
        Navigator.pop(context);
        widget.onComplete?.call(apkPath);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
      }
      widget.onError();
    }
  }

  Future<void> _startOtaUpdate() async {
    try {
      if (kDebugMode) print('🔄 Bắt đầu OTA update với URL: ${widget.otaUrl}');
      final stream = OtaUpdate().execute(widget.otaUrl!);
      await for (final event in stream) {
        if (!mounted) return;
        if (kDebugMode) print('📊 OTA Status: ${event.status}, Value: ${event.value}');
        
        switch (event.status) {
          case OtaStatus.DOWNLOADING:
            final int? percent = int.tryParse(event.value ?? '0');
            setState(() {
              _progress = percent != null ? (percent / 100).clamp(0.0, 1.0) : null;
              _progressText = percent != null ? '$percent%' : 'Đang tải...';
            });
            break;
          case OtaStatus.INSTALLING:
            // Close dialog; system installer should appear
            if (kDebugMode) print('✅ Đang kích hoạt trình cài đặt...');
            if (mounted) {
              Navigator.pop(context);
            }
            widget.onInstallTriggered?.call();
            return;
          case OtaStatus.INSTALLATION_DONE:
            // Installation complete - close and reset flag
            if (kDebugMode) print('✅ Cài đặt hoàn tất!');
            if (mounted) {
              Navigator.pop(context);
            }
            widget.onInstallTriggered?.call();
            return;
          case OtaStatus.ALREADY_RUNNING_ERROR:
            if (kDebugMode) print('❌ Lỗi: OTA đang chạy');
            if (mounted) {
              Navigator.pop(context);
            }
            widget.onError();
            return;
          case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
            if (kDebugMode) print('❌ Lỗi: Không có quyền cài đặt');
            if (mounted) {
              Navigator.pop(context);
            }
            widget.onError();
            return;
          case OtaStatus.INTERNAL_ERROR:
            if (kDebugMode) print('❌ Lỗi nội bộ: ${event.value}');
            if (mounted) {
              Navigator.pop(context);
            }
            widget.onError();
            return;
          case OtaStatus.DOWNLOAD_ERROR:
            if (kDebugMode) print('❌ Lỗi tải xuống');
            if (mounted) {
              Navigator.pop(context);
            }
            widget.onError();
            return;
          case OtaStatus.INSTALLATION_ERROR:
            if (kDebugMode) print('❌ Lỗi cài đặt');
            if (mounted) {
              Navigator.pop(context);
            }
            widget.onError();
            return;
          case OtaStatus.CHECKSUM_ERROR:
            if (kDebugMode) print('❌ Lỗi kiểm tra checksum');
            if (mounted) {
              Navigator.pop(context);
            }
            widget.onError();
            return;
          case OtaStatus.CANCELED:
            if (kDebugMode) print('⚠️ Người dùng hủy tải');
            // User canceled - close dialog and allow app to continue
            if (mounted) {
              Navigator.pop(context);
            }
            widget.onError();
            return;
        }
      }
      if (kDebugMode) print('⚠️ Stream kết thúc mà không có sự kiện INSTALLING');
    } catch (e) {
      if (kDebugMode) print('❌ Exception trong OTA: $e');
      if (mounted) {
        Navigator.pop(context);
      }
      widget.onError();
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService();
    return PopScope(
      canPop: false, // Không cho đóng dialog khi đang tải
      child: AlertDialog(
        title: Text(lang.translate('downloading')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(
              value: _progress,
              minHeight: 10,
            ),
            const SizedBox(height: 12),
            Text(_progressText),
          ],
        ),
      ),
    );
  }
}
