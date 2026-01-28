import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/bluetooth_service.dart';
import '../../services/language_service.dart';
import '../../widgets/main_app_bar.dart';
import 'widgets/hourly_weighing_chart.dart';
import 'widgets/inventory_pie_chart.dart';
import 'widgets/warehouse_list_widget.dart';
import '../../widgets/date_picker_input.dart';
import 'controllers/dashboard_controller.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final BluetoothService _bluetoothService = BluetoothService();
  final LanguageService _languageService = LanguageService();

  // --- 2. Create Controller ---
  late final DashboardController _controller;
  // Use a separate controller for the date picker text field
  final TextEditingController _dateController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // --- 3. Initialize Controller ---
    _controller = DashboardController();
    _dateController.text = DateFormat('dd/MM/yyyy').format(_controller.selectedDate);

    // Add listener to update text field if controller date changes internally (optional but good practice)
    _controller.addListener(() {
        final formattedDate = DateFormat('dd/MM/yyyy').format(_controller.selectedDate);
        if (_dateController.text != formattedDate) {
           _dateController.text = formattedDate;
        }
    });
  }

  @override
  void dispose() {
    // --- 4. Dispose Controllers ---
    _controller.dispose();
    _dateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MainAppBar(
        title: _languageService.translate('weighing_program'),
        bluetoothService: _bluetoothService,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: _languageService.translate('back_to_home'),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      // --- 5. Use AnimatedBuilder to listen ---
      body: AnimatedBuilder(
          animation: Listenable.merge([_controller, _languageService]),
          builder: (context, child) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _languageService.translate('dashboard_title'),
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Phần trên: 2 biểu đồ với chiều cao cố định
                  SizedBox(
                    height: 400,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Bar Chart Column
                        Expanded(
                          flex: 3,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                // Thêm phần header với DatePicker
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _languageService.translate('weight_by_shift'),
                                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                    ),
                                    DatePickerInput(
                                      selectedDate: _controller.selectedDate,
                                      controller: _dateController,
                                      onDateSelected: (newDate) {
                                        _controller.updateSelectedDate(newDate);
                                      },
                                      onDateCleared: () {
                                        _controller.updateSelectedDate(DateTime.now());
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                // Chart sẽ nằm trong Expanded
                                Expanded(
                                  child: HourlyWeighingChart(data: _controller.chartData),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 24),
                        // Pie Chart Column
                        Expanded(
                          flex: 2,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            // --- 7. Get data from controller ---
                            child: InventoryPieChart(
                              glueTypeData: _controller.glueTypeData,
                              totalTon: _controller.totalTon,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Phần dưới: Danh sách kho với chiều cao cố định
                  SizedBox(
                    height: 500,
                    child: WarehouseListWidget(
                      warehouseSummary: _controller.warehouseSummary,
                      warehouseDetails: _controller.warehouseDetails,
                      selectedOVNO: _controller.selectedOVNO,
                      isLoadingDetails: _controller.isLoadingDetails,
                      onOVNOTap: (ovNO) {
                        _controller.loadWarehouseDetails(ovNO);
                      },
                      onBackTap: () {
                        _controller.clearWarehouseDetails();
                      },
                    ),
                  ),
                ],
              ),
            );
          }),
    );
  }
}