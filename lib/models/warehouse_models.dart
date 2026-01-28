// Models cho Warehouse data

class WarehouseSummary {
  final String ovNO;
  final String tenPhoiKeo;
  final double tongNhap;
  final double tongXuat;
  final double tonKho;

  WarehouseSummary({
    required this.ovNO,
    required this.tenPhoiKeo,
    required this.tongNhap,
    required this.tongXuat,
    required this.tonKho,
  });

  factory WarehouseSummary.fromJson(Map<String, dynamic> json) {
    return WarehouseSummary(
      ovNO: json['ovNO'] as String,
      tenPhoiKeo: json['tenPhoiKeo'] as String,
      tongNhap: (json['tongNhap'] as num).toDouble(),
      tongXuat: (json['tongXuat'] as num).toDouble(),
      tonKho: (json['tonKho'] as num).toDouble(),
    );
  }
}

class WarehouseDetail {
  final String qrCode;
  final double qty;
  final double rkQty;
  final int package;
  final DateTime? mixTime;
  final double currentQty;
  final double lossQty;
  final String trangThaiText;

  WarehouseDetail({
    required this.qrCode,
    required this.qty,
    required this.rkQty,
    required this.package,
    this.mixTime,
    required this.currentQty,
    required this.lossQty,
    required this.trangThaiText,
  });

  factory WarehouseDetail.fromJson(Map<String, dynamic> json) {
    return WarehouseDetail(
      qrCode: json['QRCode'] as String,
      qty: (json['Qty'] as num? ?? 0.0).toDouble(),
      rkQty: (json['RKQty'] as num? ?? 0.0).toDouble(),
      package: json['Package'] as int,
      mixTime: json['MixTime'] != null ? DateTime.parse(json['MixTime'] as String) : null,
      currentQty: (json['CurrentQty'] as num? ?? 0.0).toDouble(),
      lossQty: (json['LossQty'] as num? ?? 0.0).toDouble(),
      trangThaiText: (json['trangThaiText'] as String? ?? 'Chưa cân'),
    );
  }
}
