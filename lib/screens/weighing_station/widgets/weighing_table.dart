import 'package:flutter/material.dart';
import '../../../data/weighing_data.dart';
import '../../../services/language_service.dart';
import '../controllers/weighing_station_controller.dart'; // Giữ import này

class WeighingTable extends StatelessWidget {
  final List<WeighingRecord> records;
  final WeighingType weighingType;
  final String? activeOVNO;
  final String? activeMemo;
  final String? scannedCode; // Mã được scan gần nhất

  final double totalTargetQty;
  final double totalNhap;
  final double totalXuat;
  final int xWeighed;
  final int yTotal;
  final LanguageService _languageService = LanguageService();

  WeighingTable({
    super.key,
    required this.records,
    required this.weighingType,
    this.activeOVNO,
    this.activeMemo,
    this.scannedCode,
    required this.totalTargetQty,
    required this.totalNhap,
    required this.totalXuat,
    required this.xWeighed,
    required this.yTotal,
  });

  @override
  Widget build(BuildContext context) {
    const headerStyle = TextStyle(
      fontWeight: FontWeight.bold,
      color: Colors.black,
      fontSize: 20,
    );
    const cellStyle = TextStyle(fontSize: 20);
    const summaryStyle = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.bold,
      color: Colors.black87,
    );

