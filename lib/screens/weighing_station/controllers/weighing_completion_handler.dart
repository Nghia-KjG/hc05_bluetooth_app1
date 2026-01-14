import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import '../../../services/auth_service.dart';
import '../../../services/database_helper.dart';
import '../../../services/server_status_service.dart';
import 'weighing_calculator.dart';
import 'weighing_scan_handler.dart';

/// Handler để xử lý logic hoàn tất cân
class WeighingCompletionHandler {
  final String apiBaseUrl;
  final DatabaseHelper dbHelper;
  final ServerStatusService serverStatus;
  final WeighingCalculator calculator;

  WeighingCompletionHandler({
    required this.apiBaseUrl,
    required this.dbHelper,
    required this.serverStatus,
    required this.calculator,
  });

  /// Hoàn tất cân (online)
  Future<Map<String, dynamic>> completeOnline({
    required String maCode,
    required double currentWeight,
    required String loaiCan,
    required String? deviceName,
  }) async {
    final thoiGianCan = DateTime.now();
    final thoiGianString = DateFormat('yyyy-MM-dd HH:mm:ss').format(thoiGianCan);

    // Chuẩn bị body request
    final Map<String, dynamic> body = {
      'maCode': maCode,
      'khoiLuongCan': currentWeight,
      'thoiGianCan': thoiGianString,
      'loai': loaiCan,
      'WUserID': AuthService().mUserID,
      'device': deviceName,
    };

    // Chọn endpoint phù hợp
    final String endpoint = (loaiCan == 'nhapLai' || loaiCan == 'xuatLai')
        ? '/api/reweigh'
        : '/api/complete';

    if (kDebugMode) {
      print('🛰️ Online Mode: Đang gửi lên server...');
      print('  - Endpoint: $endpoint');
      print('  - loaiCan: $loaiCan');
    }

    final url = Uri.parse('$apiBaseUrl$endpoint');
    final response = await http
        .post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: json.encode(body),
        )
        .timeout(const Duration(seconds: 10));

