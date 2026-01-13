import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import 'database_helper.dart';
import 'package:connectivity_plus/connectivity_plus.dart'; // <-- 1. THÊM IMPORT

class SyncService {
  final String _apiBaseUrl = dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:3636';
  final DatabaseHelper _dbHelper = DatabaseHelper();

  /// Đồng bộ danh sách người dùng từ /api/sync/persons (cho offline login)
  Future<void> syncPersons() async {
    if (kDebugMode) {
      print('🔄 Đang tải danh sách người dùng từ /api/sync/persons...');
    }
    try {
      final url = Uri.parse('$_apiBaseUrl/api/sync/persons');
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception('API Sync Persons thất bại: ${response.statusCode}');
      }

      final data = json.decode(response.body);
      if (kDebugMode) {
        print('📋 Phản hồi API: $data');
      }

      // Xử lý dữ liệu trả về (có thể là array hoặc object)
      List<Map<String, dynamic>> persons = [];

      if (data is List) {
        // Nếu API trả về array
        persons = List<Map<String, dynamic>>.from(
          data.map((item) => {
            'mUserID': item['MUserID']?.toString(),
            'nguoiThaoTac': item['UserName'],
          })
        );
      } else if (data is Map && data['data'] is List) {
        // Nếu API trả về object với key 'data'
        persons = List<Map<String, dynamic>>.from(
          (data['data'] as List).map((item) => {
            'mUserID': item['MUserID']?.toString(),
            'nguoiThaoTac': item['UserName'],
          })
        );
      } else if (data is Map && data['persons'] is List) {
        // Nếu API trả về object với key 'persons'
        persons = List<Map<String, dynamic>>.from(
          (data['persons'] as List).map((item) => {
            'mUserID': item['MUserID']?.toString(),
            'nguoiThaoTac': item['UserName'],
          })
        );
      }

      if (persons.isNotEmpty) {
        await _dbHelper.updateVmlPersion(persons);
        if (kDebugMode) {
          print('✅ Đã cập nhật VmlPersion: ${persons.length} người dùng');
        }
      } else {
        if (kDebugMode) {
          print('⚠️ Không tìm thấy dữ liệu người dùng trong response');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Lỗi đồng bộ người dùng: $e');
      }
      throw Exception('Lỗi đồng bộ người dùng: $e');
    }
  }

