import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import '../../../data/weighing_data.dart';
import '../../../services/bluetooth_service.dart';
import '../../../services/database_helper.dart';
import '../../../services/language_service.dart';
import '../../../services/notification_service.dart';
import '../../../services/server_status_service.dart';
import '../../../services/settings_service.dart';
import '../../../services/audio_service.dart';
import 'weighing_auto_complete_manager.dart';
import 'weighing_calculator.dart';
import 'weighing_completion_handler.dart';
import 'weighing_scan_handler.dart';
import 'weighing_state_manager.dart';

export 'weighing_calculator.dart' show WeighingType;
export 'weighing_scan_handler.dart' show WeighingException;

/// Main controller cho Weighing Station - Đã được refactor thành các module nhỏ
class WeighingStationController with ChangeNotifier {
  final BluetoothService bluetoothService;

  // === SERVICES & HANDLERS ===
  final String _apiBaseUrl =
      dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:3636';
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final ServerStatusService _serverStatus = ServerStatusService();

  late final WeighingCalculator _calculator;
  late final WeighingScanHandler _scanHandler;
  late final WeighingCompletionHandler _completionHandler;
  late final WeighingAutoCompleteManager _autoCompleteManager;
  late final WeighingStateManager _stateManager;

  // === STATE VARIABLES ===
  String? _activeOVNO;
  String? _activeMemo;
  String? _scannedCode;
  String? _reweighCode;
  WeighingType? _originalWeighingType;

  final List<WeighingRecord> _records = [];

  double _activeTotalTargetQty = 0.0;
  double _activeTotalNhap = 0.0;
  double _activeTotalXuat = 0.0;
  int _activeXWeighed = 0;
  int _activeYTotal = 0;

  WeighingType _selectedWeighingType = WeighingType.nhap;

  // === GETTERS ===
  String? get activeOVNO => _activeOVNO;
  String? get activeMemo => _activeMemo;
  String? get scannedCode => _scannedCode;
  String? get reweighCode => _reweighCode;
  List<WeighingRecord> get records => _records;

  double get activeTotalTargetQty => _activeTotalTargetQty;
  double get activeTotalNhap => _activeTotalNhap;
  double get activeTotalXuat => _activeTotalXuat;
  int get activeXWeighed => _activeXWeighed;
  int get activeYTotal => _activeYTotal;

  WeighingType get selectedWeighingType => _selectedWeighingType;
  WeighingType? get originalWeighingType => _originalWeighingType;

  // Kiểm tra xem có đang ở chế độ xuất không (bao gồm cả cân xuất lại)
  bool get isXuatMode {
    if (_selectedWeighingType == WeighingType.xuat) {
      return true;
    }
    if (_selectedWeighingType == WeighingType.canLai &&
        _originalWeighingType == WeighingType.xuat) {
      return true;
    }
    return false;
  }

  // Delegates to calculator
  double get selectedPercentage => _calculator.selectedPercentage;
  double get khoiLuongMe => _calculator.standardWeight;
  double get minWeight => _calculator.minWeight;
  double get maxWeight => _calculator.maxWeight;
  double get weighedNhapAmount => _calculator.weighedNhapAmount;
  double get weighedXuatAmount => _calculator.weighedXuatAmount;
  double get remainingXuatAmount => _calculator.remainingXuatAmount;

  // Auto-complete
  VoidCallback? get onAutoComplete => _autoCompleteManager.onAutoComplete;
  set onAutoComplete(VoidCallback? callback) =>
      _autoCompleteManager.onAutoComplete = callback;

  WeighingStationController({required this.bluetoothService}) {
    // Khởi tạo các handlers
    _calculator = WeighingCalculator();
    _scanHandler = WeighingScanHandler(
      apiBaseUrl: _apiBaseUrl,
      dbHelper: _dbHelper,
      serverStatus: _serverStatus,
      calculator: _calculator,
    );
    _completionHandler = WeighingCompletionHandler(
      apiBaseUrl: _apiBaseUrl,
      dbHelper: _dbHelper,
      serverStatus: _serverStatus,
      calculator: _calculator,
    );
    _autoCompleteManager = WeighingAutoCompleteManager(
      bluetoothService: bluetoothService,
      calculator: _calculator,
      settings: SettingsService(),
    );
    _stateManager = WeighingStateManager(
      dbHelper: _dbHelper,
      calculator: _calculator,
    );

    // Set callback cho auto-complete
    _autoCompleteManager.onCompleteWeighing = completeCurrentWeighing;

    // Khôi phục state khi khởi tạo
    restoreState();
  }

