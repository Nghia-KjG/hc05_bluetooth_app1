import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hc05_bluetooth_app/services/sync_service.dart';
import '../../services/bluetooth_service.dart';
import '../../services/notification_service.dart';
import '../../services/settings_service.dart';
import '../../services/language_service.dart';
import './controllers/weighing_station_controller.dart';

// Import các widget con
import 'widgets/current_weight_card.dart';
import 'widgets/action_min_max.dart';
import 'widgets/scan_input_field.dart';
import 'widgets/weighing_table.dart';
import '../../widgets/main_app_bar.dart';

class WeighingStationScreen extends StatefulWidget {
  const WeighingStationScreen({super.key});

  @override
  State<WeighingStationScreen> createState() => _WeighingStationScreenState();
}

class _WeighingStationScreenState extends State<WeighingStationScreen> {
  // Thêm Timer để giả lập cân
  Timer? _simulationTimer;

  // --- SỬ DỤNG DỊCH VỤ BLUETOOTH CHUNG ---
  final BluetoothService _bluetoothService = BluetoothService();
  late final WeighingStationController _controller;
  final SyncService _syncService = SyncService();

  final TextEditingController _scanTextController =
      TextEditingController(); // CONTROLLER CHO SCAN INPUT FIELD
  final FocusNode _scanFocusNode = FocusNode(); // Focus node cho ô scan input

  void _onConnectionChange() {
    // 1. Kiểm tra xem màn hình còn "sống" (mounted)
    // 2. Và kiểm tra xem Bluetooth có bị ngắt (value == null)
    if (mounted && _bluetoothService.connectedDevice.value == null) {
      // 3. Chỉ hiện thông báo, KHÔNG chuyển trang
      NotificationService().showToast(
        context: context,
        message: LanguageService().translate('connection_lost'),
        type: ToastType.error, // Hộp thoại màu đỏ
      );
    }
  }

  // Listener to update auto-complete when settings change
  void _onSettingsChanged() {
    final settings = SettingsService();
    if (settings.autoCompleteEnabled) {
      // start (or re-init) monitor
      _controller.initWeightMonitoring(context);
    } else {
      // stop monitor
      _controller.cancelAutoComplete();
    }
  }

  // HÀM GIẢ LẬP TÍN HIỆU CÂN
  void _startSimulatingWeight(double weight) {
    _simulationTimer?.cancel();

    // Cập nhật UI lần đầu
    _bluetoothService.currentWeight.value = weight;

    // Tạo Timer bắn tín hiệu mỗi 100ms
    _simulationTimer = Timer.periodic(const Duration(milliseconds: 100), (
      timer,
    ) {
      // 1. Cập nhật UI (ValueNotifier sẽ chặn nếu số trùng, nhưng kệ nó)
      _bluetoothService.currentWeight.value = weight;

      // 2. QUAN TRỌNG: Ép buộc gửi mẫu vào controller để Monitor đếm
      // Dòng này giúp Monitor nhận được: 80, 80, 80, 80... liên tục
      _controller.addWeightSample(weight);

      // Debug: Mở dòng này nếu muốn thấy nó chạy
      // print('Simulating tick: $weight');
    });
  }

