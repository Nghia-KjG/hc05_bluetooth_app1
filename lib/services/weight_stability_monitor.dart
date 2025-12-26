import 'dart:async';
import 'package:flutter/foundation.dart';

/// Service theo dõi tính ổn định của trọng lượng từ cân Bluetooth
/// Gọi callback khi trọng lượng ổn định trong khoảng thời gian xác định
class WeightStabilityMonitor {
  // Callback được gọi khi cân ổn định
  VoidCallback? onStable;

  // Danh sách các giá trị trọng lượng gần đây
  final List<double> _recentWeights = [];

  // Thời gian chờ cân ổn định (giây) - do SettingsService cung cấp
  int _stabilizationDelay;

  // Độ chênh lệch tối đa để coi là ổn định (kg) - từ SettingsService
  final double _stabilityThreshold;

  // Timer để kiểm tra định kỳ
  Timer? _checkTimer;
  
  // Trạng thái ổn định trước đó (để tránh gọi callback nhiều lần)
  bool _wasStable = false;

  // Thời điểm lần cuối phát hiện sự thay đổi "quan trọng" > stabilityThreshold
  DateTime _lastSignificantChange = DateTime.now();

  WeightStabilityMonitor({
    required int stabilizationDelay,
    required double stabilityThreshold,
    this.onStable,
  })  : _stabilizationDelay = stabilizationDelay,
        _stabilityThreshold = stabilityThreshold {
    // Bắt đầu timer kiểm tra ổn định
    _startCheckTimer();
  }

  /// Bắt đầu timer kiểm tra định kỳ
  void _startCheckTimer() {
    _checkTimer?.cancel();
    _checkTimer = Timer.periodic(
      const Duration(milliseconds: 500), // Kiểm tra mỗi 500ms
      (_) => _checkStability(),
    );
  }

  /// Cập nhật thời gian ổn định
  void updateStabilizationDelay(int delay) {
    _stabilizationDelay = delay;
    reset();
  }

  /// Thêm giá trị trọng lượng mới
  void addWeight(double weight) {
    if (weight < 0.01) {
       reset(); // Reset luôn nếu về 0
       return;
    }
    
    // Nếu danh sách trống, thêm và thoát
    if (_recentWeights.isEmpty) {
      _recentWeights.add(weight);
      // Mới có dữ liệu, coi là thay đổi mới
      _lastSignificantChange = DateTime.now();
      return;
    }

    // Kiểm tra chênh lệch với giá trị gần nhất
    final lastWeight = _recentWeights.last;
    final changeDiff = (weight - lastWeight).abs();

    // Nếu thay đổi quá lớn (>2kg), đó là mã mới → xóa tất cả mẫu cũ
    if (changeDiff > 2.0) {
      if (kDebugMode) {
        print('🔄 Phát hiện mã mới (đổi: $changeDiff kg). Reset mẫu.');
      }
      _recentWeights.clear();
      _wasStable = false;
      // Đánh dấu đây là thay đổi lớn -> reset thời điểm thay đổi quan trọng
      _lastSignificantChange = DateTime.now();
    }

    _recentWeights.add(weight);

    // Nếu thay đổi lớn hơn ngưỡng ổn định, đánh dấu thời điểm thay đổi
    if (changeDiff > _stabilityThreshold) {
      _lastSignificantChange = DateTime.now();
    }

    // Giữ lại chỉ những giá trị trong khoảng thời gian ổn định
    // Timer chạy mỗi 500ms, nên: maxSamples = (delay_seconds * 1000ms) / 500ms
    final maxSamples = (_stabilizationDelay * 1000) ~/ 500;
    if (_recentWeights.length > maxSamples) {
      _recentWeights.removeAt(0);
    }
  }

  /// Kiểm tra xem cân có ổn định không (gọi định kỳ)
  void _checkStability() {
    if (_recentWeights.isEmpty) {
      _wasStable = false;
      return;
    }

    // Tính số lượng mẫu cần để đạt stabilizationDelay
    // Timer chạy mỗi 500ms, nên: maxSamples = (delay_seconds * 1000ms) / 500ms
    final maxSamples = (_stabilizationDelay * 1000) ~/ 500;
    
    // Kiểm tra có đủ mẫu chưa - cần 70% của maxSamples (như trước)
    final bool hasEnoughSamples = _recentWeights.length >= (maxSamples * 0.7);

    if (!hasEnoughSamples) {
      if (kDebugMode) {
        final pct = (((_recentWeights.length / maxSamples) * 100).toStringAsFixed(0));
        print('📊 Chưa đủ mẫu: ${_recentWeights.length}/$maxSamples ($pct%)');
      }
    }

    final minWeight = _recentWeights.reduce((a, b) => a < b ? a : b);
    final maxWeight = _recentWeights.reduce((a, b) => a > b ? a : b);
    final diff = maxWeight - minWeight;

    final isStable = diff <= _stabilityThreshold;

    // Thời gian kể từ lần thay đổi quan trọng gần nhất
    final elapsedSinceSignificantChange = DateTime.now().difference(_lastSignificantChange).inMilliseconds / 1000.0;

    if (kDebugMode) {
      print('📊 Kiểm tra ổn định: diff=$diff kg (ngưỡng=${_stabilityThreshold}kg), mẫu=${_recentWeights.length}/$maxSamples, ổn định=$isStable, elapsedSignificantChange=${elapsedSinceSignificantChange}s');
    }

    // (debug above contains richer message including elapsedSinceSignificantChange)

    // Chỉ gọi callback khi chuyển từ không ổn định sang ổn định
    // Bổ sung: Khi trọng lượng không thay đổi trong ít nhất stabilizationDelay (theo thời gian), coi là ổn định
    final stableByTime = elapsedSinceSignificantChange >= _stabilizationDelay;

    if ((isStable && !_wasStable && hasEnoughSamples) || (stableByTime && !_wasStable)) {
      if (kDebugMode) {
        print('✅ Cân ổn định! (Chênh lệch: $diff kg, Giá trị: ${_recentWeights.last} kg)');
      }
      onStable?.call();
      _wasStable = true;
    } else if (!isStable) {
      _wasStable = false;
    }
  }

  /// Reset trạng thái
  void reset() {
    _recentWeights.clear();
    _wasStable = false;
    _lastSignificantChange = DateTime.now();
  }

  /// Hủy service
  void dispose() {
    _checkTimer?.cancel();
    _recentWeights.clear();
  }
}
