import 'package:flutter/material.dart';
import '../../core/network/dio_client.dart';
import '../../core/network/api_error.dart';
import '../../core/utils/request_key.dart';

class OperationsPage extends StatefulWidget {
  const OperationsPage({super.key});
  @override
  State<OperationsPage> createState() => _OperationsPageState();
}

class _OperationsPageState extends State<OperationsPage> {
  final _dio = DioClient.instance.dio;
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _shift;
  String? _error;
  bool _busy = true;
  @override
  void initState() {
    super.initState();
    _load();
  }

  bool _can(String permission) =>
      (_profile?['permissions'] as List? ?? []).contains(permission);
  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final profile = (await _dio.get('/auth/me')).data as Map<String, dynamic>;
      Map<String, dynamic>? shift;
      if ((profile['permissions'] as List).contains('shift:view')) {
        shift =
            (await _dio.get('/shifts/current')).data['shift']
                as Map<String, dynamic>?;
      }
      if (mounted) {
        setState(() {
          _profile = profile;
          _shift = shift;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = apiError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _shiftAction(bool close) async {
    final amount = TextEditingController();
    final note = TextEditingController();
    final form = GlobalKey<FormState>();
    final values = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(close ? 'Đóng ca — kiểm đếm tiền' : 'Mở ca bán hàng'),
        content: SingleChildScrollView(
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: amount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: close
                        ? 'Tiền mặt thực đếm (đ)'
                        : 'Tiền mặt đầu ca (đ)',
                  ),
                  validator: (value) {
                    final number = double.tryParse(value ?? '');
                    return number == null || !number.isFinite || number < 0
                        ? 'Nhập số tiền hợp lệ, không dùng dấu phân cách'
                        : null;
                  },
                ),
                TextField(
                  controller: note,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    labelText: 'Ghi chú / lý do chênh lệch',
                  ),
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
                  close ? 'counted_cash' : 'opening_cash': amount.text,
                  'note': note.text.trim(),
                  'idempotency_key': requestKey(),
                });
              }
            },
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
    if (values == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await _dio.post(
        close ? '/shifts/${_shift!['id']}/close' : '/shifts/open',
        data: values,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã cập nhật ca bán hàng')),
        );
      }
    } catch (error) {
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Cần kiểm tra trạng thái ca'),
            content: Text(apiError(error)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Tải lại trạng thái'),
              ),
            ],
          ),
        );
      }
    }
    if (mounted) await _load();
  }

  void _open(
    String title,
    String path, {
    String? collection,
    String? detailPrefix,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => RecordsPage(
          title: title,
          path: path,
          collection: collection,
          detailPrefix: detailPrefix,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Vận hành & cài đặt'),
      actions: [
        IconButton(
          onPressed: _busy ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: _busy
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_error != null)
                Text(_error!, style: const TextStyle(color: Colors.red)),
              if (_profile != null)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.storefront),
                    title: Text('${_profile!['store_name']}'),
                    subtitle: Text('${_profile!['email']}'),
                  ),
                ),
              if (_can('shift:view'))
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _shift == null
                              ? 'Chưa mở ca'
                              : 'Ca #${_shift!['id']} đang mở',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (_shift != null) ...[
                          Text('Đầu ca: ${_shift!['opening_cash']} đ'),
                          Text(
                            'Tiền mặt dự kiến: ${(_shift!['summary'] as Map?)?['expected_cash'] ?? '—'} đ',
                          ),
                          TextButton(
                            onPressed: () => _open(
                              'Chi tiết ca',
                              '/shifts/${_shift!['id']}',
                            ),
                            child: const Text('Xem số liệu và chứng từ'),
                          ),
                        ],
                        if (_shift == null && _can('shift:open'))
                          FilledButton(
                            onPressed: () => _shiftAction(false),
                            child: const Text('Mở ca'),
                          ),
                        if (_shift != null && _can('shift:close'))
                          OutlinedButton(
                            onPressed: () => _shiftAction(true),
                            child: const Text('Đóng ca'),
                          ),
                      ],
                    ),
                  ),
                ),
              if (_can('shift:view'))
                ListTile(
                  leading: const Icon(Icons.history),
                  title: const Text('Lịch sử ca bán hàng'),
                  onTap: () => _open(
                    'Ca bán hàng',
                    '/shifts',
                    collection: 'data',
                    detailPrefix: '/shifts',
                  ),
                ),
              if (_can('order:view'))
                ListTile(
                  leading: const Icon(Icons.people_outline),
                  title: const Text('Khách hàng & công nợ'),
                  onTap: () => _open(
                    'Khách hàng',
                    '/retail/customers',
                    collection: 'items',
                    detailPrefix: '/retail/customers',
                  ),
                ),
              if (_can('invoice:view'))
                ListTile(
                  leading: const Icon(Icons.assignment_return_outlined),
                  title: const Text('Lịch sử trả hàng & hoàn tiền'),
                  onTap: () => _open(
                    'Trả hàng & hoàn tiền',
                    '/refunds',
                    collection: 'data',
                  ),
                ),
              ListTile(
                leading: const Icon(Icons.receipt_long),
                title: const Text('Thông tin cửa hàng & VAT'),
                onTap: () =>
                    _open('Cửa hàng & VAT', '/retail/receipt-settings'),
              ),
              if (_can('manage_settings'))
                ListTile(
                  leading: const Icon(Icons.card_membership),
                  title: const Text('Gói dịch vụ'),
                  onTap: () => _open('Gói dịch vụ', '/billing/subscription'),
                ),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Phiếu thu công nợ nằm trong chi tiết đơn hàng. Số tiền bán hàng và phiếu thu được server tổng hợp riêng.',
                ),
              ),
            ],
          ),
  );
}

