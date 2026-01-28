import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart'; // Cần cho việc format ngày

import '../widgets/hourly_weighing_chart.dart'; // Import ChartData
import '../../../models/warehouse_models.dart'; // Import Warehouse models

// Model cho dữ liệu loại keo
class GlueTypeData {
  final String tenPhoiKeo;
  final double nhap;
  final double xuat;
  final double ton;

  GlueTypeData({
    required this.tenPhoiKeo,
    required this.nhap,
    required this.xuat,
    required this.ton,
  });

  factory GlueTypeData.fromJson(Map<String, dynamic> json) {
    return GlueTypeData(
      tenPhoiKeo: json['tenPhoiKeo'] as String,
      nhap: (json['nhap'] as num? ?? 0.0).toDouble(),
      xuat: (json['xuat'] as num? ?? 0.0).toDouble(),
      ton: (json['ton'] as num? ?? 0.0).toDouble(),
    );
  }
}

class DashboardController with ChangeNotifier {
  final String _apiBaseUrl = dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:3636';
  
  // --- State ---
  // (Xóa _allRecords vì không cần nữa)
  List<ChartData> _chartData = []; // Data cho Bar Chart
  List<GlueTypeData> _glueTypeData = []; // Data cho Pie Chart - theo loại keo
  double _totalNhap = 0.0; // Tổng nhập (để hiển thị nếu cần)
  double _totalXuat = 0.0; // Tổng xuất (để hiển thị nếu cần)
  double _totalTon = 0.0; // Tổng tồn
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  
  // Warehouse state
  List<WarehouseSummary> _warehouseSummary = [];
  List<WarehouseDetail> _warehouseDetails = [];
  String? _selectedOVNO;
  bool _isLoadingDetails = false;

  // --- Getters ---
  List<ChartData> get chartData => _chartData;
  List<GlueTypeData> get glueTypeData => _glueTypeData;
  double get totalNhap => _totalNhap;
  double get totalXuat => _totalXuat;
  double get totalTon => _totalTon;
  DateTime get selectedDate => _selectedDate;
  bool get isLoading => _isLoading;
  
  List<WarehouseSummary> get warehouseSummary => _warehouseSummary;
  List<WarehouseDetail> get warehouseDetails => _warehouseDetails;
  String? get selectedOVNO => _selectedOVNO;
  bool get isLoadingDetails => _isLoadingDetails;

  DashboardController() {
    // 1. Tải dữ liệu cho cả 2 biểu đồ và warehouse
    _loadAllDashboardData();
  }

  // --- HÀM MỚI: Tải tất cả ---
  Future<void> _loadAllDashboardData() async {
    _isLoading = true;
    notifyListeners();

    // Chạy song song 3 API
    await Future.wait([
      _loadInventorySummary(), // Tải data cho Pie Chart
      _processDataForChart(_selectedDate), // Tải data cho Bar Chart (với ngày mặc định)
      _loadWarehouseSummary(), // Tải data cho Warehouse summary
    ]);

    _isLoading = false;
    notifyListeners();
  }

