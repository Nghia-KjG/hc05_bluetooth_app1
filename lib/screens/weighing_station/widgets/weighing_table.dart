import 'package:flutter/material.dart';
import '../../../data/weighing_data.dart';
import '../../../services/language_service.dart';
import '../controllers/weighing_station_controller.dart'; // Giữ import này

class WeighingTable extends StatelessWidget {
  final List<WeighingRecord> records;
  final WeighingType weighingType;
  final WeighingType? originalWeighingType; // Loại cân gốc khi canLai
  final String? activeOVNO;
  final String? activeMemo;
  final String? scannedCode; // Mã được scan gần nhất
  final Function(String maCode)? onRecordTap; // Callback khi tap vào hàng

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
    this.originalWeighingType,
    this.activeOVNO,
    this.activeMemo,
    this.scannedCode,
    this.onRecordTap,
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
    final String khoiLuongMeHeader = _languageService.translate('batch_weight');

    // Header động cho cột Khối Lượng Đã Cân
    final String khoiLuongDaCanHeader =
        (weighingType == WeighingType.xuat || 
         (weighingType == WeighingType.canLai && originalWeighingType == WeighingType.xuat))
            ? _languageService.translate('export_weighed')
            : _languageService.translate('import_weighed');

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
                      headerCell(_languageService.translate('glue_name'), 3),
                      verticalDivider(),
                      headerCell(_languageService.translate('batch_number'), 2),
                      verticalDivider(),
                      headerCell(
                        _languageService.translate('machine_number'),
                        2,
                      ),
                      verticalDivider(),
                      headerCell(_languageService.translate('operator'), 3),
                      verticalDivider(),
                      headerCell(khoiLuongMeHeader, 3),
                      verticalDivider(),
                      headerCell(khoiLuongDaCanHeader, 3),
                      verticalDivider(),
                      headerCell(
                        _languageService.translate('weighing_time'),
                        3,
                      ),
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
                          // Chọn màu dựa trên mã được scan và trạng thái
                          Color rowColor;
                          if (record.maCode == scannedCode) {
                            // Nếu đã cân xong: màu xanh lá
                            if (record.isSuccess == true) {
                              rowColor = const Color.fromARGB(
                                255,
                                144,
                                238,
                                144,
                              ); // Light green
                            } else {
                              // Đang cân: màu vàng
                              rowColor = const Color.fromARGB(
                                255,
                                255,
                                255,
                                153,
                              );
                            }
                          } else {
                            // Các dòng khác: màu trắng
                            rowColor = Colors.white;
                          }

                          return GestureDetector(
                            // Chỉ cho phép tap vào hàng đã cân xong (màu xanh)
                            onTap:
                                (record.maCode == scannedCode &&
                                        record.isSuccess == true)
                                    ? () {
                                      onRecordTap?.call(record.maCode);
                                    }
                                    : null,
                            child: Container(
                              color: rowColor,
                              child: IntrinsicHeight(
                                child: Row(
                                  children: [
                                    dataCell(
                                      record.tenPhoiKeo ?? 'N/A',
                                      3,
                                    ), // FormulaF
                                    dataCell(
                                      '${record.package}/$yTotal',
                                      2,
                                    ), // soLo/package
                                    dataCell(record.soMay, 2), // soMay
                                    dataCell(
                                      record.nguoiThaoTac ?? 'N/A',
                                      3,
                                    ), // UerName
                                    dataCell(
                                      record.qtys.toStringAsFixed(2),
                                      3,
                                    ), // Mẻ/Tồn
                                    // Khối Lượng Đã Cân:
                                    // - Nếu cân nhập lại (canLai + originalWeighingType == nhap) VÀ thành công → hiển thị '---'
                                    // - Nếu là mã được scan (đang cân hoặc vừa cân xong):
                                    //   + Hiển thị realQty (khối lượng vừa cân)
                                    // - Nếu không phải mã scan (đã cân trước đó):
                                    //   + Cân nhập: hiển thị weighedNhapAmount
                                    //   + Cân xuất: hiển thị weighedXuatAmount
                                    dataCell(
                                      (weighingType == WeighingType.canLai && 
                                       originalWeighingType == WeighingType.nhap &&
                                       record.maCode == scannedCode &&
                                       record.isSuccess == true)
                                          ? '---' // Cân nhập lại thành công: không hiển thị
                                          : (record.maCode == scannedCode
                                              ? (record.realQty?.toStringAsFixed(2) ?? '---')
                                              : (weighingType == WeighingType.nhap || 
                                                 (weighingType == WeighingType.canLai && originalWeighingType == WeighingType.nhap))
                                                  ? (record.weighedNhapAmount?.toStringAsFixed(2) ?? '---')
                                                  : (record.weighedXuatAmount?.toStringAsFixed(2) ?? '---')),
                                      3,
                                    ), // Đã Cân
                                    Builder(
                                      builder: (context) {
                                        String thoiGianText;
                                        // Nếu là mã được scan VÀ chưa cân xong → hiển thị '---'
                                        // Nếu là mã được scan NHƯNG đã cân xong → hiển thị thời gian
                                        // Các mã khác → hiển thị thời gian hoặc '---'
                                        if (record.maCode == scannedCode &&
                                            record.isSuccess != true) {
                                          thoiGianText =
                                              '---'; // Mã đang cân chưa hoàn tất
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
                  color: const Color.fromARGB(255, 72, 183, 247),
                  padding: const EdgeInsets.symmetric(
                    vertical: 8.0,
                    horizontal: 16.0,
                  ),
                  child: Row(
                    children: [
                      Text(
                        '${_languageService.translate('order')} : $activeOVNO',
                        style: summaryStyle,
                      ),
                      const Spacer(flex: 1),
                      Text(
                        '${_languageService.translate('batches_weighed')}: $xWeighed / $yTotal',
                        style: summaryStyle,
                      ),
                      const Spacer(flex: 1),

                      // Import weight
                      Text(
                        '${_languageService.translate('import_weight')}: ${totalNhap.toStringAsFixed(2)} / ${totalTargetQty.toStringAsFixed(2)} kg',
                        style: summaryStyle,
                      ),
                      const Spacer(flex: 1),

                      // Export weight
                      Text(
                        '${_languageService.translate('export_weight')}: ${totalXuat.toStringAsFixed(2)} / ${totalNhap.toStringAsFixed(2)} kg',
                        style: summaryStyle,
                      ),
                      const Spacer(flex: 1),

                      Expanded(
                        flex: 3,
                        child: Text(
                          '${_languageService.translate('memo')}: ${activeMemo ?? ''}',
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
