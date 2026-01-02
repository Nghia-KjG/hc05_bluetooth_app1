import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/bluetooth_device.dart';

class BluetoothService {
  static final BluetoothService _instance = BluetoothService._internal();
  factory BluetoothService() => _instance;
  BluetoothService._internal();

  static const _methodChannel = MethodChannel('com.hc.bluetooth.method_channel');
  static const _eventChannel = EventChannel('com.hc.bluetooth.event_channel');
  StreamSubscription? _eventSubscription;

  final ValueNotifier<List<BluetoothDevice>> scanResults = ValueNotifier([]);
  final ValueNotifier<BluetoothDevice?> connectedDevice = ValueNotifier(null);
  final ValueNotifier<String> status = ValueNotifier('Sẵn sàng');
  final ValueNotifier<double> currentWeight = ValueNotifier(0.0);
  final ValueNotifier<bool> isScanning = ValueNotifier(false);
  
  void setSimulatedWeight(double weight) {
    currentWeight.value = weight;
  }

  BluetoothDevice? lastConnectedDevice;
  final Map<String, BluetoothDevice> _scannedDevices = {};

  bool _isThrottling = false;
  final int _throttleMilliseconds = 100;

  String _currentConnectionStatus = '';

  /// Callback cho sự kiện kết nối thành công
  void Function(BluetoothDevice device)? onConnectedCallback;

  void initialize() {
    if (_eventSubscription != null) return;
    _eventSubscription =
        _eventChannel.receiveBroadcastStream().listen(_onEvent, onError: _onError);
  }

  void _onEvent(dynamic event) {
    final String eventType = event['type'];

    switch (eventType) {
      case 'scanResult':
        final device = BluetoothDevice(
          name: event['name'] ?? 'N/A',
          address: event['address'],
          rssi: int.tryParse(event['rssi'] ?? '0') ?? 0,
        );
        _scannedDevices[device.address] = device;
        scanResults.value = _scannedDevices.values.toList();
        break;

      case 'status':
        status.value = event['message'];
        final newStatus = event['status'];

        if (newStatus == _currentConnectionStatus) return;
        _currentConnectionStatus = newStatus;

        if (newStatus == 'connected') {
          final device = _scannedDevices[event['address']];
          connectedDevice.value = device;
          lastConnectedDevice = device;

          // Gọi callback thông báo cho UI
          if (onConnectedCallback != null && device != null) {
            onConnectedCallback!(device);
          }
        } else if (newStatus == 'disconnected') {
          // Chờ 10 giây để tránh ngắt giả
          Future.delayed(const Duration(seconds: 10), () {
            // Nếu hiện tại kết nối tới một thiết bị khác, bỏ qua
            if (connectedDevice.value?.address != event['address']) return;
            // Thực sự ngắt kết nối: xóa trạng thái kết nối
            if (kDebugMode) print('ℹ️ Mất kết nối với cân ${event['address']}');
            connectedDevice.value = null;
            _currentConnectionStatus = 'disconnected';
          });
        } else if (newStatus == 'error') {
          connectedDevice.value = null;
          _currentConnectionStatus = 'error';
        } else if (newStatus == 'scanFinished') {
          isScanning.value = false;
        }
        break;

      case 'dataReceived':
        if (_isThrottling) return;
        _isThrottling = true;
        Future.delayed(Duration(milliseconds: _throttleMilliseconds), () {
          _isThrottling = false;
        });

        final String rawDataString = utf8.decode(event['data']).trim();
        final RegExp numberRegex = RegExp(r'(\d+\.?\d*)');
        final Match? match = numberRegex.firstMatch(rawDataString);

        if (match != null) {
          final String numberString = match.group(1)!;
          final double? weight = double.tryParse(numberString);
          if (weight != null) {
            currentWeight.value = weight;
          } else if (kDebugMode) {
            print('❌ Không parse được số: "$numberString"');
          }
        } else if (kDebugMode) {
          print('⚠️ Không tìm thấy số trong chuỗi nhận được: "$rawDataString"');
        }
        break;
    }
  }

  void _onError(dynamic error) {
    status.value = 'Lỗi nhận sự kiện: ${error.message}';
  }

  Future<void> startScan() async {
    isScanning.value = true;
    status.value = 'Đang quét...';
    _scannedDevices.clear();
    scanResults.value = [];
    await _methodChannel.invokeMethod('startScan');
  }

  Future<void> stopScan() async {
    isScanning.value = false;
    status.value = 'Đã dừng quét.';
    await _methodChannel.invokeMethod('stopScan');
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    status.value = 'Đang kết nối tới ${device.name}...';
    await _methodChannel.invokeMethod('connect', {'address': device.address});
  }

  Future<void> disconnect() async {
    if (connectedDevice.value != null) {
      await _methodChannel.invokeMethod('disconnect', {
        'address': connectedDevice.value!.address,
      });
      connectedDevice.value = null;
      status.value = 'Đã ngắt kết nối.';
      _currentConnectionStatus = 'disconnected';
    }
  }

  Future<void> sendData(String textData) async {
    if (connectedDevice.value == null) return;
    final Uint8List byteData = utf8.encode('$textData\n');
    await _methodChannel.invokeMethod('sendData', {
      'address': connectedDevice.value!.address,
      'data': byteData,
    });
  }

  void dispose() {
    _eventSubscription?.cancel();
    _eventSubscription = null;
  }
}
