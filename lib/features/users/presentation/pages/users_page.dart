import 'package:flutter/material.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/api_error.dart';

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});
  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  final _dio = DioClient.instance.dio;
  List<Map<String, dynamic>> _users = [];
  Map<String, dynamic>? _profile;
  bool _busy = false;
  String? _error;
  bool get _manageRoles =>
      (_profile?['permissions'] as List? ?? []).contains('manage_roles');
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final profile = (await _dio.get('/auth/me')).data as Map<String, dynamic>;
      final users = ((await _dio.get('/users/')).data as List)
          .cast<Map<String, dynamic>>();
      if (mounted) {
        setState(() {
          _profile = profile;
          _users = users;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = apiError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _create() async {
    final email = TextEditingController(), password = TextEditingController();
    final form = GlobalKey<FormState>();
    String role = 'cashier';
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, change) => AlertDialog(
          title: const Text('Thêm nhân viên'),
          content: SingleChildScrollView(
            child: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email'),
                    validator: (value) =>
                        value == null ||
                            !RegExp(
                              r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                            ).hasMatch(value.trim())
                        ? 'Email chưa hợp lệ'
                        : null,
                  ),
                  TextFormField(
                    controller: password,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Mật khẩu (12–128 ký tự)',
                    ),
                    validator: (value) =>
                        value == null || value.length < 12 || value.length > 128
                        ? 'Cần 12–128 ký tự'
                        : null,
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: role,
                    items: [
                      const DropdownMenuItem(
                        value: 'cashier',
                        child: Text('Thu ngân'),
                      ),
                      const DropdownMenuItem(
                        value: 'staff',
                        child: Text('Nhân viên'),
                      ),
                      if (_manageRoles)
                        const DropdownMenuItem(
                          value: 'manager',
                          child: Text('Quản lý'),
                        ),
                    ],
                    onChanged: (value) => change(() => role = value!),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Quay lại'),
            ),
            FilledButton(
              onPressed: () {
                if (form.currentState!.validate()) {
                  Navigator.pop(ctx, {
                    'email': email.text.trim().toLowerCase(),
                    'password': password.text,
                    'role_name': role,
                  });
                }
              },
              child: const Text('Tạo tài khoản'),
            ),
          ],
        ),
      ),
    );
    if (payload == null || !mounted) return;
    await _mutate(() async {
      await _dio.post('/users/', data: payload);
    });
  }

  Future<void> _mutate(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      await _load();
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = apiError(error);
          _busy = false;
        });
      }
    }
  }

  Future<void> _toggle(Map<String, dynamic> user) async {
    final active = user['is_active'] == true;
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(active ? 'Khóa nhân viên?' : 'Mở khóa nhân viên?'),
        content: Text('${user['email']}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Quay lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
    if (yes == true && mounted) {
      {
        await _mutate(() async {
          await _dio.put(
            '/users/${user['id']}/status',
            data: {'is_active': !active},
          );
        });
      }
    }
  }

  Future<void> _role(Map<String, dynamic> user) async {
    final role = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Thay vai trò'),
        children: [
          for (final item in [
            ('cashier', 'Thu ngân'),
            ('staff', 'Nhân viên'),
            ('manager', 'Quản lý'),
          ])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, item.$1),
              child: Text(item.$2),
            ),
        ],
      ),
    );
    if (role != null && mounted) {
      await _mutate(() async {
        await _dio.put(
          '/roles/assignments/${user['id']}',
          data: {'role_name': role},
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Nhân viên'),
      actions: [
        IconButton(
          onPressed: _busy ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
        IconButton(
          tooltip: 'Thêm nhân viên',
          onPressed: _busy ? null : _create,
          icon: const Icon(Icons.person_add_outlined),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_busy) const LinearProgressIndicator(),
        if (_error != null)
          Text(_error!, style: const TextStyle(color: Colors.red)),
        for (final user in _users)
          Card(
            child: ListTile(
              title: Text('${user['email']}'),
              subtitle: Text(
                '${user['role'] ?? 'Chưa có vai trò'} • ${user['is_active'] == true ? 'Đang hoạt động' : 'Đã khóa'}',
              ),
              trailing:
                  user['role'] == 'owner' || user['id'] == _profile?['user_id']
                  ? const Icon(Icons.verified_user_outlined)
                  : PopupMenuButton<String>(
                      enabled: !_busy,
                      onSelected: (value) =>
                          value == 'status' ? _toggle(user) : _role(user),
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: 'status',
                          child: Text('Khóa / mở khóa'),
                        ),
                        if (_manageRoles)
                          const PopupMenuItem(
                            value: 'role',
                            child: Text('Thay vai trò'),
                          ),
                      ],
                    ),
            ),
          ),
        if (!_busy && _users.isEmpty && _error == null)
          const Center(child: Text('Chưa có nhân viên')),
      ],
    ),
  );
}
