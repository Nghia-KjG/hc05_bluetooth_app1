import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/database_helper.dart';
import 'package:sqflite/sqflite.dart';
import '../../../data/weighing_data.dart';
import '../../../services/bluetooth_service.dart';
import '../../../services/notification_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../../services/server_status_service.dart';

enum WeighingType { nhap, xuat }

class WeighingException implements Exception {
  final String message;
  WeighingException(this.message);
}

class WeighingStationController with ChangeNotifier {
  final BluetoothService bluetoothService;

  // --- ĐỊNH NGHĨA IP CỦA BACKEND ---
  final String _apiBaseUrl = dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:3636';

  final DatabaseHelper _dbHelper = DatabaseHelper();
  final ServerStatusService _serverStatus = ServerStatusService();

  String? _activeOVNO;
  String? _activeMemo;
  String? get activeOVNO => _activeOVNO;
  String? get activeMemo => _activeMemo;

  // --- STATE ---
  final List<WeighingRecord> _records = [];
  List<WeighingRecord> get records => _records;

  double _activeTotalTargetQty = 0.0;
  double _activeTotalNhap = 0.0;
  double _activeTotalXuat = 0.0;
  double get activeTotalTargetQty => _activeTotalTargetQty;
  double get activeTotalNhap => _activeTotalNhap;
  double get activeTotalXuat => _activeTotalXuat;

  double _selectedPercentage = 1.0;
  double get selectedPercentage => _selectedPercentage;
  double _standardWeight = 0.0;
  double get khoiLuongMe => _standardWeight;
  double _minWeight = 0.0;
  double _maxWeight = 0.0;
  double get minWeight => _minWeight;
  double get maxWeight => _maxWeight;
  int _activeXWeighed = 0;
  int _activeYTotal = 0;
  int get activeXWeighed => _activeXWeighed;
  int get activeYTotal => _activeYTotal;

  WeighingType _selectedWeighingType = WeighingType.nhap;
  WeighingType get selectedWeighingType => _selectedWeighingType;

  // --- BIẾN ĐỂ THEO DÕI CÂN LẠI ---
  bool _isReweighing = false;
  bool get isReweighing => _isReweighing;
  String? _previousWeighingType; // 'nhap' hoặc 'xuat' - loại cân trước đó

  WeighingStationController({required this.bluetoothService});

  // --- HÀM TÍNH TOÁN ---
  void _calculateMinMax() {
    if (_standardWeight == 0) {
      _minWeight = 0.0;
      _maxWeight = 0.0;
    } else {
      final deviation = _standardWeight * (_selectedPercentage / 100.0);
      _minWeight = _standardWeight - deviation;
      _maxWeight = _standardWeight + deviation;
    }
  }

  void updatePercentage(double newPercentage) {
    _selectedPercentage = newPercentage;
    _calculateMinMax();
    notifyListeners();
  }

  /// Cập nhật loại cân được chọn. Nếu đang ở chế độ offline và
  /// mã hiện tại đã được cân nhập trước đó, không cho phép chọn `nhap`.
  Future<void> updateWeighingType(WeighingType? newType, BuildContext context) async {
    if (newType == null) return;

    // Nếu đang cân lại, không cho phép thay đổi loại cân
    if (_isReweighing) {
      if (context.mounted) {
        NotificationService().showToast(
          context: context,
          message: 'Đang cân lại, không thể thay đổi loại cân.',
          type: ToastType.error,
        );
      }
      return;
    }

    // Nếu user muốn chuyển sang 'nhap' nhưng mã hiện tại đã có bản ghi 'nhap' (offline), chặn lại.
    if (newType == WeighingType.nhap && _records.isNotEmpty) {
      final currentRecord = _records[0];
      final db = await _dbHelper.database;

      // Kiểm tra: đã có 'nhap' trong HistoryQueue (chờ sync) hoặc trong VmlWorkS với realQty != NULL
      final existingInQueue = await db.query('HistoryQueue', where: 'maCode = ? AND loai = ?', whereArgs: [currentRecord.maCode, 'nhap']);
      final existingInCache = await db.query('VmlWorkS', where: 'maCode = ? AND loai = ? AND realQty IS NOT NULL', whereArgs: [currentRecord.maCode, 'nhap']);

      if (existingInQueue.isNotEmpty || existingInCache.isNotEmpty) {
        if (context.mounted) {
          NotificationService().showToast(
            context: context,
            message: 'Mã này đã được CÂN NHẬP (offline). Không thể chuyển về Cân Nhập.',
            type: ToastType.error,
          );
        }
        return;
      }
    }

    _selectedWeighingType = newType;
    notifyListeners();
  }

