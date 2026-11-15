import '../../core/utils/money.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/network/dio_client.dart';
import '../../core/network/api_error.dart';
import '../../core/storage/secure_storage.dart';
import '../../core/utils/request_key.dart';

/// Manual return of all remaining refundable quantities; server records the ledger.
class RefundPage extends StatefulWidget {
  const RefundPage({super.key, required this.invoiceId});
  final int invoiceId;
  @override
  State<RefundPage> createState() => _RefundPageState();
}

class _RefundPageState extends State<RefundPage> {
  final _dio = DioClient.instance.dio;
  final _reason = TextEditingController(), _reference = TextEditingController();
  Map<String, dynamic>? _data, _pending;
  bool _busy = false, _restock = false, _returned = false, _canRefund = false;
  String? _error, _key;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _reason.dispose();
    _reference.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _busy = true);
    try {
      final profile = (await _dio.get('/auth/me')).data as Map;
      _key =
          'refund_${profile['tenant_id']}_${profile['store_id']}_${profile['user_id']}_${widget.invoiceId}';
      final raw = await SecureStorage.instance.readValue(_key!);
      final data =
          (await _dio.get('/refunds/invoices/${widget.invoiceId}')).data
              as Map<String, dynamic>;
      if (mounted) {
        setState(() {
          _pending = raw == null
              ? null
              : jsonDecode(raw) as Map<String, dynamic>;
          _data = data;
          _canRefund = (profile['permissions'] as List).contains(
            'invoice:refund',
          );
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = apiError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    if (_busy || !_canRefund) return;
    if (_pending == null && (_reason.text.trim().length < 3 || !_returned)) {
      setState(
        () => _error = 'Nhập lý do ít nhất 3 ký tự và xác nhận đã trả đủ tiền.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final payload =
          _pending ??
          <String, dynamic>{
            'idempotency_key': requestKey(),
            'reason': _reason.text.trim(),
            'payout_reference': _reference.text.trim().isEmpty
                ? null
                : _reference.text.trim(),
            'money_returned': true,
            'payment_method': _data!['payment_method'],
            'items': [
              for (final line
                  in (_data!['items'] as List).cast<Map<String, dynamic>>())
                if ((line['available_quantity'] as int) > 0)
                  {
                    'order_item_id': line['order_item_id'],
                    'quantity': line['available_quantity'],
                    'restock': _restock,
                  },
            ],
          };
      await SecureStorage.instance.writeValue(_key!, jsonEncode(payload));
      _pending = payload;
      final response = await _dio.post(
        '/refunds/invoices/${widget.invoiceId}',
        data: payload,
      );
      await SecureStorage.instance.writeValue(_key!, null);
      _pending = null;
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Đã ghi nhận hoàn tiền'),
            content: Text(
              'Phiếu #${response.data['id']} • ${response.data['amount']} đ',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Đóng'),
              ),
            ],
          ),
        );
        if (mounted) Navigator.pop(context);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error =
              '${apiError(error)} Không trả tiền lần nữa. Dùng Đối chiếu yêu cầu để nhận lại kết quả cùng mã.';
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text('Trả hàng hóa đơn #${widget.invoiceId}'),
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
        if (_data != null) ...[
          Text('Đơn #${_data!['order_id']} • ${_data!['status']}'),
          Text(
            'Tiền còn có thể hoàn: ${moneyDifference('${_data!['total']}', '${_data!['refunded_amount']}')} đ',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const Text(
            'Thao tác này trả toàn bộ số lượng còn được hoàn. Chỉ xác nhận sau khi đã trả đủ số tiền trên cho khách.',
          ),
          for (final line
              in (_data!['items'] as List).cast<Map<String, dynamic>>())
            ListTile(
              title: Text('${line['product_name']}'),
              subtitle: Text('Còn được trả: ${line['available_quantity']}'),
            ),
          if (_data!['explanation'] != null) Text('${_data!['explanation']}'),
          if (_pending != null)
            const Text(
              'Đang có yêu cầu cần đối chiếu. Dữ liệu yêu cầu đã được giữ nguyên; không hoàn tiền lần hai.',
            ),
          if (_pending == null && _canRefund && _data!['eligible'] == true) ...[
            TextField(
              controller: _reason,
              maxLength: 500,
              decoration: const InputDecoration(labelText: 'Lý do trả hàng'),
            ),
            TextField(
              controller: _reference,
              maxLength: 255,
              decoration: const InputDecoration(
                labelText: 'Mã giao dịch hoàn tiền (nếu có)',
              ),
            ),
            SwitchListTile(
              value: _restock,
              title: const Text('Nhập lại kho toàn bộ hàng trả'),
              onChanged: _busy
                  ? null
                  : (value) => setState(() => _restock = value),
            ),
            CheckboxListTile(
              value: _returned,
              title: const Text('Tôi đã trả đủ tiền cho khách'),
              onChanged: _busy
                  ? null
                  : (value) {
                      setState(() {
                        _returned = value ?? false;
                      });
                    },
            ),
          ],
          if (_canRefund && (_pending != null || _data!['eligible'] == true))
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: Text(
                _pending != null
                    ? 'Đối chiếu yêu cầu đã gửi'
                    : 'Ghi nhận trả hàng & hoàn tiền',
              ),
            ),
        ],
      ],
    ),
  );
}
