import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../../../data/weighing_data.dart'; // Import WeighingRecord
import '../widgets/history_table.dart'; // Import SummaryData
import '../../../services/settings_service.dart';
import '../../../services/database_helper.dart';

class HistoryController with ChangeNotifier {
  final String _apiBaseUrl = dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:3636';
  final SettingsService _settings = SettingsService();

  final TextEditingController dateController = TextEditingController();
  final TextEditingController searchController = TextEditingController();

  // _allRecords: Danh sách GỐC, chứa cả Record VÀ Summary (để lọc)
  List<dynamic> _allRecords = []; 
  
  // _filteredRecords: Danh sách HIỂN THỊ
  List<dynamic> _filteredRecords = []; 
  List<dynamic> get filteredRecords => _filteredRecords;

  String _selectedFilterType = 'Tên phôi keo';
  String get selectedFilterType => _selectedFilterType;
  DateTime? _selectedDate;
  DateTime? get selectedDate => _selectedDate;
  String _searchText = '';
  String get searchText => _searchText;
  
  // Device filter
  String? _selectedDevice;
  String? get selectedDevice => _selectedDevice;
  List<String> _deviceList = [];
  List<String> get deviceList => _deviceList;

  HistoryController() {
    // Khởi tạo ngày hiện tại
    _selectedDate = DateTime.now();
    dateController.text = DateFormat('dd/MM/yyyy').format(_selectedDate!);
    
    _loadDevices(); // Tải danh sách devices
    _loadData(); // Tải data gốc 1 lần
    _settings.addListener(_loadData);
    searchController.addListener(() {
      if (_searchText != searchController.text) {
        _searchText = searchController.text;
        _runFilter(); // Chạy lọc và rebuild list
      }
    });
  }

  @override
  void dispose() {
    dateController.dispose();
    searchController.dispose();
    _settings.removeListener(_loadData);
    super.dispose();
  }

  // --- 1. SỬA HÀM _loadData ---
  // Hàm này tải và parse vào _allRecords (List<dynamic>)
  void _loadData() async {
    List<dynamic> newDisplayList = [];
    try {
      final String days = _settings.historyRange;
      final url = Uri.parse('$_apiBaseUrl/api/history?days=$days');
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> groupedData = json.decode(response.body);

        // Duyệt qua từng NHÓM (mỗi nhóm là 1 OVNO)
        for (var group in groupedData) {
          
          // Lấy danh sách record con
          final List<dynamic> recordsJson = group['records'] ?? [];
          final List<WeighingRecord> recordList = recordsJson.map((jsonItem) {
            return WeighingRecord(
              maCode: jsonItem['maCode'] as String,
              ovNO: jsonItem['ovNO'] as String,
              package: jsonItem['package'] ?? 0,
              mUserID: jsonItem['mUserID'].toString(),
              qtys: (jsonItem['qtys'] as num? ?? 0.0).toDouble(),
              mixTime: DateTime.parse(jsonItem['mixTime']),
              realQty: (jsonItem['realQty'] as num? ?? 0.0).toDouble(),
              isSuccess: true,
              loai: jsonItem['loai'],
              soLo: jsonItem['soLo'] ?? 0,
              tenPhoiKeo: jsonItem['tenPhoiKeo'],
              soMay: jsonItem['soMay'].toString(),
              nguoiThaoTac: jsonItem['nguoiThaoTac'],
              device: jsonItem['device'] as String?,
            );
          }).toList();

          // Thêm các record con vào list hiển thị
          newDisplayList.addAll(recordList);

          // Thêm HÀNG TÓM TẮT vào list hiển thị
          newDisplayList.add(SummaryData(
            ovNO: group['ovNO'] as String,
            memo: group['memo'] as String?,
            totalTargetQty: (group['totalTargetQty'] as num? ?? 0.0).toDouble(),
            totalNhap: (group['totalNhap'] as num? ?? 0.0).toDouble(),
            totalXuat: (group['totalXuat'] as num? ?? 0.0).toDouble(),
            xWeighed: (group['x_WeighedNhap'] as num? ?? 0).toInt(),
            yTotal: (group['y_TotalPackages'] as num? ?? 0).toInt(),
          ));
        }
        
        _allRecords = newDisplayList; // Gán vào danh sách GỐC
        
      } else {
        if (kDebugMode) print('Lỗi tải lịch sử: ${response.statusCode}');
        _allRecords = [];
      }
    } catch (e) {
      if (kDebugMode) print('Lỗi mạng khi tải lịch sử: $e');
      _allRecords = [];
    }
    
