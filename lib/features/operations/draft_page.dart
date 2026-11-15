import 'refund_page.dart';
import 'package:flutter/material.dart';
import '../../core/network/dio_client.dart';
import '../../core/network/api_error.dart';
import 'operations_page.dart';

/// Resume the exact server draft instead of creating a replacement order.
class DraftPage extends StatefulWidget {
  const DraftPage({super.key, required this.orderId});
  final int orderId;
  @override
  State<DraftPage> createState() => _DraftPageState();
}

class _DraftPageState extends State<DraftPage> {
  final _dio = DioClient.instance.dio;
  Map<String, dynamic>? _order;
  List<String> _permissions = [];
  String? _error;
  bool _busy = false;
  String _method = 'cash';
  bool _received = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
      _received = false;
    });
    try {
      final profile = (await _dio.get('/auth/me')).data as Map;
      final data =
          (await _dio.get('/orders/${widget.orderId}')).data
              as Map<String, dynamic>;
      if (mounted) {
        setState(() {
          _order = data;
          _permissions = (profile['permissions'] as List).cast<String>();
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = apiError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _quantity(Map<String, dynamic> item) async {
    final quantity = TextEditingController(text: '${item['quantity']}');
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${(item['product'] as Map?)?['name'] ?? 'Sản phẩm'}'),
        content: TextField(
          controller: quantity,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Số lượng (0 để bỏ khỏi đơn)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Quay lại'),
          ),
          FilledButton(
            onPressed: () {
              final number = int.tryParse(quantity.text);
              if (number != null && number >= 0) Navigator.pop(ctx, number);
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
    if (result == null || !mounted) return;
    // Output schema has allocated discounts only, not original discount rules.
    // Do not silently reconstruct or discard them during an edit.
    if (double.parse('${_order!['discount_amount'] ?? 0}') > 0) {
      setState(
        () => _error =
            'Đơn có giảm giá: hãy sửa trên website để giữ đúng quy tắc giảm giá gốc. App chưa có dữ liệu quy tắc từ API đọc đơn.',
      );
      return;
    }
    final items = (_order!['items'] as List)
        .cast<Map<String, dynamic>>()
        .map(
          (line) => {
            'product_id': line['product_id'],
            'quantity': line['id'] == item['id'] ? result : line['quantity'],
          },
        )
        .where((line) => line['quantity'] != 0)
        .toList();
    if (items.isEmpty) {
      setState(
        () => _error =
            'Đơn cần ít nhất một sản phẩm. Dùng Hủy đơn nếu không tiếp tục.',
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await _dio.put(
        '/orders/${widget.orderId}',
        data: {
          'version': _order!['version'],
          'customer_id': _order!['customer_id'],
          'items': items,
          'preferred_payment_method': _order!['preferred_payment_method'],
        },
      );
      await _load();
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = apiError(error);
        });
      }
    }
  }

  Future<void> _pay() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final current =
          (await _dio.get('/orders/${widget.orderId}')).data
              as Map<String, dynamic>;
      if (current['status'] == 'paid') {
        await _load();
        return;
      }
      if (current['version'] != _order!['version'] ||
          '${current['total']}' != '${_order!['total']}') {
        if (mounted) {
          setState(() {
            _order = current;
            _error = 'Đơn đã thay đổi. Kiểm tra lại tổng tiền.';
            _received = false;
            _busy = false;
          });
        }
        return;
      }
      if (current['status'] == 'draft') {
        await _dio.post(
          '/orders/${widget.orderId}/quick-checkout',
          data: {
            'version': current['version'],
            'expected_total': current['total'],
            'payment_method': _method,
            'money_received': true,
          },
        );
      } else if (current['status'] == 'confirmed') {
        await _dio.post(
          '/invoices/${widget.orderId}',
          data: {'payment_method': _method},
        );
      } else {
        throw StateError('Trạng thái đơn không cho phép thanh toán.');
      }
      await _load();
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _received = false;
          _error =
              '${apiError(error)} Đơn #${widget.orderId} được giữ nguyên; tải lại trước khi thao tác tiếp.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text('Đơn #${widget.orderId}'),
      actions: [
        IconButton(
          onPressed: _busy ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (_busy) const LinearProgressIndicator(),
        if (_error != null)
          Text(_error!, style: const TextStyle(color: Colors.red)),
        if (_order != null) ...[
          Text('Trạng thái: ${_order!['status']}'),
          Text(
            '${_order!['total']} đ',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          Text(
            'VAT: ${_order!['tax_amount']} đ • Giảm giá: ${_order!['discount_amount']} đ',
          ),
          for (final item
              in (_order!['items'] as List).cast<Map<String, dynamic>>())
            Card(
              child: ListTile(
                title: Text(
                  '${(item['product'] as Map?)?['name'] ?? 'Sản phẩm'}',
                ),
                subtitle: Text('${item['quantity']} × ${item['price']} đ'),
                trailing:
                    _order!['status'] == 'draft' &&
                        _permissions.contains('order:create')
                    ? IconButton(
                        onPressed: _busy ? null : () => _quantity(item),
                        icon: const Icon(Icons.edit_outlined),
                      )
                    : null,
              ),
            ),
          if (['draft', 'confirmed'].contains(_order!['status']) &&
              _permissions.contains('invoice:create')) ...[
            DropdownButtonFormField<String>(
              initialValue: _method,
              decoration: const InputDecoration(labelText: 'Phương thức'),
              items: const [
                DropdownMenuItem(value: 'cash', child: Text('Tiền mặt')),
                DropdownMenuItem(value: 'card', child: Text('Thẻ')),
                DropdownMenuItem(
                  value: 'transfer',
                  child: Text('Chuyển khoản'),
                ),
              ],
              onChanged: _busy
                  ? null
                  : (value) => setState(() {
                      _method = value!;
                      _received = false;
                    }),
            ),
            CheckboxListTile(
              value: _received,
              title: const Text('Tôi đã nhận đủ tiền'),
              onChanged: _busy
                  ? null
                  : (value) => setState(() => _received = value ?? false),
            ),
            FilledButton(
              onPressed:
                  _busy ||
                      !_received ||
                      (_order!['status'] == 'draft' &&
                          !_permissions.contains('order:confirm'))
                  ? null
                  : _pay,
              child: const Text('Xác nhận thanh toán'),
            ),
          ],
          if (_order!['invoice'] != null &&
              _permissions.contains('invoice:view'))
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => RefundPage(
                    invoiceId: (_order!['invoice'] as Map)['id'] as int,
                  ),
                ),
              ),
              child: const Text('Trả hàng / hoàn tiền'),
            ),
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => RecordsPage(
                  title: 'Phiếu thu đơn #${widget.orderId}',
                  path: '/retail/orders/${widget.orderId}/payments',
                ),
              ),
            ),
            child: const Text('Xem phiếu thu & công nợ'),
          ),
        ],
      ],
    ),
  );
}
