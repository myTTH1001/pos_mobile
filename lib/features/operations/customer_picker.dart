import 'package:flutter/material.dart';
import '../../core/network/dio_client.dart';
import '../../core/network/api_error.dart';

class CustomerPicker extends StatefulWidget {
  const CustomerPicker({super.key});
  @override
  State<CustomerPicker> createState() => _CustomerPickerState();
}

class _CustomerPickerState extends State<CustomerPicker> {
  final _search = TextEditingController();
  final _rows = <Map<String, dynamic>>[];
  String? _error;
  bool _busy = false, _more = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      if (reset) _rows.clear();
    });
    try {
      final data =
          (await DioClient.instance.dio.get(
                '/retail/customers',
                queryParameters: {
                  'search': _search.text.trim(),
                  'limit': 20,
                  'offset': _rows.length,
                },
              )).data
              as Map;
      if (mounted) {
        setState(() {
          _rows.addAll((data['items'] as List).cast<Map<String, dynamic>>());
          _more = _rows.length < (data['total'] as int);
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = apiError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Chọn khách hàng')),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _search,
            onSubmitted: (_) => _load(reset: true),
            decoration: InputDecoration(
              labelText: 'Tên / số điện thoại',
              suffixIcon: IconButton(
                onPressed: _busy ? null : () => _load(reset: true),
                icon: const Icon(Icons.search),
              ),
            ),
          ),
        ),
        if (_busy) const LinearProgressIndicator(),
        if (_error != null) Text(_error!),
        Expanded(
          child: ListView(
            children: [
              ListTile(
                title: const Text('Khách lẻ'),
                onTap: () => Navigator.pop(context, <String, dynamic>{
                  'id': null,
                  'full_name': 'Khách lẻ',
                }),
              ),
              for (final row in _rows)
                ListTile(
                  title: Text('${row['full_name']}'),
                  subtitle: Text('${row['phone']}'),
                  onTap: () => Navigator.pop(context, row),
                ),
              if (_more)
                TextButton(
                  onPressed: _busy ? null : _load,
                  child: const Text('Tải thêm'),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}
