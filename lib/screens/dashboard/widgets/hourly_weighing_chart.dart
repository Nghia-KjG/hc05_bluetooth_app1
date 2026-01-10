import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../services/language_service.dart';

// Dữ liệu mẫu
class ChartData {
  final String label;
  final double nhap;
  final double xuat;
  const ChartData(this.label, this.nhap, this.xuat);
}

class HourlyWeighingChart extends StatelessWidget {
  HourlyWeighingChart({super.key, required this.data});
  // Màu sắc
  static const Color colorNhap = Color(0xFF81C784); // Xanh l
  static const Color colorXuat = Color(0xFFE57373); // Đỏ
  final List<ChartData> data;
  final LanguageService _languageService = LanguageService();
  
  @override
  Widget build(BuildContext context) {
    // --- 5. TÍNH TOÁN maxY ĐỘNG ---
    double maxY = 2000; // Mặc định
    if (data.isNotEmpty) {
      // Tìm giá trị lớn nhất giữa nhập và xuất
      final maxNhap = data.map((d) => d.nhap).reduce((a, b) => a > b ? a : b);
      final maxXuat = data.map((d) => d.xuat).reduce((a, b) => a > b ? a : b);
      final maxVal = maxNhap > maxXuat ? maxNhap : maxXuat;
      
      // Làm tròn lên 100 gần nhất
      maxY = (maxVal / 100).ceil() * 100;
      if (maxY == 0) maxY = 2000; // Tránh trường hợp 0
    }
    return AnimatedBuilder(
      animation: _languageService,
      builder: (context, child) {
        return Column(
      children: [
        Expanded(
          child: BarChart(
            BarChartData(
              // 1. Căn chỉnh
              alignment: BarChartAlignment.spaceAround,
              
              // 2. Trục Y (Trái)
              titlesData: FlTitlesData(
                show: true,
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                
                // Trục Y
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) {
                      if (value == 0) return _bottomTitle('0', meta);
                      if (value == 200) return _bottomTitle('200', meta);
                      if (value == 400) return _bottomTitle('400', meta);
                      if (value == 600) return _bottomTitle('600', meta); 
                      if (value == 800) return _bottomTitle('800', meta);
                      if (value == 1000) return _bottomTitle('1000', meta);
                      if (value == 1200) return _bottomTitle('1200', meta);
                      if (value == 1800) return _bottomTitle('1800',meta);
                      return const Text('');
                    },
                  ),
                ),
                
                // Trục X
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    getTitlesWidget: (value, meta) {
                      // value ở đây là index (0, 1, 2...)
                      if (value.toInt() >= data.length) return const Text(''); // Tránh lỗi
                        final String label = data[value.toInt()].label; // <-- Lấy nhãn (Ca 1, Ca 2, Ca 3)
                        return _bottomTitle(label, meta);
                    },
                  ),
                ),
              ),
              
              // 3. Cài đặt lưới
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: Colors.grey[200]!,
                  strokeWidth: 1,
                ),
              ),
              // 4. Bỏ viền
              borderData: FlBorderData(show: false),
              // 5. Cài đặt tương tác
              barTouchData: BarTouchData(
                
                // 1. TẮT TƯƠNG TÁC (KHÔNG CẦN CHẠM/HOVER)
                enabled: false, 
                touchTooltipData: BarTouchTooltipData(
                  tooltipPadding: EdgeInsets.all(2),
                  tooltipMargin: 5, // Khoảng cách 5px phía trên cột
                  //tooltipBorderRadius: BorderRadius.zero,
                  tooltipBorder: BorderSide.none, // BỎ BORDER
                  // 3. TÙY CHỈNH NỘI DUNG (CHỈ HIỂN THỊ SỐ)
                  getTooltipItem: (
                    BarChartGroupData group,
                    int groupIndex,
                    BarChartRodData rod,
                    int rodIndex,
                  ) {
                    double value = rod.toY;

                    // Không hiển thị số 0
                    if (value == 0) {
                      return null;
                    }

                    // Chỉ trả về con số
                    return BarTooltipItem(
                      value.toStringAsFixed(2),
                      const TextStyle(
                        color: Colors.white, // Màu chữ trắng trên nền tối
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  },
                ),
              ),
              
              // 5. Dữ liệu cột
              barGroups: _generateBarGroups(),

              // 6. Giới hạn Y
              maxY: maxY,
            ),
          ),
        ),
        const SizedBox(height: 16),
        // 7. Chú thích (Legend)
        _buildLegend(),
          ],
        );
      },
    );
  }

  // Hàm tạo các cột dữ liệu (ĐÃ SỬA)
  List<BarChartGroupData> _generateBarGroups() {
    const double barWidth = 80; // Độ rộng của mỗi cột (nhập/xuất)
    const double barsSpace = 10; // Khoảng cách giữa 2 cột (nhập/xuất)

    return List.generate(data.length, (index) {
      final item = data[index];
      return BarChartGroupData(
        x: index, // Vị trí nhóm (0, 1, 2... ứng với 7h, 8h...)
        barsSpace: barsSpace, // Khoảng cách giữa 2 cột

        // --- 4. THÊM DÒNG NÀY ĐỂ BẮT BUỘC HIỂN THỊ SỐ ---
        showingTooltipIndicators: [0, 1], 
        // --- KẾT THÚC THÊM ---

        barRods: [
          // CỘT 1: NHẬP (XANH)
          BarChartRodData(
            toY: item.nhap,
            width: barWidth,
            color: colorNhap, // Dùng 'color' thay vì 'rodStackItems'
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(4),
            ),
          ),

          // CỘT 2: XUẤT (ĐỎ)
          BarChartRodData(
            toY: item.xuat,
            width: barWidth,
            color: colorXuat, // Dùng 'color'
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(4),
            ),
          ),
        ],
      );
    });
  }

  // Widget helper cho chú thích
  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _legendItem(colorNhap, _languageService.translate('imported_weight')),
        const SizedBox(width: 16),
        _legendItem(colorXuat, _languageService.translate('exported_weight')),
      ],
    );
  }

  Widget _legendItem(Color color, String text) {
    return Row(
      children: [
        Container(width: 16, height: 16, color: color),
        const SizedBox(width: 8),
        Text(text),
      ],
    );
  }

  // Widget helper cho các tiêu đề (Trục X, Y)
  Widget _bottomTitle(String text, TitleMeta meta) {
    return SideTitleWidget(
      meta : meta,
      child: Text(text, style: const TextStyle(fontSize: 12)),
    );
  }
}