  // === PUBLIC METHODS ===

  /// Cập nhật percentage
  void updatePercentage(double newPercentage) {
    _calculator.updatePercentage(newPercentage);
    notifyListeners();
  }

  /// Lấy tên cân hiện tại
  String? getConnectedDeviceName() {
    final device = bluetoothService.connectedDevice.value;
    return device?.name;
  }

  /// Cập nhật loại cân
  Future<void> updateWeighingType(
    WeighingType? newType,
    BuildContext context,
  ) async {
    if (newType == null) return;

    // Kiểm tra nếu user muốn chọn nhập nhưng đã có bản ghi nhập (offline)
    if (newType == WeighingType.nhap && _records.isNotEmpty) {
      final currentRecord = _records[0];
      final db = await _dbHelper.database;

      final existingInQueue = await db.query(
        'HistoryQueue',
        where: 'maCode = ? AND loai = ?',
        whereArgs: [currentRecord.maCode, 'nhap'],
      );
      final existingInCache = await db.query(
        'VmlWorkS',
        where: 'maCode = ? AND loai = ? AND realQty IS NOT NULL',
        whereArgs: [currentRecord.maCode, 'nhap'],
      );

      if (existingInQueue.isNotEmpty || existingInCache.isNotEmpty) {
        if (context.mounted) {
          NotificationService().showToast(
            context: context,
            message: LanguageService().translate('already_weighed_import'),
            type: ToastType.error,
          );
        }
        return;
      }
    }

    // Reset chế độ cân lại nếu người dùng chọn nhập hoặc xuất
    if (newType == WeighingType.nhap || newType == WeighingType.xuat) {
      _reweighCode = null;
      _originalWeighingType = null;
      if (kDebugMode) {
        print(
          '🔓 ${LanguageService().translate('exit_reweigh_mode')} $newType',
        );
      }
    }

    _selectedWeighingType = newType;
    _calculator.updateWeighingType(newType);
    notifyListeners();
  }

  /// Yêu cầu cân lại mã
  Future<void> requestReweigh(BuildContext context, String maCode) async {
    // Tìm record để xác định loại cân ban đầu
    WeighingRecord? record;
    try {
      record = _records.firstWhere((r) => r.maCode == maCode);
    } catch (e) {
      if (context.mounted) {
        NotificationService().showToast(
          context: context,
          message: '${LanguageService().translate('record_not_found')} $maCode',
          type: ToastType.error,
        );
      }
      return;
    }

    // Xác định loại cân ban đầu từ record
    WeighingType? originalType;
    if (record.loai != null) {
      final loaiNormalized = record.loai!.toLowerCase().trim();
      if (loaiNormalized == 'nhap') {
        originalType = WeighingType.nhap;
      } else if (loaiNormalized == 'xuat') {
        originalType = WeighingType.xuat;
      }
    }

    if (originalType == null) {
      NotificationService().showToast(
        context: context,
        message:
            '${LanguageService().translate('cannot_determine_weighing_type')} $maCode',
        type: ToastType.error,
      );
      return;
    }

    // Hiển thị dialog xác nhận
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(LanguageService().translate('reweigh')),
          content: Text(
            '${LanguageService().translate('reweigh_code_question')} $maCode?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(LanguageService().translate('cancel')),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(LanguageService().translate('confirm')),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      _selectedWeighingType = WeighingType.canLai;
      _reweighCode = maCode;
      _originalWeighingType = originalType;

      _calculator.reset();
      notifyListeners();

      if (context.mounted) {
        final typeText = originalType == WeighingType.nhap ? 'NHẬP' : 'XUẤT';
        NotificationService().showToast(
          context: context,
          message: 'Vui lòng scan lại mã $maCode để cân lại (từ $typeText)',
          type: ToastType.info,
        );
      }
    }
  }