    // Chấp nhận cả 200 (OK) và 201 (Created)
    if (response.statusCode == 200 || response.statusCode == 201) {
      return json.decode(response.body);
    } else {
      final errorData = json.decode(response.body);
      throw WeighingException(
        errorData['message'] ?? 'Lỗi server ${response.statusCode}',
      );
    }
  }

  /// Cập nhật cache sau khi hoàn tất online thành công
  Future<void> updateCacheAfterOnlineComplete({
    required Database db,
    required String maCode,
    required double currentWeight,
    required String loaiCan,
    required String thoiGianString,
  }) async {
    // Lấy giá trị cũ để cộng dồn
    final existingRecord = await db.query(
      'VmlWorkS',
      columns: ['weighedNhapAmount', 'weighedXuatAmount'],
      where: 'maCode = ?',
      whereArgs: [maCode],
    );

    final updateData = <String, dynamic>{
      'realQty': currentWeight,
      'mixTime': thoiGianString,
      'loai': loaiCan,
    };

    if (existingRecord.isNotEmpty) {
      final oldNhap =
          (existingRecord.first['weighedNhapAmount'] as num? ?? 0.0).toDouble();
      final oldXuat =
          (existingRecord.first['weighedXuatAmount'] as num? ?? 0.0).toDouble();

      if (loaiCan == 'nhap' || loaiCan == 'nhapLai') {
        final newNhapAmount = oldNhap + currentWeight;
        updateData['weighedNhapAmount'] = newNhapAmount;
      } else if (loaiCan == 'xuat' || loaiCan == 'xuatLai') {
        final newXuatAmount = oldXuat + currentWeight;
        updateData['weighedXuatAmount'] = newXuatAmount;
      }
    }

    await db.update(
      'VmlWorkS',
      updateData,
      where: 'maCode = ?',
      whereArgs: [maCode],
    );
  }

  /// Hoàn tất cân (offline) - lưu vào queue
  Future<void> completeOffline({
    required Database db,
    required String maCode,
    required double currentWeight,
    required String loaiCan,
    required String? deviceName,
  }) async {
    if (kDebugMode) {
      print('🔌 Offline Mode: Đang lưu "Hoàn tất" vào cache...');
    }

    final thoiGianCan = DateTime.now();
    final thoiGianString = DateFormat('yyyy-MM-dd HH:mm:ss').format(thoiGianCan);

    // Kiểm tra offline
    await _validateOfflineWeighing(db, maCode, loaiCan, currentWeight);

    // Lưu vào cả 2 bảng cục bộ
    await db.transaction((txn) async {
      // Lưu vào HistoryQueue
      await txn.insert('HistoryQueue', {
        'maCode': maCode,
        'khoiLuongCan': currentWeight,
        'thoiGianCan': thoiGianString,
        'loai': loaiCan,
        'WUserID': AuthService().mUserID,
        'device': deviceName,
      });

      // Cập nhật VmlWorkS
      final updateData = <String, dynamic>{
        'realQty': currentWeight,
        'mixTime': thoiGianString,
        'loai': loaiCan,
      };

      // Lấy giá trị cũ để cộng dồn
      final existingRecord = await txn.query(
        'VmlWorkS',
        columns: ['weighedNhapAmount', 'weighedXuatAmount'],
        where: 'maCode = ?',
        whereArgs: [maCode],
      );

      if (existingRecord.isNotEmpty) {
        final oldNhap =
            (existingRecord.first['weighedNhapAmount'] as num? ?? 0.0).toDouble();
        final oldXuat =
            (existingRecord.first['weighedXuatAmount'] as num? ?? 0.0).toDouble();

        if (loaiCan == 'nhap' || loaiCan == 'nhapLai') {
          final newNhapAmount = oldNhap + currentWeight;
          updateData['weighedNhapAmount'] = newNhapAmount;
        } else if (loaiCan == 'xuat' || loaiCan == 'xuatLai') {
          final newXuatAmount = oldXuat + currentWeight;
          updateData['weighedXuatAmount'] = newXuatAmount;
        }
      }

      await txn.update(
        'VmlWorkS',
        updateData,
        where: 'maCode = ?',
        whereArgs: [maCode],
      );
    });
  }

  /// Validate offline weighing (kiểm tra không được cân trùng)
  Future<void> _validateOfflineWeighing(
    Database db,
    String maCode,
    String loaiCan,
    double currentWeight,
  ) async {
    // Kiểm tra cho cân nhập
    if (loaiCan == 'nhap' || loaiCan == 'nhapLai') {
      final existingInQueue = await db.query(
        'HistoryQueue',
        where: 'maCode = ? AND loai = ?',
        whereArgs: [maCode, 'nhap'],
      );
      if (existingInQueue.isNotEmpty) {
        throw WeighingException('Mã này đã được cân (đang chờ đồng bộ).');
      }

      final existingInCache = await db.query(
        'VmlWorkS',
        where: 'maCode = ? AND realQty IS NOT NULL',
        whereArgs: [maCode],
      );
      if (existingInCache.isNotEmpty) {
        throw WeighingException('Mã này đã được cân nhập (đã đồng bộ).');
      }
    }

    // Kiểm tra cho cân xuất (offline)
    if (loaiCan == 'xuat' || loaiCan == 'xuatLai') {
      final weighedNhap = calculator.weighedNhapAmount;
      final weighedXuat = calculator.weighedXuatAmount;

      if (weighedNhap <= 0) {
        throw WeighingException('Lỗi: Mã này CHƯA CÂN NHẬP (offline).');
      }

      final newTotalXuat = weighedXuat + currentWeight;
      if (newTotalXuat > weighedNhap) {
        throw WeighingException(
          'Lỗi: Tổng xuất (${newTotalXuat.toStringAsFixed(2)} kg) vượt quá tổng nhập (${weighedNhap.toStringAsFixed(2)} kg)!',
        );
      }
    }
  }
}
