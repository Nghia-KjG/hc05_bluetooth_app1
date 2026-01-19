// lib/data/weighing_data.dart

// --- Bảng _VML_Persional ---
import 'package:flutter/foundation.dart';

final Map<int, Map<String, dynamic>> mockPersionalData = {
  7265: {'UerName': 'LA HOANG NAM'},
  9268: {'UerName': 'PHAM TRUONG HOANG BAO DI'},
  10004: {'UerName': 'NGUYEN KIM NGAN'},
  23158: {'UerName': 'NGUYEN VAN A'}, // Thêm ví dụ
};

// --- Bảng _VML_Work ---
final Map<String, Map<String, dynamic>> mockWorkData = {
  'PD202508000002': {
    'FormulaF': 'V6504W-01',
    'Qty': 1871.1904, // Sử dụng dấu chấm thập phân
    'Batch': 20,
    'soMay': '1', // Giữ là String nếu cần
    'Memo': 'Test',
  },
  'PD202510000001': {
    'FormulaF': 'V-5500G-01',
    'Qty': 1871.1904,
    'Batch': 30,
    'soMay': '1',
    'Memo': null,
  },
  'PD202510000003': {
    'FormulaF': 'V-5500G-01',
    'Qty': 2288.10,
    'Batch': 30,
    'soMay': '1',
    'Memo': null,
  },
};

// --- Bảng _VML_WorkLS ---
// Dùng làm class chính WeighingRecord
class WeighingRecord {
  final String maCode; // QRCode
  final String ovNO; // OVNO
  final int package; // package
  final String mUserID; // MUserID
  DateTime? mixTime; // MixTime (Thời gian cân thực tế)
  final double qtys; // Qty (Khối lượng mẻ/tồn - theo logic mới)
  double? realQty; // RKQty (Khối lượng cân thực tế)
  bool? isSuccess; // Trạng thái thành công (tự thêm)
  String? loai; // Loại nhập/xuất (từ mock history)
  final int soLo;
  double? weighedNhapAmount; // Trọng lượng đã cân nhập của mã này
  double? weighedXuatAmount; // Trọng lượng đã cân xuất của mã này

  // --- Thêm các trường từ bảng khác (để tiện truy cập) ---
  String? tenPhoiKeo; // FormulaF (từ _VML_Work)
  final String soMay; // soMay (từ _VML_Work)
  String? nguoiThaoTac; // UerName (từ _VML_Persional)
  String? device; // Tên thiết bị cân (từ bảng Devices)

  WeighingRecord({
    required this.maCode,
    required this.ovNO,
    required this.package,
    required this.mUserID,
    required this.qtys,
    required this.soLo,
    this.mixTime,
    this.realQty,
    this.isSuccess,
    this.loai,
    this.weighedNhapAmount,
    this.weighedXuatAmount,
    // Các trường bổ sung
    this.tenPhoiKeo,
    required this.soMay,
    this.nguoiThaoTac,
    this.device,
    String? memo,
  });
}

