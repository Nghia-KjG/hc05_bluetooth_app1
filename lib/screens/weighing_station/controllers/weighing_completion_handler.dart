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
      // Nếu là cân lại, XÓA bản ghi cũ trong HistoryQueue trước
      if (loaiCan == 'nhapLai') {
        await txn.delete(
          'HistoryQueue',
          where: 'maCode = ? AND loai = ?',
          whereArgs: [maCode, 'nhap'],
        );
        if (kDebugMode) print('🗑️ Đã xóa bản ghi cân nhập cũ trong queue');
      } else if (loaiCan == 'xuatLai') {
        await txn.delete(
          'HistoryQueue',
          where: 'maCode = ? AND loai = ?',
          whereArgs: [maCode, 'xuat'],
        );
        if (kDebugMode) print('🗑️ Đã xóa bản ghi cân xuất cũ trong queue');
      }

      // Lưu vào HistoryQueue
      // Khi cân lại offline: lưu lại là 'nhap'/'xuat' (không phải 'nhapLai'/'xuatLai')
      // Vì bản ghi cũ đã bị xóa, nên không cần phân biệt khi đồng bộ lên server
      String loaiToSave = loaiCan;
      if (loaiCan == 'nhapLai') {
        loaiToSave = 'nhap';
      } else if (loaiCan == 'xuatLai') {
        loaiToSave = 'xuat';
      }
      
      await txn.insert('HistoryQueue', {
        'maCode': maCode,
        'khoiLuongCan': currentWeight,
        'thoiGianCan': thoiGianString,
        'loai': loaiToSave, // Lưu 'nhap'/'xuat' thay vì 'nhapLai'/'xuatLai'
        'WUserID': AuthService().mUserID,
        'device': deviceName,
      });

      // Cập nhật VmlWorkS
      final updateData = <String, dynamic>{
        'realQty': currentWeight,
        'mixTime': thoiGianString,
        'loai': loaiToSave, // Cũng lưu 'nhap'/'xuat'
      };

      // QUAN TRỌNG: KHÔNG cộng vào cache khi offline!
      // - Cache chỉ lưu giá trị từ SERVER (đã đồng bộ)
      // - Queue lưu giá trị offline (chờ đồng bộ)
      // - Khi tính weighedAmounts: cache + queue
      // - Nếu cộng vào cache ở đây → gấp đôi!
      
      // Chỉ cập nhật realQty, mixTime, loai - KHÔNG cập nhật weighedAmounts

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
    if (loaiCan == 'nhap') {
      // Chỉ kiểm tra khi cân nhập lần đầu (không phải cân lại)
      // Không còn 'nhapLai' trong queue nữa (đã chuyển thành 'nhap')
      final existingInQueue = await db.query(
        'HistoryQueue',
        where: 'maCode = ? AND loai = ?',
        whereArgs: [maCode, 'nhap'],
      );
      if (existingInQueue.isNotEmpty) {
        throw WeighingException('Mã này đã được cân nhập (đang chờ đồng bộ).');
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
    
    // Không validate cho nhapLai/xuatLai vì đó là cân lại (cho phép thay thế)

    // Kiểm tra cho cân xuất (offline)
    if (loaiCan == 'xuat' || loaiCan == 'xuatLai') {
      final weighedNhap = calculator.weighedNhapAmount;
      
      if (weighedNhap <= 0) {
        throw WeighingException('Lỗi: Mã này CHƯA CÂN NHẬP (offline).');
      }

      // Logic khác nhau cho xuất lần đầu vs xuất lại
      if (loaiCan == 'xuatLai') {
        // Xuất LẠI: Logic đặc biệt - phần xuất cũ được "hoàn trả"
        // Có thể xuất tối đa = Còn lại + Khối lượng xuất cũ
        
        // 1. Lấy khối lượng xuất CŨ (đang chuẩn bị xóa)
        final oldXuatQueue = await db.query(
          'HistoryQueue',
          where: 'maCode = ? AND loai = ?',
          whereArgs: [maCode, 'xuat'],
        );
        
        double oldXuatAmount = 0.0;
        for (var row in oldXuatQueue) {
          oldXuatAmount += (row['khoiLuongCan'] as num? ?? 0.0).toDouble();
        }
        
        // 2. Lấy từ cache (đã đồng bộ)
        final cacheRecord = await db.query(
          'VmlWorkS',
          columns: ['weighedXuatAmount'],
          where: 'maCode = ?',
          whereArgs: [maCode],
        );
        final cachedXuat = cacheRecord.isNotEmpty
            ? (cacheRecord.first['weighedXuatAmount'] as num? ?? 0.0).toDouble()
            : 0.0;
        
        // 3. Tổng xuất KHÁC = chỉ cache (không tính xuất cũ trong queue)
        // Vì không còn xuatLai trong queue nữa (đã chuyển thành 'xuat')
        final otherXuatAmount = cachedXuat;
        
        // 4. CÂN LẠI: Cho phép = Còn lại + Xuất cũ (hoàn trả)
        final remainingAllowed = weighedNhap - otherXuatAmount;
        final maxAllowed = remainingAllowed + oldXuatAmount;
        
        if (currentWeight > maxAllowed) {
          throw WeighingException(
            'Lỗi: Xuất lại (${currentWeight.toStringAsFixed(2)} kg) vượt quá khối lượng cho phép (${maxAllowed.toStringAsFixed(2)} kg)!\n'
            'Còn lại: ${remainingAllowed.toStringAsFixed(2)} kg + Xuất cũ: ${oldXuatAmount.toStringAsFixed(2)} kg',
          );
        }
        
        if (kDebugMode) {
          print('🔄 Xuất lại: ${currentWeight.toStringAsFixed(2)} kg');
          print('  - Tổng nhập: ${weighedNhap.toStringAsFixed(2)} kg');
          print('  - Cache xuất: ${cachedXuat.toStringAsFixed(2)} kg');
          print('  - Xuất cũ (hoàn trả): ${oldXuatAmount.toStringAsFixed(2)} kg');
          print('  - Đã xuất (khác): ${otherXuatAmount.toStringAsFixed(2)} kg');
          print('  - Còn lại: ${remainingAllowed.toStringAsFixed(2)} kg');
          print('  - Tối đa cho phép: ${maxAllowed.toStringAsFixed(2)} kg ✅');
        }
      } else {
        // Xuất LẦN ĐẦU: cộng thêm vào tổng xuất hiện tại
        final weighedXuat = calculator.weighedXuatAmount;
        final newTotalXuat = weighedXuat + currentWeight;
        if (newTotalXuat > weighedNhap) {
          throw WeighingException(
            'Lỗi: Tổng xuất (${newTotalXuat.toStringAsFixed(2)} kg) vượt quá tổng nhập (${weighedNhap.toStringAsFixed(2)} kg)!',
          );
        }
      }
    }
  }
}
