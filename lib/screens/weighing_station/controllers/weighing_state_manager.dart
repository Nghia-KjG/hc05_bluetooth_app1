import 'package:flutter/foundation.dart';
import '../../../data/weighing_data.dart';
import '../../../services/database_helper.dart';
import 'weighing_calculator.dart';

/// Manager để lưu và khôi phục state
class WeighingStateManager {
  final DatabaseHelper dbHelper;
  final WeighingCalculator calculator;

  WeighingStateManager({
    required this.dbHelper,
    required this.calculator,
  });

  /// Lưu state hiện tại vào database
  Future<void> saveState({
    required String? activeOVNO,
    required String? activeMemo,
    required String? scannedCode,
    required double activeTotalTargetQty,
    required double activeTotalNhap,
    required double activeTotalXuat,
    required int activeXWeighed,
    required int activeYTotal,
    required int selectedWeighingTypeIndex,
  }) async {
    try {
      final db = await dbHelper.database;

      // Xóa state cũ
      await db.delete('WeighingState');

      // Lưu state mới
      final calculatorState = calculator.toMap();
      
      await db.insert('WeighingState', {
        'activeOVNO': activeOVNO,
        'activeMemo': activeMemo,
        'scannedCode': scannedCode,
        'activeTotalTargetQty': activeTotalTargetQty,
        'activeTotalNhap': activeTotalNhap,
        'activeTotalXuat': activeTotalXuat,
        'activeXWeighed': activeXWeighed,
        'activeYTotal': activeYTotal,
        'weighedNhapAmount': calculatorState['weighedNhapAmount'],
        'weighedXuatAmount': calculatorState['weighedXuatAmount'],
        'selectedPercentage': calculatorState['selectedPercentage'],
        'standardWeight': calculatorState['standardWeight'],
        'selectedWeighingType': selectedWeighingTypeIndex,
        'timestamp': DateTime.now().toIso8601String(),
      });

      if (kDebugMode) {
        print('💾 Đã lưu state: OVNO=$activeOVNO, ScannedCode=$scannedCode');
      }
    } catch (e) {
      if (kDebugMode) print('❌ Lỗi lưu state: $e');
    }
  }

  /// Khôi phục state từ database
  Future<Map<String, dynamic>?> restoreState() async {
    try {
      final db = await dbHelper.database;

      // Lấy state đã lưu
      final List<Map<String, dynamic>> result = await db.query(
        'WeighingState',
        limit: 1,
      );

      if (result.isEmpty) {
        if (kDebugMode) print('ℹ️ Không có state để khôi phục');
        return null;
      }

      final state = result.first;

      // Khôi phục calculator state
      calculator.restoreFromMap(state);

      if (kDebugMode) {
        print(
          '✅ Đã khôi phục state: OVNO=${state['activeOVNO']}, ScannedCode=${state['scannedCode']}',
        );
      }

      return state;
    } catch (e) {
      if (kDebugMode) print('❌ Lỗi khôi phục state: $e');
      return null;
    }
  }

  /// Khôi phục danh sách records từ cache
  Future<List<WeighingRecord>> restoreRecords(String activeOVNO) async {
    try {
      final db = await dbHelper.database;
      final List<WeighingRecord> records = [];

      // Query tất cả mã cùng OVNO từ VmlWorkS
      final List<Map<String, dynamic>> allCodesInOVNO = await db.rawQuery(
        '''
          SELECT S.maCode, S.ovNO, S.package, S.mUserID, S.qtys,
            S.realQty, S.loai, S.weighedNhapAmount, S.weighedXuatAmount, S.mixTime,
            W.tenPhoiKeo, W.soMay, W.memo,
            P.nguoiThaoTac, S.package as soLo
          FROM VmlWorkS AS S
          LEFT JOIN VmlWork AS W ON S.ovNO = W.ovNO
          LEFT JOIN VmlPersion AS P ON S.mUserID = P.mUserID
          WHERE S.ovNO = ?
          ORDER BY S.package ASC
        ''',
        [activeOVNO],
      );

      for (var codeData in allCodesInOVNO) {
        // Parse mixTime nếu có
        DateTime? mixTime;
        if (codeData['mixTime'] != null) {
          try {
            mixTime = DateTime.parse(codeData['mixTime'].toString());
          } catch (e) {
            // Ignore parse error
          }
        }

        final newRecord = WeighingRecord(
          maCode: codeData['maCode'] ?? '',
          ovNO: codeData['ovNO'] ?? '',
          package: (codeData['package'] as num? ?? 0).toInt(),
          mUserID: (codeData['mUserID'] ?? '').toString(),
          qtys: (codeData['qtys'] as num? ?? 0.0).toDouble(),
          soLo: (codeData['soLo'] as num? ?? 0).toInt(),
          tenPhoiKeo: codeData['tenPhoiKeo'],
          soMay: (codeData['soMay'] ?? '').toString(),
          nguoiThaoTac: codeData['nguoiThaoTac'],
          weighedNhapAmount:
              (codeData['weighedNhapAmount'] as num? ?? 0.0).toDouble(),
          weighedXuatAmount:
              (codeData['weighedXuatAmount'] as num? ?? 0.0).toDouble(),
          mixTime: mixTime,
        );

        // Đánh dấu isSuccess nếu mã đã có realQty
        if (codeData['realQty'] != null) {
          newRecord.isSuccess = true;
          newRecord.realQty = (codeData['realQty'] as num).toDouble();
          newRecord.loai = codeData['loai']?.toString();
        }

        records.add(newRecord);
      }

      if (kDebugMode) {
        print(
          '✅ Đã khôi phục ${records.length} records cho OVNO=$activeOVNO',
        );
      }

      return records;
    } catch (e) {
      if (kDebugMode) print('❌ Lỗi khôi phục records: $e');
      return [];
    }
  }

  /// Xóa state đã lưu
  Future<void> clearSavedState() async {
    try {
      final db = await dbHelper.database;
      await db.delete('WeighingState');

      if (kDebugMode) {
        print('🗑️ Đã xóa state đã lưu');
      }
    } catch (e) {
      if (kDebugMode) print('❌ Lỗi xóa state: $e');
    }
  }
}
