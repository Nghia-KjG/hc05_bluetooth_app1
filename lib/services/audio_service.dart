import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';

/// Service để phát tiếng bíp khi cân thành công
/// Sử dụng HapticFeedback + gọi native sound
class AudioService {
  // Singleton
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  static const platform = MethodChannel('com.hc.bluetooth.method_channel');
  static const audioChannel = MethodChannel('com.hc.audio.channel');
  final AudioPlayer _player = AudioPlayer();

  /// Phát âm thanh thành công khi cân
  Future<void> playSuccessBeep() async {
    try {
      if (kDebugMode) print('🔊 Đang phát âm thanh thành công...');
      
      // Phát âm thanh từ file mp3
      await _player.stop();
      await _player.setVolume(1.0);
      final bytes = await rootBundle.load('lib/assets/audio/success.mp3');
      await _player.play(BytesSource(bytes.buffer.asUint8List()));
      
      if (kDebugMode) print('✅ Âm thanh thành công đã phát');
    } catch (e) {
      if (kDebugMode) print('❌ Lỗi phát âm thanh: $e');
    }
  }

  /// Phát tiếng bíp đôi (xác nhận thành công)
  Future<void> playDoubleBeep() async {
    try {
      if (kDebugMode) print('🔊 Đang phát bíp đôi...');
      
      // Bíp lần 1
      await HapticFeedback.mediumImpact();
      await Future.delayed(const Duration(milliseconds: 200));
      // Bíp lần 2
      await HapticFeedback.mediumImpact();
      
      if (kDebugMode) print('✅ Bíp đôi đã phát');
    } catch (e) {
      if (kDebugMode) print('❌ Lỗi phát bíp đôi: $e');
    }
  }

  /// Phát rung cảnh báo (lỗi)
  Future<void> playErrorVibration() async {
    try {
      if (kDebugMode) print('🔊 Đang phát rung cảnh báo...');
      
      await HapticFeedback.vibrate();
      await Future.delayed(const Duration(milliseconds: 100));
      await HapticFeedback.vibrate();
      await Future.delayed(const Duration(milliseconds: 100));
      await HapticFeedback.vibrate();
      
      if (kDebugMode) print('✅ Rung cảnh báo đã phát');
    } catch (e) {
      if (kDebugMode) print('❌ Lỗi phát rung cảnh báo: $e');
    }
  }
}