    // Sau khi tải xong, chạy filter (và tạo nhóm) lần đầu
    _runFilter(); 
  }

  bool _isSameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  // --- 2. SỬA HÀM _runFilter ---
  // Hàm này chỉ LỌC từ _allRecords (đã bao gồm Summary)
  void _runFilter() {
    
    // Bắt đầu bằng danh sách gốc (đã có Summary)
    List<dynamic> filteredList = _allRecords; 

    // --- BỘ LỌC 1: LỌC THEO NGÀY ---
    if (_selectedDate != null) {
      filteredList = filteredList.where((item) {
        if (item is SummaryData) return true; // Giữ Summary
        if (item is WeighingRecord) {
          return _isSameDay(item.mixTime, _selectedDate);
        }
        return false;
      }).toList();
    }
    
    // --- BỘ LỌC 1.5: LỌC THEO DEVICE ---
    if (_selectedDevice != null && _selectedDevice!.isNotEmpty) {
      filteredList = filteredList.where((item) {
        if (item is SummaryData) return true; // Giữ Summary
        if (item is WeighingRecord) {
          return item.device == _selectedDevice;
        }
        return false;
      }).toList();
    }

    // --- BỘ LỌC 2: LỌC THEO LOẠI (NẾU ĐƯỢC CHỌN) ---
    // (Bỏ 'else', áp dụng lọc này TRƯỚC khi lọc text)
    if (_selectedFilterType == 'Cân Nhập') {
      filteredList = filteredList.where((item) {
        if (item is SummaryData) return true;
        if (item is WeighingRecord) return item.loai == 'nhap';
        return false;
      }).toList();
    } else if (_selectedFilterType == 'Cân Xuất') {
      filteredList = filteredList.where((item) {
        if (item is SummaryData) return true;
        if (item is WeighingRecord) return item.loai == 'xuat';
        return false;
      }).toList();
    }
    
    // --- BỘ LỌC 3: LỌC THEO TỪ KHÓA (LUÔN LUÔN CHẠY) ---
    // (Áp dụng cho danh sách ĐÃ LỌC ở trên)
    if (_searchText.isNotEmpty) { 
      String query = _searchText.toLowerCase();
      filteredList = filteredList.where((item) {
        
        // 1. Nếu là Hàng Tóm Tắt (SummaryData)
        if (item is SummaryData) {
          // Chỉ tìm theo OVNO (nếu filter type là OVNO hoặc TẤT CẢ)
          if (_selectedFilterType == 'OVNO' || _selectedFilterType == 'Tên phôi keo' || _selectedFilterType == 'Mã code') {
             return item.ovNO.toLowerCase().contains(query);
          }
          // Nếu filter type là 'Cân Nhập'/'Xuất', nó sẽ tìm theo các trường record
          // và hàng summary sẽ được giữ lại nếu record con khớp
          return true; 
        }
        
        // 2. Nếu là Hàng Dữ Liệu (WeighingRecord)
        if (item is WeighingRecord) {
          // Chỉ tìm theo trường đã chọn trong dropdown
          if (_selectedFilterType == 'Tên phôi keo') {
            return item.tenPhoiKeo?.toLowerCase().contains(query) ?? false;
          } else if (_selectedFilterType == 'Mã code') {
            return item.maCode.toLowerCase().contains(query);
          } else if (_selectedFilterType == 'OVNO') {
            return item.ovNO.toLowerCase().contains(query);
          } else if (_selectedFilterType == 'Cân Nhập' || _selectedFilterType == 'Cân Xuất') {
            // Nếu đang lọc theo loại, cho phép tìm kiếm trong TẤT CẢ các trường
            return (item.tenPhoiKeo?.toLowerCase().contains(query) ?? false) ||
                   (item.maCode.toLowerCase().contains(query)) ||
                   (item.ovNO.toLowerCase().contains(query));
          }
        }
        return false;
      }).toList();
    }
    
    // --- XÓA HÀNG TÓM TẮT "MỒ CÔI" ---
    List<dynamic> cleanList = [];
    for (int i = 0; i < filteredList.length; i++) {
      final item = filteredList[i];
      if (item is SummaryData) {
        if (i == 0 || filteredList[i - 1] is SummaryData) {
          continue; 
        }
      }
      cleanList.add(item);
    }

    _filteredRecords = cleanList; 
    notifyListeners(); 
  }

  void updateFilterType(String? newType) {
    if (newType != null && _selectedFilterType != newType) {
      _selectedFilterType = newType;
      _runFilter(); 
    }
  }

  void updateSelectedDate(DateTime newDate) {
    if (_selectedDate != newDate) {
      _selectedDate = newDate;
      dateController.text = DateFormat('dd/MM/yyyy').format(newDate);
      _runFilter();
    }
  }

  void clearSelectedDate() {
    if (_selectedDate != null) {
      _selectedDate = null;
      dateController.clear();
      _runFilter();
    }
  }
  
  // Load danh sách devices từ database
  Future<void> _loadDevices() async {
    try {
      final deviceMap = await DatabaseHelper().getDeviceNameMap();
      _deviceList = deviceMap.values.toSet().toList(); // Loại bỏ trùng lặp
      _deviceList.sort(); // Sắp xếp theo alphabet
      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('Lỗi load devices: $e');
      _deviceList = [];
    }
  }
  
  void updateSelectedDevice(String? device) {
    if (_selectedDevice != device) {
      _selectedDevice = device;
      _runFilter();
    }
  }
  
  void clearSelectedDevice() {
    if (_selectedDevice != null) {
      _selectedDevice = null;
      _runFilter();
    }
  }
}