  // --- LẤY DỮ LIỆU OFFLINE ---
  Future<Map<String, dynamic>> _scanFromCache(Database db, String code) async {
  final List<Map<String, dynamic>> localData = await db.rawQuery(
    '''
        SELECT S.maCode, S.ovNO, S.package, S.mUserID, S.qtys,
          S.realQty,
          S.loai,
           W.tenPhoiKeo, W.soMay, W.memo, W.totalTargetQty,
           P.nguoiThaoTac, S.package as soLo
    FROM VmlWorkS AS S
    LEFT JOIN VmlWork AS W ON S.ovNO = W.ovNO
    LEFT JOIN VmlPersion AS P ON S.mUserID = P.mUserID
    WHERE S.maCode = ?
    ''',
    [code],
  );

  if (localData.isNotEmpty) {
    if (kDebugMode) {
      print('🔍 Tìm thấy mã $code trong cache cục bộ.');
    }
    return localData.first;
  } else {
    throw WeighingException('Mã "$code" không có trong dữ liệu offline.');
  }
}

  // --- HÀM XỬ LÝ SCAN ---
  Future<void> handleScan(BuildContext context, String code) async {
  Map<String, dynamic> data;
  final db = await _dbHelper.database;
  final bool isServerConnected = _serverStatus.isServerConnected;
  
  // Biến để lưu trạng thái từ backend
  bool? isNhapWeighedFromServer;
  bool? isXuatWeighedFromServer;

  // Reset trạng thái cân lại
  _isReweighing = false;
  _previousWeighingType = null;

  try {
    if (isServerConnected) {
      // --- BƯỚC 1: KIỂM TRA TỪ BACKEND TRƯỚC ---
      if (kDebugMode) print('🛰️ Online Mode: Đang gọi API để kiểm tra trạng thái...');
      final url = Uri.parse('$_apiBaseUrl/api/scan/$code');
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        data = json.decode(response.body);
        // Server may return either explicit booleans or a 'loai' string.
        final bool flagNhap = data['isNhapWeighed'] == true;
        final String loaiFromServer = (data['loai'] ?? '').toString().toLowerCase().trim();
        isNhapWeighedFromServer = flagNhap || (loaiFromServer == 'nhap');
        final bool flagXuat = data['isXuatWeighed'] == true;
        isXuatWeighedFromServer = flagXuat || (loaiFromServer == 'xuat');

        // THAY ĐỔI: Cho phép cân lại nếu đã cân xuất
        // Nếu đã cân xuất → đang cân lại từ xuất
        if (isXuatWeighedFromServer == true) {
          _isReweighing = true;
          _previousWeighingType = 'xuat';
          if (kDebugMode) print('🔄 Đang cân lại từ CÂN XUẤT');
        }
        // Nếu đã cân nhập (nhưng chưa xuất) → đang cân lại từ nhập
        else if (isNhapWeighedFromServer == true) {
          _isReweighing = true;
          _previousWeighingType = 'nhap';
          if (kDebugMode) print('🔄 Đang cân lại từ CÂN NHẬP');
        }

        // Lưu cache
        await db.insert(
          'VmlWork',
          {
            'ovNO': data['ovNO'],
            'tenPhoiKeo': data['tenPhoiKeo'],
            'soMay': data['soMay'],
            'memo': data['memo'],
            'totalTargetQty': data['totalTargetQty'],
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        await db.insert(
          'VmlPersion',
          {
            'mUserID': data['mUserID'].toString(),
            'nguoiThaoTac': data['nguoiThaoTac'],
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      } else if (response.statusCode == 404) {
        final errorData = json.decode(response.body);
        throw WeighingException(errorData['message'] ?? 'Không tìm thấy mã');
      } else {
        throw WeighingException('Lỗi server: ${response.statusCode}, thử lại offline...');
      }
    } else {
      // --- BƯỚC 1 (OFFLINE): KIỂM TRA DỮ LIỆU LOCAL TRƯỚC ---
      if (kDebugMode) print('🔌 Offline Mode: Đang tìm trong cache cục bộ...');
      data = await _scanFromCache(db, code);

      // Kiểm tra trạng thái từ VmlWorkS và HistoryQueue
      final String loaiFromCache = (data['loai'] ?? '').toString().toLowerCase().trim();
      final dynamic realQtyFromCache = data['realQty'];

      // Kiểm tra trong HistoryQueue
      final existingNhapInQueue = await db.query(
        'HistoryQueue',
        where: 'maCode = ? AND loai = ?',
        whereArgs: [code, 'nhap'],
      );
      final existingXuatInQueue = await db.query(
        'HistoryQueue',
        where: 'maCode = ? AND loai = ?',
        whereArgs: [code, 'xuat'],
      );

      // Xác định trạng thái
      bool hasWeighedNhapInCache = (realQtyFromCache != null && loaiFromCache == 'nhap');
      bool hasWeighedXuatInCache = (realQtyFromCache != null && loaiFromCache == 'xuat');
      bool hasWeighedNhapInQueue = existingNhapInQueue.isNotEmpty;
      bool hasWeighedXuatInQueue = existingXuatInQueue.isNotEmpty;

      isNhapWeighedFromServer = hasWeighedNhapInCache || hasWeighedNhapInQueue;
      isXuatWeighedFromServer = hasWeighedXuatInCache || hasWeighedXuatInQueue;

      // THAY ĐỔI: Cho phép cân lại offline
      if (isXuatWeighedFromServer == true) {
        _isReweighing = true;
        _previousWeighingType = 'xuat';
        if (kDebugMode) print('🔄 Offline: Đang cân lại từ CÂN XUẤT');
      } else if (isNhapWeighedFromServer == true) {
        _isReweighing = true;
        _previousWeighingType = 'nhap';
        if (kDebugMode) print('🔄 Offline: Đang cân lại từ CÂN NHẬP');
      }

      if (kDebugMode) {
        print('🔍 loaiFromCache="$loaiFromCache" (hasWeighedNhapInCache=$hasWeighedNhapInCache)');
        print('🔍 existingNhapInQueue (Chờ sync): ${existingNhapInQueue.length} (hasWeighedNhapInQueue=$hasWeighedNhapInQueue)');
        print('🔍 existingXuatInQueue (Chờ sync): ${existingXuatInQueue.length} (hasWeighedXuatInQueue=$hasWeighedXuatInQueue)');
      }
    }

    // --- BƯỚC 2: TỰ ĐỘNG XÁC ĐỊNH LOẠI CÂN DỰA TRÊN TRẠNG THÁI ---
    WeighingType autoDetectedType;
    String statusMessage;

    if (_isReweighing) {
      // Nếu đang cân lại, giữ nguyên loại cân dựa trên lần cân trước
      if (_previousWeighingType == 'xuat') {
        autoDetectedType = WeighingType.xuat;
        statusMessage = 'CÂN LẠI XUẤT';
      } else {
        autoDetectedType = WeighingType.nhap;
        statusMessage = 'CÂN LẠI NHẬP';
      }
    } else {
      // Nếu chưa cân lại
      if (isNhapWeighedFromServer == true) {
        autoDetectedType = WeighingType.xuat;
        statusMessage = 'CÂN XUẤT';
      } else {
        autoDetectedType = WeighingType.nhap;
        statusMessage = 'CÂN NHẬP';
      }
    }

    if (kDebugMode) {
      print('📊 Trạng thái mã $code:');
      print('  - Đã cân nhập: $isNhapWeighedFromServer');
      print('  - Đã cân xuất: $isXuatWeighedFromServer');
      print('  - Đang cân lại: $_isReweighing (từ: $_previousWeighingType)');
      print('  - Loại tự động: $statusMessage');
    }

    // --- BƯỚC 3: CẬP NHẬT LOẠI CÂN ---
    _selectedWeighingType = autoDetectedType;

    // --- CẬP NHẬT UI ---
    if (!context.mounted) return;

    if (_activeOVNO == null || _activeOVNO != data['ovNO']) {
      _activeOVNO = data['ovNO'];
      _activeMemo = data['memo'];
    }

    _activeTotalTargetQty = (data['totalTargetQty'] as num? ?? 0.0).toDouble();
    _activeTotalNhap = (data['totalNhapWeighed'] as num? ?? 0.0).toDouble();
    _activeTotalXuat = (data['totalXuatWeighed'] as num? ?? 0.0).toDouble();
    _activeXWeighed = (data['x_WeighedNhap'] as num? ?? 0).toInt();
    _activeYTotal = (data['y_TotalPackages'] as num? ?? 0).toInt();
    _standardWeight = (data['qtys'] as num).toDouble();
    _calculateMinMax();

    final newRecord = WeighingRecord(
      maCode: data['maCode'],
      ovNO: data['ovNO'],
      package: data['package'],
      mUserID: data['mUserID'].toString(),
      qtys: (data['qtys'] as num).toDouble(),
      soLo: data['soLo'],
      tenPhoiKeo: data['tenPhoiKeo'],
      soMay: data['soMay'].toString(),
      nguoiThaoTac: data['nguoiThaoTac'],
    );

    _records.insert(0, newRecord);
    if (_records.length > 2) _records.removeLast();

    NotificationService().showToast(
      context: context,
      message: 'Scan mã $code thành công!\nLoại: $statusMessage',
      type: ToastType.success,
    );
  } on WeighingException catch (e) {
    if (kDebugMode) print('⚖️ Lỗi nghiệp vụ: ${e.message}');
    if (!context.mounted) return;
    NotificationService().showToast(context: context, message: e.message, type: ToastType.error);
  } catch (e) {
    if (kDebugMode) print('❌ Lỗi không xác định: $e');
    if (!context.mounted) return;
    NotificationService().showToast(context: context, message: 'Lỗi: $e', type: ToastType.error);
  } finally {
    notifyListeners();
  }
}

  // --- HOÀN TẤT CÂN ---
  Future<bool> completeCurrentWeighing(BuildContext context, double currentWeight) async {
    // 1. Kiểm tra cơ bản (Giữ nguyên)
    if (_records.isEmpty) {
      NotificationService().showToast(
        context: context,
        message: 'Vui lòng scan mã trước.',
        type: ToastType.error,
      );
      return false;
    }

    final currentRecord = _records[0];
    if (currentRecord.isSuccess == true) return true;

    final bool isInRange = (currentWeight >= _minWeight) && (currentWeight <= _maxWeight);
    if (!isInRange) {
      NotificationService().showToast(
        context: context,
        message: 'Lỗi: Trọng lượng không nằm trong phạm vi!',
        type: ToastType.error,
      );
      return false;
    }

    final thoiGianCan = DateTime.now();
    
    // THAY ĐỔI: Xác định loại cân (nhap/xuat/nhapLai/xuatLai)
    String loaiCan;
    if (_isReweighing) {
      // Đang cân lại
      if (_previousWeighingType == 'nhap') {
        loaiCan = 'nhapLai';
      } else if (_previousWeighingType == 'xuat') {
        loaiCan = 'xuatLai';
      } else {
        // Fallback (không nên xảy ra)
        loaiCan = (_selectedWeighingType == WeighingType.nhap) ? 'nhapLai' : 'xuatLai';
      }
    } else {
      // Cân lần đầu
      loaiCan = (_selectedWeighingType == WeighingType.nhap) ? 'nhap' : 'xuat';
    }

    final thoiGianString = DateFormat('yyyy-MM-dd HH:mm:ss').format(thoiGianCan);
    final db = await _dbHelper.database;

    // 3. Kiểm tra trạng thái mạng
    final bool isServerConnected = _serverStatus.isServerConnected;

    try {
      if (isServerConnected) {
        // --- 4. LOGIC KHI CÓ MẠNG (ONLINE) ---
        if (kDebugMode) print('🛰️ Online Mode: Đang gửi "Hoàn tất" lên server với loại: $loaiCan');
        
        final Map<String, dynamic> body = {
          'maCode': currentRecord.maCode,
          'khoiLuongCan': currentWeight,
          'thoiGianCan': thoiGianString,
          'loai': loaiCan,
        };
        
        final url = Uri.parse('$_apiBaseUrl/api/complete');
        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: json.encode(body),
        ).timeout(const Duration(seconds: 10));

        if (!context.mounted) return false;

        if (response.statusCode == 201) {
          // A. API THÀNH CÔNG (Online)
          final data = json.decode(response.body);
          
          // Cập nhật Hàng Tóm Tắt (lấy data mới từ server)
          final summary = data['summaryData'];
          if (summary != null) {
            _activeTotalTargetQty = (summary['totalTargetQty'] as num).toDouble();
            _activeTotalNhap = (summary['totalNhapWeighed'] as num).toDouble();
            _activeTotalXuat = (summary['totalXuatWeighed'] as num).toDouble();
            _activeMemo = summary['memo'];
          }
          
          // Cập nhật cache VmlWorkS (vì đã cân thành công)
          await db.update(
            'VmlWorkS',
            {'realQty': currentWeight, 'mixTime': thoiGianString, 'loai': loaiCan},
            where: 'maCode = ?',
            whereArgs: [currentRecord.maCode],
          );
          
          // (Không cần lưu vào HistoryQueue, vì server đã lưu)

        } else {
          // B. API BÁO LỖI (Vd: Lỗi 400 "Vượt khối lượng")
          final errorData = json.decode(response.body);
          throw WeighingException(errorData['message'] ?? 'Lỗi server ${response.statusCode}');
        }
      
      } else {
        // --- 5. LOGIC KHI MẤT MẠNG (OFFLINE) ---
        if (kDebugMode) print('🔌 Offline Mode: Đang lưu "Hoàn tất" vào cache với loại: $loaiCan');
        
        // THAY ĐỔI: Nếu đang cân lại, không cần kiểm tra trùng lặp nghiêm ngặt
        if (!_isReweighing) {
          // Kiểm tra (offline) xem đã cân chưa - chỉ khi KHÔNG phải cân lại
          // Đối với cân nhập
          if (loaiCan == 'nhap') {
            final existingInQueue = await db.query('HistoryQueue', where: 'maCode = ? AND loai = ?', whereArgs: [currentRecord.maCode, 'nhap']);
            if (existingInQueue.isNotEmpty) {
              throw WeighingException('Mã này đã được cân (đang chờ đồng bộ).');
            }
            final existingInCache = await db.query('VmlWorkS', where: 'maCode = ? AND realQty IS NOT NULL', whereArgs: [currentRecord.maCode]);
            if (existingInCache.isNotEmpty) {
              throw WeighingException('Mã này đã được cân nhập (đã đồng bộ).');
            }
          }
          
          // Đối với cân xuất
          if (loaiCan == 'xuat') {
            // 1) Bắt buộc phải đã có cân nhập trước (offline):
            final existingNhapInQueue = await db.query('HistoryQueue', where: 'maCode = ? AND loai = ?', whereArgs: [currentRecord.maCode, 'nhap']);
            final existingNhapInCache = await db.query('VmlWorkS', where: 'maCode = ? AND realQty IS NOT NULL', whereArgs: [currentRecord.maCode]);
            if (existingNhapInQueue.isEmpty && existingNhapInCache.isEmpty) {
              throw WeighingException('Lỗi: Mã này CHƯA CÂN NHẬP (offline).');
            }

            // 2) Ngăn chặn cân xuất trùng (đã có xuat chờ/đã lưu)
            final existingXuatInQueue = await db.query('HistoryQueue', where: 'maCode = ? AND loai = ?', whereArgs: [currentRecord.maCode, 'xuat']);
            if (existingXuatInQueue.isNotEmpty) {
              throw WeighingException('Mã này đã được cân xuất (đang chờ đồng bộ).');
            }
            final existingXuatInCache = await db.query('VmlWorkS', where: 'maCode = ? AND loai = ? AND realQty IS NOT NULL', whereArgs: [currentRecord.maCode, 'xuat']);
            if (existingXuatInCache.isNotEmpty) {
              throw WeighingException('Mã này đã được cân xuất (đã đồng bộ).');
            }
          }
        }
        
        // Lưu vào Cả 2 Bảng Cục bộ
        await db.transaction((txn) async {
          await txn.insert('HistoryQueue', {
            'maCode': currentRecord.maCode,
            'khoiLuongCan': currentWeight,
            'thoiGianCan': thoiGianString,
            'loai': loaiCan,
          });
          await txn.update(
            'VmlWorkS',
            {'realQty': currentWeight, 'mixTime': thoiGianString, 'loai': loaiCan},
            where: 'maCode = ?',
            whereArgs: [currentRecord.maCode],
          );
        });
      }

      // --- 6. CẬP NHẬT UI (CHUNG CHO CẢ ONLINE/OFFLINE THÀNH CÔNG) ---
      currentRecord.isSuccess = true;
      currentRecord.mixTime = thoiGianCan;
      currentRecord.realQty = currentWeight;
      currentRecord.loai = loaiCan;
      _standardWeight = 0.0;
      _calculateMinMax();

      // Reset trạng thái cân lại sau khi hoàn tất
      _isReweighing = false;
      _previousWeighingType = null;

      if (!context.mounted) return false;
      
      String loaiCanMessage;
      if (loaiCan == 'nhapLai') {
        loaiCanMessage = 'CÂN LẠI NHẬP';
      } else if (loaiCan == 'xuatLai') {
        loaiCanMessage = 'CÂN LẠI XUẤT';
      } else if (loaiCan == 'nhap') {
        loaiCanMessage = 'CÂN NHẬP';
      } else {
        loaiCanMessage = 'CÂN XUẤT';
      }

      NotificationService().showToast(
        context: context,
        message: 'Tên Phôi Keo: ${currentRecord.tenPhoiKeo}\n'
                 'Số Lô: ${currentRecord.soLo}\n'
                 'Loại: $loaiCanMessage\n'
                 'Đã cân: ${currentWeight.toStringAsFixed(3)} kg!',
        type: ToastType.success,
      );
      
      notifyListeners();
      return true;

    } on WeighingException catch (e) {
      // Bắt lỗi nghiệp vụ (Vd: "Vượt khối lượng", "Đã cân")
      if (kDebugMode) print('⚖️ Lỗi nghiệp vụ cân: ${e.message}');
      if (!context.mounted) return false;
      NotificationService().showToast(context: context, message: e.message, type: ToastType.error);
      return false;

    } catch (e) {
      // Bắt lỗi nghiêm trọng (Lỗi mạng, Lỗi SQLite)
      if (kDebugMode) print('❌ Lỗi nghiêm trọng khi hoàn tất: $e');
      if (!context.mounted) return false;
      NotificationService().showToast(
        context: context,
        message: 'Lỗi kết nối hoặc DB: $e',
        type: ToastType.error,
      );
      return false;
    }
  }
}