class RecordsPage extends StatefulWidget {
  const RecordsPage({
    super.key,
    required this.title,
    required this.path,
    this.collection,
    this.detailPrefix,
  });
  final String title, path;
  final String? collection, detailPrefix;
  @override
  State<RecordsPage> createState() => _RecordsPageState();
}

class _RecordsPageState extends State<RecordsPage> {
  final _rows = <Map<String, dynamic>>[];
  Map<String, dynamic>? _detail;
  bool _loading = false, _more = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
      if (reset) _rows.clear();
    });
    try {
      final data =
          (await DioClient.instance.dio.get(
                widget.path,
                queryParameters: widget.collection == null
                    ? null
                    : {'limit': 20, 'offset': _rows.length},
              )).data
              as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        if (widget.collection == null) {
          _detail = data;
          _more = false;
        } else {
          final page = (data[widget.collection] as List)
              .cast<Map<String, dynamic>>();
          _rows.addAll(page);
          _more =
              data['has_more'] as bool? ??
              (_rows.length < (data['total'] as int? ?? _rows.length));
        }
      });
    } catch (error) {
      if (mounted) setState(() => _error = apiError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.title),
      actions: [
        IconButton(
          onPressed: _loading ? null : () => _load(reset: true),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_loading) const LinearProgressIndicator(),
        if (_error != null) ...[
          Text(_error!, style: const TextStyle(color: Colors.red)),
          TextButton(
            onPressed: () => _load(reset: true),
            child: const Text('Thử lại'),
          ),
        ],
        if (_detail != null) RecordFields(value: _detail!),
        for (final row in _rows)
          Card(
            child: ListTile(
              title: Text(
                '${row['full_name'] ?? (row['id'] != null ? '#${row['id']}' : '')}',
              ),
              subtitle: Text(
                [
                  row['phone'],
                  row['status'],
                  row['opened_at'],
                  row['amount'],
                  row['reason'],
                ].where((x) => x != null).join(' • '),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                final prefix = widget.detailPrefix;
                final path = prefix == null
                    ? null
                    : '$prefix/${row['id']}${prefix == '/retail/customers' ? '/history' : ''}';
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => path != null
                        ? RecordsPage(title: widget.title, path: path)
                        : Scaffold(
                            appBar: AppBar(title: Text(widget.title)),
                            body: SingleChildScrollView(
                              padding: const EdgeInsets.all(16),
                              child: RecordFields(value: row),
                            ),
                          ),
                  ),
                );
              },
            ),
          ),
        if (_rows.isEmpty && _detail == null && !_loading && _error == null)
          const Center(child: Text('Chưa có dữ liệu')),
        if (_more && widget.collection != null)
          TextButton(
            onPressed: _loading ? null : _load,
            child: const Text('Tải thêm'),
          ),
      ],
    ),
  );
}

