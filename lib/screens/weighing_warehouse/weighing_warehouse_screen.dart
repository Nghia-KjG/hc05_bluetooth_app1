import 'package:flutter/material.dart';
import '../../services/bluetooth_service.dart';
import '../../widgets/main_app_bar.dart';
import 'widgets/summary_table.dart';
import 'widgets/detail_table.dart';

class WeighingWarehouseScreen extends StatefulWidget {
  const WeighingWarehouseScreen({super.key});

  @override
  State<WeighingWarehouseScreen> createState() =>
      _WeighingWarehouseScreenState();
}

class _WeighingWarehouseScreenState extends State<WeighingWarehouseScreen> {
  final BluetoothService _bluetoothService = BluetoothService();
  final TextEditingController _scanController = TextEditingController();
  final FocusNode _scanFocusNode = FocusNode();

  DateTime _selectedDate = DateTime.now();
  String _selectedShift = 'Ca 1';
  double _selectedPercentage = 0.5;

  @override
  void initState() {
    super.initState();
    // Auto-focus scan input when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scanFocusNode.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MainAppBar(
        title: 'Hệ Thống Cân Hóa Chất',
        bluetoothService: _bluetoothService,
      ),
      body: Column(
        children: [
          // Header section
          _buildHeader(),

          const SizedBox(height: 8),

          // Main content
          Expanded(
            child: Row(
              children: [
                // Left side - Tables
                Expanded(
                  flex: 7,
                  child: Column(
                    children: [
                      // Bảng tổng hóa chất
                      const Expanded(flex: 3, child: SummaryTable()),

                      const SizedBox(height: 8),

                      // Bảng chi tiết hợp chất - đơn chất
                      const Expanded(flex: 4, child: DetailTable()),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Right side - Scan & Weight Display
                Expanded(
                  flex: 3,
                  child: Column(
                    children: [
                      _buildScanSection(),
                      const SizedBox(height: 8),
                      _buildWeightDisplay(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        border: Border(bottom: BorderSide(color: Colors.grey[400]!)),
      ),
      child: Row(
        children: [
          // Ngày
          Row(
            children: [
              const Text(
                'Ngày:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey[400]!),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: InkWell(
                  onTap: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null && picked != _selectedDate) {
                      setState(() {
                        _selectedDate = picked;
                      });
                    }
                  },
                  child: Row(
                    children: [
                      Text(
                        '${_selectedDate.day.toString().padLeft(2, '0')}/${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.year}',
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.calendar_today, size: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(width: 24),

          // CA dropdown
          Row(
            children: [
              const Text(
                'CA:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey[400]!),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: DropdownButton<String>(
                  value: _selectedShift,
                  underline: const SizedBox(),
                  items:
                      ['Ca 1', 'Ca 2', 'Ca 3', 'CAHC']
                          .map(
                            (shift) => DropdownMenuItem(
                              value: shift,
                              child: Text(
                                shift,
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          )
                          .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedShift = value;
                      });
                    }
                  },
                ),
              ),
            ],
          ),

          const SizedBox(width: 16),

          // Nút Tìm Kiếm
          ElevatedButton.icon(
            onPressed: () {
              // TODO: Implement search
            },
            icon: const Icon(Icons.search),
            label: const Text('Tìm Kiếm'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[400],
              foregroundColor: Colors.black,
            ),
          ),

          const Spacer(),
          

          // Chất đã cân
          const Text(
            'Chất Đã Cân:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          const Text(
            '1/15',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green[50],
        border: Border.all(color: Colors.green[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Scan input
          Row(
            children: [
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _scanController,
                  focusNode: _scanFocusNode,
                  onSubmitted: _handleScan,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFFE8F5E9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: const BorderSide(color: Color(0xFFB9E5BC)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: const BorderSide(color: Color(0xFFB9E5BC)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: const BorderSide(
                        color: Color(0xFF4CAF50),
                        width: 2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    suffixIcon: IconButton(
                      icon: const Icon(
                        Icons.qr_code_scanner,
                        color: Color(0xFF4CAF50),
                      ),
                      onPressed: () {
                        _scanFocusNode.requestFocus();
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey[400]!),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: DropdownButton<double>(
                  value: _selectedPercentage,
                  underline: const SizedBox(),
                  style: const TextStyle(fontSize: 13, color: Colors.black),
                  items:
                      [0.1, 0.5, 1.0, 2.0, 5.0]
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text('${value}%'),
                            ),
                          )
                          .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedPercentage = value;
                      });
                    }
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Info display
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: const TextSpan(
                    style: TextStyle(fontSize: 14, color: Colors.black),
                    children: [
                      TextSpan(
                        text: 'Tên Hóa Chất: ',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(text: 'LOCTITE AQUACE ARF-40'),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                RichText(
                  text: const TextSpan(
                    style: TextStyle(fontSize: 14, color: Colors.black),
                    children: [
                      TextSpan(
                        text: 'Mã Hóa Chất: ',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(text: 'W201000029'),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                RichText(
                  text: const TextSpan(
                    style: TextStyle(fontSize: 14, color: Colors.black),
                    children: [
                      TextSpan(
                        text: 'Định Mức (kg): ',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(text: '0.457'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Hoàn Tất button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                // TODO: Implement complete
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text(
                'Hoàn Tất',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleScan(String value) {
    if (value.isEmpty) return;

    // TODO: Implement scan logic
    print('Scanned: $value');

    // Clear and refocus
    _scanController.clear();
    _scanFocusNode.requestFocus();
  }

  Widget _buildWeightDisplay() {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            // Scale name
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'CÂN 1',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Text(
                    'LOCTITE AQUACE ARF-40',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Weight display
            const Expanded(
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '459.1',
                      style: TextStyle(
                        fontSize: 72,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'G',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Min/Max display
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Min: 0.4547 Max: 0.4593 (kg)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scanController.dispose();
    _scanFocusNode.dispose();
    super.dispose();
  }
}
