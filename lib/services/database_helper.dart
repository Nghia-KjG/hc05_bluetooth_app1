import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDb();
    return _database!;
  }

  Future<Database> _initDb() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, "weighing_app.db");

    return await openDatabase(
      path,
      version: 10,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE VmlWorkS (
        maCode TEXT PRIMARY KEY,
        ovNO TEXT,
        package INTEGER,
        mUserID TEXT,
        qtys REAL,
        realQty REAL,
        mixTime TEXT,
        loai TEXT,
        weighedNhapAmount REAL DEFAULT 0,
        weighedXuatAmount REAL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE VmlWork (
        ovNO TEXT PRIMARY KEY,
        tenPhoiKeo TEXT,
        soMay TEXT,
        memo TEXT,
        totalTargetQty REAL
      )
    ''');

    await db.execute('''
      CREATE TABLE VmlPersion (
        mUserID TEXT PRIMARY KEY,
        nguoiThaoTac TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE HistoryQueue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        maCode TEXT NOT NULL,
        khoiLuongCan REAL,
        thoiGianCan TEXT,
        loai TEXT,
        WUserID TEXT,
        device TEXT
      )
    ''');

    // Lưu lịch sử cân cục bộ (không bị xóa sau khi sync)
    await db.execute('''
      CREATE TABLE LocalHistory (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        maCode TEXT NOT NULL,
        khoiLuongCan REAL,
        thoiGianCan TEXT,
        loai TEXT,
        ovNO TEXT,
        device TEXT,
        tenPhoiKeo TEXT,
        soMay TEXT,
        package INTEGER,
        mUserID TEXT,
        nguoiThaoTac TEXT,
        qtys REAL,
        realQty REAL,
        memo TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE FailedSyncs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        maCode TEXT NOT NULL,
        khoiLuongCan REAL,
        thoiGianCan TEXT,
        loai TEXT,
        WUserID TEXT,
        device TEXT,
        errorMessage TEXT,
        failedAt TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE Devices (
        address TEXT PRIMARY KEY,
        name TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE WeighingState (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        activeOVNO TEXT,
        activeMemo TEXT,
        scannedCode TEXT,
        activeTotalTargetQty REAL,
        activeTotalNhap REAL,
        activeTotalXuat REAL,
        activeXWeighed INTEGER,
        activeYTotal INTEGER,
        weighedNhapAmount REAL,
        weighedXuatAmount REAL,
        selectedPercentage REAL,
        standardWeight REAL,
        selectedWeighingType INTEGER,
        timestamp TEXT
      )
    ''');
  }

  /// Cập nhật bảng VmlPersion từ danh sách người dùng từ API/Sync
  /// (Được gọi sau khi đăng nhập online để lưu cache cho offline login)
  Future<void> updateVmlPersion(List<Map<String, dynamic>> users) async {
    final db = await database;
    final batch = db.batch();

    // Xóa dữ liệu cũ
    batch.delete('VmlPersion');

    // Thêm dữ liệu mới
    for (var user in users) {
      batch.insert('VmlPersion', {
        'mUserID': user['mUserID']?.toString(),
        'nguoiThaoTac': user['nguoiThaoTac'],
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    await batch.commit(noResult: true);
  }

  // Tự động thêm cột mới nếu DB cũ không có
  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE VmlWorkS ADD COLUMN realQty REAL');
      await db.execute('ALTER TABLE VmlWorkS ADD COLUMN mixTime TEXT');
      await db.execute('ALTER TABLE VmlWorkS ADD COLUMN loai TEXT');
    }
    // Version 3: add FailedSyncs table if upgrading from <3
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS FailedSyncs (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          maCode TEXT NOT NULL,
          khoiLuongCan REAL,
          thoiGianCan TEXT,
          loai TEXT,
          device TEXT,
          errorMessage TEXT,
          failedAt TEXT
        )
      ''');
    }

    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS Devices (
          address TEXT PRIMARY KEY,
          name TEXT
        )
      ''');
    }

    if (oldVersion < 5) {
      // Thêm cột WUserID vào HistoryQueue và FailedSyncs nếu chưa có
      await db.execute('ALTER TABLE HistoryQueue ADD COLUMN WUserID TEXT');
      await db.execute('ALTER TABLE FailedSyncs ADD COLUMN WUserID TEXT');
    }

    if (oldVersion < 6) {
      // Thêm cột weighedNhapAmount và weighedXuatAmount vào VmlWorkS
      await db.execute(
        'ALTER TABLE VmlWorkS ADD COLUMN weighedNhapAmount REAL DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE VmlWorkS ADD COLUMN weighedXuatAmount REAL DEFAULT 0',
      );
    }

    if (oldVersion < 7) {
      // Thêm cột device vào HistoryQueue và FailedSyncs
      await db.execute('ALTER TABLE HistoryQueue ADD COLUMN device TEXT');
      await db.execute('ALTER TABLE FailedSyncs ADD COLUMN device TEXT');
    }

    if (oldVersion < 8) {
      // Tạo bảng WeighingState để lưu trạng thái màn hình cân
      await db.execute('''
        CREATE TABLE IF NOT EXISTS WeighingState (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          activeOVNO TEXT,
          activeMemo TEXT,
          scannedCode TEXT,
          activeTotalTargetQty REAL,
          activeTotalNhap REAL,
          activeTotalXuat REAL,
          activeXWeighed INTEGER,
          activeYTotal INTEGER,
          weighedNhapAmount REAL,
          weighedXuatAmount REAL,
          selectedPercentage REAL,
          standardWeight REAL,
          selectedWeighingType INTEGER,
          timestamp TEXT
        )
      ''');
    }

    if (oldVersion < 9) {
      // Tạo bảng LocalHistory để lưu lịch sử cân cục bộ (không xóa sau sync)
      await db.execute('''
        CREATE TABLE IF NOT EXISTS LocalHistory (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          maCode TEXT NOT NULL,
          khoiLuongCan REAL,
          thoiGianCan TEXT,
          loai TEXT,
          ovNO TEXT,
          device TEXT
        )
      ''');
    }

    if (oldVersion < 10) {
      // Bổ sung thông tin đầy đủ cho LocalHistory
      await db.execute('ALTER TABLE LocalHistory ADD COLUMN tenPhoiKeo TEXT');
      await db.execute('ALTER TABLE LocalHistory ADD COLUMN soMay TEXT');
      await db.execute('ALTER TABLE LocalHistory ADD COLUMN package INTEGER');
      await db.execute('ALTER TABLE LocalHistory ADD COLUMN mUserID TEXT');
      await db.execute('ALTER TABLE LocalHistory ADD COLUMN nguoiThaoTac TEXT');
      await db.execute('ALTER TABLE LocalHistory ADD COLUMN qtys REAL');
      await db.execute('ALTER TABLE LocalHistory ADD COLUMN realQty REAL');
      await db.execute('ALTER TABLE LocalHistory ADD COLUMN memo TEXT');
    }
  }

  /// Lấy thông tin chi tiết của 1 mã code
  Future<Map<String, dynamic>?> getCodeInfo(String maCode) async {
    final db = await database;
    final result = await db.rawQuery(
      '''
      SELECT S.maCode, S.ovNO, S.package, S.mUserID, S.qtys,
             S.realQty, S.mixTime, S.loai,
             W.tenPhoiKeo, W.soMay, W.memo, W.totalTargetQty,
             P.nguoiThaoTac, S.package as soLo
      FROM VmlWorkS AS S
      LEFT JOIN VmlWork AS W ON S.ovNO = W.ovNO
      LEFT JOIN VmlPersion AS P ON S.mUserID = P.mUserID
      WHERE S.maCode = ?
    ''',
      [maCode],
    );

    if (result.isNotEmpty) return result.first;
    return null;
  }

  Future<List<Map<String, dynamic>>> getPendingSyncRecords() async {
    final db = await database;

    return await db.rawQuery('''
      SELECT 
        H.id, H.maCode, H.khoiLuongCan, H.thoiGianCan, H.loai,
        S.package as soLo, W.tenPhoiKeo, P.nguoiThaoTac
      FROM 
        HistoryQueue AS H
      LEFT JOIN 
        VmlWorkS AS S ON H.maCode = S.maCode
      LEFT JOIN 
        VmlWork AS W ON S.ovNO = W.ovNO
      LEFT JOIN 
        VmlPersion AS P ON S.mUserID = P.mUserID
      ORDER BY 
        H.id ASC
    ''');
  }

  /// Lấy các bản ghi đồng bộ thất bại
  Future<List<Map<String, dynamic>>> getFailedSyncRecords() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT
        F.id, F.maCode, F.khoiLuongCan, F.thoiGianCan, F.loai, F.errorMessage, F.failedAt,
        S.package as soLo, W.tenPhoiKeo, P.nguoiThaoTac
      FROM FailedSyncs AS F
      LEFT JOIN VmlWorkS AS S ON F.maCode = S.maCode
      LEFT JOIN VmlWork AS W ON S.ovNO = W.ovNO
      LEFT JOIN VmlPersion AS P ON S.mUserID = P.mUserID
      ORDER BY F.failedAt DESC
    ''');
  }

  /// Lấy 10 mã đã đồng bộ thành công nhất (theo thời gian mixTime)
  Future<List<Map<String, dynamic>>> getLast10SuccessfulRecords() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT
        S.maCode, S.realQty AS khoiLuongCan, S.mixTime AS thoiGianCan, S.loai,
        S.package as soLo, W.tenPhoiKeo, P.nguoiThaoTac
      FROM VmlWorkS AS S
      LEFT JOIN VmlWork AS W ON S.ovNO = W.ovNO
      LEFT JOIN VmlPersion AS P ON S.mUserID = P.mUserID
      WHERE S.realQty IS NOT NULL
      ORDER BY S.mixTime DESC
      LIMIT 10
    ''');
  }

  /// Xóa bản ghi FailedSync theo id
  Future<void> deleteFailedSyncById(int id) async {
    final db = await database;
    await db.delete('FailedSyncs', where: 'id = ?', whereArgs: [id]);
  }

  /// Cập nhật message/failedAt cho bản ghi FailedSync (khi retry thất bại)
  Future<void> updateFailedSyncError(int id, String errorMessage) async {
    final db = await database;
    await db.update(
      'FailedSyncs',
      {
        'errorMessage': errorMessage,
        'failedAt': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Kiểm tra xem mã đã cân nhập chưa (offline)
  Future<bool> isCodeAlreadyNhap(String maCode) async {
    final db = await database;
    final result = await db.query(
      'VmlWorkS',
      where: 'maCode = ? AND loai = ?',
      whereArgs: [maCode, 'nhap'],
    );
    return result.isNotEmpty;
  }

  /// Cập nhật bảng Devices từ API /api/devices
  Future<void> updateDevices(List<Map<String, dynamic>> devices) async {
    final db = await database;
    final batch = db.batch();

    batch.delete('Devices');

    for (final device in devices) {
      final String? address = device['address']?.toString().toUpperCase();
      final String? name = device['name']?.toString();
      if (address == null || address.isEmpty) continue;

      batch.insert('Devices', {
        'address': address,
        'name': name ?? 'N/A',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    await batch.commit(noResult: true);
  }

  /// Lấy map địa chỉ MAC => tên đã lưu
  Future<Map<String, String>> getDeviceNameMap() async {
    final db = await database;
    final rows = await db.query('Devices', columns: ['address', 'name']);
    final Map<String, String> result = {};
    for (final row in rows) {
      final addr = row['address']?.toString();
      final name = row['name']?.toString();
      if (addr != null && name != null) {
        result[addr.toUpperCase()] = name;
      }
    }
    return result;
  }
}
