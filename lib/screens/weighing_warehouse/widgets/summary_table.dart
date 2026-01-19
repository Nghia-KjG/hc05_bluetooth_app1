import 'package:flutter/material.dart';

class SummaryTable extends StatelessWidget {
  const SummaryTable({super.key});

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
                'BẢNG TỔNG HÓA CHẤT PHA KEO HÀNG NGÀY',
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
                  _buildHeaderCell('Mã Hóa Chất', flex: 2),
                  _buildHeaderCell('Tên Hóa Chất', flex: 4),
                  _buildHeaderCell('Định Mức\n(kg)', flex: 2),
                  _buildHeaderCell('Tổng Cân\n(kg)', flex: 2),
                  _buildHeaderCell('Độ lệch\n(%)', flex: 2),
                ],
              ),
            ),
          ),

          // Table Body
          Expanded(
            child: ListView.builder(
              itemCount: 7,
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
    final bool isHighlighted = index == 5 || index == 6;
    final Color? bgColor = isHighlighted ? Colors.blue[50] : Colors.white;

    return IntrinsicHeight(
      child: Row(
        children: [
          _buildCell(index.toString(), flex: 1, bgColor: bgColor),
          _buildCell('W20100004$index', flex: 2, bgColor: bgColor),
          _buildCell(
            index == 5
                ? 'W - 08 + 5% ARF - 40 (A)'
                : index == 6
                ? '233CPA+10%224-2 (A)'
                : 'Sample Chemical $index',
            flex: 4,
            bgColor: bgColor,
            align: TextAlign.left,
          ),
          _buildCell(
            index == 5
                ? '9.600'
                : index == 6
                ? '0.248'
                : (index * 1.5).toStringAsFixed(3),
            flex: 2,
            bgColor: bgColor,
          ),
          _buildCell(
            isHighlighted ? (index * 0.1).toStringAsFixed(3) : '0.000',
            flex: 2,
            bgColor: bgColor,
          ),
          _buildCell(
            isHighlighted ? (index * 0.5).toStringAsFixed(3) : '0.000',
            flex: 2,
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
        child: Text(
          text,
          style: const TextStyle(fontSize: 13),
          textAlign: align,
        ),
      ),
    );
  }
}
