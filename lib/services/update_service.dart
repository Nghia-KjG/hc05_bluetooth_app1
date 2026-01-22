import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Model để lưu thông tin phiên bản
class VersionInfo {
    final String currentVersion;
    final String latestVersion;
    final String changelog;
    final String downloadUrl;
    final bool needsUpdate;
  final String? fileName;
  final int? fileSize;
  final String? minSupportedVersion;
  final List<String>? releaseNotes;
  final String? updatedAt;
  final String? checksum;

    VersionInfo({
      required this.currentVersion,
      required this.latestVersion,
      required this.changelog,
      required this.downloadUrl,
      required this.needsUpdate,
      this.fileName,
      this.fileSize,
      this.minSupportedVersion,
      this.releaseNotes,
      this.updatedAt,
      this.checksum,
    });

  factory VersionInfo.fromJson(Map<String, dynamic> json, String currentVersion) {
    final latest = json['latestVersion']?.toString() ?? currentVersion;
    final hasUpdateFlag = json['hasUpdate'] == true;
    final notes = (json['releaseNotes'] is List)
        ? List<String>.from((json['releaseNotes'] as List).map((e) => e.toString()))
        : null;
    final changelog = (notes != null && notes.isNotEmpty)
        ? notes.join('\n• ')
        : (json['changelog']?.toString() ?? 'Cập nhật phiên bản mới');

    return VersionInfo(
      currentVersion: currentVersion,
      latestVersion: latest,
      changelog: notes != null && notes.isNotEmpty ? '• $changelog' : changelog,
      downloadUrl: json['downloadUrl']?.toString() ?? '',
      needsUpdate: hasUpdateFlag || compareVersions(currentVersion, latest),
      fileName: json['fileName']?.toString(),
      fileSize: (json['fileSize'] is num) ? (json['fileSize'] as num).toInt() : null,
      minSupportedVersion: json['minSupportedVersion']?.toString(),
      releaseNotes: notes,
      updatedAt: json['updatedAt']?.toString(),
      checksum: json['checksum']?.toString(),
    );
  }
}

/// So sánh phiên bản (trả về true nếu latestVersion > currentVersion)
bool compareVersions(String current, String latest) {
    try {
      final currParts = current.split('.').map((e) => int.parse(e)).toList();
      final latestParts = latest.split('.').map((e) => int.parse(e)).toList();

      // Đảm bảo cả hai có cùng độ dài
      while (currParts.length < latestParts.length) {
        currParts.add(0);
      }
      while (latestParts.length < currParts.length) {
        latestParts.add(0);
      }

      for (int i = 0; i < currParts.length; i++) {
        if (latestParts[i] > currParts[i]) return true;
        if (latestParts[i] < currParts[i]) return false;
      }
      return false;
    } catch (e) {
      if (kDebugMode) print('❌ Lỗi so sánh phiên bản: $e');
      return false;
  }
}

class UpdateService {
  static final UpdateService _instance = UpdateService._internal();
  factory UpdateService() => _instance;
  UpdateService._internal();

  final String _apiBaseUrl = dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:3636';

  /// Kiểm tra phiên bản từ server
  Future<VersionInfo> checkUpdate() async {
    try {
      if (kDebugMode) print('🔄 Kiểm tra cập nhật từ $_apiBaseUrl/api/app-update/check');

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      // Server expects GET with query param `version`
      final url = Uri.parse('$_apiBaseUrl/api/app-update/check?version=$currentVersion');
      final response = await http
          .get(url)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final versionInfo = VersionInfo.fromJson(data, currentVersion);

        if (kDebugMode) {
          print('✅ Phiên bản hiện tại: $currentVersion');
          print('📦 Phiên bản trên server: ${versionInfo.latestVersion}');
          print('🔄 Cần cập nhật: ${versionInfo.needsUpdate}');
        }

        return versionInfo;
      } else {
        throw Exception('Kiểm tra cập nhật thất bại: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) print('❌ Lỗi kiểm tra cập nhật: $e');
      rethrow;
    }
  }

  /// Tải xuống file APK
  Future<String> downloadUpdate(
    String downloadUrl,
    Function(int, int) onProgress,
  ) async {
    try {
      if (kDebugMode) print('⬇️  Bắt đầu tải $downloadUrl');

      final client = http.Client();
      final response = await client.send(
        http.Request('GET', Uri.parse(downloadUrl)),
      );

      if (response.statusCode != 200) {
        throw Exception('Tải xuống thất bại: ${response.statusCode}');
      }

      final contentLength = response.contentLength ?? 0;
      int downloadedBytes = 0;
      
      // Lưu file vào thư mục tạm khi stream về
      final tempDir = await getTemporaryDirectory();
      final apkPath = '${tempDir.path}/update.apk';
      final file = File(apkPath);
      final sink = file.openWrite();

      await for (final chunk in response.stream) {
        sink.add(chunk);
        downloadedBytes += chunk.length;
        onProgress(downloadedBytes, contentLength);
      }

      await sink.flush();
      await sink.close();
      client.close();

      if (kDebugMode) print('✅ Tải xuống xong: $apkPath');
      return apkPath;
    } catch (e) {
      if (kDebugMode) print('❌ Lỗi tải xuống: $e');
      rethrow;
    }
  }

}