  /// Đồng bộ danh sách cân để hiển thị tên thân thiện theo MAC
  Future<void> syncDevices() async {
    if (kDebugMode) {
      print('🔄 Đang tải danh sách cân từ /api/devices...');
    }

    try {
      final url = Uri.parse('$_apiBaseUrl/api/devices');
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception('API Sync Devices thất bại: ${response.statusCode}');
      }

      final data = json.decode(response.body);
      List<Map<String, dynamic>> devices = [];

      if (data is List) {
        devices = List<Map<String, dynamic>>.from(
          data.map((item) => {
            'address': item['Address']?.toString().toUpperCase(),
            'name': item['Name']?.toString(),
          }),
        );
      } else if (data is Map && data['data'] is List) {
        devices = List<Map<String, dynamic>>.from(
          (data['data'] as List).map((item) => {
            'address': item['Address']?.toString().toUpperCase(),
            'name': item['Name']?.toString(),
          }),
        );
      }

      devices.removeWhere((d) => (d['address'] as String?)?.isEmpty ?? true);

      if (devices.isNotEmpty) {
        await _dbHelper.updateDevices(devices);
        if (kDebugMode) {
          print('✅ Đã lưu ${devices.length} cân vào cache');
        }
      } else if (kDebugMode) {
        print('⚠️ Không tìm thấy dữ liệu cân trong response');
      }

    } catch (e) {
      if (kDebugMode) {
        print('❌ Lỗi đồng bộ devices: $e');
      }
      throw Exception('Lỗi đồng bộ devices: $e');
    }
  }

  Future<void> syncAllData() async {
    if (kDebugMode) {
      print('🔄 Bắt đầu đồng bộ TẤT CẢ dữ liệu chưa cân...');
    }
    try {
      // 1. Gọi API để lấy dữ liệu mới
      final url = Uri.parse('$_apiBaseUrl/api/sync/unweighed');
      final response = await http.get(url).timeout(const Duration(seconds: 30)); // Cho 30s

      if (response.statusCode != 200) {
        throw Exception('API Sync thất bại: ${response.statusCode}');
      }

      final List<dynamic> data = json.decode(response.body);
      if (kDebugMode) {
        print('🔄 Tải về ${data.length} bản ghi chưa cân.');
      }

      // 2. Lấy DB và bắt đầu "Batch" (Giao dịch hàng loạt)
      final db = await _dbHelper.database;
      final batch = db.batch();

      // 3. XÓA SẠCH CACHE CŨ (Lưu ý: `VmlPersion` được quản lý riêng bởi `/api/sync/persons`)
      // Xóa các bảng dữ liệu cân/đơn hàng, nhưng KHÔNG xóa `VmlPersion` ở đây
      batch.delete('VmlWorkS');
      batch.delete('VmlWork');

      // 4. Lặp qua dữ liệu mới và "Nhồi" (Populate)
      for (var item in data) {
        // Dùng 'insert OR REPLACE' để cập nhật
        
        // Thêm vào VmlWorkS
        // Determine loai: prefer server-provided, otherwise infer from realQty
        final String inferredLoai = (item['loai'] != null && item['loai'].toString().isNotEmpty)
            ? item['loai'].toString()
            : (item['realQty'] != null ? 'nhap' : 'chua');

        batch.insert('VmlWorkS', {
          'maCode': item['maCode'],
          'ovNO': item['ovNO'],
          'package': item['package'],
          'mUserID': item['mUserID']?.toString(),
          'qtys': item['qtys'],
          'realQty': item['realQty'],
          'mixTime': item['mixTime'],
          'loai': inferredLoai,
          'weighedNhapAmount': item['weighedNhapAmount'] ?? 0.0,
          'weighedXuatAmount': item['weighedXuatAmount'] ?? 0.0,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        
        // Thêm vào VmlWork
        batch.insert('VmlWork', {
          'ovNO': item['ovNO'],
          'tenPhoiKeo': item['tenPhoiKeo'],
          'soMay': item['soMay']?.toString(),
          'memo': item['memo'],
          'totalTargetQty': item['totalTargetQty'],
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        
        // NOTE: Không thêm vào VmlPersion ở đây — danh sách người dùng
        // được lấy từ /api/sync/persons và cập nhật bởi syncPersons().
      }

      // 5. Commit batch
      await batch.commit(noResult: true);
      if (kDebugMode) {
        print('✅ Đồng bộ thành công ${data.length} bản ghi vào cache.');
      }

      await syncHistoryQueue();

    } catch (e) {
      if (kDebugMode) {
        print('❌ Lỗi đồng bộ dữ liệu: $e');
      }
      // Ném lỗi để LoginScreen có thể bắt
      throw Exception('Lỗi đồng bộ: $e');
    }
    if (kDebugMode) {
      print('🔄 Đồng bộ HistoryQueue hoàn tất.');
    }
  }

  Future<void> syncHistoryQueue() async {
    if (kDebugMode) {
      print('🔄 Bắt đầu đồng bộ HistoryQueue...');
    }
    final db = await _dbHelper.database;
    
    // Kiểm tra mạng trước
    final connectivityResult = await Connectivity().checkConnectivity();
    if (!connectivityResult.contains(ConnectivityResult.wifi) && 
        !connectivityResult.contains(ConnectivityResult.mobile)) {
      if (kDebugMode) {
        print('🌐 Không có mạng, hủy đồng bộ Queue.');
      }
      return; 
    }

    final List<Map<String, dynamic>> pendingRecords = await db.query('HistoryQueue');

    if (pendingRecords.isEmpty) {
      if (kDebugMode) {
        print('✅ Queue trống, không có gì để đồng bộ.');
      }
      return;
    }

    if (kDebugMode) {
      print('🔄 Tìm thấy ${pendingRecords.length} record trong Queue cần đồng bộ.');
    }

    for (var record in pendingRecords) {
      final int localId = record['id'];
      
      try {
        final url = Uri.parse('$_apiBaseUrl/api/complete');
        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'maCode': record['maCode'],
            'khoiLuongCan': record['khoiLuongCan'],
            'thoiGianCan': record['thoiGianCan'],
            'loai': record['loai'],
            'WUserID': record['WUserID'],
          }),
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 201) {
          await db.delete('HistoryQueue', where: 'id = ?', whereArgs: [localId]);
          if (kDebugMode) {
            print('✅ Đã đồng bộ thành công ID Queue: $localId');
          }

        } else if (response.statusCode >= 400 && response.statusCode < 500) {
          // Client error: lưu lỗi vào bảng FailedSyncs để hiển thị cho người dùng
          String errMsg = 'Lỗi ${response.statusCode}';
          try {
            final Map<String, dynamic> body = json.decode(response.body);
            if (body['message'] != null) errMsg = body['message'];
          } catch (_) {}

          if (kDebugMode) {
            print('❌ Lỗi 4xx khi đồng bộ ID Queue: $localId. Chuyển vào FailedSyncs: $errMsg');
          }

          await db.insert('FailedSyncs', {
            'maCode': record['maCode'],
            'khoiLuongCan': record['khoiLuongCan'],
            'thoiGianCan': record['thoiGianCan'],
            'loai': record['loai'],
            'WUserID': record['WUserID'],
            'errorMessage': errMsg,
            'failedAt': DateTime.now().toIso8601String(),
          });

          await db.delete('HistoryQueue', where: 'id = ?', whereArgs: [localId]);

        } else {
          if (kDebugMode) {
            print('⚠️ Lỗi 5xx khi đồng bộ ID Queue: $localId. Sẽ thử lại sau.');
          }
        }

      } catch (e) {
        if (kDebugMode) {
          print('🌐 Lỗi mạng khi đồng bộ ID Queue: $localId. Sẽ thử lại sau.');
        }
        break; 
      }
    }
    if (kDebugMode) {
      print('🔄 Đồng bộ HistoryQueue hoàn tất.');
    }
  }

  /// Thử đồng bộ lại một bản ghi thất bại (FailedSyncs)
  /// Trả về true nếu thành công và xóa bản ghi FailedSyncs, false nếu thất bại hoặc mạng lỗi.
  Future<bool> retryFailedSync(int failedId, Map<String, dynamic> failedRecord) async {
    final db = await _dbHelper.database;

    // Kiểm tra mạng
    final connectivityResult = await Connectivity().checkConnectivity();
    if (!connectivityResult.contains(ConnectivityResult.wifi) && 
        !connectivityResult.contains(ConnectivityResult.mobile)) {
      if (kDebugMode) print('🌐 Không có mạng, không thể retry.');
      return false;
    }

    try {
      final url = Uri.parse('$_apiBaseUrl/api/complete');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'maCode': failedRecord['maCode'],
          'khoiLuongCan': failedRecord['khoiLuongCan'],
          'thoiGianCan': failedRecord['thoiGianCan'],
          'loai': failedRecord['loai'],
          'WUserID': failedRecord['WUserID'],
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 201) {
        // Thành công: xóa khỏi FailedSyncs
        await db.delete('FailedSyncs', where: 'id = ?', whereArgs: [failedId]);

        // Đồng thời cập nhật VmlWorkS để hiển thị trong danh sách "đã đồng bộ"
        await db.update(
          'VmlWorkS',
          {
            'realQty': failedRecord['khoiLuongCan'],
            'mixTime': failedRecord['thoiGianCan'],
            'loai': failedRecord['loai'],
          },
          where: 'maCode = ?',
          whereArgs: [failedRecord['maCode']],
        );

        if (kDebugMode) print('✅ Retry thành công cho FailedSync id=$failedId');
        return true;

      } else if (response.statusCode >= 400 && response.statusCode < 500) {
        // Cập nhật lỗi mới vào FailedSyncs
        String errMsg = 'Lỗi ${response.statusCode}';
        try {
          final Map<String, dynamic> body = json.decode(response.body);
          if (body['message'] != null) errMsg = body['message'];
        } catch (_) {}

        if (kDebugMode) print('❌ Retry lỗi 4xx cho id=$failedId: $errMsg');
        await _dbHelper.updateFailedSyncError(failedId, errMsg);
        return false;

      } else {
        if (kDebugMode) print('⚠️ Retry gặp lỗi server cho id=$failedId (status ${response.statusCode})');
        return false;
      }

    } catch (e) {
      if (kDebugMode) print('🌐 Lỗi mạng khi retry id=$failedId: $e');
      return false;
    }
  }
}