    Widget verticalDivider() =>
        Container(width: 1, color: Colors.white.withValues(alpha: 1));
    Widget headerCell(String title, int flex) => Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Center(
          child: Text(title, style: headerStyle, textAlign: TextAlign.center),
        ),
      ),
    );

    Widget dataCell(String text, int flex) => Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 4.0),
        child: Center(
          child: Text(text, style: cellStyle, textAlign: TextAlign.center),
        ),
      ),
    );

    // Header động cho cột Khối Lượng Mẻ/Tồn
    final String khoiLuongMeHeader =
        (weighingType == WeighingType.nhap)
            ? 'Khối Lượng Mẻ (kg)'
            //'Khối Lượng Tồn (kg)' //chưa dùng
            : 'Khối Lượng Mẻ (kg)';

    return AnimatedBuilder(
      animation: _languageService,
      builder: (context, child) {
        return Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          clipBehavior: Clip.antiAlias,
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Column(
            children: [
              // --- HEADER ROW (Đã cập nhật) ---
              Container(
                color: const Color(0xFF40B9FF),
                child: IntrinsicHeight(
                  child: Row(
                    children: [
                      headerCell('Tên Phôi Keo', 3),
                      verticalDivider(),
                      headerCell('Số Mẻ/Lô', 2),
                      verticalDivider(),
                      headerCell('Số Máy', 2),
                      verticalDivider(),
                      headerCell('Người Thao Tác', 3),
                      verticalDivider(),
                      headerCell(khoiLuongMeHeader, 3),
                      verticalDivider(),
                      headerCell('Khối Lượng Đã Cân (kg)', 3),
                      verticalDivider(),
                      headerCell('Thời Gian Cân', 3),
                    ],
                  ),
                ),
              ),

              // --- KẾT THÚC HEADER ---
              // --- DATA ROWS (Giới hạn chiều cao để hiển thị 2 dòng) ---
              if (records.isEmpty)
                Container(
                  width: double.infinity,
                  height: 120, // Chiều cao cho 2 dòng
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      _languageService.translate('scan_to_display_info'),
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                )
              else
                Container(
                  constraints: const BoxConstraints(
                    maxHeight:
                        120, // Chiều cao tối đa cho 2 dòng (mỗi dòng ~60px)
                  ),
                  child: Builder(
                    builder: (context) {
                      // Sắp xếp: mã được scan lên đầu
                      final sortedRecords = List<WeighingRecord>.from(records);
                      if (scannedCode != null) {
                        sortedRecords.sort((a, b) {
                          if (a.maCode == scannedCode) return -1;
                          if (b.maCode == scannedCode) return 1;
                          return 0;
                        });
                      }

                      return ListView.builder(
                        shrinkWrap: true,
                        physics:
                            const AlwaysScrollableScrollPhysics(), // Cho phép scroll
                        itemCount: sortedRecords.length,
                        itemBuilder: (context, index) {
                          final record = sortedRecords[index];
                          // Chọn màu dựa trên trạng thái (isSuccess)
                          Color rowColor;
                          if (record.isSuccess == true) {
                            rowColor = const Color.fromARGB(
                              255,
                              182,
                              240,
                              188,
                            ); // Màu xanh lá nếu thành công
                          } else if (index > 0 && record.realQty == null) {
                            // Chưa hoàn tất mà đã scan mã mới (không phải dòng đầu tiên và chưa có realQty)
                            rowColor = const Color.fromARGB(
                              255,
                              255,
                              205,
                              210,
                            ); // Màu đỏ nhạt
                          } else {
                            rowColor =
                                index.isEven
                                    ? Colors.white
                                    : const Color.fromARGB(
                                      255,
                                      231,
                                      231,
                                      231,
                                    ); // Màu sọc vằn
                          }

                          return Container(
                            color: rowColor,
                            child: IntrinsicHeight(
                              child: Row(
                                children: [
                                  dataCell(
                                    record.tenPhoiKeo ?? 'N/A',
                                    3,
                                  ), // FormulaF
                                  dataCell(
                                    '${record.package}/${record.soLo}',
                                    2,
                                  ), // soLo/package
                                  dataCell(record.soMay, 2), // soMay
                                  dataCell(
                                    record.nguoiThaoTac ?? 'N/A',
                                    3,
                                  ), // UerName
                                  dataCell(
                                    record.qtys.toStringAsFixed(3),
                                    3,
                                  ), // Mẻ/Tồn
                                  // Khối Lượng Đã Cân:
                                  // - Nếu là mã được scan: hiển thị realQty hoặc '---'
                                  // - Nếu không phải mã scan: hiển thị weighedNhapAmount
                                  dataCell(
                                    record.maCode == scannedCode
                                        ? (record.realQty?.toStringAsFixed(3) ??
                                            '---')
                                        : (record.weighedNhapAmount
                                                ?.toStringAsFixed(3) ??
                                            '---'),
                                    3,
                                  ), // Đã Cân
                                  Builder(
                                    builder: (context) {
                                      String thoiGianText;
                                      // Nếu là mã được scan: không hiển thị mixTime từ backend
                                      // Chỉ hiển thị mixTime cho các mã khác
                                      if (record.maCode == scannedCode) {
                                        thoiGianText =
                                            '---'; // Mã đang cân chưa có thời gian
                                      } else if (record.mixTime == null) {
                                        thoiGianText =
                                            '---'; // chưa có thời gian cân '---'
                                      } else {
                                        final dt = record.mixTime!;
                                        // Định dạng: dd/MM/yyyy HH:mm
                                        final d = dt.day.toString().padLeft(
                                          2,
                                          '0',
                                        );
                                        final m = dt.month.toString().padLeft(
                                          2,
                                          '0',
                                        );
                                        final y = dt.year;
                                        final h = dt.hour.toString().padLeft(
                                          2,
                                          '0',
                                        );
                                        final min = dt.minute
                                            .toString()
                                            .padLeft(2, '0');
                                        thoiGianText = '$d/$m/$y  $h:$min';
                                      }
                                      return dataCell(thoiGianText, 3);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              // --- DÒNG TÓM TẮT ---
              if (activeOVNO != null)
                Container(
                  color: const Color.fromARGB(255, 247, 220, 72),
                  padding: const EdgeInsets.symmetric(
                    vertical: 8.0,
                    horizontal: 16.0,
                  ),
                  child: Row(
                    children: [
                      Text('Lệnh : $activeOVNO', style: summaryStyle),
                      const Spacer(flex: 1),
                      Text(
                        'Số mẻ đã cân: $xWeighed / $yTotal',
                        style: summaryStyle,
                      ),
                      const Spacer(flex: 1),

                      // Sửa 'Nhập'
                      Text(
                        'Nhập: ${totalNhap.toStringAsFixed(3)} / ${totalTargetQty.toStringAsFixed(3)} kg',
                        style: summaryStyle,
                      ),
                      const Spacer(flex: 1),

                      // Sửa 'Xuất'
                      Text(
                        'Xuất: ${totalXuat.toStringAsFixed(3)} / ${totalNhap.toStringAsFixed(3)} kg',
                        style: summaryStyle,
                      ),
                      const Spacer(flex: 1),

                      Expanded(
                        flex: 3,
                        child: Text(
                          'Memo: ${activeMemo ?? ''}',
                          style: summaryStyle,
                          textAlign: TextAlign.right,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
