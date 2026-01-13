import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/database_helper.dart';
import '../../services/sync_service.dart'; // Import SyncService
import '../../services/notification_service.dart';
import '../../services/language_service.dart';
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class PendingSyncScreen extends StatefulWidget {
  const PendingSyncScreen({super.key});

  @override
  State<PendingSyncScreen> createState() => _PendingSyncScreenState();
}

class _PendingSyncScreenState extends State<PendingSyncScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final SyncService _syncService = SyncService();
  final LanguageService _languageService = LanguageService();
  
  bool _isLoading = true;
  bool _isSyncing = false;
  List<Map<String, dynamic>> _pendingRecords = [];
  List<Map<String, dynamic>> _failedRecords = [];

  @override
  void initState() {
    super.initState();
    _loadPendingData();
  }

  // 1. Tải dữ liệu từ DB Cục bộ
  Future<void> _loadPendingData() async {
    setState(() => _isLoading = true);
    final data = await _dbHelper.getPendingSyncRecords();
    final failed = await _dbHelper.getFailedSyncRecords();

    setState(() {
      _pendingRecords = data;
      _failedRecords = failed;
      _isLoading = false;
    });
  }

  // 2. Chạy đồng bộ thủ công
  Future<void> _runSync() async {
    setState(() => _isSyncing = true);
    // 1. Kiểm tra mạng ngay lập tức
    final connectivityResult = await Connectivity().checkConnectivity();
    if (!connectivityResult.contains(ConnectivityResult.wifi) && 
        !connectivityResult.contains(ConnectivityResult.mobile)) 
    {
      if (mounted) {
        NotificationService().showToast(
          context: context,
          message: _languageService.translate('no_network'),
          type: ToastType.error,
        );
      }
      setState(() => _isSyncing = false);
      return; // Dừng lại, không chạy sync
    }
    
    // Hiển thị dialog loading
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(_languageService.translate('syncing_data'), style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 8),
                Text(_languageService.translate('please_wait'), style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          );
        },
      );
    }
    
    try {
      // Bước 1: Tải dữ liệu mới từ server (như lúc đăng nhập online)
      if (kDebugMode) print('📥 Đang tải dữ liệu mới từ server...');
      await _syncService.syncPersons(); // Đồng bộ danh sách người dùng
      await _syncService.syncDevices(); // Đồng bộ danh sách cân
      await _syncService.syncAllData(); // Đồng bộ dữ liệu chưa cân
      
      // Bước 2: Đẩy dữ liệu pending lên server
      if (kDebugMode) print('📤 Đang đẩy dữ liệu pending lên server...');
      await _syncService.syncHistoryQueue();
      
      // Đóng dialog loading
      if (mounted) {
        Navigator.of(context).pop();
      }
      
      if (mounted) {
        NotificationService().showToast(
          context: context,
          message: _languageService.translate('sync_complete'),
          type: ToastType.success,
        );
      }
      
      // Tải lại danh sách (giờ nó sẽ rỗng)
      await _loadPendingData();

    } catch (e) {
      if (kDebugMode) { // Đảm bảo bạn đã import 'package:flutter/foundation.dart';
        print('--- LỖI ĐỒNG BỘ (PendingSyncScreen) ---');
        print(e);
        print('------------------------------------');
      }

      // Đóng dialog loading
      if (mounted) {
        Navigator.of(context).pop();
      }

      // Hiển thị thông báo thân thiện cho người dùng
      if (mounted) {
        NotificationService().showToast(
          context: context,
          message: _languageService.translate('server_error'),
          type: ToastType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  // 3. Định dạng thời gian (chuyển từ UTC sang local timezone)
  String _formatTime(String isoString) {
    try {
      final dt = DateTime.parse(isoString);
      // Nếu là UTC, chuyển sang local timezone
      final localDt = dt.isUtc ? dt.toLocal() : dt;
      return DateFormat('dd/MM HH:mm:ss').format(localDt);
    } catch (_) {
      return isoString;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _languageService,
      builder: (context, child) {
        return Scaffold(
          appBar: AppBar(
            title: Text(_languageService.translate('pending_sync_title')),
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _buildBody(),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _isSyncing ? null : _runSync,
            icon: _isSyncing 
                ? const CircularProgressIndicator(color: Colors.white) 
                : const Icon(Icons.sync),
            label: _isSyncing 
                ? Text(_languageService.translate('syncing')) 
                : Text(_languageService.translate('sync_now')),
            backgroundColor: Colors.blue,
          ),
        );
      },
    );
  }

  Widget _buildBody() {
    // Nếu cả 2 danh sách trống
    if (_pendingRecords.isEmpty && _failedRecords.isEmpty) {
      return Center(
        child: Text(
          _languageService.translate('no_pending_data'),
          style: const TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        // Pending section
        if (_pendingRecords.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text('${_languageService.translate('pending_count')} (${_pendingRecords.length})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          ..._pendingRecords.map((record) {
            final bool isNhap = record['loai'] == 'nhap';
            final weightText = '${(record['khoiLuongCan'] as num).toStringAsFixed(2)} kg';
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              elevation: 2,
              child: ListTile(
                isThreeLine: true,
                leading: CircleAvatar(
                  backgroundColor: isNhap ? Colors.green[100] : Colors.blue[100],
                  child: Icon(
                    isNhap ? Icons.arrow_downward : Icons.arrow_upward,
                    color: isNhap ? Colors.green[800] : Colors.blue[800],
                  ),
                ),
                title: Text('${record['tenPhoiKeo'] ?? 'N/A'} (${_languageService.translate('lot')}: ${record['soLo']})', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${_languageService.translate('code')}: ${record['maCode']} | ${_languageService.translate('weighed_by')}: ${record['nguoiThaoTac'] ?? 'N/A'}'),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text('${_languageService.translate('at_time')}: ${_formatTime(record['thoiGianCan'])}'),
                        const Spacer(),
                        Text(isNhap ? _languageService.translate('weighing_import') : _languageService.translate('weighing_export'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isNhap ? Colors.green[700] : Colors.blue[700])),
                      ],
                    ),
                  ],
                ),
                trailing: Text(weightText, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
              ),
            );
          }),
        ],

        // Failed section
        if (_failedRecords.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text('${_languageService.translate('failed_count')} (${_failedRecords.length})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red)),
          ),
          ..._failedRecords.map((record) {
            final bool isNhap = record['loai'] == 'nhap';
            final String errMsg = record['errorMessage'] ?? 'Lỗi không xác định';

            return Card(
              color: Colors.red[25],
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              elevation: 1,
              child: ListTile(
                isThreeLine: true,
                leading: CircleAvatar(
                  backgroundColor: isNhap ? Colors.green[50] : Colors.blue[50],
                  child: Icon(isNhap ? Icons.error : Icons.error, color: Colors.red[700]),
                ),
                title: Text('${record['tenPhoiKeo'] ?? 'N/A'} (${_languageService.translate('lot')}: ${record['soLo']})', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${_languageService.translate('code')}: ${record['maCode']}\n${_languageService.translate('at_time')}: ${_formatTime(record['thoiGianCan'] ?? '')}'),
                    const SizedBox(height: 6),
                    Text(errMsg, style: const TextStyle(color: Colors.redAccent), maxLines: 3, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text('${(record['khoiLuongCan'] as num).toStringAsFixed(2)} kg', style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(width: 12),
                        IconButton(
                          tooltip: 'Retry',
                          icon: const Icon(Icons.refresh, color: Colors.orange),
                          onPressed: () async {
                            if (_isSyncing) return;
                            setState(() => _isSyncing = true);
                            final success = await _syncService.retryFailedSync(record['id'] as int, record);
                            if (!mounted) return;
                            if (success) {
                              NotificationService().showToast(context: context, message: _languageService.translate('retry_success'), type: ToastType.success);
                            } else {
                              NotificationService().showToast(context: context, message: _languageService.translate('retry_failed'), type: ToastType.error);
                            }
                            await _loadPendingData();
                            setState(() => _isSyncing = false);
                          },
                        ),
                        IconButton(
                          tooltip: _languageService.translate('delete'),
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: Text(_languageService.translate('confirm')),
                                content: Text(_languageService.translate('confirm_delete')),
                                actions: [
                                  TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(_languageService.translate('cancel'))),
                                  TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(_languageService.translate('delete'))),
                                ],
                              ),
                            );
                            if (ok == true) {
                              await _dbHelper.deleteFailedSyncById(record['id'] as int);
                              await _loadPendingData();
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ],
    );
  }
}