# SaaS POS Flutter — bản nâng cấp để kiểm tra

Bản này tiếp tục phát triển `pos_mobile-main(1).zip`, đối chiếu với backend/website `company-app-main (3)(1).zip`. **Chưa phải bản đã nghiệm thu hoặc sẵn sàng vận hành.** Backend, website và migrations được giữ nguyên từng byte.

Đọc `docs/BAN_GIAO.md` để xem tính năng, giới hạn và bằng chứng kiểm tra. `docs/FILES_CHANGED.md` liệt kê toàn bộ file thay đổi.

## Chạy trên Windows 11

1. Cài Flutter SDK có Dart **3.11.4 trở lên**, thêm thư mục `flutter\bin` vào PATH.
2. Cài Android Studio, Android SDK và cấu hình thiết bị Android thật hoặc emulator. Không cần npm.
3. Giải nén dự án vào thư mục riêng, ví dụ `C:\Projects\pos_mobile`. Giữ nguyên backend đang sử dụng.
4. Mở PowerShell trong thư mục chứa `pubspec.yaml`:

```powershell
flutter doctor
flutter doctor --android-licenses
flutter pub get
flutter devices
flutter analyze
flutter test
flutter run --dart-define=API_BASE_URL=https://TEN-MIEN-CUA-BAN/api
```

Ứng dụng mặc định giữ domain API có sẵn trong source gốc. Đổi `API_BASE_URL` khi dùng server khác; đừng thêm dấu `/` ở cuối. Cấu hình này được đóng vào bản build; đổi server cần chạy/build lại.

### Kết nối backend trên máy tính cùng mạng

- Điện thoại/tablet thật: dùng IP LAN của máy chạy backend, ví dụ `http://192.168.1.50:8000/api`.
- Android emulator: `http://10.0.2.2:8000/api`.
- Không dùng localhost trên điện thoại để gọi máy tính.
- Máy tính và thiết bị cùng mạng; server phải lắng nghe trên IP phù hợp, Windows Firewall cho phép cổng đó.
- HTTP chỉ được bật ở Android debug. Bản release yêu cầu HTTPS hợp lệ. Không tắt xác minh chứng chỉ.

```powershell
flutter run --dart-define=API_BASE_URL=http://192.168.1.50:8000/api
flutter build apk --debug --dart-define=API_BASE_URL=http://192.168.1.50:8000/api
```

APK debug khi build thành công: `build\app\outputs\flutter-apk\app-debug.apk`.

Cài thiết bị qua USB bằng `flutter install --debug` sau khi build đúng cấu hình, hoặc chép APK sang thiết bị và cho phép cài ứng dụng từ nguồn đó. Dùng tài khoản/môi trường thử nghiệm, không dùng dữ liệu vận hành để nghiệm thu thanh toán.

### Release và iOS

Source gốc vẫn dùng application ID mẫu và cấu hình ký debug cho release. **Chưa được cấu hình ký/phát hành production**. Cần thiết lập định danh, chứng chỉ và khóa ký riêng trước phát hành. iOS cần macOS/Xcode và chứng chỉ phù hợp; phiên làm việc này không build iOS.

## Luồng sử dụng

- Đăng nhập bằng email. Đăng ký mới dùng endpoint SaaS với tên doanh nghiệp, mã doanh nghiệp, email, mật khẩu 12–128 ký tự, tên cửa hàng.
- Trên điện thoại, mở menu bên trái để tới Báo cáo/Nhân viên và Vận hành & cài đặt. Trên tablet, dùng thanh điều hướng và biểu tượng cài đặt.
- Mở ca tại Vận hành & cài đặt trước thanh toán.
- Bán hàng: thêm hàng, chọn khách, nhập giảm giá/lý do nếu có quyền. Tạo đơn nháp hoặc Tiếp tục.
- Màn thanh toán lấy tổng/VAT/giảm giá từ server; chỉ xác nhận sau khi đã thu đủ tiền.
- Sau lỗi mạng, đối chiếu lại đúng đơn trước khi thử lại. Không tạo giỏ mới hoặc thu tiền lần hai chỉ vì app báo timeout.
- Đơn hàng → chi tiết → nút mở rộng để tiếp tục đơn nháp, sửa số lượng đơn chưa giảm giá, xem phiếu thu hoặc trả toàn bộ phần hàng còn được hoàn.
- Hoàn tiền là ghi nhận giao dịch đã trả thủ công; app không tự chuyển tiền ngân hàng.

## Máy quét

Ghép máy quét dạng bàn phím HID với Android bằng USB OTG hoặc Bluetooth. Cấu hình máy quét kết thúc bằng Enter. Chọn ô “Tìm tên / quét mã rồi Enter”, quét barcode/SKU của sản phẩm trong cửa hàng. App gọi `/products/scan` riêng cho từng mã và xếp hàng các lần quét. Quét cùng mã hai lần phải tăng hai đơn vị. Việc bắt phím toàn ứng dụng khi ô tìm kiếm không có focus chưa được triển khai. Không có quét camera trong bản này.

## Máy in

Giữ dịch vụ ESC/POS Bluetooth hiện có; chọn 58/80mm theo cài đặt server và lấy tên cửa hàng từ server. Ghép máy in trong cài đặt Bluetooth của Android, cho quyền thiết bị lân cận khi hệ điều hành yêu cầu, chọn máy in trong app và thử bằng đơn thử đã trả tiền. Kiểm tra tên cửa hàng, khổ giấy, nội dung dài, dấu tiếng Việt, mất kết nối và in lại. In lại không được tạo đơn/thanh toán mới.

Chưa xác minh plugin tự xin quyền runtime trên Android mới; chưa xác nhận USB/LAN/iOS hoặc bất kỳ model máy in nào. Phần in đang chuyển một số nội dung tiếng Việt về không dấu; không cam kết in Unicode đầy đủ.