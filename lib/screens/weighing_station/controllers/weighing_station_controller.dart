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
import '../../../services/weight_stability_monitor.dart';
import '../../../services/audio_service.dart';
import '../../../services/settings_service.dart';

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

  // === TỰ ĐỘNG HOÀN TẤT ===
  WeightStabilityMonitor? _stabilityMonitor;
  Timer? _autoCompleteTimer;
  bool _isAutoCompletePending = false;

  /// Callback để thông báo UI (ví dụ: clear scan field) khi auto-complete hoàn tất
  VoidCallback? onAutoComplete;

  WeighingStationController({required this.bluetoothService});

  // --- HÀM TÍNH TOÁN ---
  void _calculateMinMax() {
    if (_standardWeight == 0) {
      _minWeight = 0.0;
      _maxWeight = 0.0;
    } else {
      // Nếu chọn 0.1 (100g option), tính cố định ±0.1kg
      // Nếu chọn các giá trị khác, tính theo phần trăm
      final deviation = _selectedPercentage == 0.1
          ? 0.1 // Cố định 100g (0.1kg)
          : _standardWeight * (_selectedPercentage / 100.0);
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
        final bool isXuatWeighed = data['isXuatWeighed'] == true || (loaiFromServer == 'xuat');

        // Kiểm tra xem mã đã cân xuất chưa (không cho phép cân lại nếu cân xuất rồi)
        if (isXuatWeighed) {
          throw WeighingException('Mã này đã được CÂN XUẤT (trên hệ thống). Không thể cân lại!');
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

      // --- BẮT ĐẦU SỬA LỖI ---
      // 1. Kiểm tra trạng thái từ VmlWorkS (cache đã đồng bộ)
      final String loaiFromCache = (data['loai'] ?? '').toString().toLowerCase().trim();
      final dynamic realQtyFromCache = data['realQty'];
      // Nếu `realQty` đã có (không null) coi là đã cân (nhập) — an toàn hơn khi `loai` có thể bị thiếu
      bool hasWeighedNhapInCache = (realQtyFromCache != null) || (loaiFromCache == 'nhap');

      // 2. Kiểm tra thêm HistoryQueue (dữ liệu chờ đồng bộ)
      final existingNhapInQueue = await db.query(
        'HistoryQueue',
        where: 'maCode = ? AND loai = ?',
        whereArgs: [code, 'nhap'],
      );
      bool hasWeighedNhapInQueue = existingNhapInQueue.isNotEmpty;

      // 3. Trạng thái "Đã cân nhập" = (đã cân trong cache) HOẶC (đã cân trong hàng đợi)
      isNhapWeighedFromServer = hasWeighedNhapInCache || hasWeighedNhapInQueue;
      // --- KẾT THÚC SỬA LỖI ---

      // Ghi lại dạng normalized để debug
      if (kDebugMode) {
        print('🔍 loaiFromCache="$loaiFromCache" (hasWeighedNhapInCache=$hasWeighedNhapInCache)');
        print('🔍 existingNhapInQueue (Chờ sync): ${existingNhapInQueue.length} (hasWeighedNhapInQueue=$hasWeighedNhapInQueue)');
      }
    }

    // --- BƯỚC 2: TỰ ĐỘNG XÁC ĐỊNH LOẠI CÂN DỰA TRÊN TRẠNG THÁI ---
    // - Nếu chưa cân nhập → loại = nhap
    // - Nếu đã cân nhập → loại = xuat
    WeighingType autoDetectedType = isNhapWeighedFromServer == true 
        ? WeighingType.xuat 
        : WeighingType.nhap;

    if (kDebugMode) {
      print('📊 Trạng thái mã $code:');
      print('  - Đã cân nhập: $isNhapWeighedFromServer');
      print('  - Loại tự động: ${autoDetectedType == WeighingType.nhap ? "CÂN NHẬP" : "CÂN XUẤT"}');
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

    // Reset monitor cho mã mới
    _stabilityMonitor?.reset();
    _isAutoCompletePending = false;
    _autoCompleteTimer?.cancel();

    final typeText = autoDetectedType == WeighingType.nhap ? "CÂN NHẬP" : "CÂN XUẤT";
    NotificationService().showToast(
      context: context,
      message: 'Scan mã $code thành công!\nLoại: $typeText',
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
  /// Hoàn tất phiếu cân (lưu trọng lượng thực tế).
  /// - Kiểm tra trọng lượng có nằm trong khoảng min-max không.
  /// - Gửi dữ liệu lên server nếu có mạng; nếu mất mạng thì lưu vào queue offline.
  /// - Cập nhật cache local VmlWorkS và HistoryQueue (offline).
  /// - Trả về true nếu thành công, false nếu lỗi.
  /// 
  /// Thêm thông báo thành công với tên phôi keo, số lô và khối lượng cân.
  /// Clear ô input scan khi hoàn tất thành công (qua callback onAutoComplete).
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
    final loaiCan = (_selectedWeighingType == WeighingType.nhap) ? 'nhap' : 'xuat';
    final thoiGianString = DateFormat('yyyy-MM-dd HH:mm:ss').format(thoiGianCan);
    final db = await _dbHelper.database;

    // 3. Kiểm tra trạng thái mạng
    final bool isServerConnected = _serverStatus.isServerConnected;

    try {
      if (isServerConnected) {
        // --- 4. LOGIC KHI CÓ MẠNG (ONLINE) ---
        if (kDebugMode) print('🛰️ Online Mode: Đang gửi "Hoàn tất" lên server...');
        
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
        if (kDebugMode) print('🔌 Offline Mode: Đang lưu "Hoàn tất" vào cache...');
        
        // Kiểm tra (offline) xem đã cân chưa
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
          //    - Trong HistoryQueue có bản ghi 'nhap' (chờ đồng bộ) HOẶC
          //    - Trong VmlWorkS có loai = 'nhap' và realQty IS NOT NULL (đã cân nhập và lưu)
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

      if (!context.mounted) return false;
      NotificationService().showToast(
        context: context,
        message: 'Tên Phôi Keo: ${currentRecord.tenPhoiKeo}\n'
                 'Số Lô: ${currentRecord.soLo}\n'
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

  // === PHƯƠNG THỨC TỰ ĐỘNG HOÀN TẤT ===
  /// Khởi tạo theo dõi ổn định cân
  void initWeightMonitoring(BuildContext context) {
    final settings = SettingsService();
    
    if (kDebugMode) {
      print('🔍 initWeightMonitoring - autoCompleteEnabled: ${settings.autoCompleteEnabled}');
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
      print('📊 Khởi tạo theo dõi ổn định (Delay: ${settings.stabilizationDelay}s, Threshold: ${settings.stabilityThreshold}kg)');
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

  /// Gọi khi cân ổn định
  void _onWeightStable(BuildContext context) {
    if (!context.mounted) return;
    if (_isAutoCompletePending) return;

    final settings = SettingsService();
    // Lấy trọng lượng TẠI THỜI ĐIỂM PHÁT HIỆN ỔN ĐỊNH
    final stableWeight = bluetoothService.currentWeight.value;
    
    // Check range lần 1 (như cũ)
    final isInRange = (stableWeight >= _minWeight) && (stableWeight <= _maxWeight);
    if (!isInRange) return; // Bỏ qua nếu không trong range
    
    if (kDebugMode) {
      print('✅ Cân ổn định ($stableWeight kg)! Đợi ${settings.autoCompleteDelay}s...');
    }

    _isAutoCompletePending = true;
    // Hiển thị thông báo nhỏ (tùy chọn) để người dùng biết sắp lưu
    // NotificationService().showToast(context: context, message: "Giữ nguyên...", type: ToastType.info);

    _autoCompleteTimer = Timer(
      Duration(seconds: settings.autoCompleteDelay),
      () async {
        if (!context.mounted) return;
        
        // Lấy trọng lượng TẠI THỜI ĐIỂM LƯU (sau khi chờ)
        final currentWeight = bluetoothService.currentWeight.value;
        
        // --- SỬA ĐỔI QUAN TRỌNG TẠI ĐÂY ---
        // Nếu trong lúc chờ, người dùng đã nhấc hàng ra (trọng lượng giảm mạnh hoặc về 0)
        // Thì HỦY BỎ và KHÔNG BÁO LỖI
        if (currentWeight < _minWeight) {
           if (kDebugMode) print('⚠️ Hủy tự động: Hàng đã bị nhấc ra trước khi hoàn tất.');
           _isAutoCompletePending = false;
           return; 
        }
        // -----------------------------------

        final success = await completeCurrentWeighing(context, currentWeight);
        
        if (success) {
          if (settings.beepOnSuccess) {
            if (kDebugMode) print('🎵 Gọi playSuccessBeep()...');
            await AudioService().playSuccessBeep();
          }
          // Thông báo UI để dọn dẹp scan input (clear, stop simulation, ...)
          try {
            onAutoComplete?.call();
          } catch (e) {
            if (kDebugMode) print('⚠️ Lỗi khi gọi onAutoComplete: $e');
          }
        }
        _isAutoCompletePending = false;
      },
    );
  }

  /// Hủy monitoring khi rời màn hình
  void cancelAutoComplete() {
    _autoCompleteTimer?.cancel();
    _autoCompleteTimer = null;
    _stabilityMonitor?.dispose();
    _stabilityMonitor = null;
    _isAutoCompletePending = false;
    // Hủy callback UI để tránh leak
    onAutoComplete = null;
  }

  @override
  void dispose() {
    cancelAutoComplete();
    super.dispose();
  }
}