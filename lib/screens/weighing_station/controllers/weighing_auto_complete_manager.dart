import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../services/audio_service.dart';
import '../../../services/bluetooth_service.dart';
import '../../../services/settings_service.dart';
import '../../../services/weight_stability_monitor.dart';
import 'weighing_calculator.dart';

/// Manager để xử lý tự động hoàn tất cân
class WeighingAutoCompleteManager {
  final BluetoothService bluetoothService;
  final WeighingCalculator calculator;
  final SettingsService settings;

  WeightStabilityMonitor? _stabilityMonitor;
  Timer? _autoCompleteTimer;
  bool _isAutoCompletePending = false;

  /// Callback khi auto-complete hoàn tất thành công
  VoidCallback? onAutoComplete;

  /// Callback để thực hiện việc hoàn tất cân
  Future<bool> Function(BuildContext context, double weight)? onCompleteWeighing;

  WeighingAutoCompleteManager({
    required this.bluetoothService,
    required this.calculator,
    required this.settings,
  });

  bool get isAutoCompletePending => _isAutoCompletePending;

  /// Khởi tạo theo dõi ổn định cân
  void initWeightMonitoring(BuildContext context) {
    if (kDebugMode) {
      print(
        '🔍 initWeightMonitoring - autoCompleteEnabled: ${settings.autoCompleteEnabled}',
      );
    }

    if (!settings.autoCompleteEnabled) {
      if (kDebugMode) print('⚠️ Tự động hoàn tất bị TẮT');
      return;
    }

    // Dispose previous monitor if any
    _stabilityMonitor?.dispose();

    _stabilityMonitor = WeightStabilityMonitor(
      stabilizationDelay: settings.stabilizationDelay,
      stabilityThreshold: settings.stabilityThreshold,
      onStable: () {
        _onWeightStable(context);
      },
    );

    if (kDebugMode) {
      print(
        '📊 Khởi tạo theo dõi ổn định (Delay: ${settings.stabilizationDelay}s, Threshold: ${settings.stabilityThreshold}kg)',
      );
    }
  }

  /// Thêm giá trị cân vào monitor
  void addWeightSample(double weight) {
    if (_stabilityMonitor == null) {
      if (kDebugMode) print('⚠️ Monitor là NULL, bỏ qua: $weight');
      return;
    }
    _stabilityMonitor!.addWeight(weight);
  }

  /// Reset monitor
  void reset() {
    _stabilityMonitor?.reset();
    _isAutoCompletePending = false;
    _autoCompleteTimer?.cancel();
  }

  /// Gọi khi cân ổn định
  void _onWeightStable(BuildContext context) {
    if (!context.mounted) return;
    if (_isAutoCompletePending) return;

    // Lấy trọng lượng tại thời điểm phát hiện ổn định
    final stableWeight = bluetoothService.currentWeight.value;

    // Check range lần 1
    final isInRange = calculator.isInRange(stableWeight);
    if (!isInRange) return; // Bỏ qua nếu không trong range

    if (kDebugMode) {
      print(
        '✅ Cân ổn định ($stableWeight kg)! Đợi ${settings.autoCompleteDelay}s...',
      );
    }

    _isAutoCompletePending = true;

    _autoCompleteTimer = Timer(
      Duration(seconds: settings.autoCompleteDelay),
      () async {
        if (!context.mounted) return;

        // Lấy trọng lượng tại thời điểm lưu (sau khi chờ)
        final currentWeight = bluetoothService.currentWeight.value;

        // Nếu trong lúc chờ, người dùng đã nhấc hàng ra (trọng lượng giảm mạnh hoặc về 0)
        // Thì HỦY BỎ và KHÔNG BÁO LỖI
        if (currentWeight < calculator.minWeight) {
          if (kDebugMode) {
            print('⚠️ Hủy tự động: Hàng đã bị nhấc ra trước khi hoàn tất.');
          }
          _isAutoCompletePending = false;
          return;
        }

        // Gọi callback để hoàn tất cân
        if (onCompleteWeighing != null) {
          final success = await onCompleteWeighing!(context, currentWeight);

          if (success) {
            if (kDebugMode) print('✅ Cân thành công! Kiểm tra settings.beepOnSuccess = ${settings.beepOnSuccess}');
            if (settings.beepOnSuccess) {
              if (kDebugMode) print('🎵 Gọi playSuccessBeep()...');
              await AudioService().playSuccessBeep();
            }

            // Thông báo UI để dọn dẹp scan input
            try {
              onAutoComplete?.call();
            } catch (e) {
              if (kDebugMode) print('⚠️ Lỗi khi gọi onAutoComplete: $e');
            }
          }
        }

        _isAutoCompletePending = false;
      },
    );
  }

  /// Hủy monitoring khi rời màn hình
  void dispose() {
    _autoCompleteTimer?.cancel();
    _autoCompleteTimer = null;
    _stabilityMonitor?.dispose();
    _stabilityMonitor = null;
    _isAutoCompletePending = false;
    onAutoComplete = null;
    onCompleteWeighing = null;
  }
}