  @override
  void initState() {
    super.initState();
    debugPrint('🚀 WeighingStationScreen initState');
    // --- KHỞI TẠO CONTROLLER ---
    _controller = WeighingStationController(
      bluetoothService: _bluetoothService,
    );
    // Đăng ký callback để clear scan input khi auto-complete thành công
    _controller.onAutoComplete = () {
      if (!mounted) return;
      // Dừng giả lập (nếu đang mở)
      final bool wasSimulating = _simulationTimer != null;
      _simulationTimer?.cancel();
      _simulationTimer = null;
      // Xóa ô scan
      _scanTextController.clear();
      // Nếu đang chạy timer mô phỏng trước đó, reset trọng lượng hiển thị
      if (wasSimulating) {
        _bluetoothService.currentWeight.value = 0.0;
      }
      setState(() {});
      // Focus lại ô scan sau khi auto-complete
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) _scanFocusNode.requestFocus();
      });
    };
    // Initialize according to current settings
    if (SettingsService().autoCompleteEnabled) {
      _controller.initWeightMonitoring(context);
    }

    // Register listener for future changes
    SettingsService().addListener(_onSettingsChanged);
    _bluetoothService.connectedDevice.addListener(_onConnectionChange);
    _syncService.syncHistoryQueue();

    // Request focus cho ô scan sau khi build xong
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint('📌 PostFrameCallback - Requesting focus cho _scanFocusNode');
      _scanFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _simulationTimer?.cancel(); // Hủy Timer giả lập nếu còn chạy
    _controller.dispose();
    _scanTextController.dispose(); // Hủy controller khi màn hình bị hủy
    _scanFocusNode.dispose(); // Hủy FocusNode của ô scan
    _bluetoothService.connectedDevice.removeListener(_onConnectionChange);
    SettingsService().removeListener(_onSettingsChanged);
    super.dispose();
  }

  Widget _buildWeighingTypeDropdown() {
    // Xác định màu sắc dựa trên loại cân
    final bool isNhap = _controller.selectedWeighingType == WeighingType.nhap;
    final Color backgroundColor =
        isNhap
            ? const Color(0xFF4CAF50) // Xanh lá cho Nhập
            : const Color(0xFF2196F3); // Xanh dương cho Xuất

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 115, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(10.0),
        boxShadow: [
          BoxShadow(
            color: backgroundColor.withValues(alpha: 5),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<WeighingType>(
          value: _controller.selectedWeighingType,
          icon: const SizedBox.shrink(), // Xóa icon mũi tên
          dropdownColor: Colors.transparent, // Nền trong suốt

          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          items: [
            DropdownMenuItem(
              value: WeighingType.nhap,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 100,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50), // Xanh lá cho Nhập
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Text(
                      LanguageService().translate('weighing_import'),
                      style: const TextStyle(color: Colors.white, fontSize: 20),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.arrow_downward,
                      color: Color.fromARGB(255, 238, 234, 9),
                      size: 30,
                    ),
                  ],
                ),
              ),
            ),
            DropdownMenuItem(
              value: WeighingType.xuat,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 100,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF2196F3), // Xanh dương cho Xuất
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Text(
                      LanguageService().translate('weighing_export'),
                      style: const TextStyle(color: Colors.white, fontSize: 20),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.arrow_upward,
                      color: Color.fromARGB(255, 238, 9, 9),
                      size: 30,
                    ),
                  ],
                ),
              ),
            ),
          ],
          onChanged: (WeighingType? newValue) async {
            if (newValue != null) {
              await _controller.updateWeighingType(newValue, context);
              setState(() {}); // Force rebuild để đổi màu
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Khi tap vào bất kỳ đâu trên màn hình -> request focus cho ô scan
      onTap: () {
        debugPrint('👆 TAP! Requesting focus cho _scanFocusNode');
        _scanFocusNode.requestFocus();
      },
      child: Scaffold(
        appBar: MainAppBar(
          title: LanguageService().translate('weighing_program'),
          bluetoothService: _bluetoothService,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: LanguageService().translate('back_to_home'),
            onPressed: () {
              // Logic cho nút Back cụ thể của màn hình này
              Navigator.of(context).pop();
            },
          ),
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            return AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                // Hàm _buildLayout bây giờ nằm bên trong builder
                return _buildLayout();
              },
            );
          },
        ),
      ),
    );
  }

  // Widget layout chính
  Widget _buildLayout() {
    // Xác định màu nền dựa trên loại cân
    final bool isNhap = _controller.selectedWeighingType == WeighingType.nhap;
    final Color pageBackgroundColor =
        isNhap
            ? const Color.fromARGB(133, 219, 158, 43) // Xanh lá nhạt cho Nhập
            : const Color.fromARGB(
              255,
              112,
              128,
              144,
            ); // Xanh dương nhạt cho Xuất

    return Container(
      color: pageBackgroundColor, // Nền toàn trang
      width: double.infinity,
      height: double.infinity,
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight:
                MediaQuery.of(
                  context,
                ).size.height, // đảm bảo kéo dài đủ màn hình
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 12.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      LanguageService().translate('weighing_station'),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pushNamed('/history');
                      },
                      icon: const Icon(Icons.history, size: 24),
                      label: Text(
                        LanguageService().translate('history'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1976D2),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Cột bên trái
                    Expanded(
                      flex: 2,
                      child: CurrentWeightCard(
                        bluetoothService: _bluetoothService,
                        minWeight: _controller.minWeight,
                        maxWeight: _controller.maxWeight,
                        khoiLuongMe: _controller.khoiLuongMe,
                        hasScannedCode: _scanTextController.text.isNotEmpty,
                        isXuat:
                            _controller.selectedWeighingType ==
                            WeighingType.xuat,
                        weighedNhapAmount: _controller.weighedNhapAmount,
                        weighedXuatAmount: _controller.weighedXuatAmount,
                      ),
                    ),
                    const SizedBox(width: 24),
                    // Cột bên phải
                    Expanded(
                      flex: 3,
                      child: Column(
                        children: [
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              ActionBar(
                                selectedPercentage:
                                    _controller.selectedPercentage,
                                onPercentageChanged:
                                    _controller.updatePercentage,
                              ),
                              const SizedBox(width: 16),
                              _buildWeighingTypeDropdown(),
                            ],
                          ),
                          const SizedBox(height: 20),
                          ScanInputField(
                            controller: _scanTextController,
                            focusNode: _scanFocusNode,
                            onScan: (code) {
                              debugPrint('🎯 onScan callback: "$code"');
                              _controller.handleScan(context, code);
                              // Focus lại ô scan sau khi xử lý scan
                              Future.delayed(
                                const Duration(milliseconds: 100),
                                () {
                                  if (mounted) _scanFocusNode.requestFocus();
                                },
                              );
                            },
                          ),
                          const SizedBox(height: 20),
                          // === KHU VỰC TEST (Chỉ dùng khi dev) ===
                          if (kDebugMode) ...[
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.yellow.shade100,
                                border: Border.all(color: Colors.orange),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    LanguageService().translate(
                                      'debug_simulate',
                                    ),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      labelText: LanguageService().translate(
                                        'enter_weight',
                                      ),
                                      hintText: LanguageService().translate(
                                        'example',
                                      ),
                                      border: const OutlineInputBorder(),
                                      isDense: true,
                                      filled: true,
                                      fillColor: Colors.white,
                                    ),
                                    onChanged: (value) {
                                      // 1. Parse số
                                      final double? weight = double.tryParse(
                                        value,
                                      );

                                      if (weight != null) {
                                        // 2. Bắt đầu giả lập dòng chảy dữ liệu
                                        _startSimulatingWeight(weight);
                                      } else {
                                        // Nếu xóa trắng hoặc nhập sai, dừng giả lập
                                        _simulationTimer?.cancel();
                                      }
                                    },
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    LanguageService().translate('debug_note'),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                          ValueListenableBuilder<double>(
                            valueListenable: _bluetoothService.currentWeight,
                            builder: (context, currentWeight, child) {
                              // Thêm mẫu cân vào monitor để theo dõi ổn định
                              _controller.addWeightSample(currentWeight);

                              final bool isInRange =
                                  (currentWeight >= _controller.minWeight) &&
                                  (currentWeight <= _controller.maxWeight) &&
                                  _controller.minWeight > 0;

                              final Color buttonColor =
                                  isInRange
                                      ? Colors.green
                                      : const Color(0xFFE8EAF6);
                              final Color textColor =
                                  isInRange ? Colors.white : Colors.indigo;

                              return SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () async {
                                    if (_controller.khoiLuongMe == 0.0) {
                                      NotificationService().showToast(
                                        context: context,
                                        message: LanguageService().translate(
                                          'please_scan_to_weigh',
                                        ),
                                        type: ToastType.info,
                                      );
                                      return;
                                    }

                                    final bool success = await _controller
                                        .completeCurrentWeighing(
                                          context,
                                          currentWeight,
                                        );

                                    if (success) {
                                      _scanTextController.clear();
                                      // Focus lại ô scan sau khi hoàn tất
                                      Future.delayed(
                                        const Duration(milliseconds: 100),
                                        () {
                                          if (mounted)
                                            _scanFocusNode.requestFocus();
                                        },
                                      );
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: buttonColor,
                                    foregroundColor: textColor,
                                    elevation: 2,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 32,
                                      vertical: 16,
                                    ),
                                    minimumSize: const Size(
                                      double.infinity,
                                      48,
                                    ),
                                  ),
                                  child: Text(
                                    LanguageService().translate('complete'),
                                    style: const TextStyle(fontSize: 30),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                WeighingTable(
                  records: _controller.records,
                  weighingType: _controller.selectedWeighingType,
                  activeOVNO: _controller.activeOVNO,
                  activeMemo: _controller.activeMemo,
                  scannedCode: _controller.scannedCode,
                  totalTargetQty: _controller.activeTotalTargetQty,
                  totalNhap: _controller.activeTotalNhap,
                  totalXuat: _controller.activeTotalXuat,
                  xWeighed: _controller.activeXWeighed,
                  yTotal: _controller.activeYTotal,
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