  /// Xử lý scan mã
  Future<void> handleScan(BuildContext context, String code) async {
    // Kiểm tra nếu đang ở chế độ cân lại
    if (_selectedWeighingType == WeighingType.canLai) {
      if (code != _reweighCode) {
        if (context.mounted) {
          NotificationService().showToast(
            context: context,
            message:
                '${LanguageService().translate('reweigh_mode_scan_only')} $_reweighCode!',
            type: ToastType.error,
          );
        }
        return;
      }
    }

    // Xóa state cũ khi scan mã mới
    if (_scannedCode != null && _scannedCode != code) {
      await clearSavedState();
      if (kDebugMode) {
        print(
          '🔄 ${LanguageService().translate('new_code_clear_state')} ($_scannedCode → $code)',
        );
      }
    }

    try {
      final db = await _dbHelper.database;
      await _serverStatus.checkServer();
      final bool isServerConnected = _serverStatus.isServerConnected;

      Map<String, dynamic> data;
      bool? isNhapWeighedFromServer;
      double weighedNhap = 0.0;
      double weighedXuat = 0.0;

      if (isServerConnected) {
        // ONLINE MODE
        data = await _scanHandler.scanFromServer(code);

        // Xử lý weighedAmounts từ data
        if (data['codes'] != null && data['codes'] is List) {
          final List<dynamic> codes = data['codes'];
          for (var codeData in codes) {
            if (codeData['maCode'] == code) {
              isNhapWeighedFromServer =
                  codeData['isNhapWeighed'] == 1 ||
                  codeData['isNhapWeighed'] == true;
              weighedNhap =
                  (codeData['weighedNhapAmount'] as num? ?? 0.0).toDouble();
              weighedXuat =
                  (codeData['weighedXuatAmount'] as num? ?? 0.0).toDouble();
              break;
            }
          }
        } else {
          final bool flagNhap =
              data['isNhapWeighed'] == true || data['isNhapWeighed'] == 1;
          isNhapWeighedFromServer = flagNhap;
          weighedNhap = (data['weighedNhapAmount'] as num? ?? 0.0).toDouble();
          weighedXuat = (data['weighedXuatAmount'] as num? ?? 0.0).toDouble();
        }

        // Validate
        _scanHandler.validateNotFullyExported(weighedNhap, weighedXuat);

        // Lưu cache
        await _scanHandler.saveCacheFromOnlineData(db, data, code);
      } else {
        // OFFLINE MODE
        data = await _scanHandler.scanFromCache(db, code);

        // Xử lý trạng thái offline - hỗ trợ canLai mode
        final String loaiFromCache =
            (data['loai'] ?? '').toString().toLowerCase().trim();
        final dynamic realQtyFromCache = data['realQty'];

        // Khi ở chế độ canLai, cần kiểm tra dựa trên _originalWeighingType
        String loaiToCheck = loaiFromCache;
        if (_selectedWeighingType == WeighingType.canLai &&
            _originalWeighingType != null) {
          loaiToCheck =
              _originalWeighingType == WeighingType.nhap ? 'nhap' : 'xuat';
        }

        bool hasWeighedNhapInCache =
            (realQtyFromCache != null) || (loaiFromCache == 'nhap');

        final existingNhapInQueue = await db.query(
          'HistoryQueue',
          where: 'maCode = ? AND loai = ?',
          whereArgs: [code, 'nhap'],
        );
        bool hasWeighedNhapInQueue = existingNhapInQueue.isNotEmpty;

        // Khi canLai: kiểm tra dựa trên loai ban đầu
        if (_selectedWeighingType == WeighingType.canLai &&
            _originalWeighingType == WeighingType.xuat) {
          // Cân lại xuất: kiểm tra xem xuất đã được cân chưa
          hasWeighedNhapInCache = false;
          hasWeighedNhapInQueue = false;
        }

        isNhapWeighedFromServer =
            hasWeighedNhapInCache || hasWeighedNhapInQueue;

        // Tính weighedAmounts từ cache + queue
        final cachedNhap =
            (data['weighedNhapAmount'] as num? ?? 0.0).toDouble();
        final cachedXuat =
            (data['weighedXuatAmount'] as num? ?? 0.0).toDouble();

        final nhapQueue = await db.query(
          'HistoryQueue',
          where: 'maCode = ? AND loai = ?',
          whereArgs: [code, 'nhap'],
        );
        final xuatQueue = await db.query(
          'HistoryQueue',
          where: 'maCode = ? AND loai = ?',
          whereArgs: [code, 'xuat'],
        );

        double queueNhap = 0.0;
        double queueXuat = 0.0;
        for (var row in nhapQueue) {
          queueNhap += (row['khoiLuongCan'] as num? ?? 0.0).toDouble();
        }
        for (var row in xuatQueue) {
          queueXuat += (row['khoiLuongCan'] as num? ?? 0.0).toDouble();
        }

        // Logic đơn giản: cache + queue
        // (Không còn nhapLai/xuatLai vì đã chuyển thành nhap/xuat khi lưu)
        weighedNhap = cachedNhap + queueNhap;
        weighedXuat = cachedXuat + queueXuat;

        _scanHandler.validateNotFullyExported(weighedNhap, weighedXuat);
      }

      // Cập nhật calculator
      _calculator.updateWeighedAmounts(weighedNhap, weighedXuat);

      // Tự động xác định loại cân (trừ khi đang cân lại)
      if (_selectedWeighingType != WeighingType.canLai) {
        _selectedWeighingType = _scanHandler.determineAutoWeighingType(
          isNhapWeighedFromServer,
        );
        _calculator.updateWeighingType(_selectedWeighingType);
      } else {
        // Đang cân lại: cập nhật originalWeighingType vào calculator
        _calculator.setOriginalWeighingType(_originalWeighingType);
      }

      // Cập nhật UI state
      _activeOVNO = data['ovNO'];
      _activeMemo = data['memo'];
      _scannedCode = code;

      _activeTotalTargetQty =
          (data['totalTargetQty'] as num? ?? 0.0).toDouble();
      _activeTotalNhap = (data['totalNhapWeighed'] as num? ?? 0.0).toDouble();
      _activeTotalXuat = (data['totalXuatWeighed'] as num? ?? 0.0).toDouble();
      _activeXWeighed = (data['x_WeighedNhap'] as num? ?? 0).toInt();
      _activeYTotal = (data['y_TotalPackages'] as num? ?? 0).toInt();

      // Parse records
      _records.clear();
      _records.addAll(_scanHandler.parseRecordsFromData(data, code));

      // Tìm qtys của mã được scan để cập nhật calculator
      double scannedQtys = 0.0;
      for (var record in _records) {
        if (record.maCode == code) {
          scannedQtys = record.qtys;
          break;
        }
      }
      _calculator.updateStandardWeight(scannedQtys);

      // Reset auto-complete monitor
      _autoCompleteManager.reset();

      // Thông báo thành công
      if (context.mounted) {
        String notificationMessage;
        if (_selectedWeighingType == WeighingType.canLai) {
          notificationMessage = 'Scan mã $code thành công!\nLoại: CÂN LẠI';
        } else {
          final typeText =
              _selectedWeighingType == WeighingType.nhap
                  ? "CÂN NHẬP"
                  : "CÂN XUẤT";
          notificationMessage = 'Scan mã $code thành công!\nLoại: $typeText';
        }

        NotificationService().showToast(
          context: context,
          message: notificationMessage,
          type: ToastType.success,
        );
      }

      notifyListeners();
    } on WeighingException catch (e) {
      if (kDebugMode){
        print(
          '⚖️ ${LanguageService().translate('business_logic_error')}: ${e.message}',
        );}
      if (context.mounted) {
        NotificationService().showToast(
          context: context,
          message: e.message,
          type: ToastType.error,
        );
      }
    } catch (e) {
      if (kDebugMode){
        print('❌ ${LanguageService().translate('unknown_error')}: $e');}
      if (context.mounted) {
        NotificationService().showToast(
          context: context,
          message: 'Lỗi: $e',
          type: ToastType.error,
        );
      }
    }
  }

