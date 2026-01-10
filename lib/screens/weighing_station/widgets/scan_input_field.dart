import 'dart:async';
import 'package:flutter/material.dart';
import '../../../services/language_service.dart';

class ScanInputField extends StatefulWidget {
  
  final TextEditingController controller;
  final Function(String code) onScan;
  final FocusNode? focusNode;

  const ScanInputField({
    super.key,
    required this.controller,
    required this.onScan,
    this.focusNode,
  });

  @override
  State<ScanInputField> createState() => _ScanInputFieldState();
}

class _ScanInputFieldState extends State<ScanInputField> {
  final LanguageService _languageService = LanguageService();
  Timer? _idleTimer; // Timer phát hiện khoảng nghỉ giữa các lần scan
  DateTime? _lastInputTime; // Thời điểm nhận ký tự cuối cùng
  static const _idleThreshold = Duration(milliseconds: 300); // Nếu nghỉ > 300ms thì coi như scan mới

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    super.dispose();
  }

  void _handleScan(BuildContext context) {
    final code = widget.controller.text.trim();
    debugPrint('🔫 _handleScan called, code: "$code"');
    if (code.isNotEmpty) {
      widget.onScan(code);
      // Giữ focus để sẵn sàng scan tiếp
      Future.delayed(const Duration(milliseconds: 50), () {
        widget.focusNode?.requestFocus();
      });
    }
  }

  void _onTextChanged(String value) {
    debugPrint('📝 TextField onChanged: "$value"');
    
    final now = DateTime.now();
    
    // Kiểm tra xem có phải đang bắt đầu scan mới hay không
    // (nếu đã có text cũ VÀ đã nghỉ > 300ms từ lần nhập cuối)
    if (_lastInputTime != null && 
        widget.controller.text.length > 1 && 
        now.difference(_lastInputTime!) > _idleThreshold) {
      
      debugPrint('🆕 Phát hiện scan mới sau ${now.difference(_lastInputTime!).inMilliseconds}ms nghỉ!');
      
      // Lấy ký tự mới được thêm vào (ký tự cuối)
      final newChar = value.isNotEmpty ? value.substring(value.length - 1) : '';
      
      // Clear text cũ, chỉ giữ ký tự mới
      widget.controller.text = newChar;
      widget.controller.selection = TextSelection.fromPosition(
        TextPosition(offset: newChar.length),
      );
      
      debugPrint('✨ Đã clear mã cũ, bắt đầu với: "$newChar"');
    }
    
    _lastInputTime = now;
  }

  @override
  Widget build(BuildContext context) {
    const Color fillColor = Color(0xFFE8F5E9);
    const Color borderColor = Color(0xFFB9E5BC);
    const Color buttonColor = Color(0xFF4CAF50);

    return AnimatedBuilder(
      animation: _languageService,
      builder: (context, child) {
        return TextField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          autofocus: true,
          keyboardType: TextInputType.none,
          onSubmitted: (_) {
            _handleScan(context);
          },
          onChanged: _onTextChanged,
          decoration: InputDecoration(
            hintText: _languageService.translate('scan_hint'),
            hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            filled: true,
            fillColor: fillColor,
            contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
              borderSide: const BorderSide(color: borderColor, width: 2.0),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
              borderSide: BorderSide(color: buttonColor, width: 2.0),
            ),
            suffixIcon: Padding(
              padding: const EdgeInsets.all(5.0),
              child: ElevatedButton.icon(
                onPressed: () => _handleScan(context),
                icon: const Icon(Icons.qr_code_scanner, size: 20),
                label: Text(_languageService.translate('scan_button')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: buttonColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                  minimumSize: const Size(80, 36),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}