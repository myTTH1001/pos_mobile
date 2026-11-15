import 'package:dio/dio.dart';

String apiError(Object error) {
  if (error is! DioException) {
    return error.toString().replaceFirst('Exception: ', '');
  }
  final data = error.response?.data;
  final detail = data is Map ? data['detail'] : null;
  if (detail is String) return detail;
  if (detail is List) {
    return 'Thông tin chưa hợp lệ. Vui lòng kiểm tra các ô nhập.';
  }
  if (error.response?.statusCode == 403) {
    return 'Bạn không có quyền thực hiện thao tác này.';
  }
  if (error.response?.statusCode == 402) {
    return 'Gói dịch vụ đã hết hạn. Vui lòng kiểm tra cài đặt cửa hàng.';
  }
  return 'Không xác định được kết quả từ máy chủ. Kiểm tra kết nối và trạng thái chứng từ trước khi thử lại.';
}
