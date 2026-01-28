import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../services/language_service.dart';
import '../controllers/dashboard_controller.dart';

// Màu sắc cho các loại keo (có thể tùy chỉnh thêm)
const List<Color> glueColors = [
  Color(0xFF4CAF50), // Xanh lá
  Color(0xFF2196F3), // Xanh dương
  Color(0xFFFFA726), // Cam
  Color(0xFFE91E63), // Hồng
  Color(0xFF9C27B0), // Tím
  Color(0xFFFF5722), // Đỏ cam
  Color(0xFF00BCD4), // Cyan
  Color(0xFFFFEB3B), // Vàng
];

class InventoryPieChart extends StatefulWidget {
  final List<GlueTypeData> glueTypeData;
  final double totalTon;

  const InventoryPieChart({
    super.key,
    required this.glueTypeData,
    required this.totalTon,
  });

  @override
  State<InventoryPieChart> createState() => _InventoryPieChartState();
}

class _InventoryPieChartState extends State<InventoryPieChart> {
  int? _selectedIndex;
  final LanguageService _languageService = LanguageService();

  @override
  void initState() {
    super.initState();
    _selectedIndex = null;
  }

  @override
  Widget build(BuildContext context) {
    // Nếu không có dữ liệu, hiển thị trống
    if (widget.glueTypeData.isEmpty) {
      return Center(
        child: Text(
          _languageService.translate('no_data'),
          style: const TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return AnimatedBuilder(
      animation: _languageService,
      builder: (context, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Tiêu đề với tổng tồn kho
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _languageService.translate('inventory_overview'),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // 2. Biểu đồ tròn với text ở giữa
            Expanded(
              child: Stack(
                children: [
                  PieChart(
                    PieChartData(
                      pieTouchData: PieTouchData(
                        enabled: true,
                        touchCallback: (FlTouchEvent event, pieTouchResponse) {
                          setState(() {
                            if (pieTouchResponse == null || pieTouchResponse.touchedSection == null) {
                              _selectedIndex = null;
                            } else {
                              _selectedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                            }
                          });
                        },
                      ),
                      sectionsSpace: 2,
                      centerSpaceRadius: 60,
                      sections: _buildPieChartSections(),
                    ),
                  ),
                  // Hiển thị thông tin ở giữa
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_selectedIndex != null && 
                            _selectedIndex! >= 0 && 
                            _selectedIndex! < widget.glueTypeData.length)
                          _buildSelectedInfo()
                        else
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _languageService.translate('total'),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.totalTon.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              Text(
                                'kg',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // 3. Thông tin chi tiết khi chạm vào
            if (_selectedIndex != null && 
                _selectedIndex! >= 0 && 
                _selectedIndex! < widget.glueTypeData.length) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: glueColors[_selectedIndex! % glueColors.length].withValues(alpha: 0.1),
                  border: Border.all(
                    color: glueColors[_selectedIndex! % glueColors.length],
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.glueTypeData[_selectedIndex!].tenPhoiKeo,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: glueColors[_selectedIndex! % glueColors.length],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Khối lượng',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                            Text(
                              '${widget.glueTypeData[_selectedIndex!].ton.toStringAsFixed(2)} kg',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tỉ lệ',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                            Text(
                              '${((widget.glueTypeData[_selectedIndex!].ton / widget.totalTon) * 100).toStringAsFixed(1)}%',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ] else
              Text(
                '👆 Chạm vào biểu đồ để xem chi tiết',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
              ),
          ],
        );
      },
    );
  }

  Widget _buildSelectedInfo() {
    if (_selectedIndex == null || _selectedIndex! >= widget.glueTypeData.length) {
      return const SizedBox.shrink();
    }

    final glue = widget.glueTypeData[_selectedIndex!];
    final percentage = (glue.ton / widget.totalTon) * 100;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          glue.tenPhoiKeo,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: glueColors[_selectedIndex! % glueColors.length],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          glue.ton.toStringAsFixed(2),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        Text(
          '${percentage.toStringAsFixed(1)}%',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  // Tạo sections cho PieChart
  List<PieChartSectionData> _buildPieChartSections() {
    if (widget.totalTon <= 0) {
      return [
        PieChartSectionData(
          color: Colors.grey.shade300,
          value: 100,
          title: '0%',
          radius: 60,
          titleStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.black54,
          ),
        ),
      ];
    }

    return List.generate(widget.glueTypeData.length, (index) {
      final glue = widget.glueTypeData[index];
      final percentage = (glue.ton / widget.totalTon) * 100;
      final color = glueColors[index % glueColors.length];
      final isSelected = _selectedIndex == index && 
                         _selectedIndex! >= 0 && 
                         _selectedIndex! < widget.glueTypeData.length;

      return PieChartSectionData(
        color: color,
        value: percentage,
        title: isSelected ? '${percentage.toStringAsFixed(1)}%' : '',
        radius: isSelected ? 70 : 60,
        titleStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    });
  }
}