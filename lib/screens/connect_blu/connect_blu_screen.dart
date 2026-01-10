import 'package:flutter/material.dart';
import '../../models/bluetooth_device.dart';
import '../../services/bluetooth_service.dart';
import '../../services/notification_service.dart';
import '../../services/language_service.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final BluetoothService _bluetoothService = BluetoothService();
  final LanguageService _languageService = LanguageService();

  @override
  void initState() {
    super.initState();
    _bluetoothService.initialize();

    // Khi kết nối thành công
    _bluetoothService.onConnectedCallback = (device) async {
      if (!mounted) return;

      NotificationService().showToast(
        context: context,
        message: '${_languageService.translate('connected_success')} ${device.name}',
        type: ToastType.success,
      );
      await Future.delayed(const Duration(seconds: 4));
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/weighing_station');
    };
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _languageService,
      builder: (context, child) {
        return Scaffold(
          appBar: AppBar(
            title: Text(_languageService.translate('search_scale')),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: _languageService.translate('back_to_home'),
          onPressed: () {
            _bluetoothService.stopScan();
            Navigator.of(context).pop();
          },
        ),
        actions: [
          ValueListenableBuilder<bool>(
            valueListenable: _bluetoothService.isScanning,
            builder: (context, isScanning, child) {
              return isScanning
                  ? IconButton(icon: const Icon(Icons.stop), onPressed: _bluetoothService.stopScan)
                  : IconButton(icon: const Icon(Icons.search), onPressed: _bluetoothService.startScan);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          ValueListenableBuilder<String>(
            valueListenable: _bluetoothService.status,
            builder: (context, status, child) => Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(status),
            ),
          ),
          const Divider(),
          Expanded(
            child: ValueListenableBuilder<List<BluetoothDevice>>(
              valueListenable: _bluetoothService.scanResults,
              builder: (context, results, child) {
                if (results.isEmpty) {
                  return Center(child: Text(_languageService.translate('no_devices_found')));
                }
                return ListView.builder(
                  itemCount: results.length,
                  itemBuilder: (context, index) {
                    final device = results[index];
                    return ListTile(
                      leading: const Icon(Icons.bluetooth),
                      title: Text(device.name),
                      subtitle: Text(device.address),
                      trailing: Text('RSSI: ${device.rssi}'),
                      onTap: () => _bluetoothService.connectToDevice(device),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
        );
      },
    );
  }
}
