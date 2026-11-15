import 'package:dio/dio.dart';

String apiError(Object error) {
  if (error is! DioException) {
    return 'Không thể hoàn tất thao tác. Vui lòng thử lại.';
  }
  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return 'Máy chủ không phản hồi kịp. Kiểm tra kết nối và trạng thái thao tác trước khi thử lại.';
    case DioExceptionType.connectionError:
      return 'Không kết nối được máy chủ. Kiểm tra Máy chủ kết nối, Wi-Fi, backend và tường lửa trên máy tính.';
    case DioExceptionType.badCertificate:
      return 'Chứng chỉ HTTPS của máy chủ không hợp lệ.';
    case DioExceptionType.cancel:
      return 'Yêu cầu đã bị hủy. Kiểm tra kết quả trước khi thử lại.';
    default:
      break;
  }
  final status = error.response?.statusCode;
  if (status == 404 || status == 405) {
    return 'Không tìm thấy API phù hợp. Kiểm tra địa chỉ máy chủ và tiền tố /api.';
  }
  if (status != null && status >= 500) {
    return 'Máy chủ đang lỗi (HTTP $status). Cần kiểm tra log backend và database.';
  }
  final data = error.response?.data;
  final detail = data is Map ? data['detail'] : null;
  if (detail is String) return detail;
  if (detail is List) {
    const labels = {
      'tenant_name': 'Tên doanh nghiệp', 'slug': 'Mã doanh nghiệp',
      'email': 'Email', 'username': 'Email đăng nhập',
      'password': 'Mật khẩu (12–128 ký tự khi đăng ký)',
      'store_name': 'Tên cửa hàng', 'vertical': 'Loại hình kinh doanh',
    };
    final fields = <String>{};
    for (final item in detail) {
      if (item is Map && item['loc'] is List) {
        final loc = item['loc'] as List;
        if (loc.isNotEmpty && labels.containsKey(loc.last)) {
          fields.add(labels[loc.last]!);
        }
      }
    }
    return fields.isEmpty ? 'Thông tin chưa hợp lệ. Vui lòng kiểm tra các ô nhập.'
        : 'Vui lòng kiểm tra: ${fields.join(', ')}.';
  }
  if (status == 401) return 'Sai email hoặc mật khẩu, hoặc phiên đã hết hạn.';
  if (status == 403) return 'Bạn không có quyền thực hiện thao tác này.';
  if (status == 402) return 'Gói dịch vụ đã hết hạn. Vui lòng kiểm tra cài đặt cửa hàng.';
  return 'Không xác định được kết quả từ máy chủ. Kiểm tra kết nối và trạng thái chứng từ trước khi thử lại.';
}