// Dữ liệu mẫu cho _VML_WorkLS (chỉ vài dòng để test)
final Map<String, Map<String, dynamic>> mockWorkLSData = {
  '202508000001': {
    'OVNO': 'PD202508000002',
    'package': 1,
    'MUserID': 9268,
    'MixTime': null,
    'Qty': 80.00,
    'RKQty': null,
  },
  '202508000002': {
    'OVNO': 'PD202508000002',
    'package': 2,
    'MUserID': 9268,
    'MixTime': null,
    'Qty': 80.00,
    'RKQty': null,
  },
  '202508000003': {
    'OVNO': 'PD202508000002',
    'package': 3,
    'MUserID': 9268,
    'MixTime': null,
    'Qty': 80.00,
    'RKQty': null,
  },
  '202510000001': {
    'OVNO': 'PD202510000001',
    'package': 1,
    'MUserID': 9268,
    'MixTime': null,
    'Qty': 80.00,
    'RKQty': null,
  },
  '202510000002': {
    'OVNO': 'PD202510000001',
    'package': 2,
    'MUserID': 9268,
    'MixTime': null,
    'Qty': 80.00,
    'RKQty': null,
  },
  '202510000003': {
    'OVNO': 'PD202510000001',
    'package': 3,
    'MUserID': 9268,
    'MixTime': null,
    'Qty': 80.00,
    'RKQty': null,
  },

  // Thêm mã từ mock history để test dashboard
  '202508000001_hist_nhap': {
    'OVNO': 'PD202508000002', // Giả sử cùng OVNO
    'package': 1, // Giả sử
    'MUserID': 23158, // Giả sử
    'MixTime': '29/10/2025 08:10', // Dạng string để parse
    'Qty': 80.00, // Khối lượng mẻ/tồn
    'RKQty': 80.00, // Khối lượng thực tế
    'loai': 'nhap',
  },
  '202508000001_hist_xuat': {
    'OVNO': 'PD202508000002', // Giả sử cùng OVNO
    'package': 1, // Giả sử
    'MUserID': 23158, // Giả sử
    'MixTime': '29/10/2025 08:15', // Dạng string để parse
    'Qty': 80.00, // Khối lượng mẻ/tồn
    'RKQty': 80.00, // Khối lượng thực tế
    'loai': 'xuat',
  },
};

// --- Bảng _VML_History ---
// Dữ liệu này sẽ được dùng để load vào HistoryScreen và DashboardController
// Chuyển sang dùng trực tiếp mockWorkLSData ở trên

final Map<String, Map<String, dynamic>> mockHistoryData = {
  'N202508000001': {
    // Key có thể cần duy nhất hơn
    'maCode': '202508000001',
    'MixTime': '29/10/2025 08:10',
    'khoiLuongSauCan': 80.0, // Đổi thành double
    'loai': 'nhap',
    // Cần thêm QRCode để liên kết
  },
  'X202508000001': {
    'maCode': '202508000001',
    'MixTime': '29/10/2025 08:15',
    'khoiLuongSauCan': 80.0,
    'loai': 'xuat',
  },
  'N202508000002': {
    // Key có thể cần duy nhất hơn
    'maCode': '202508000002',
    'MixTime': '29/10/2025 08:20',
    'khoiLuongSauCan': 80.0, // Đổi thành double
    'loai': 'nhap',
    // Cần thêm QRCode để liên kết
  },
  'N202510000001': {
    // Key có thể cần duy nhất hơn
    'maCode': '202510000001',
    'MixTime': '29/10/2025 08:10',
    'khoiLuongSauCan': 80.0, // Đổi thành double
    'loai': 'nhap',
    // Cần thêm QRCode để liên kết
  },
  'X202510000001': {
    'maCode': '202510000001',
    'MixTime': '29/10/2025 08:15',
    'khoiLuongSauCan': 80.0,
    'loai': 'xuat',
  },
};

// --- Hàm Parse Date Helper ---
// (Chuyển hàm này ra đây để dùng chung)
DateTime? parseMixTime(dynamic mixTimeValue) {
  if (mixTimeValue is String) {
    try {
      // Format: '29/10/2025 08:10'
      final parts = mixTimeValue.split(' ');
      final dateParts = parts[0].split('/'); // ['29', '10', '2025']
      final timeParts = parts[1].split(':'); // ['08', '10']
      return DateTime(
        int.parse(dateParts[2]), // year
        int.parse(dateParts[1]), // month
        int.parse(dateParts[0]), // day
        int.parse(timeParts[0]), // hour
        int.parse(timeParts[1]), // minute
      );
    } catch (e) {
      if (kDebugMode) {
        print('Lỗi parse MixTime String: $e');
      }
      return null;
    }
  } else if (mixTimeValue is DateTime) {
    return mixTimeValue; // Nếu đã là DateTime thì trả về luôn
  }
  return null; // Trả về null nếu không parse được
}
