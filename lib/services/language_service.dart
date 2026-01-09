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
      'english': 'Tiếng Anh',
      
      // Settings Screen
      'settings': 'Cài đặt',
      'general_settings': 'Cài đặt chung',
      'auto_complete': 'Tự động hoàn tất',
      'auto_complete_desc': 'Bật tự động hoàn tất',
      'stability_threshold': 'Ngưỡng ổn định',
      'stability_threshold_desc': 'Số lần đọc liên tiếp cần để xác nhận ổn định',
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
      'back_to_home': 'Quay lại trang chủ',
      'debug_simulate': '🛠️ DEBUG: Giả lập cân',
      'enter_weight': 'Nhập trọng lượng (kg)',
      'example': 'VD: 50.5',
      'debug_note': 'Lưu ý: Nhập số xong giữ nguyên, hệ thống sẽ tự bắn data liên tục để kích hoạt "Ổn định".',
      
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
      'server_error': 'Lỗi kết nối máy chủ. Vui lòng kiểm tra lại mạng và thử lại.',
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
      
      // Notifications
      'please_enter_card_number': 'Vui lòng nhập số thẻ.',
      'login_success': 'Đăng nhập thành công! Chào',
      'offline_login_success': 'Đăng nhập Offline thành công! Chào',
      'please_scan_code': 'Vui lòng scan mã trước.',
      'weight_out_of_range': 'Lỗi: Trọng lượng không nằm trong phạm vi!',
      'scan_success': 'Scan mã thành công!\nLoại:',
      'please_scan_to_weigh': 'Vui lòng scan mã để cân!',
      'connection_lost': 'Đã mất kết nối với cân Bluetooth!',
    },
    'en': {
      // Login Screen
      'login_title': 'Login',
      'weighing_program': 'SEMI-FINISHED GLUE WEIGHING PROGRAM',
      'card_number': 'User ID',
      'factory': 'Factory',
      'login_button': 'Login',
      'language': 'Language',
      'vietnamese': 'Vietnamese',
      'english': 'English',
      
      // Settings Screen
      'settings': 'Settings',
      'general_settings': 'General Settings',
      'auto_complete': 'Auto Complete',
      'auto_complete_desc': 'Enable auto complete',
      'stability_threshold': 'Stability Threshold',
      'stability_threshold_desc': 'Number of consecutive reads to confirm stability',
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
      'dashboard': 'Dashboard',
      'history': 'Weighing History',
      'pending_data': 'Pending Data',
      'app_version': 'Weighing Station App - Version',
      'not_connected': 'Not connected to scale! Redirecting to connection page...',
      
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
      'back_to_home': 'Back to Home',
      'debug_simulate': '🛠️ DEBUG: Simulate Scale',
      'enter_weight': 'Enter weight (kg)',
      'example': 'Ex: 50.5',
      'debug_note': 'Note: Enter a number and wait, the system will continuously send data to trigger "Stable".',
      
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
      'pending_sync_title': 'Pending Weighing Data (Offline)',
      'no_pending_data': 'No data pending for sync.',
      'pending_count': 'Pending',
      'failed_count': 'Sync Failed',
      'sync_now': 'Sync Now',
      'syncing': 'Syncing...',
      'syncing_data': 'Syncing data...',
      'please_wait': 'Please wait',
      'sync_complete': 'Sync complete!',
      'no_network': 'No network connection. Please try again later.',
      'server_error': 'Server connection error. Please check network and try again.',
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
      
      // Notifications
      'please_enter_card_number': 'Please enter card number.',
      'login_success': 'Login successful! Welcome',
      'offline_login_success': 'Offline login successful! Welcome',
      'please_scan_code': 'Please scan code first.',
      'weight_out_of_range': 'Error: Weight is out of range!',
      'scan_success': 'Scan successful!\nType:',
      'please_scan_to_weigh': 'Please scan code to weigh!',
      'connection_lost': 'Bluetooth scale connection lost!',
    },
  };
}