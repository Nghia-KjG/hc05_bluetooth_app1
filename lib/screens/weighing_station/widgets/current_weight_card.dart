//import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../services/bluetooth_service.dart';
import '../../../services/language_service.dart';

class CurrentWeightCard extends StatefulWidget {
  final BluetoothService bluetoothService;
  final double minWeight;
  final double maxWeight;
  final double khoiLuongMe;
  final bool hasScannedCode;
  final bool isXuat;
  final double weighedNhapAmount;
  final double weighedXuatAmount;

  const CurrentWeightCard({
    super.key,
    required this.bluetoothService,
    required this.minWeight,
    required this.maxWeight,
    required this.khoiLuongMe,
    required this.hasScannedCode,
    this.isXuat = false,
    this.weighedNhapAmount = 0.0,
    this.weighedXuatAmount = 0.0,
  });

  @override
  State<CurrentWeightCard> createState() => _CurrentWeightCardState();
}
  class _CurrentWeightCardState extends State<CurrentWeightCard> {
  // 2. Thêm Controller cho ô Test
  final TextEditingController _testWeightController = TextEditingController();

  @override
  void dispose() {
    _testWeightController.dispose();
    super.dispose();
  }

  /*void _onTestWeightChanged(String text) {
    final double? weight = double.tryParse(text.trim());
    if (weight != null) {
      // GỌI HÀM CỦA SERVICE
      widget.bluetoothService.setSimulatedWeight(weight);
    }
  }*/

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ValueListenableBuilder<double>(
          valueListenable: widget.bluetoothService.currentWeight,
          builder: (context, currentWeight, child) {
            final bool isInRange = (currentWeight >= widget.minWeight) && (currentWeight <= widget.maxWeight);
            final Color statusColor = (isInRange || widget.minWeight == 0.0) ? Colors.green : Colors.red;
            final double deviationPercent = (widget.khoiLuongMe == 0)
                ? 0
                : ((currentWeight - widget.khoiLuongMe) / widget.khoiLuongMe) * 100;
            final String deviationString =
                '${deviationPercent > 0 ? '+' : ''}${deviationPercent.toStringAsFixed(1)}%';
            // --- (Kết thúc logic) ---

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(LanguageService().translate('current_weight'),
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black54)),
                const SizedBox(height: 10),
                
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Số cân
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          widget.hasScannedCode ? currentWeight.toStringAsFixed(3) : '---',
                          style: TextStyle(
                            fontSize: 60,
                            fontWeight: FontWeight.bold,
                            color: widget.hasScannedCode ? const Color(0xFF1E88E5) : Colors.grey,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Kg',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: widget.hasScannedCode ? const Color(0xFF1E88E5) : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(), // Đẩy ô test sang phải
                    
                    // Ô Test
                    /*if (kDebugMode) ...[
                      SizedBox(
                        width: 130, // Giới hạn chiều rộng
                        child: TextField(
                          controller: _testWeightController,
                          onChanged: _onTestWeightChanged, // Gọi hàm khi gõ
                          textAlign: TextAlign.center,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            hintText: 'Nhập (test)',
                            isDense: true, // Làm cho nó nhỏ gọn
                            filled: true,
                            fillColor: Colors.grey[200],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              //borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          ),
                        ),
                      ),
                    ],*/
                  ],
                ),

                //const SizedBox(height: 12),
                const Divider(),
                //const SizedBox(height: 12),
                
                // Hiển thị thông tin cân xuất nếu đang ở chế độ xuất
                if (widget.isXuat && widget.weighedNhapAmount > 0) ...[
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(LanguageService().translate('weighed_in'), style: const TextStyle(fontSize: 16, color: Colors.green)),
                            Text(
                              '${widget.weighedNhapAmount.toStringAsFixed(3)} kg',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(LanguageService().translate('weighed_out'), style: const TextStyle(fontSize: 16, color: Colors.orange)),
                            Text(
                              '${widget.weighedXuatAmount.toStringAsFixed(3)} kg',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orange),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(LanguageService().translate('remaining'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                            Text(
                              '${(widget.weighedNhapAmount - widget.weighedXuatAmount).toStringAsFixed(3)} kg',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                
                // MIN / MAX (Ẩn khi cân xuất)
                if (!widget.isXuat) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('MIN', style: TextStyle(fontSize: 14, color: Colors.black54, fontWeight: FontWeight.bold)),
                          Text(
                            '${widget.minWeight.toStringAsFixed(3)} kg',
                            style: const TextStyle(fontSize: 18, color: Colors.green, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('MAX', style: TextStyle(fontSize: 14, color: Colors.black54, fontWeight: FontWeight.bold)),
                          Text(
                            '${widget.maxWeight.toStringAsFixed(3)} kg',
                            style: const TextStyle(fontSize: 18, color: Colors.red, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Chênh lệch
                  Text(
                    '${LanguageService().translate('deviation')}: $deviationString',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: 1.0,
                    color: statusColor,
                    backgroundColor: statusColor.withValues(alpha: 0.5),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}