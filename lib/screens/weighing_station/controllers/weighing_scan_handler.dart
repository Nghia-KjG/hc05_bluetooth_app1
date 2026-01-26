import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import '../../../data/weighing_data.dart';
import '../../../services/database_helper.dart';
import '../../../services/language_service.dart';
import '../../../services/server_status_service.dart';
import 'weighing_calculator.dart';

class WeighingException implements Exception {
  final String message;
  WeighingException(this.message);
}

/// Handler để xử lý logic scan mã
class WeighingScanHandler {
  final String apiBaseUrl;
  final DatabaseHelper dbHelper;
  final ServerStatusService serverStatus;
  final WeighingCalculator calculator;

  WeighingScanHandler({
    required this.apiBaseUrl,
    required this.dbHelper,
    required this.serverStatus,
    required this.calculator,
  });

  /// Lấy dữ liệu offline từ cache
  Future<Map<String, dynamic>> scanFromCache(Database db, String code) async {
    final List<Map<String, dynamic>> localData = await db.rawQuery(
      '''
        SELECT S.maCode, S.ovNO, S.package, S.mUserID, S.qtys,
          S.realQty,
          S.loai,
          S.weighedNhapAmount,
          S.weighedXuatAmount,
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
        print(
          '🔍 ${LanguageService().translate('found_in_cache').replaceAll('\$1', code)}',
        );
      }
      return localData.first;
    } else {
      // Nếu mã không tìm thấy, trả về bản ghi với giá trị mặc định
      if (kDebugMode) {
        print(
          '⚠️ ${LanguageService().translate('not_in_cache_default').replaceAll('\$1', code)}',
        );
      }
      return {
        'maCode': code,
        'ovNO': null,
        'package': 0,
        'mUserID': null,
        'qtys': 0.0,
        'realQty': null,
        'loai': null,
        'weighedNhapAmount': 0.0,
        'weighedXuatAmount': 0.0,
        'tenPhoiKeo': null,
        'soMay': null,
        'memo': null,
        'totalTargetQty': 0.0,
        'nguoiThaoTac': null,
        'soLo': 0,
      };
    }
  }

  /// Scan mã từ server (online)
  Future<Map<String, dynamic>> scanFromServer(String code) async {
    if (kDebugMode) {
      print('🛰️ ${LanguageService().translate('online_checking_api')}');
    }

    final url = Uri.parse('$apiBaseUrl/api/scan/$code');
    final response = await http.get(url).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      
      // Kiểm tra isEmpty từ backend
      final isEmpty = data['isEmpty'];
      if (isEmpty == 1 || isEmpty == true) {
        if (kDebugMode) {
          print('⚠️ Mã $code đã cân hoàn tất (isEmpty = 1)');
        }
        throw WeighingException(
          'Mã $code đã cân hoàn tất!\nKhông thể cân tiếp.',
        );
      }
      
      return data;
    } else if (response.statusCode == 404) {
      final errorData = json.decode(response.body);
      throw WeighingException(
        errorData['message'] ?? LanguageService().translate('code_not_found'),
      );
    } else {
      throw WeighingException(
        LanguageService()
            .translate('server_error_retry_offline')
            .replaceAll('\$1', '${response.statusCode}'),
      );
    }
  }

  /// Lưu cache từ data online
  Future<void> saveCacheFromOnlineData(
    Database db,
    Map<String, dynamic> data,
    String scannedCode,
  ) async {
    // Lưu cache VmlWork
    await db.insert('VmlWork', {
      'ovNO': data['ovNO'],
      'tenPhoiKeo': data['tenPhoiKeo'],
      'soMay': data['soMay'],
      'memo': data['memo'],
      'totalTargetQty': data['totalTargetQty'],
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    // Lưu cache VmlPersion
    await db.insert('VmlPersion', {
      'mUserID': data['mUserID'].toString(),
      'nguoiThaoTac': data['nguoiThaoTac'],
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    // Lưu cache VmlWorkS
    if (data['codes'] != null && data['codes'] is List) {
      final List<dynamic> codes = data['codes'];
      for (var codeData in codes) {
        await db.insert('VmlWorkS', {
          'maCode': codeData['maCode'],
          'ovNO': data['ovNO'],
          'package': codeData['package'],
          'mUserID': codeData['mUserID']?.toString(),
          'qtys': codeData['qtys'],
          'realQty': codeData['realQty'],
          'mixTime': codeData['mixTime'],
          'loai':
              (codeData['isNhapWeighed'] == 1 ||
                      codeData['isNhapWeighed'] == true)
                  ? 'nhap'
                  : null,
          'weighedNhapAmount': codeData['weighedNhapAmount'] ?? 0.0,
          'weighedXuatAmount': codeData['weighedXuatAmount'] ?? 0.0,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    } else {
      // Không có codes array - lưu mã đơn lẻ
      final bool flagNhap =
          data['isNhapWeighed'] == true || data['isNhapWeighed'] == 1;

      await db.insert('VmlWorkS', {
        'maCode': scannedCode,
        'ovNO': data['ovNO'],
        'package': data['package'],
        'mUserID': data['mUserID']?.toString(),
        'qtys': data['qtys'],
        'realQty': data['realQty'],
        'mixTime': data['mixTime'],
        'loai': flagNhap ? 'nhap' : null,
        'weighedNhapAmount': data['weighedNhapAmount'] ?? 0.0,
        'weighedXuatAmount': data['weighedXuatAmount'] ?? 0.0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  /// Parse weighing records từ data
  List<WeighingRecord> parseRecordsFromData(
    Map<String, dynamic> data,
    String scannedCode,
  ) {
    final List<WeighingRecord> records = [];

    if (data['codes'] != null && data['codes'] is List) {
      final List<dynamic> codes = data['codes'];

      for (var codeData in codes) {
        // Parse mixTime từ backend nếu có
        DateTime? mixTime;
        if (codeData['mixTime'] != null) {
          try {
            mixTime = DateTime.parse(codeData['mixTime'].toString());
          } catch (e) {
            if (kDebugMode){
              print(
                '⚠️ ${LanguageService().translate('parse_mixtime_error')}: $e',
              );
            } 
          }
        }

        final newRecord = WeighingRecord(
          maCode: codeData['maCode'] ?? '',
          ovNO: data['ovNO'] ?? '',
          package: (codeData['package'] as num? ?? 0).toInt(),
          mUserID: (codeData['mUserID'] ?? '').toString(),
          qtys: (codeData['qtys'] as num? ?? 0.0).toDouble(),
          soLo: (data['soLo'] as num? ?? 0).toInt(),
          tenPhoiKeo: data['tenPhoiKeo'],
          soMay: (data['soMay'] ?? '').toString(),
          nguoiThaoTac: data['nguoiThaoTac'],
          weighedNhapAmount:
              (codeData['weighedNhapAmount'] as num? ?? 0.0).toDouble(),
          weighedXuatAmount:
              (codeData['weighedXuatAmount'] as num? ?? 0.0).toDouble(),
          mixTime: mixTime,
        );
        records.add(newRecord);
      }
    } else {
      // Không có codes array - tạo record đơn lẻ
      final newRecord = WeighingRecord(
        maCode: data['maCode'] ?? scannedCode,
        ovNO: data['ovNO'] ?? '',
        package: (data['package'] as num? ?? 0).toInt(),
        mUserID: (data['mUserID'] ?? '').toString(),
        qtys: (data['qtys'] as num? ?? 0.0).toDouble(),
        soLo: (data['soLo'] as num? ?? 0).toInt(),
        tenPhoiKeo: data['tenPhoiKeo'],
        soMay: (data['soMay'] ?? '').toString(),
        nguoiThaoTac: data['nguoiThaoTac'],
        weighedNhapAmount:
            (data['weighedNhapAmount'] as num? ?? 0.0).toDouble(),
        weighedXuatAmount:
            (data['weighedXuatAmount'] as num? ?? 0.0).toDouble(),
      );
      records.add(newRecord);
    }

    return records;
  }

  /// Kiểm tra xem đã xuất hết chưa
  void validateNotFullyExported(double weighedNhap, double weighedXuat) {
    if (weighedNhap > 0 && weighedXuat >= weighedNhap) {
      throw WeighingException(
        LanguageService()
            .translate('fully_exported_cannot_weigh')
            .replaceAll('\$1', weighedXuat.toStringAsFixed(2))
            .replaceAll('\$2', weighedNhap.toStringAsFixed(2)),
      );
    }
  }

  /// Xác định loại cân tự động (nhập/xuất) dựa trên trạng thái
  WeighingType determineAutoWeighingType(bool? isNhapWeighed) {
    return isNhapWeighed == true ? WeighingType.xuat : WeighingType.nhap;
  }
}
