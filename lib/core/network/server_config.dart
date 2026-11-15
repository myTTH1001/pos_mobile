import 'package:shared_preferences/shared_preferences.dart';
import '../constants/api_constants.dart';

class ServerConfig {
  static const _key = 'api_base_url';
  static String baseUrl = ApiConstants.baseUrl;

  static String normalize(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null || !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty || uri.userInfo.isNotEmpty ||
        uri.hasQuery || uri.hasFragment || uri.port == 0) {
      throw const FormatException('Nhập URL http:// hoặc https:// hợp lệ.');
    }
    if (['0.0.0.0', '::'].contains(uri.host)) {
      throw const FormatException('Dùng IP máy tính trong mạng LAN, không dùng 0.0.0.0.');
    }
    var path = uri.path.replaceAll(RegExp(r'/+$'), '');
    if (!path.endsWith('/api')) path = '$path/api';
    return uri.replace(path: path).toString();
  }

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_key);
      baseUrl = normalize(saved ?? ApiConstants.baseUrl);
    } catch (_) {
      baseUrl = ApiConstants.baseUrl;
    }
  }

  static Future<void> save(String value) async {
    final normalized = normalize(value);
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(_key, normalized)) {
      throw StateError('Không lưu được địa chỉ máy chủ.');
    }
    baseUrl = normalized;
  }
}
