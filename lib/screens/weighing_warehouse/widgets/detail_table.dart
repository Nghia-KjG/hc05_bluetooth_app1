import 'package:flutter/material.dart';

class DetailTable extends StatelessWidget {
  const DetailTable({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.2),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Title
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 149, 67, 160),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: const Center(
              child: Text(
                'BẢNG CHI TIẾT HỢP CHẤT - ĐƠN CHẤT',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),

          // Table Header
          Container(
            color: Colors.grey[200],
            child: IntrinsicHeight(
              child: Row(
                children: [
                  _buildHeaderCell('No.', flex: 1),
                  _buildHeaderCell('Mã Hợp Chất', flex: 2),
                  _buildHeaderCell('Mã Đơn Chất', flex: 2),
                  _buildHeaderCell('Tên Đơn Chất', flex: 4),
                  _buildHeaderCell('Định Mức\n(kg)', flex: 2),
                  _buildHeaderCell('Tỉ Lệ\n(%)', flex: 1),
                  _buildHeaderCell('Tổng Cân\n(kg)', flex: 2),
                  _buildHeaderCell('Độ Lệch\n(%)', flex: 1),
                  _buildHeaderCell('Người Cân', flex: 2),
                  _buildHeaderCell('Ngày Cân', flex: 3),
                ],
              ),
            ),
          ),

          // Table Body
          Expanded(
            child: ListView.builder(
              itemCount: 2,
              itemBuilder: (context, index) {
                return _buildRow(index + 1);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String text, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          border: Border(right: BorderSide(color: Colors.grey[300]!)),
        ),
        child: Center(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildRow(int index) {
    final bool isFirst = index == 1;
    final Color? bgColor = isFirst ? Colors.blue[50] : Colors.white;

    return IntrinsicHeight(
      child: Row(
        children: [
          _buildCell(index.toString(), flex: 1, bgColor: bgColor),
          _buildCell('WP01000045', flex: 2, bgColor: bgColor),
          _buildCell('W20100002$index', flex: 2, bgColor: bgColor),
          _buildCell(
            isFirst ? 'LOCTITE AQUACE ARF-40' : 'LOCTITE AQUACE W-08',
            flex: 4,
            bgColor: bgColor,
            align: TextAlign.left,
          ),
          _buildCell(isFirst ? '0.457' : '9.14', flex: 2, bgColor: bgColor),
          _buildCell(isFirst ? '4.762' : '95.23', flex: 1, bgColor: bgColor),
          _buildCell(isFirst ? '0.459' : '0.00', flex: 2, bgColor: bgColor),
          _buildCell(isFirst ? '0.5' : '0.0', flex: 1, bgColor: bgColor),
          _buildCell(isFirst ? '50589' : '', flex: 2, bgColor: bgColor),
          _buildCell(
            isFirst ? '2025-11-24\n16:18:00' : '',
            flex: 3,
            bgColor: bgColor,
          ),
        ],
      ),
    );
  }

  Widget _buildCell(
    String text, {
    int flex = 1,
    Color? bgColor,
    TextAlign align = TextAlign.center,
  }) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: bgColor,
          border: Border(
            right: BorderSide(color: Colors.grey[300]!),
            bottom: BorderSide(color: Colors.grey[300]!),
          ),
        ),
        child: Align(
          alignment:
              align == TextAlign.left ? Alignment.centerLeft : Alignment.center,
          child: Text(
            text,
            style: const TextStyle(fontSize: 13),
            textAlign: align,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}
