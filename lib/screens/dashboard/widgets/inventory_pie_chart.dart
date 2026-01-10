import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../services/language_service.dart';

// (Màu sắc chúng ta đã dùng ở Bar chart)
const Color colorNhap = Color(0xFF42A5F5); // Xanh lá
const Color colorTon = Color(0xFFFFA726); // Đỏ

class InventoryPieChart extends StatelessWidget {
  final double totalNhap;
  final double totalXuat;
  final LanguageService _languageService = LanguageService();

  InventoryPieChart({
    super.key,
    required this.totalNhap,
    required this.totalXuat,
  });

  @override
  Widget build(BuildContext context) {
    // Logic tính toán: Tồn kho = Nhập - Xuất
    final double tonKho = totalNhap - totalXuat;

    // Tính %
    double phanTramXuat = 0;
    double phanTramTon = 0;

    if (totalNhap > 0) {
      phanTramXuat = (totalXuat / totalNhap) * 100;
      phanTramTon = (tonKho / totalNhap) * 100;
    } else {
      phanTramTon = 100; // Nếu không nhập gì, tồn 100% (của 0)
    }
    
    // Xử lý trường hợp Tồn kho < 0 (Xuất nhiều hơn Nhập)
    // Nếu bị âm, coi Tồn = 0 và Xuất = 100%
    if (tonKho < 0) {
      phanTramTon = 0;
      phanTramXuat = 100;
    }

    return AnimatedBuilder(
      animation: _languageService,
      builder: (context, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Tiêu đề
            Text(
              _languageService.translate('inventory_overview'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
        const SizedBox(height: 24),
        
        // 2. Biểu đồ tròn
        Expanded(
          child: PieChart(
            PieChartData(
              // Bỏ tương tác (click)
              pieTouchData: PieTouchData(enabled: false), 
              sectionsSpace: 4, // Khoảng cách giữa các phần
              centerSpaceRadius: 50, // Lỗ ở giữa
              
              sections: [
                // Phần 1: Tồn Kho (Đỏ)
                PieChartSectionData(
                  color: colorTon,
                  value: phanTramTon,
                  title: '${phanTramTon.toStringAsFixed(0)}%', // Hiển thị %
                  radius: 60,
                  titleStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                
                // Phần 2: Đã Xuất (Đỏ)
                PieChartSectionData(
                  color: colorNhap,
                  value: phanTramXuat,
                  title: '${phanTramXuat.toStringAsFixed(0)}%', // Hiển thị %
                  radius: 60,
                   titleStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        
        // 3. Chú thích (Legend)
        _buildLegendItem(colorNhap, '${_languageService.translate('exported_weight')} (${totalXuat.toStringAsFixed(2)})'),
        const SizedBox(height: 8),
        _buildLegendItem(colorTon, '${_languageService.translate('inventory_weight')} (${tonKho.toStringAsFixed(3)})'),
          ],
        );
      },
    );
  }

  // Widget helper cho Chú thích
  Widget _buildLegendItem(Color color, String text) {
    return Row(
      children: [
        Container(width: 16, height: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 14),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}