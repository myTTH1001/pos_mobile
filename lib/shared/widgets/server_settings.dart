import 'package:flutter/material.dart';
import '../../core/network/dio_client.dart';
import '../../core/network/server_config.dart';
import '../../core/storage/secure_storage.dart';

class ServerSettings extends StatefulWidget {
  const ServerSettings({super.key, this.enabled = true});
  final bool enabled;

  @override
  State<ServerSettings> createState() => _ServerSettingsState();
}

class _ServerSettingsState extends State<ServerSettings> {
  Future<void> _edit() async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => const _ServerDialog(),
    );
    if (mounted && changed == true) setState(() {});
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TextButton.icon(
        onPressed: widget.enabled ? _edit : null,
        icon: const Icon(Icons.dns_outlined),
        label: const Text('Máy chủ kết nối'),
      ),
      Text(
        ServerConfig.baseUrl,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: 16),
    ],
  );
}

class _ServerDialog extends StatefulWidget {
  const _ServerDialog();
  @override
  State<_ServerDialog> createState() => _ServerDialogState();
}

class _ServerDialogState extends State<_ServerDialog> {
  final _controller = TextEditingController(text: ServerConfig.baseUrl);
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final url = ServerConfig.normalize(_controller.text);
      if (url != ServerConfig.baseUrl) {
        // Never send a session belonging to another server to the new host.
        await SecureStorage.instance.clearTokens();
        await ServerConfig.save(url);
        DioClient.instance.invalidateSession();
        DioClient.instance.dio.options.baseUrl = url;
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error is FormatException
              ? error.message.toString()
              : 'Không lưu được cấu hình. Vui lòng thử lại.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      title: const Text('Máy chủ kết nối'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Nhập địa chỉ backend. Điện thoại và máy tính cần cùng mạng Wi-Fi. Ví dụ: http://192.168.1.10:8000/api',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              enabled: !_saving,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: 'Địa chỉ API',
                errorText: _error,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '127.0.0.1 chỉ dùng khi đã cấu hình adb reverse qua USB. Đổi máy chủ sẽ xóa phiên đăng nhập cũ.',
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Đang lưu…' : 'Lưu'),
        ),
      ],
    ),
  );
}
