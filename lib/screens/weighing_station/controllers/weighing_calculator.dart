// Weighing Calculator để tính toán Min/Max weight dựa trên percentage và weighing type

enum WeighingType { nhap, xuat, canLai }

/// Calculator để tính toán Min/Max weight dựa trên percentage và weighing type
class WeighingCalculator {
  double _selectedPercentage = 1.0;
  double _standardWeight = 0.0;
  double _minWeight = 0.0;
  double _maxWeight = 0.0;
  double _weighedNhapAmount = 0.0;
  double _weighedXuatAmount = 0.0;
  WeighingType _weighingType = WeighingType.nhap;
  WeighingType? _originalWeighingType; // Loại cân gốc khi cân lại

  double get selectedPercentage => _selectedPercentage;
  double get standardWeight => _standardWeight;
  double get minWeight => _minWeight;
  double get maxWeight => _maxWeight;
  double get weighedNhapAmount => _weighedNhapAmount;
  double get weighedXuatAmount => _weighedXuatAmount;
  double get remainingXuatAmount => _weighedNhapAmount - _weighedXuatAmount;

  /// Cập nhật percentage và tính lại min/max
  void updatePercentage(double newPercentage) {
    _selectedPercentage = newPercentage;
    _calculateMinMax();
  }

  /// Cập nhật standard weight và tính lại min/max
  void updateStandardWeight(double weight) {
    _standardWeight = weight;
    _calculateMinMax();
  }

  /// Cập nhật weighing type và tính lại min/max
  void updateWeighingType(WeighingType type) {
    _weighingType = type;
    _calculateMinMax();
  }

  /// Set original weighing type (cho cân lại)
  void setOriginalWeighingType(WeighingType? type) {
    _originalWeighingType = type;
    _calculateMinMax();
  }

  /// Cập nhật trọng lượng đã cân nhập/xuất
  void updateWeighedAmounts(double nhapAmount, double xuatAmount) {
    _weighedNhapAmount = nhapAmount;
    _weighedXuatAmount = xuatAmount;
    _calculateMinMax();
  }

  /// Reset về trạng thái ban đầu
  void reset() {
    _standardWeight = 0.0;
    _minWeight = 0.0;
    _maxWeight = 0.0;
    _originalWeighingType = null;
    _calculateMinMax();
  }

  /// Tính toán min/max dựa trên weighing type
  void _calculateMinMax() {
    if (_standardWeight == 0) {
      _minWeight = 0.0;
      _maxWeight = 0.0;
    } else if (_weighingType == WeighingType.xuat) {
      // CÂN XUẤT: Min/Max dựa trên trọng lượng còn có thể xuất
      final double remaining = _weighedNhapAmount - _weighedXuatAmount;
      if (remaining <= 0) {
        _minWeight = 0.0;
        _maxWeight = 0.0;
      } else {
        _minWeight = 0.001; // Tối thiểu 1g
        _maxWeight = remaining;
      }
    } else if (_weighingType == WeighingType.canLai) {
      // CÂN LẠI: Tính dựa trên loại cân gốc
      if (_originalWeighingType == WeighingType.xuat) {
        // Cân lại từ XUẤT: Tính giống cân xuất
        final double remaining = _weighedNhapAmount - _weighedXuatAmount;
        if (remaining <= 0) {
          _minWeight = 0.0;
          _maxWeight = 0.0;
        } else {
          _minWeight = 0.001;
          _maxWeight = remaining;
        }
      } else {
        // Cân lại từ NHẬP: Tính theo phần trăm
        final deviation =
            _selectedPercentage == 0.1
                ? 0.1
                : _standardWeight * (_selectedPercentage / 100.0);
        _minWeight = _standardWeight - deviation;
        _maxWeight = _standardWeight + deviation;
      }
    } else {
      // CÂN NHẬP: Tính theo phần trăm như cũ
      final deviation =
          _selectedPercentage == 0.1
              ? 0.1 // Cố định 100g (0.1kg)
              : _standardWeight * (_selectedPercentage / 100.0);
      _minWeight = _standardWeight - deviation;
      _maxWeight = _standardWeight + deviation;
    }
  }

  /// Kiểm tra trọng lượng có nằm trong khoảng min/max không
  bool isInRange(double weight) {
    return weight >= _minWeight && weight <= _maxWeight;
  }

  /// Restore state từ map
  void restoreFromMap(Map<String, dynamic> state) {
    _selectedPercentage = (state['selectedPercentage'] as num?)?.toDouble() ?? 1.0;
    _standardWeight = (state['standardWeight'] as num?)?.toDouble() ?? 0.0;
    _weighedNhapAmount = (state['weighedNhapAmount'] as num?)?.toDouble() ?? 0.0;
    _weighedXuatAmount = (state['weighedXuatAmount'] as num?)?.toDouble() ?? 0.0;
    
    final weighingTypeIndex = (state['selectedWeighingType'] as num?)?.toInt() ?? 0;
    _weighingType = WeighingType.values[weighingTypeIndex];
    
    _calculateMinMax();
  }

  /// Lưu state thành map
  Map<String, dynamic> toMap() {
    return {
      'selectedPercentage': _selectedPercentage,
      'standardWeight': _standardWeight,
      'weighedNhapAmount': _weighedNhapAmount,
      'weighedXuatAmount': _weighedXuatAmount,
      'selectedWeighingType': _weighingType.index,
    };
  }
}
