import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../data/weighing_data.dart'; // Import model
import '../../../services/language_service.dart';

class SummaryData {
  final String ovNO;
  final String? memo;
  final double totalTargetQty;
  final double totalNhap;
  final double totalXuat;
  final int xWeighed;
  final int yTotal;

  SummaryData({
    required this.ovNO,
    this.memo,
    required this.totalTargetQty,
    required this.totalNhap,
    required this.totalXuat,
    required this.xWeighed,
    required this.yTotal,
  });
}

class HistoryTable extends StatelessWidget {
  final List<dynamic> records; // <-- Đổi tên biến (hoặc giữ 'records' nếu bạn muốn)
  const HistoryTable({super.key, required this.records});

  @override
  Widget build(BuildContext context) {
    const headerStyle = TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 13);
    const cellStyle = TextStyle(fontSize: 14);
    const summaryStyle = TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87);

    // --- (Hàm helper headerCell, dataCell, formatDateTime giữ nguyên) ---
    Widget headerCell(String title, int flex) => Expanded(
        flex: flex,
        child: Container(
          color: const Color(0xFF40B9FF), // Màu xanh nhạt header
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Center(
              child: Text(title, style: headerStyle, textAlign: TextAlign.center)),
        ));
  Widget dataCell(String text, int flex, {TextAlign align = TextAlign.center}) => Expanded(
      flex: flex,
      child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 4.0),
          child: Text(text, style: cellStyle, textAlign: TextAlign.center)));

    Widget verticalDivider() => Container(width: 1, color: Colors.white.withValues(alpha: 1));
    // Định dạng ngày giờ
    String formatDateTime(DateTime? dt) {
      if (dt == null) return '---';
      return DateFormat('dd/MM/yyyy HH:mm').format(dt);
    }
    // --- (Kết thúc hàm helper) ---

    // --- KHÔNG CẦN LOGIC NHÓM Ở ĐÂY NỮA (CONTROLLER ĐÃ LÀM) ---

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[300]!)
      ),
      child: Column(
        children: [
          // Header Row (Giữ nguyên)
          IntrinsicHeight(
            child: Row(
              children: [
                headerCell('Mã Code', 3), verticalDivider(),
                headerCell('Tên Phôi Keo', 4), verticalDivider(),
                headerCell('Số Mẻ', 3), verticalDivider(),
                headerCell('Số Máy', 3), verticalDivider(),
                headerCell('Người Thao Tác', 4), verticalDivider(),
                headerCell('Thời Gian Cân', 4), verticalDivider(),
                headerCell('KL Mẻ(kg)', 3), verticalDivider(),
                headerCell('KL Đã Cân(kg)', 3), verticalDivider(),
                headerCell('Loại Cân', 3), 
              ],
            ),
          ),

          // --- 2. SỬA LẠI BODY ---
          Expanded(
            child: Container(
              color: Colors.white,
              child: records.isEmpty // Đổi tên 'displayList' thành 'records'
                ? Center(child: Text('Không có dữ liệu lịch sử.', style: TextStyle(color: Colors.grey[600])))
                : ListView.builder(
                    itemCount: records.length, // Dùng list từ controller
                    itemBuilder: (context, index) {
                      final item = records[index];

                      if (item is WeighingRecord) {
                        // RENDER HÀNG DỮ LIỆU
                        final record = item;
                        // Màu khác nhau theo loại cân
                        Color backgroundColor;
                        if (record.loai == 'nhap') {
                          backgroundColor = const Color(0xFFE3F2FD); // Xanh nhạt
                        } else if (record.loai == 'xuat') {
                          backgroundColor = const Color(0xFFFFF9C4); // Vàng nhạt
                        } else {
                          backgroundColor = Colors.white;
                        }
                        
                        return Container(
                          decoration: BoxDecoration(
                            color: backgroundColor,
                            border: Border(
                              bottom: BorderSide(color: Colors.grey[400]!, width: 0.5),
                            ),
                          ),
                          child: IntrinsicHeight(
                            child: Row(
                              children: [
                                dataCell(record.maCode, 3),
                                dataCell(record.tenPhoiKeo ?? 'N/A', 4, align: TextAlign.left),
                                dataCell(record.soLo.toString(), 3),
                                dataCell(record.soMay, 3),
                                dataCell(record.nguoiThaoTac ?? 'N/A', 4, align: TextAlign.left),
                                dataCell(formatDateTime(record.mixTime), 4),
                                dataCell(record.qtys.toStringAsFixed(2), 3, align: TextAlign.right),
                                dataCell(record.realQty?.toStringAsFixed(2) ?? '---', 3, align: TextAlign.right),
                                dataCell(record.loai ?? 'N/A', 3),
                              ],
                            ),
                          ),
                        );
                      } else if (item is SummaryData) {
                        // RENDER HÀNG TÓM TẮT (ĐÃ CẬP NHẬT)
                        final summary = item;
                        return Column(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: const Color.fromARGB(255, 162, 238, 164),
                                border: Border(
                                  bottom: BorderSide(color: Colors.grey[700]!, width: 1.0),
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text('${LanguageService().translate('order')} : ${summary.ovNO}', style: summaryStyle),
                                      const Spacer(flex: 1),
                                      Text('${LanguageService().translate('batch_count')}: ${summary.xWeighed} / ${summary.yTotal}', style: summaryStyle),
                                      const Spacer(flex: 1),
                                      // Dùng dữ liệu thật
                                      Text(
                                        '${LanguageService().translate('import_weight')}: ${summary.totalNhap.toStringAsFixed(2)} / ${summary.totalTargetQty.toStringAsFixed(2)} kg', 
                                        style: summaryStyle
                                      ),
                                      const Spacer(flex: 1),
                                      // Dùng dữ liệu thật
                                      Text(
                                        '${LanguageService().translate('export_weight')}: ${summary.totalXuat.toStringAsFixed(2)} / ${summary.totalNhap.toStringAsFixed(2)} kg', 
                                        style: summaryStyle
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${LanguageService().translate('memo')}: ${summary.memo ?? ''}',
                                    style: summaryStyle,
                                    textAlign: TextAlign.left,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8), // Khoảng cách bên dưới hàng tóm tắt
                          ],
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
            ),
          ),
        ],
      ),
    );
  }
}