  /// Hoàn tất cân
  Future<bool> completeCurrentWeighing(
    BuildContext context,
    double currentWeight,
  ) async {
    // Kiểm tra cơ bản
    if (_records.isEmpty || _scannedCode == null) {
      NotificationService().showToast(
        context: context,
        message: LanguageService().translate('no_code_scanned'),
        type: ToastType.error,
      );
      return false;
    }

    final currentRecord = _records.firstWhere(
      (r) => r.maCode == _scannedCode,
      orElse: () => _records[0],
    );

    if (kDebugMode){
      print(
        '🎯 ${LanguageService().translate('completing_weighing_for')}: ${currentRecord.maCode}',
      );}

    if (currentRecord.isSuccess == true) return true;

    // Kiểm tra range
    if (!_calculator.isInRange(currentWeight)) {
      NotificationService().showToast(
        context: context,
        message: 'Lỗi: Trọng lượng không nằm trong phạm vi!',
        type: ToastType.error,
      );
      return false;
    }

    // Xác định loại cân
    String loaiCan;
    if (_selectedWeighingType == WeighingType.nhap) {
      loaiCan = 'nhap';
    } else if (_selectedWeighingType == WeighingType.xuat) {
      loaiCan = 'xuat';
    } else if (_selectedWeighingType == WeighingType.canLai) {
      if (_originalWeighingType == WeighingType.nhap) {
        loaiCan = 'nhapLai';
      } else if (_originalWeighingType == WeighingType.xuat) {
        loaiCan = 'xuatLai';
      } else {
        loaiCan = 'nhap';
      }
    } else {
      loaiCan = 'nhap';
    }

    if (kDebugMode) {
      print('🔍 DEBUG completeCurrentWeighing:');
      print('  - maCode: ${currentRecord.maCode}');
      print('  - _selectedWeighingType: $_selectedWeighingType');
      print('  - _originalWeighingType: $_originalWeighingType');
      print('  - loaiCan: $loaiCan');
      print('  - currentWeight: $currentWeight');
    }

    final db = await _dbHelper.database;
    final thoiGianCan = DateTime.now();
    final thoiGianString = DateFormat(
      'yyyy-MM-dd HH:mm:ss',
    ).format(thoiGianCan);

    // Kiểm tra trạng thái mạng
    await _serverStatus.checkServer();
    final bool isServerConnected = _serverStatus.isServerConnected;

    try {
      if (isServerConnected) {
        // ONLINE MODE
        final result = await _completionHandler.completeOnline(
          maCode: currentRecord.maCode,
          currentWeight: currentWeight,
          loaiCan: loaiCan,
          deviceName: getConnectedDeviceName(),
        );

        // Cập nhật summary từ server
        final summary = result['summaryData'];
        if (summary != null) {
          _activeTotalTargetQty = (summary['totalTargetQty'] as num).toDouble();
          _activeTotalNhap = (summary['totalNhapWeighed'] as num).toDouble();
          _activeTotalXuat = (summary['totalXuatWeighed'] as num).toDouble();
          _activeMemo = summary['memo'];
        }

        // Cập nhật cache
        await _completionHandler.updateCacheAfterOnlineComplete(
          db: db,
          maCode: currentRecord.maCode,
          currentWeight: currentWeight,
          loaiCan: loaiCan,
          thoiGianString: thoiGianString,
        );
      } else {
        // OFFLINE MODE
        await _completionHandler.completeOffline(
          db: db,
          maCode: currentRecord.maCode,
          currentWeight: currentWeight,
          loaiCan: loaiCan,
          deviceName: getConnectedDeviceName(),
        );
      }

      // Lưu lịch sử cân cục bộ (không xóa sau khi sync)
      await db.insert(
        'LocalHistory',
        {
          'maCode': currentRecord.maCode,
          'khoiLuongCan': currentWeight,
          'thoiGianCan': thoiGianString,
          'loai': loaiCan,
          'ovNO': _activeOVNO,
          'device': getConnectedDeviceName(),
          'tenPhoiKeo': currentRecord.tenPhoiKeo,
          'soMay': currentRecord.soMay,
          'package': currentRecord.package,
          'mUserID': currentRecord.mUserID,
          'nguoiThaoTac': currentRecord.nguoiThaoTac,
          'qtys': currentRecord.qtys,
          'realQty': currentWeight,
          'memo': _activeMemo,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // Cập nhật UI
      currentRecord.isSuccess = true;
      currentRecord.mixTime = thoiGianCan;
      currentRecord.realQty = currentWeight;
      currentRecord.loai = loaiCan;

      _calculator.reset();

      // Reset chế độ cân lại
      if (_selectedWeighingType == WeighingType.canLai) {
        _selectedWeighingType = WeighingType.nhap;
        _reweighCode = null;
        _originalWeighingType = null;
      }

      // Phát âm thanh thành công (fallback ngoài auto-complete)
      if (SettingsService().beepOnSuccess) {
        try {
          if (kDebugMode) print('🎵 playSuccessBeep() từ completeCurrentWeighing');
          await AudioService().playSuccessBeep();
        } catch (e) {
          if (kDebugMode) print('🔇 Lỗi playSuccessBeep(): $e');
        }
      }

      if (context.mounted) {
        final String actionText =
            loaiCan == 'nhapLai' || loaiCan == 'xuatLai' ? 'Cân lại' : 'Đã cân';
        NotificationService().showToast(
          context: context,
          message:
              'Tên Phôi Keo: ${currentRecord.tenPhoiKeo}\n'
              'Số Lô: ${currentRecord.soLo}\n'
              '$actionText: ${currentWeight.toStringAsFixed(2)} kg!',
          type: ToastType.success,
        );
      }

      notifyListeners();
      return true;
    } on WeighingException catch (e) {
      if (kDebugMode){
        print(
          '⚖️ ${LanguageService().translate('weighing_business_error')}: ${e.message}',
        );}
      if (context.mounted) {
        NotificationService().showToast(
          context: context,
          message: e.message,
          type: ToastType.error,
        );
      }
      return false;
    } catch (e) {
      if (kDebugMode){
        print(
          '❌ ${LanguageService().translate('critical_error_completing')}: $e',
        );}
      if (context.mounted) {
        NotificationService().showToast(
          context: context,
          message: 'Lỗi kết nối hoặc DB: $e',
          type: ToastType.error,
        );
      }
      return false;
    }
  }

  // === AUTO-COMPLETE METHODS ===

  void initWeightMonitoring(BuildContext context) {
    _autoCompleteManager.initWeightMonitoring(context);
  }

  void addWeightSample(double weight) {
    _autoCompleteManager.addWeightSample(weight);
  }

  void cancelAutoComplete() {
    _autoCompleteManager.dispose();
  }

  // === STATE MANAGEMENT ===

  Future<void> saveState() async {
    await _stateManager.saveState(
      activeOVNO: _activeOVNO,
      activeMemo: _activeMemo,
      scannedCode: _scannedCode,
      activeTotalTargetQty: _activeTotalTargetQty,
      activeTotalNhap: _activeTotalNhap,
      activeTotalXuat: _activeTotalXuat,
      activeXWeighed: _activeXWeighed,
      activeYTotal: _activeYTotal,
      selectedWeighingTypeIndex: _selectedWeighingType.index,
    );
  }

  Future<void> restoreState() async {
    final state = await _stateManager.restoreState();
    if (state == null) return;

    _activeOVNO = state['activeOVNO'] as String?;
    _activeMemo = state['activeMemo'] as String?;
    _scannedCode = state['scannedCode'] as String?;
    _activeTotalTargetQty =
        (state['activeTotalTargetQty'] as num?)?.toDouble() ?? 0.0;
    _activeTotalNhap = (state['activeTotalNhap'] as num?)?.toDouble() ?? 0.0;
    _activeTotalXuat = (state['activeTotalXuat'] as num?)?.toDouble() ?? 0.0;
    _activeXWeighed = (state['activeXWeighed'] as num?)?.toInt() ?? 0;
    _activeYTotal = (state['activeYTotal'] as num?)?.toInt() ?? 0;

    final weighingTypeIndex =
        (state['selectedWeighingType'] as num?)?.toInt() ?? 0;
    _selectedWeighingType = WeighingType.values[weighingTypeIndex];

    // Khôi phục records
    if (_scannedCode != null && _activeOVNO != null) {
      _records.clear();
      _records.addAll(await _stateManager.restoreRecords(_activeOVNO!));
    }

    notifyListeners();
  }

  Future<void> clearSavedState() async {
    await _stateManager.clearSavedState();
  }

  @override
  void dispose() {
    saveState();
    cancelAutoComplete();
    super.dispose();
  }
}
