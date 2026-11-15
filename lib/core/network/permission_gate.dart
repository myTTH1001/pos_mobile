import 'package:flutter/material.dart';
import 'dio_client.dart';
import 'api_error.dart';

class PermissionGate extends StatefulWidget {
  const PermissionGate({
    super.key,
    required this.permission,
    required this.child,
  });
  final String permission;
  final Widget child;
  @override
  State<PermissionGate> createState() => _PermissionGateState();
}

class _PermissionGateState extends State<PermissionGate> {
  late Future<bool> _allowed;
  Future<bool> _check() async {
    final data = (await DioClient.instance.dio.get('/auth/me')).data as Map;
    return (data['permissions'] as List).contains(widget.permission);
  }

  @override
  void initState() {
    super.initState();
    _allowed = _check();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
    future: _allowed,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.data == true) return widget.child;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 40),
              Text(
                snapshot.hasError
                    ? apiError(snapshot.error!)
                    : 'Bạn chưa được cấp quyền cho màn hình này.',
                textAlign: TextAlign.center,
              ),
              TextButton(
                onPressed: () => setState(() => _allowed = _check()),
                child: const Text('Kiểm tra lại'),
              ),
            ],
          ),
        ),
      );
    },
  );
}
