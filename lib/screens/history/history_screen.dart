import 'package:flutter/material.dart';
import '../../services/bluetooth_service.dart';
import '../../services/language_service.dart';
import '../../widgets/main_app_bar.dart';
import 'widgets/history_table.dart';
import '../../widgets/date_picker_input.dart';
import 'controllers/history_controller.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final BluetoothService _bluetoothService = BluetoothService();
  final LanguageService _languageService = LanguageService();
  
  // --- Tạo Controller ---
  late final HistoryController _controller;

  @override
  void initState() {
    super.initState();
    // --- KHỞI TẠO CONTROLLER ---
    _controller = HistoryController();
  }

  @override
  void dispose() {
    // --- HỦY CONTROLLER ---
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MainAppBar(
        title: _languageService.translate('weighing_program'),
        bluetoothService: _bluetoothService,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: _languageService.translate('back_to_home'),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      
      body: Container(
        padding: const EdgeInsets.all(24.0),
        // --- DÙNG ANIMATED BUILDER ĐỂ LẮNG NGHE ---
        child: AnimatedBuilder(
          animation: Listenable.merge([_controller, _languageService]), // Lắng nghe thay đổi từ controller và language
          builder: (context, child) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      _languageService.translate('history_title'),
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                    ),
                    _buildFilterBar(), // <-- Gọi hàm _buildFilterBar (sẽ sửa ở dưới)
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  // Lấy data từ controller
                  child: HistoryTable(records: _controller.filteredRecords), 
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // --- HÀM _buildFilterBar ĐỂ DÙNG CONTROLLER ---
  Widget _buildFilterBar() {
    return Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
      // Dropdown Loại Filter
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
        child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _controller.selectedFilterType,
          items: [
                    // --- 2. THÊM 2 LỰA CHỌN MỚI ---
          DropdownMenuItem(value: 'Cân Nhập', child: Text(_languageService.translate('filter_import'))),
          DropdownMenuItem(value: 'Cân Xuất', child: Text(_languageService.translate('filter_export'))),
                    // --- LỰA CHỌN CŨ ---
          DropdownMenuItem(value: 'Tên phôi keo', child: Text(_languageService.translate('filter_glue_name'))),
          DropdownMenuItem(value: 'Mã code', child: Text(_languageService.translate('filter_code'))),
          DropdownMenuItem(value: 'Lệnh', child: Text(_languageService.translate('filter_ovno'))),
          ],
          onChanged: (value) {
          _controller.updateFilterType(value);
          },
        ),
        ),
      ),
      const SizedBox(width: 16),
      
      // Date Picker (Giữ nguyên)
      DatePickerInput(
        selectedDate: _controller.selectedDate,
        controller: _controller.dateController,
        onDateSelected: (newDate) {
        _controller.updateSelectedDate(newDate);
        },
        onDateCleared: () {
        _controller.clearSelectedDate();
        },
      ),
      
      const VerticalDivider(),
      
      // Search Field (Sửa lại)
      SizedBox(
        width: 250,
        child: TextField(
        controller: _controller.searchController,
        decoration: InputDecoration(
          hintText: _languageService.translate('search_hint'),
          prefixIcon: const Icon(Icons.search),
          // (Code viền đen của bạn)
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: const BorderSide(color: Colors.black, width: 1.0),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: const BorderSide(color: Colors.black, width: 2.0),
          ),         
          filled: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
        ),
        ),
      ),
      ],
    ),
    );
  }
}