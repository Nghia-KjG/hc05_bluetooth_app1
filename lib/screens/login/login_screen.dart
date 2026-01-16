import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hc05_bluetooth_app/screens/weighing_station/controllers/weighing_station_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../../services/notification_service.dart';
import '../../services/auth_service.dart';
import '../../services/database_helper.dart';
import '../../services/sync_service.dart';
import '../../services/language_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _soTheController = TextEditingController();
  String _selectedFactory = 'LHG';
  bool _isLoading = false;
  String? _userRole; // Lưu role của user
  bool _isCheckingRole = false; // Đang kiểm tra role
  Timer? _debounceTimer; // Timer cho debounce

  // Địa chỉ server nội bộ

  @override
  void initState() {
    super.initState();
    // Sử dụng WidgetsBinding để đảm bảo load sau khi widget build xong
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSavedCardNumber();
    });
  }

  // Load số thẻ đã lưu từ SharedPreferences
  Future<void> _loadSavedCardNumber() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedSoThe = prefs.getString('lastLoginSoThe');
      if (kDebugMode) print('📋 Load số thẻ đã lưu: $savedSoThe');
      if (savedSoThe != null && savedSoThe.isNotEmpty) {
        setState(() {
          _soTheController.text = savedSoThe;
        });
      }
    } catch (e) {
      if (kDebugMode) print('⚠️ Lỗi load số thẻ đã lưu: $e');
    }
  }

  @override
  void dispose() {
    _soTheController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  // ===== HÀM KIỂM TRA ROLE =====
  Future<void> _checkUserRole(String soThe) async {
    if (soThe.isEmpty) {
      setState(() {
        _userRole = null;
        _isCheckingRole = false;
      });
      return;
    }

    setState(() => _isCheckingRole = true);

    try {
      // Kiểm tra kết nối mạng
      final connectivityResult = await Connectivity().checkConnectivity();
      final bool isOnline =
          connectivityResult.contains(ConnectivityResult.wifi) ||
          connectivityResult.contains(ConnectivityResult.mobile);

      if (!isOnline) {
        // Offline: Ẩn factory dropdown
        setState(() {
          _userRole = 'user';
          _isCheckingRole = false;
        });
        return;
      }

      // Gọi API để check role
      final url = Uri.parse('${dotenv.env['API_BASE_URL']}/api/auth/check-role');
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'userID': soThe}),
          )
          .timeout(const Duration(seconds: 5));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final role = data['role'] as String?;
        setState(() {
          _userRole = role ?? 'user';
          _isCheckingRole = false;
        });
        if (kDebugMode) print('✅ Role của user $soThe: $_userRole');
      } else {
        // Nếu API lỗi, mặc định là user (ẩn factory)
        setState(() {
          _userRole = 'user';
          _isCheckingRole = false;
        });
      }
    } catch (e) {
      // Lỗi kết nối: Mặc định là user
      if (kDebugMode) print('⚠️ Lỗi kiểm tra role: $e');
      if (mounted) {
        setState(() {
          _userRole = 'user';
          _isCheckingRole = false;
        });
      }
    }
  }

  // ===== HÀM ĐĂNG NHẬP =====
  Future<void> _handleLogin() async {
    setState(() => _isLoading = true);

    final soThe = _soTheController.text.trim();
    if (soThe.isEmpty) {
      // (Báo lỗi "Vui lòng nhập số thẻ"...)
      NotificationService().showToast(
        context: context,
        message: LanguageService().translate('please_enter_card_number'),
        type: ToastType.info,
      );
      setState(() => _isLoading = false);
      return;
    }

    // Biến để lưu thông tin user
    String? userName;
    String? successMessage;

    try {
      // BƯỚC 1: KIỂM TRA MẠNG
      final connectivityResult = await Connectivity().checkConnectivity();
      final bool isOnline =
          connectivityResult.contains(ConnectivityResult.wifi) ||
          connectivityResult.contains(ConnectivityResult.mobile);

      if (isOnline) {
        // --- 2. LOGIC KHI CÓ MẠNG (ONLINE FIRST) ---
        if (kDebugMode) print('🛰️ Đang đăng nhập Online...');
        try {
          final url = Uri.parse('${dotenv.env['API_BASE_URL']}/api/auth/login');
          final response = await http
              .post(
                url,
                headers: {'Content-Type': 'application/json'},
                body: json.encode({'mUserID': soThe}),
              )
              .timeout(const Duration(seconds: 10));

          if (!mounted) return;
          final data = json.decode(response.body);

          if (response.statusCode == 200) {
            // API THÀNH CÔNG
            userName = data['userData']['UserName'] as String;
            successMessage = data['message'];
            // Lưu role nếu có
            final role = data['userData']['Role'] as String?;
            if (role != null) {
              setState(() => _userRole = role);
            }

            // Đồng bộ danh sách người dùng từ /api/sync/persons (cho offline login)
            await _syncPersonsForOfflineLogin();

            // Đồng bộ danh sách cân để map tên hiển thị theo MAC
            await _syncDevicesForBluetoothLabel();

            // Chạy đồng bộ ngầm (không cần await)
            _runSync();
          } else {
            // API THẤT BẠI (Vd: 404 - Sai số thẻ)
            throw WeighingException(data['message'] ?? 'Số thẻ không hợp lệ.');
          }
        } catch (e) {
          // LỖI KHI GỌI API (Vd: Timeout, 500, Mất kết nối...)
          // -> CHUYỂN SANG KIỂM TRA OFFLINE (FALLBACK)
          if (kDebugMode) {
            print('⚠️ Lỗi API ($e), đang thử đăng nhập Offline...');
          }
          userName = await _loginFromCache(soThe);
          successMessage = 'Đăng nhập Offline thành công! Chào $userName';
        }
      } else {
        // --- 3. LOGIC KHI KHÔNG CÓ MẠNG (OFFLINE FIRST) ---
        if (kDebugMode) print('🔌 Đang đăng nhập Offline...');
        userName = await _loginFromCache(soThe);
        successMessage = 'Đăng nhập Offline thành công! Chào $userName';
      }

      // --- 4. XỬ LÝ KẾT QUẢ THÀNH CÔNG (Dù là Online hay Offline) ---
      AuthService().login(soThe, userName); // Lưu state
      final prefs =
          await SharedPreferences.getInstance(); // Lưu SharedPreferences
      await prefs.setString('soThe', soThe);
      await prefs.setString('factory', _selectedFactory);
      await prefs.setString(
        'lastLoginSoThe',
        soThe,
      ); // Lưu số thẻ để hiển thị lần sau
      if (kDebugMode) print('💾 Đã lưu số thẻ: $soThe vào SharedPreferences');

      if (!mounted) return;
      NotificationService().showToast(
        context: context,
        message: successMessage!,
        type: ToastType.success,
      );
      await Future.delayed(const Duration(seconds: 3)); // Đợi toast

      // Chuyển trang
      if (!mounted) return;
      _soTheController.clear();
      Navigator.of(context).pushReplacementNamed('/home');
    } catch (e) {
      // BẮT LỖI (Vd: Sai số thẻ (Online), Không tìm thấy (Offline))
      if (!mounted) return;
      final String msg =
          e is WeighingException
              ? e.message
              : e.toString().replaceFirst("Exception: ", "");
      NotificationService().showToast(
        context: context,
        message: msg,
        type: ToastType.error,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- 5. HÀM HELPER MỚI (ĐỂ KIỂM TRA CACHE) ---
  Future<String> _loginFromCache(String soThe) async {
    final db = await DatabaseHelper().database;
    final List<Map<String, dynamic>> localUser = await db.query(
      'VmlPersion',
      columns: ['nguoiThaoTac'],
      where: 'mUserID = ?',
      whereArgs: [soThe],
    );

    if (localUser.isEmpty) {
      throw WeighingException('Số thẻ không tồn tại trong dữ liệu Offline.');
    }

    return localUser.first['nguoiThaoTac'] as String;
  }

  // --- 6. HÀM HELPER (ĐỒNG BỘ DANH SÁCH NGƯỜI DÙNG TỪ /api/sync/persons) ---
  Future<void> _syncPersonsForOfflineLogin() async {
    try {
      if (kDebugMode) {
        print('👥 Đang tải danh sách người dùng cho offline login...');
      }
      await SyncService().syncPersons();
      if (kDebugMode) print('✅ Đã tải danh sách người dùng thành công');
    } catch (e) {
      // Không báo lỗi vì người dùng vẫn có thể đăng nhập online
      if (kDebugMode) print('⚠️ Lỗi tải danh sách người dùng: $e');
    }
  }

  Future<void> _syncDevicesForBluetoothLabel() async {
    try {
      if (kDebugMode) print('⚙️ Đang tải danh sách cân để hiển thị tên...');
      await SyncService().syncDevices();
      if (kDebugMode) print('✅ Đã tải danh sách cân thành công');
    } catch (e) {
      if (kDebugMode) print('⚠️ Lỗi tải danh sách cân: $e');
    }
  }

  // --- 7. HÀM HELPER (CHẠY SYNC NGẦM) ---
  Future<void> _runSync() async {
    // (Hàm này chạy ngầm, không báo toast)
    try {
      if (kDebugMode) print('🔄 Đang chạy đồng bộ dữ liệu ngầm...');
      await SyncService().syncAllData();
      if (kDebugMode) print('✅ Đồng bộ ngầm hoàn tất.');
    } catch (e) {
      if (kDebugMode) print('❌ Lỗi đồng bộ ngầm: $e');
    }
  }

  // ===== HÀM KIỂM TRA SERVER LAN =====
  /*Future<bool> _canReachLocalServer(String serverUrl) async {
    try {
      final response = await http
          .get(Uri.parse(serverUrl))
          .timeout(const Duration(seconds: 3));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }*/

  // ===== GIAO DIỆN =====
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Ẩn bàn phím khi tap ra ngoài
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFB0D9F3),
        body: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height,
            ),
            child: Center(
              child: LayoutBuilder(
                builder:
                    (context, constraints) =>
                        constraints.maxWidth > 800
                            ? _buildWideLayout()
                            : _buildNarrowLayout(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWideLayout() {
    return Row(
      children: [
        Expanded(
          child: Center(
            child: Image.asset(
              'lib/assets/images/weight_login.png',
              width: 400,
            ),
          ),
        ),
        Expanded(child: Center(child: _buildLoginForm())),
      ],
    );
  }

  Widget _buildNarrowLayout() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset('lib/assets/images/weight_login.png', width: 250),
          const SizedBox(height: 32),
          _buildLoginForm(),
        ],
      ),
    );
  }

  Widget _buildLoginForm() {
    return AnimatedBuilder(
      animation: LanguageService(),
      builder: (context, child) {
        final lang = LanguageService();
        return Container(
          width: 400,
          padding: const EdgeInsets.all(32.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                lang.translate('login_title'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 32),
              Text(
                lang.translate('card_number'),
                style: TextStyle(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _soTheController,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  suffixIcon: _soTheController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            setState(() {
                              _soTheController.clear();
                              _userRole = null;
                            });
                            _debounceTimer?.cancel();
                          },
                        )
                      : null,
                ),
                onChanged: (value) {
                  setState(() {}); // Để cập nhật hiển thị nút X
                  
                  // Hủy timer cũ
                  _debounceTimer?.cancel();
                  
                  // Tạo timer mới: sau 200ms không thay đổi thì check role
                  _debounceTimer = Timer(const Duration(milliseconds: 200), () {
                    _checkUserRole(value.trim());
                  });
                },
                // Khi ấn Enter: ẩn bàn phím và check role
                onSubmitted: (value) {
                  FocusScope.of(context).unfocus(); // Ẩn bàn phím
                  _debounceTimer?.cancel(); // Hủy debounce timer
                  _checkUserRole(value.trim()); // Check role ngay lập tức
                },
              ),
              // Hiển thị factory dropdown nếu role là 'admin'
              if (_userRole == 'admin') ...[
                const SizedBox(height: 20),
                Text(
                  lang.translate('factory'),
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonHideUnderline(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedFactory,
                    icon: const Icon(Icons.factory_outlined),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    items:
                        ['LHG', 'LYV', 'LVL', 'LAZ', 'LZS', 'LYM']
                            .map(
                              (v) => DropdownMenuItem(value: v, child: Text(v)),
                            )
                            .toList(),
                    onChanged:
                        (v) => setState(() => _selectedFactory = v ?? 'LHG'),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Text(
                lang.translate('language'),
                style: TextStyle(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonHideUnderline(
                child: DropdownButtonFormField<String>(
                  initialValue: lang.currentLanguage,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'vi',
                      child: Row(
                        children: [
                          Image.asset(
                            'lib/assets/images/vi.png',
                            width: 20,
                            height: 20,
                            errorBuilder:
                                (context, error, stackTrace) =>
                                    const Icon(Icons.flag, size: 20),
                          ),
                          const SizedBox(width: 8),
                          Text(lang.translate('vietnamese')),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'en',
                      child: Row(
                        children: [
                          Image.asset(
                            'lib/assets/images/en.png',
                            width: 20,
                            height: 20,
                            errorBuilder:
                                (context, error, stackTrace) =>
                                    const Icon(Icons.flag, size: 20),
                          ),
                          const SizedBox(width: 8),
                          Text(lang.translate('english')),
                        ],
                      ),
                    ),
                  ],
                  onChanged: (v) async {
                    if (v != null) {
                      await lang.setLanguage(v);
                      setState(() {});
                    }
                  },
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _handleLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                child:
                    _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                          lang.translate('login_button'),
                          style: const TextStyle(fontSize: 16),
                        ),
              ),
            ],
          ),
        );
      },
    );
  }
}