const _labels = <String, String>{
  'id': 'Mã',
  'order_id': 'Đơn hàng',
  'invoice_id': 'Hóa đơn',
  'receipt_id': 'Phiếu thu',
  'refund_id': 'Phiếu hoàn tiền',
  'status': 'Trạng thái',
  'amount': 'Số tiền',
  'total': 'Tổng tiền',
  'paid': 'Đã thu',
  'due': 'Còn phải thu',
  'full_name': 'Khách hàng',
  'phone': 'Điện thoại',
  'name': 'Tên',
  'address': 'Địa chỉ',
  'vat_percent': 'VAT (%)',
  'width': 'Khổ hóa đơn (mm)',
  'footer': 'Chân hóa đơn',
  'opening_cash': 'Tiền đầu ca',
  'counted_cash': 'Tiền thực đếm',
  'expected_cash': 'Tiền dự kiến',
  'difference': 'Chênh lệch',
  'opened_at': 'Mở ca lúc',
  'closed_at': 'Đóng ca lúc',
  'opened_by_name': 'Người mở ca',
  'closed_by_name': 'Người đóng ca',
  'note': 'Ghi chú',
  'reason': 'Lý do',
  'payment_method': 'Phương thức',
  'created_at': 'Thời gian',
  'current_period_end': 'Kết thúc kỳ',
  'trial_end': 'Hết dùng thử',
  'current_period_start': 'Bắt đầu kỳ',
  'price_monthly': 'Giá tháng',
  'price_yearly': 'Giá năm',
  'subscription': 'Gói đang dùng',
  'plan': 'Gói',
  'access': 'Quyền sử dụng',
  'summary': 'Tổng hợp',
  'shift': 'Ca bán hàng',
  'entries': 'Giao dịch trong ca',
  'data': 'Chứng từ',
  'items': 'Chi tiết',
  'customer': 'Khách hàng',
  'orders': 'Đơn hàng',
  'refunds': 'Hoàn tiền',
  'receivable': 'Công nợ',
  'kind': 'Loại giao dịch',
  'cash_in': 'Thu',
  'cash_out': 'Chi',
  'opening_note': 'Ghi chú mở ca',
  'closing_note': 'Ghi chú đóng ca',
  'max_stores': 'Giới hạn cửa hàng',
  'max_users': 'Giới hạn nhân viên',
  'max_products': 'Giới hạn sản phẩm',
};
String _display(dynamic value) {
  const names = {
    'cash': 'Tiền mặt',
    'card': 'Thẻ',
    'transfer': 'Chuyển khoản',
    'open': 'Đang mở',
    'closed': 'Đã đóng',
    'paid': 'Đã thanh toán',
    'confirmed': 'Đã xác nhận',
    'draft': 'Nháp',
    'cancelled': 'Đã hủy',
    'trialing': 'Dùng thử',
    'active': 'Đang hoạt động',
    'expired': 'Hết hạn',
    'cash_in': 'Thu tiền mặt',
    'cash_out': 'Chi tiền mặt',
    'sale': 'Bán hàng',
    'receipt': 'Phiếu thu',
    'refund': 'Hoàn tiền',
  };
  return names[value.toString()] ?? value?.toString() ?? '—';
}

class RecordFields extends StatelessWidget {
  const RecordFields({super.key, required this.value});
  final Map<String, dynamic> value;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final entry in value.entries.where(
        (entry) => _labels.containsKey(entry.key),
      ))
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: entry.value is Map
              ? ExpansionTile(
                  title: Text(_labels[entry.key]!),
                  children: [
                    RecordFields(
                      value: Map<String, dynamic>.from(entry.value as Map),
                    ),
                  ],
                )
              : entry.value is List
              ? ExpansionTile(
                  title: Text(_labels[entry.key]!),
                  children: [
                    for (final row in (entry.value as List).whereType<Map>())
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: RecordFields(
                            value: Map<String, dynamic>.from(row),
                          ),
                        ),
                      ),
                  ],
                )
              : Wrap(
                  spacing: 8,
                  children: [
                    Text(
                      '${_labels[entry.key]}:',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(_display(entry.value)),
                  ],
                ),
        ),
    ],
  );
}
