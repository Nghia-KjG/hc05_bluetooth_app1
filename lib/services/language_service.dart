import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageService extends ChangeNotifier {
  static final LanguageService _instance = LanguageService._internal();
  factory LanguageService() => _instance;
  LanguageService._internal();

  String _currentLanguage = 'vi'; // Mặc định tiếng Việt
  String get currentLanguage => _currentLanguage;

  static const String _languageKey = 'app_language';

  // Khởi tạo và load ngôn ngữ đã lưu
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _currentLanguage = prefs.getString(_languageKey) ?? 'vi';
    notifyListeners();
  }

  // Đổi ngôn ngữ
  Future<void> setLanguage(String languageCode) async {
    if (_currentLanguage == languageCode) return;

    _currentLanguage = languageCode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, languageCode);
    notifyListeners();
  }

  // Lấy text theo ngôn ngữ hiện tại
  String translate(String key) {
    return _translations[_currentLanguage]?[key] ?? key;
  }

  // Định nghĩa translations
  static final Map<String, Map<String, String>> _translations = {
    'vi': {
      // Login Screen
      'login_title': 'Đăng nhập',
      'weighing_program': 'LƯU TRÌNH CÂN KEO BÁN THÀNH PHẨM',
      'card_number': 'Số thẻ',
      'factory': 'Nhà máy',
      'login_button': 'Đăng nhập',
      'language': 'Ngôn ngữ',
      'vietnamese': 'Tiếng Việt',
      'english': 'English',

      // Settings Screen
      'settings': 'Cài đặt',
      'general_settings': 'Cài đặt chung',
      'auto_complete': 'Tự động hoàn tất',
      'auto_complete_desc': 'Bật tự động hoàn tất',
      'stability_threshold': 'Ngưỡng ổn định',
      'stability_threshold_desc':
          'Số lần đọc liên tiếp cần để xác nhận ổn định',
      'sound_enabled': 'Bật âm thanh',
      'sound_enabled_desc': 'Phát tiếng bíp khi cân thành công',
      'history_range': 'Lịch sử cân',
      'stability_delay': 'Thời gian chờ cân ổn định:',
      'complete_delay': 'Thời gian hoàn tất (sau ổn định):',
      'max_deviation': 'Độ chênh lệch tối đa (test):',
      'sound': 'Âm thanh',
      'app_info': 'Thông tin ứng dụng',
      'version': 'Phiên bản',
      'logout': 'Đăng xuất',
      '30_days': '30 Ngày',
      '7_days': '7 Ngày',
      '15_days': '15 Ngày',
      '90_days': '90 Ngày',
      'all_history': 'Tất cả lịch sử',
      '3_seconds': '3 giây',
      '5_seconds': '5 giây',
      '10_seconds': '10 giây',

      // Home Screen
      'weighing_station': 'Trạm cân',
      'weighing_warehouse': 'Kho cân',
      'dashboard': 'Dash Board',
      'history': 'Lịch sử cân',
      'pending_data': 'Dữ liệu chờ',
      'app_version': 'Weighing Station App - Phiên bản',
      'not_connected': 'Chưa kết nối với cân! Đang chuyển đến trang kết nối...',

      // Weighing Station Screen
      'scan_to_display_info': 'Vui lòng scan mã để hiển thị thông tin',
      'current_weight': 'Trọng lượng hiện tại',
      'min': 'MIN',
      'max': 'MAX',
      'deviation': 'Chênh lệch',
      'weighed_in': 'Đã nhập:',
      'weighed_out': 'Đã xuất:',
      'remaining': 'Còn lại:',
      'scan_code': 'Quét mã Code',
      'complete': 'Hoàn tất',
      'weighing_import': 'Cân Nhập',
      'weighing_export': 'Cân Xuất',
      'weighing_reweigh': 'Cân Lại',
      'back_to_home': 'Quay lại trang chủ',
      'debug_simulate': '🛠️ DEBUG: Giả lập cân',
      'enter_weight': 'Nhập trọng lượng (kg)',
      'example': 'VD: 50.5',
      'debug_note':
          'Lưu ý: Nhập số xong giữ nguyên, hệ thống sẽ tự bắn data liên tục để kích hoạt "Ổn định".',

      // App Bar
      'options': 'Tùy chọn',

      // Bluetooth Service
      'ready': 'Sẵn sàng',
      'scanning': 'Đang quét...',
      'stopped_scan': 'Đã dừng quét.',
      'connecting_to': 'Đang kết nối tới',
      'disconnected': 'Đã ngắt kết nối.',
      'event_error': 'Lỗi nhận sự kiện',

      // Scan Input Field
      'scan_hint': 'Scan hoặc Nhập mã tại đây...',
      'scan_button': 'Scan',

      // History Screen
      'history_title': 'Lịch sử cân',
      'filter_device': 'Thiết bị',
      'all_devices': 'Tất cả',
      'filter_import': 'Cân Nhập',
      'filter_export': 'Cân Xuất',
      'filter_glue_name': 'Tên phôi keo',
      'filter_code': 'Mã code',
      'filter_ovno': 'OVNO',
      'search_hint': 'Tìm kiếm...',

      // Dashboard Screen
      'dashboard_title': 'Dashboard - Tổng Quan',
      'weight_by_shift': 'Khối Lượng Cân Theo Ca',

      // Pending Sync Screen
      'pending_sync_title': 'Dữ liệu cân chờ (Offline)',
      'no_pending_data': 'Không có dữ liệu nào chờ đồng bộ.',
      'pending_count': 'Chưa đồng bộ',
      'failed_count': 'Đồng bộ thất bại',
      'sync_now': 'Đồng bộ ngay',
      'syncing': 'Đang đồng bộ...',
      'syncing_data': 'Đang đồng bộ dữ liệu...',
      'please_wait': 'Vui lòng đợi',
      'sync_complete': 'Đồng bộ hoàn tất!',
      'no_network': 'Không có kết nối mạng. Vui lòng thử lại sau.',
      'server_error':
          'Lỗi kết nối máy chủ. Vui lòng kiểm tra lại mạng và thử lại.',
      'retry_success': 'Đã retry thành công!',
      'retry_failed': 'Retry thất bại hoặc chưa có mạng.',
      'confirm': 'Xác nhận',
      'confirm_delete': 'Bạn có chắc muốn xóa bản ghi thất bại này không?',
      'cancel': 'Hủy',
      'delete': 'Xóa',
      'lot': 'Lô',
      'code': 'Mã',
      'weighed_by': 'Cân bởi',
      'at_time': 'Lúc',

      // Bluetooth Status Action
      'disconnect_tooltip': 'Ngắt kết nối',
      'confirm_disconnect_title': 'Xác nhận ngắt kết nối',
      'confirm_disconnect_message': 'Bạn có chắc muốn ngắt kết nối với',
      'disconnect_button': 'Ngắt kết nối',
      'disconnected_success': 'Đã ngắt kết nối!',
      'connection_lost_text': 'Mất kết nối cân',
      'reconnect_tooltip': 'Kết nối lại',
      'reconnecting': 'Đang kết nối lại...',
      'cannot_reconnect':
          'Không thể kết nối lại, đang chuyển sang trang kết nối cân.',

      // Charts
      'inventory_overview': 'Tổng Quan Tồn Kho',
      'exported_weight': 'Khối lượng cân xuất',
      'inventory_weight': 'Khối lượng tồn kho',
      'imported_weight': 'Khối lượng cân nhập',

      // Connect Bluetooth Screen
      'search_scale': 'Tìm kiếm Cân',
      'no_devices_found': 'Không tìm thấy thiết bị nào.',
      'connected_success': '✅ Kết nối thành công với cân',

      // Notifications
      'please_enter_card_number': 'Vui lòng nhập số thẻ.',
      'login_success': 'Đăng nhập thành công! Chào',
      'offline_login_success': 'Đăng nhập Offline thành công! Chào',
      'please_scan_code': 'Vui lòng scan mã trước.',
      'weight_out_of_range': 'Lỗi: Trọng lượng không nằm trong phạm vi!',
      'scan_success': 'Scan mã thành công!\nLoại:',
      'please_scan_to_weigh': 'Vui lòng scan mã để cân!',
      'connection_lost': 'Đã mất kết nối với cân Bluetooth!',

      // Notification Titles
      'notification_success': 'Thành công',
      'notification_error': 'Đã xảy ra lỗi',
      'notification_info': 'Thông báo',

      // Table Labels
      'order': 'Lệnh',
      'batches_weighed': 'Số mẻ đã cân',
      'import_weight': 'Nhập',
      'export_weight': 'Xuất',
      'memo': 'Memo',
      'batch_count': 'Số mẻ đã cân',

      // Weighing Table Headers
      'code_header': 'Mã Code',
      'glue_name': 'Tên Phôi Keo',
      'batch_number': 'Số Mẻ',
      'machine_number': 'Số Máy',
      'operator': 'Người Thao Tác',
      'weighing_time': 'Thời Gian Cân',
      'batch_weight': 'Khối Lượng Mẻ (kg)',
      'weighed_weight': 'KL Đã Cân(kg)',
      'weighing_type_label': 'Loại Cân',
      'import_weighed': 'Khối Lượng Đã Cân Nhập (kg)',
      'export_weighed': 'Khối Lượng Đã Cân Xuất (kg)',
      'no_history_data': 'Không có dữ liệu lịch sử.',

      // Weighing Controller Messages
      'already_weighed_import':
          'Mã này đã được cân nhập (offline). Không thể chọn lại cân nhập!',
      'exit_reweigh_mode': 'Thoát chế độ cân lại - Người dùng chọn',
      'record_not_found': 'Không tìm thấy record để cân lại',
      'cannot_determine_weighing_type':
          'Không xác định được loại cân ban đầu của mã',
      'reweigh': 'Cân lại',
      'reweigh_code_question': 'Bạn muốn cân lại mã',
      'reweigh_mode_scan_only': 'Chế độ cân lại: Chỉ được scan mã',
      'reweigh_mode_activated': 'Đã vào chế độ cân lại cho mã',
      'new_code_clear_state': 'Scan mã mới: Xóa state cũ',
      'business_logic_error': 'Lỗi nghiệp vụ',
      'unknown_error': 'Lỗi không xác định',
      'no_code_scanned': 'Chưa scan mã nào. Vui lòng scan mã trước!',
      'completing_weighing_for': 'Hoàn tất cân cho mã',
      'saved_state': 'Đã lưu state: OVNO=',
      'restored_state': 'Đã khôi phục state: OVNO=',
      'no_state_to_restore': 'Không có state để khôi phục',
      'error_saving_state': 'Lỗi lưu state',
      'error_restoring_state': 'Lỗi khôi phục state',

      // Completion Handler Messages
      'online_mode_sending': 'Online Mode: Đang gửi lên server...',
      'endpoint': 'Endpoint',
      'weighing_type': 'loaiCan',
      'offline_mode_saving': 'Offline Mode: Đang lưu "Hoàn tất" vào cache...',
      'deleted_old_import_record': 'Đã xóa bản ghi cân nhập cũ trong queue',
      'deleted_old_export_record': 'Đã xóa bản ghi cân xuất cũ trong queue',
      'already_weighed_import_pending':
          'Mã này đã được cân nhập (đang chờ đồng bộ).',
      'already_weighed_import_synced': 'Mã này đã được cân nhập (đã đồng bộ).',
      'not_weighed_import_offline': 'Lỗi: Mã này CHƯA CÂN NHẬP (offline).',
      'weighing_business_error': 'Lỗi nghiệp vụ cân',
      'critical_error_completing': 'Lỗi nghiêm trọng khi hoàn tất',

      // Scan Handler Messages
      'found_in_cache': 'Tìm thấy mã trong cache cục bộ.',
      'not_in_cache_default': 'Mã không có trong cache, tạo bản ghi mặc định.',
      'online_checking_api':
          'Online Mode: Đang gọi API để kiểm tra trạng thái...',
      'code_not_found': 'Không tìm thấy mã',
      'fully_exported_cannot_weigh': 'Mã này đã XUẤT HẾT. Không thể cân thêm!',
      'parse_mixtime_error': 'Lỗi parse mixTime',
    },
    'en': {
      // Login Screen
      'login_title': 'Login',
      'weighing_program': 'SEMI-FINISHED GLUE WEIGHING SOP',
      'card_number': 'User ID',
      'factory': 'Factory',
      'login_button': 'Login',
      'language': 'Language',
      'vietnamese': 'Tiếng Việt',
      'english': 'English',

      // Settings Screen
      'settings': 'Settings',
      'general_settings': 'General Settings',
      'auto_complete': 'Auto Complete',
      'auto_complete_desc': 'Enable auto complete',
      'stability_threshold': 'Stability Threshold',
      'stability_threshold_desc':
          'Number of consecutive reads to confirm stability',
      'sound_enabled': 'Sound Enabled',
      'sound_enabled_desc': 'Play beep when weighing is completed',
      'history_range': 'Weighing History',
      'stability_delay': 'Stability wait time:',
      'complete_delay': 'Complete delay (after stable):',
      'max_deviation': 'Max deviation (test):',
      'sound': 'Sound',
      'app_info': 'App Information',
      'version': 'Version',
      'logout': 'Logout',
      '30_days': '30 Days',
      '7_days': '7 Days',
      '15_days': '15 Days',
      '90_days': '90 Days',
      'all_history': 'All History',
      '3_seconds': '3 seconds',
      '5_seconds': '5 seconds',
      '10_seconds': '10 seconds',

      // Home Screen
      'weighing_station': 'Weighing Station',
      'weighing_warehouse': 'Weighing Warehouse',
      'dashboard': 'Dashboard',
      'history': 'Weighing History',
      'pending_data': 'Waiting Data',
      'app_version': 'Weighing Station App - Version',
      'not_connected':
          'Not connected to scale! Redirecting to connection page...',

      // Weighing Station Screen
      'scan_to_display_info': 'Please scan code to display information',
      'current_weight': 'Current Weight',
      'min': 'MIN',
      'max': 'MAX',
      'deviation': 'Deviation',
      'weighed_in': 'Imported:',
      'weighed_out': 'Exported:',
      'remaining': 'Remaining:',
      'scan_code': 'Scan Code',
      'complete': 'Complete',
      'weighing_import': 'Import',
      'weighing_export': 'Export',
      'weighing_reweigh': 'Reweigh',
      'back_to_home': 'Back to Home',
      'debug_simulate': '🛠️ DEBUG: Simulate Scale',
      'enter_weight': 'Enter weight (kg)',
      'example': 'Ex: 50.5',
      'debug_note':
          'Note: Enter a number and wait, the system will continuously send data to trigger "Stable".',

      // App Bar
      'options': 'Options',

      // Bluetooth Service
      'ready': 'Ready',
      'scanning': 'Scanning...',
      'stopped_scan': 'Scan stopped.',
      'connecting_to': 'Connecting to',
      'disconnected': 'Disconnected.',
      'event_error': 'Event error',

      // Scan Input Field
      'scan_hint': 'Scan or Enter code here...',
      'scan_button': 'Scan',

      // History Screen
      'history_title': 'Weighing History',
      'filter_device': 'Device',
      'all_devices': 'All Devices',
      'filter_import': 'Import',
      'filter_export': 'Export',
      'filter_glue_name': 'Glue Name',
      'filter_code': 'Code',
      'filter_ovno': 'OVNO',
      'search_hint': 'Search...',

      // Dashboard Screen
      'dashboard_title': 'Dashboard - Overview',
      'weight_by_shift': 'Weight By Shift',

      // Pending Sync Screen
      'pending_sync_title': 'Weighing Data (Offline)',
      'no_pending_data': 'No data waiting for sync.',
      'pending_count': 'Pending',
      'failed_count': 'Sync Failed',
      'sync_now': 'Sync Now',
      'syncing': 'Syncing...',
      'syncing_data': 'Syncing data...',
      'please_wait': 'Please wait',
      'sync_complete': 'Sync complete!',
      'no_network': 'No network connection. Please try again later.',
      'server_error':
          'Server connection error. Please check network and try again.',
      'retry_success': 'Retry successful!',
      'retry_failed': 'Retry failed or no network.',
      'confirm': 'Confirm',
      'confirm_delete': 'Are you sure you want to delete this failed record?',
      'cancel': 'Cancel',
      'delete': 'Delete',
      'lot': 'Lot',
      'code': 'Code',
      'weighed_by': 'Weighed by',
      'at_time': 'At',

      // Bluetooth Status Action
      'disconnect_tooltip': 'Disconnect',
      'confirm_disconnect_title': 'Confirm Disconnect',
      'confirm_disconnect_message': 'Are you sure you want to disconnect from',
      'disconnect_button': 'Disconnect',
      'disconnected_success': 'Disconnected!',
      'connection_lost_text': 'Scale Connection Lost',
      'reconnect_tooltip': 'Reconnect',
      'reconnecting': 'Reconnecting...',
      'cannot_reconnect': 'Cannot reconnect, redirecting to connection page.',

      // Charts
      'inventory_overview': 'Inventory Overview',
      'exported_weight': 'Exported Weight',
      'inventory_weight': 'Inventory Weight',
      'imported_weight': 'Imported Weight',

      // Connect Bluetooth Screen
      'search_scale': 'Search Scale',
      'no_devices_found': 'No devices found.',
      'connected_success': '✅ Successfully connected to scale',

      // Notifications
      'please_enter_card_number': 'Please enter USER ID.',
      'login_success': 'Login successful! Welcome',
      'offline_login_success': 'Offline login successful! Welcome',
      'please_scan_code': 'Please scan code first.',
      'weight_out_of_range': 'Error: Weight is out of range!',
      'scan_success': 'Scan successful!\nType:',
      'please_scan_to_weigh': 'Please scan code to weigh!',
      'connection_lost': 'Bluetooth scale connection lost!',

      // Notification Titles
      'notification_success': 'Success',
      'notification_error': 'Error',
      'notification_info': 'Information',

      // Table Labels
      'order': 'Order',
      'batches_weighed': 'Batches Weighed',
      'import_weight': 'Import',
      'export_weight': 'Export',
      'memo': 'Memo',
      'batch_count': 'Batch Count',

      // Weighing Table Headers
      'code_header': 'Code',
      'glue_name': 'Glue Name',
      'batch_number': 'Batch No.',
      'machine_number': 'Machine No.',
      'operator': 'Operator',
      'weighing_time': 'Weighing Time',
      'batch_weight': 'Batch Weight (kg)',
      'weighed_weight': 'Weighed Weight(kg)',
      'weighing_type_label': 'Weighing Type',
      'import_weighed': 'Imported Weight (kg)',
      'export_weighed': 'Exported Weight (kg)',
      'no_history_data': 'No history data available.',

      // Weighing Controller Messages
      'already_weighed_import':
          'This code has already been weighed for import (offline). Cannot select import again!',
      'exit_reweigh_mode': 'Exited reweigh mode - User selected',
      'record_not_found': 'Record not found for reweighing',
      'cannot_determine_weighing_type':
          'Cannot determine original weighing type for code',
      'reweigh': 'Reweigh',
      'reweigh_code_question': 'Do you want to reweigh code',
      'reweigh_mode_scan_only': 'Reweigh mode: Only scan code',
      'reweigh_mode_activated': 'Entered reweigh mode for code',
      'new_code_clear_state': 'New code scanned: Clearing old state',
      'business_logic_error': 'Business logic error',
      'unknown_error': 'Unknown error',
      'no_code_scanned': 'No code scanned. Please scan code first!',
      'completing_weighing_for': 'Completing weighing for code',
      'saved_state': 'Saved state: OVNO=',
      'restored_state': 'Restored state: OVNO=',
      'no_state_to_restore': 'No state to restore',
      'error_saving_state': 'Error saving state',
      'error_restoring_state': 'Error restoring state',

      // Completion Handler Messages
      'online_mode_sending': 'Online Mode: Sending to server...',
      'endpoint': 'Endpoint',
      'weighing_type': 'weighingType',
      'offline_mode_saving': 'Offline Mode: Saving "Complete" to cache...',
      'deleted_old_import_record': 'Deleted old import record in queue',
      'deleted_old_export_record': 'Deleted old export record in queue',
      'already_weighed_import_pending':
          'This code has already been weighed for import (pending sync).',
      'already_weighed_import_synced':
          'This code has already been weighed for import (synced).',
      'not_weighed_import_offline':
          'Error: This code has NOT been weighed for import (offline).',
      'weighing_business_error': 'Weighing business error',
      'critical_error_completing': 'Critical error when completing',

      // Scan Handler Messages
      'found_in_cache': 'Found code in local cache.',
      'not_in_cache_default': 'Code not in cache, creating default record.',
      'online_checking_api': 'Online Mode: Calling API to check status...',
      'code_not_found': 'Code not found',
      'fully_exported_cannot_weigh':
          'This code has been FULLY EXPORTED. Cannot weigh more!',
      'parse_mixtime_error': 'Error parsing mixTime',
    },
  };
}
