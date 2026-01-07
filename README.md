## Weighing Station App (HC-05 Bluetooth)

Ứng dụng Flutter phục vụ trạm cân keo bán thành phẩm. Kết nối tới cân công nghiệp qua Bluetooth Classic (HC-05), đọc trọng lượng theo thời gian thực, phát hiện ổn định, tự động hoàn tất, hỗ trợ làm việc offline và đồng bộ dữ liệu khi có mạng.

Phiên bản: 1.0.0

---

### Tính năng chính

- Kết nối Bluetooth HC-05: Quét thiết bị, kết nối/Ngắt kết nối, hiển thị trạng thái.
- Đọc trọng lượng: Parse dữ liệu thô nhận từ cân, cập nhật theo thời gian thực.
- Ổn định trọng lượng: Theo dõi mẫu cân liên tục để xác định khi cân ổn định (WeightStabilityMonitor).
- Tự động hoàn tất: Khi đủ điều kiện (trong khoảng min–max, ổn định), tự chốt phiếu theo cấu hình.
- Offline-first: Lưu lịch sử cân, công việc vào SQLite; đồng bộ lên server khi mạng sẵn sàng.
- Đồng bộ nền: Tự động sync Persons/Devices/Work và hàng đợi HistoryQueue.
- Màn hình chức năng: Đăng nhập, Trạm cân, Lịch sử, Dashboard, Dữ liệu chờ, Cài đặt.
- Thông báo/Âm thanh: Toast thân thiện, âm báo xác nhận/lỗi (Android).

---

### Kiến trúc & thành phần chính

- Services
	- `BluetoothService`: Giao tiếp qua MethodChannel/EventChannel Android, quản lý scan/kết nối/nhận dữ liệu.
	- `SyncService`: Đồng bộ dữ liệu hai chiều, quản lý hàng đợi offline (`HistoryQueue`).
	- `DatabaseHelper`: SQLite (sqflite) cho cache offline (VmlWork, VmlWorkS, VmlPersion, …).
	- `SettingsService`: Cấu hình người dùng (auto-complete, tỉ lệ dung sai…).
	- `ServerStatusService`: Theo dõi trạng thái API nền.
	- `WeightStabilityMonitor`: Xác định “ổn định” dựa trên chuỗi mẫu trọng lượng.
	- `NotificationService`/`AudioService`: Thông báo và âm hiệu.
- State management: `ChangeNotifier`/`ValueNotifier` đơn giản, controller chuyên trách màn hình.
- Màn hình trạm cân: `WeighingStationController` điều phối luồng scan mã → tải dữ liệu → tính min/max → nhận trọng lượng → hoàn tất.

---

### Yêu cầu hệ thống

- Flutter stable mới (khuyến nghị Flutter 3.24+). Dự án dùng Dart `^3.7.2` theo pubspec.
- Thiết bị Android có Bluetooth Classic (HC-05). iOS/macOS chưa có triển khai native tương ứng.
- Backend API nội bộ (cấu hình qua `.env`).

---

### Cấu hình môi trường

1) Tạo file `.env` ở thư mục gốc dự án với biến sau:

```
API_BASE_URL=http://192.168.**.***:3636

```

2) Đảm bảo đường dẫn `.env` đã được khai báo trong `pubspec.yaml` dưới `flutter/assets` (đã có sẵn).

---

### Cài đặt & chạy

```bash
# Cài dependency
flutter pub get

# Chạy app trên thiết bị Android/giả lập
flutter run -d android

# Build APK phát hành
flutter build apk --release
```

Lần đầu chạy trên Android 12+ có thể cần cấp quyền Bluetooth (SCAN/CONNECT) và Location theo yêu cầu hệ điều hành.

---

### Luồng sử dụng nhanh

1) Đăng nhập bằng số thẻ và chọn nhà máy.
2) Vào “Trạm cân”. Nếu chưa kết nối cân, ứng dụng sẽ hướng dẫn sang trang kết nối.
3) Quét/nhập mã lệnh công việc → ứng dụng tải thông tin, tính trọng lượng chuẩn và khoảng min–max.
4) Khi cân ổn định và nằm trong khoảng cho phép, nhấn “Hoàn tất” hoặc hệ thống tự hoàn tất (nếu bật auto-complete).
5) Khi offline, dữ liệu sẽ lưu vào hàng đợi và tự đồng bộ khi có mạng.

---

### Cấu trúc thư mục quan trọng

- `lib/services/` – Bluetooth, Sync, DB, Settings, Notification, Audio, ServerStatus, WeightStability…
- `lib/screens/weighing_station/` – UI trạm cân, widgets, controller `weighing_station_controller.dart`.
- `android/` – Native code (Kotlin) cho Bluetooth Classic qua MethodChannel.
- `lib/assets/` – Hình ảnh giao diện.

---

### Ghi chú nền tảng

- Android: đã triển khai Bluetooth Classic (HC-05) qua kênh nền tảng.
- iOS/macOS/Linux/Web: chưa hỗ trợ giao tiếp cân HC-05. Ứng dụng chủ yếu nhắm Android.

---

### Troubleshooting

- Không thấy thiết bị cân khi quét:
	- Bật Bluetooth, cấp quyền (Android 12+ cần BLUETOOTH_SCAN/CONNECT), bật GPS nếu yêu cầu.
	- Kiểm tra cân HC-05 ở trạng thái discoverable.
- Đã kết nối nhưng không nhận số cân:
	- Chuỗi dữ liệu phải chứa số dạng `123.45`. Ứng dụng parse bằng RegExp để lấy số đầu tiên.
	- Kiểm tra tốc độ gửi của cân và khoảng throttle trong `BluetoothService`.
- API không phản hồi:
	- Kiểm tra `API_BASE_URL` trong `.env`. Ứng dụng sẽ fallback offline nếu không truy cập được.
- Tự động hoàn tất không kích hoạt:
	- Đảm bảo bật cấu hình auto-complete trong phần Cài đặt và trọng lượng đang trong khoảng min–max, đủ số mẫu ổn định.

---

### Phát triển

- Thư viện chính: `flutter_dotenv`, `sqflite`, `path_provider`, `connectivity_plus`, `shared_preferences`, `permission_handler`, `provider` (đã khai báo trong `pubspec.yaml`).
- Đóng góp: vui lòng tạo nhánh/PR với mô tả rõ ràng. Tránh thay đổi native Android nếu không cần thiết.

---

### Miễn trừ trách nhiệm

Mã nguồn chỉ dùng nội bộ cho hệ thống trạm cân. Vui lòng không public endpoint hoặc thông tin nội bộ trong báo lỗi/log khi build phát hành.