  // --- 1. SỬA HÀM TẢI DATA BIỂU ĐỒ TRÒN ---
  Future<void> _loadInventorySummary() async {
    try {
      final url = Uri.parse('$_apiBaseUrl/api/dashboard/inventory-summary');
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Đọc từ JSON 'summary'
        final summary = data['summary'];
        _totalNhap = (summary['totalNhap'] as num? ?? 0.0).toDouble();
        _totalXuat = (summary['totalXuat'] as num? ?? 0.0).toDouble();
        _totalTon = (summary['totalTon'] as num? ?? 0.0).toDouble();
        
        // Đọc dữ liệu 'byGlueType'
        final List<dynamic> byGlueType = data['byGlueType'] ?? [];
        _glueTypeData = byGlueType
            .map((item) => GlueTypeData.fromJson(item))
            .toList();

        if (kDebugMode) {
          print('✅ Đã tải ${_glueTypeData.length} loại keo');
          for (var glue in _glueTypeData) {
            print('  - ${glue.tenPhoiKeo}: Tồn ${glue.ton.toStringAsFixed(1)} kg');
          }
        }

      } else {
        if (kDebugMode) print('Lỗi tải Pie Chart: ${response.statusCode}');
        _resetPieChartData();
      }
    } catch (e) {
      if (kDebugMode) print('Lỗi mạng Pie Chart: $e');
      _resetPieChartData();
    }
    // (Không cần notifyListeners() vội, để hàm _loadAllDashboardData làm)
  }
  // --- KẾT THÚC SỬA ---

  // --- 2. SỬA HÀM TẢI DATA BIỂU ĐỒ CỘT ---
  Future<void> _processDataForChart(DateTime date) async {
    try {
      // Format ngày thành 'YYYY-MM-DD'
      final String formattedDate = DateFormat('yyyy-MM-dd').format(date);
      
      // Gọi API mới
      final url = Uri.parse('$_apiBaseUrl/api/dashboard/shift-weighing?date=$formattedDate');
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);

        // Map dữ liệu JSON mới
        _chartData = data.map((item) {
          return ChartData(
            item['Ca'] as String, // "Ca 1"
            (item['KhoiLuongNhap'] as num? ?? 0.0).toDouble(),
            (item['KhoiLuongXuat'] as num? ?? 0.0).toDouble(),
          );
        }).toList();

      } else {
        if (kDebugMode) print('Lỗi tải Bar Chart: ${response.statusCode}');
        _resetBarChartData();
      }
    } catch (e) {
      if (kDebugMode) print('Lỗi mạng Bar Chart: $e');
      _resetBarChartData();
    }
    // (Không cần notifyListeners() vội, để hàm _loadAllDashboardData làm)
  }
  // --- KẾT THÚC SỬA ---

  // --- 3. SỬA HÀM CẬP NHẬT NGÀY ---
  void updateSelectedDate(DateTime newDate) async {
    final currentDateOnly = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final newDateOnly = DateTime(newDate.year, newDate.month, newDate.day);

    if (currentDateOnly != newDateOnly) {
      _selectedDate = newDate;
      _isLoading = true;
      notifyListeners(); // Hiển thị loading

      await _processDataForChart(newDate); // Chỉ tải lại Bar Chart
      
      _isLoading = false;
      notifyListeners(); // Cập nhật Bar Chart mới
    }
  }

  // --- 4. THÊM HÀM REFRESH (GỌI TỪ UI NẾU CẦN) ---
  Future<void> refreshData() async {
    await _loadAllDashboardData();
  }

  // --- 5. WAREHOUSE FUNCTIONS ---
  Future<void> _loadWarehouseSummary() async {
    try {
      final url = Uri.parse('$_apiBaseUrl/api/warehouse/summary');
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        _warehouseSummary = data
            .map((item) => WarehouseSummary.fromJson(item))
            .toList();

        if (kDebugMode) {
          print('✅ Đã tải ${_warehouseSummary.length} lệnh kho');
        }
      } else {
        if (kDebugMode) print('Lỗi tải Warehouse Summary: ${response.statusCode}');
        _warehouseSummary = [];
      }
    } catch (e) {
      if (kDebugMode) print('Lỗi mạng Warehouse Summary: $e');
      _warehouseSummary = [];
    }
  }

  Future<void> loadWarehouseDetails(String ovNO) async {
    _selectedOVNO = ovNO;
    _isLoadingDetails = true;
    notifyListeners();

    try {
      if (kDebugMode) print('🔄 Đang tải chi tiết cho lệnh: $ovNO');
      
      final url = Uri.parse('$_apiBaseUrl/api/warehouse/details/$ovNO');
      if (kDebugMode) print('📡 URL: $url');
      
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      
      if (kDebugMode) print('📊 Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (kDebugMode) print('📦 Raw data length: ${data.length}');
        if (kDebugMode) print('📦 Raw data: $data');
        
        _warehouseDetails = data
            .map((item) => WarehouseDetail.fromJson(item))
            .toList();

        if (kDebugMode) {
          print('✅ Đã tải ${_warehouseDetails.length} mã code cho $ovNO');
          for (var detail in _warehouseDetails) {
            print('  - ${detail.qrCode}: ${detail.trangThaiText}');
          }
        }
      } else {
        if (kDebugMode) print('❌ Lỗi tải Warehouse Details: ${response.statusCode}');
        if (kDebugMode) print('❌ Response body: ${response.body}');
        _warehouseDetails = [];
      }
    } catch (e) {
      if (kDebugMode) print('❌ Lỗi mạng Warehouse Details: $e');
      _warehouseDetails = [];
    }

    _isLoadingDetails = false;
    if (kDebugMode) print('✅ Hoàn tất tải chi tiết. Số lượng: ${_warehouseDetails.length}');
    notifyListeners();
  }

  void clearWarehouseDetails() {
    _selectedOVNO = null;
    _warehouseDetails = [];
    notifyListeners();
  }

  // --- 6. THÊM HÀM RESET (ĐỂ DÙNG KHI LỖI) ---
  void _resetBarChartData() {
    _chartData = [
      ChartData('Ca 1', 0.0, 0.0),
      ChartData('Ca 2', 0.0, 0.0),
      ChartData('Ca 3', 0.0, 0.0),
    ];
  }

  void _resetPieChartData() {
    _totalNhap = 0.0;
    _totalXuat = 0.0;
    _totalTon = 0.0;
    _glueTypeData = [];
  }
}