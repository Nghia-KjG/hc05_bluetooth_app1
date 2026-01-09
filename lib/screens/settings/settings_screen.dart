import 'package:flutter/material.dart';
import '../../services/settings_service.dart';
import '../../services/language_service.dart';
import 'package:flutter/foundation.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  // --- MAP CÁC LỰA CHỌN ---
  final Map<String, String> _historyRangeOptions = const {
    '30': '30 Ngày',
    '7': '7 Ngày',
    '15': '15 Ngày',
    '90': '90 Ngày',
    'all': 'Tất cả lịch sử',
  };

  final Map<int, String> _stabilizationDelayOptions = const {
    3: '3 giây',
    5: '5 giây',
    10: '10 giây',
  };

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([SettingsService(), LanguageService()]),
      builder: (context, child) {
        final settings = SettingsService();
        final lang = LanguageService();

        return Scaffold(
          appBar: AppBar(
            title: Text(lang.translate('settings')),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // === PHẦN 0: NGÔN NGỮ ===
              _buildSectionHeader(lang.translate('language')),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(color: Colors.grey.shade400),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: lang.currentLanguage,
                    isExpanded: true,
                    icon: const Icon(Icons.language),
                    items: [
                      DropdownMenuItem(
                        value: 'vi',
                        child: Text(lang.translate('vietnamese')),
                      ),
                      DropdownMenuItem(
                        value: 'en',
                        child: Text(lang.translate('english')),
                      ),
                    ],
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        lang.setLanguage(newValue);
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 32),
              
              // === PHẦN 1: LỊCH SỬ CÂN ===
              _buildSectionHeader(lang.translate('history_range')),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(color: Colors.grey.shade400),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: settings.historyRange,
                    isExpanded: true,
                    icon: const Icon(Icons.calendar_today_outlined),
                    items: [
                      DropdownMenuItem(value: '30', child: Text(lang.translate('30_days'))),
                      DropdownMenuItem(value: '7', child: Text(lang.translate('7_days'))),
                      DropdownMenuItem(value: '15', child: Text(lang.translate('15_days'))),
                      DropdownMenuItem(value: '90', child: Text(lang.translate('90_days'))),
                      DropdownMenuItem(value: 'all', child: Text(lang.translate('all_history'))),
                    ],
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        settings.updateHistoryRange(newValue);
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // === PHẦN 2: TỰ ĐỘNG HOÀN TẤT ===
              _buildSectionHeader(lang.translate('auto_complete')),
              _buildToggleSetting(
                label: lang.translate('auto_complete_desc'),
                value: settings.autoCompleteEnabled,
                onChanged: (value) {
                  settings.updateAutoCompleteEnabled(value);
                },
              ),
              const SizedBox(height: 16),

              // Điều kiện: chỉ hiện các tùy chọn nếu bật tự động hoàn tất
              if (settings.autoCompleteEnabled) ...[
                _buildSettingLabel(lang.translate('stability_delay')),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8.0),
                    border: Border.all(color: Colors.grey.shade400),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: settings.stabilizationDelay,
                      isExpanded: true,
                      icon: const Icon(Icons.hourglass_bottom),
                      items: [
                        DropdownMenuItem(value: 3, child: Text(lang.translate('3_seconds'))),
                        DropdownMenuItem(value: 5, child: Text(lang.translate('5_seconds'))),
                        DropdownMenuItem(value: 10, child: Text(lang.translate('10_seconds'))),
                      ],
                      onChanged: (int? newValue) {
                        if (newValue != null) {
                          settings.updateStabilizationDelay(newValue);
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildSliderSetting(
                  label: '${lang.translate('complete_delay')} ${settings.autoCompleteDelay}s',
                  value: settings.autoCompleteDelay.toDouble(),
                  min: 1,
                  max: 5,
                  step: 1.0,
                  valueLabel: (v) => '${v.toInt()}s',
                  onChanged: (value) {
                    settings.updateAutoCompleteDelay(value.toInt());
                  },
                ),
                const SizedBox(height: 16),
                if (kDebugMode) ...[
                  _buildSliderSetting(
                    label: '${lang.translate('max_deviation')} ${(settings.stabilityThreshold * 1000).toStringAsFixed(0)}g',
                    value: settings.stabilityThreshold,
                    min: 0.01,
                    max: 1.0,
                    step: 0.01,
                    valueLabel: (v) => '${(v * 1000).toStringAsFixed(0)}g',
                    onChanged: (value) {
                      settings.updateStabilityThreshold(value);
                    },
                  ),
                ],
              ],
              const SizedBox(height: 32),

              // === PHẦN 3: ÂM THANH ===
              _buildSectionHeader(lang.translate('sound')),
              _buildToggleSetting(
                label: lang.translate('sound_enabled_desc'),
                value: settings.beepOnSuccess,
                onChanged: (value) {
                  settings.updateBeepOnSuccess(value);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // Widget tạo tiêu đề section
  Widget _buildSectionHeader(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.blue.shade800,
        ),
      ),
    );
  }

  // Widget tạo nhãn cài đặt
  Widget _buildSettingLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          color: Colors.black87,
        ),
      ),
    );
  }

  // Widget toggle switch
  Widget _buildToggleSetting({
    required String label,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 14),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  // Widget slider
  Widget _buildSliderSetting({
    required String label,
    required double value,
    required double min,
    required double max,
    double step = 1.0,
    required Function(double) onChanged,
    String Function(double)? valueLabel,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14),
        ),
        const SizedBox(height: 8),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: (() {
            // Calculate divisions based on the provided step. Ensure > 0 or leave null.
            final double range = (max - min).abs();
            if (step <= 0) return null;
            final int calcDiv = (range / step).round();
            return calcDiv > 0 ? calcDiv : null;
          })(),
          label: valueLabel != null
              ? valueLabel(value)
              : value.toStringAsFixed(step >= 1 ? 0 : (() {
                  // compute decimal digits based on step
                  var decimals = 0;
                  var s = step;
                  while (s < 1 && decimals < 6) {
                    s *= 10;
                    decimals++;
                  }
                  return decimals;
                })()),
          onChanged: onChanged,
        ),
      ],
    );
  }
}