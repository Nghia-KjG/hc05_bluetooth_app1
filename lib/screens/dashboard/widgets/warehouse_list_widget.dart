import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/warehouse_models.dart';
// import '../../../services/language_service.dart';

class WarehouseListWidget extends StatelessWidget {
  final List<WarehouseSummary> warehouseSummary;
  final List<WarehouseDetail> warehouseDetails;
  final String? selectedOVNO;
  final bool isLoadingDetails;
  final Function(String ovNO) onOVNOTap;
  final VoidCallback onBackTap;

  const WarehouseListWidget({
    super.key,
    required this.warehouseSummary,
    required this.warehouseDetails,
    required this.selectedOVNO,
    required this.isLoadingDetails,
    required this.onOVNOTap,
    required this.onBackTap,
  });

  @override
  Widget build(BuildContext context) {
    // final lang = LanguageService();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              if (selectedOVNO != null) ...[
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: onBackTap,
                  tooltip: 'Quay lại',
                ),
                const SizedBox(width: 8),
              ],
              Text(
                selectedOVNO != null 
                    ? 'Chi tiết lệnh: $selectedOVNO'
                    : 'Danh sách lệnh còn tồn kho',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Content
          Expanded(
            child: selectedOVNO == null
                ? _buildSummaryList()
                : _buildDetailsList(),
          ),
        ],
      ),
    );
  }

  // Danh sách tổng quan
  Widget _buildSummaryList() {
    if (warehouseSummary.isEmpty) {
      return const Center(
        child: Text(
          'Không có lệnh nào còn tồn kho',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return SingleChildScrollView(
      child: Table(
        border: TableBorder.all(color: Colors.grey.shade300),
        columnWidths: const {
          0: FlexColumnWidth(2),
          1: FlexColumnWidth(3),
          2: FlexColumnWidth(1.5),
          3: FlexColumnWidth(1.5),
          4: FlexColumnWidth(1.5),
        },
        children: [
          // Header
          TableRow(
            decoration: BoxDecoration(color: Colors.blue.shade100),
            children: [
              _buildHeaderCell('Lệnh'),
              _buildHeaderCell('Tên Phôi Keo'),
              _buildHeaderCell('Tổng Nhập\n(kg)'),
              _buildHeaderCell('Tổng Xuất\n(kg)'),
              _buildHeaderCell('Tồn Kho\n(kg)'),
            ],
          ),
          // Data rows
          ...warehouseSummary.map((item) => TableRow(
            children: [
              _buildDataCell(
                item.ovNO,
                isClickable: true,
                onTap: () => onOVNOTap(item.ovNO),
              ),
              _buildDataCell(item.tenPhoiKeo),
              _buildDataCell(item.tongNhap.toStringAsFixed(1)),
              _buildDataCell(item.tongXuat.toStringAsFixed(1)),
              _buildDataCell(
                item.tonKho.toStringAsFixed(1),
                textColor: Colors.orange.shade700,
                fontWeight: FontWeight.bold,
              ),
            ],
          )),
        ],
      ),
    );
  }

  // Danh sách chi tiết
  Widget _buildDetailsList() {
    if (isLoadingDetails) {
      return const Center(child: CircularProgressIndicator());
    }

    if (warehouseDetails.isEmpty) {
      return const Center(
        child: Text(
          'Không có dữ liệu chi tiết',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return SingleChildScrollView(
      child: Table(
        border: TableBorder.all(color: Colors.grey.shade300),
        columnWidths: const {
          0: FlexColumnWidth(2),
          1: FlexColumnWidth(1),
          2: FlexColumnWidth(1.5),
          3: FlexColumnWidth(1.5),
          4: FlexColumnWidth(1.5),
          5: FlexColumnWidth(1.5),
          6: FlexColumnWidth(2),
          7: FlexColumnWidth(2),
        },
        children: [
          // Header
          TableRow(
            decoration: BoxDecoration(color: Colors.blue.shade100),
            children: [
              _buildHeaderCell('Mã Code'),
              _buildHeaderCell('Số Mẻ'),
              _buildHeaderCell('KL Mẻ\n(kg)'),
              _buildHeaderCell('KL Nhập\n(kg)'),
              _buildHeaderCell('KL Còn\n(kg)'),
              _buildHeaderCell('Hao Hụt\n(kg)'),
              _buildHeaderCell('Thời Gian Nhập'),
              _buildHeaderCell('Trạng Thái'),
            ],
          ),
          // Data rows
          ...warehouseDetails.map((item) {
            final statusColor = _getStatusColor(item.trangThaiText);
            final timeStr = item.mixTime != null 
                ? DateFormat('dd/MM HH:mm').format(item.mixTime!)
                : '---';
            
            return TableRow(
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
              ),
              children: [
                _buildDataCell(item.qrCode),
                _buildDataCell(item.package.toString()),
                _buildDataCell(item.qty.toStringAsFixed(1)),
                _buildDataCell(item.rkQty.toStringAsFixed(1)),
                _buildDataCell(item.currentQty.toStringAsFixed(1)),
                _buildDataCell(item.lossQty.toStringAsFixed(1)),
                _buildDataCell(timeStr),
                _buildStatusCell(item.trangThaiText, statusColor),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String text) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildDataCell(
    String text, {
    bool isClickable = false,
    VoidCallback? onTap,
    Color? textColor,
    FontWeight? fontWeight,
  }) {
    final child = Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12,
          color: textColor ?? (isClickable ? Colors.blue : Colors.black87),
          fontWeight: fontWeight,
          decoration: isClickable ? TextDecoration.underline : null,
        ),
      ),
    );

    if (isClickable && onTap != null) {
      return InkWell(
        onTap: onTap,
        child: child,
      );
    }

    return child;
  }

  Widget _buildStatusCell(String status, Color color) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color, width: 1),
        ),
        child: Text(
          status,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    final normalized = status.toLowerCase().trim();
    
    if (normalized.contains('hết') || normalized.contains('het')) {
      return const Color.fromARGB(255, 51, 50, 50);
    } else if (normalized.contains('còn') || normalized.contains('con') || 
               normalized.contains('hàng') || normalized.contains('hang')) {
      return Colors.green;
    } else if (normalized.contains('chưa') || normalized.contains('chua')) {
      return Colors.blue;
    } else {
      return Colors.orange;
    }
  }
}
