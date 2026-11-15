import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/pos_bloc.dart';

class PaymentSheet extends StatefulWidget {
  const PaymentSheet({super.key});
  @override
  State<PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<PaymentSheet> {
  String _method = 'cash';
  bool _received = false;
  @override
  void initState() {
    super.initState();
    context.read<PosBloc>().add(const PosPrepareCheckout());
  }

  @override
  Widget build(BuildContext context) => BlocConsumer<PosBloc, PosState>(
    listener: (context, state) {
      if (state.status == PosStatus.success) Navigator.pop(context);
    },
    builder: (context, state) {
      final order = state.checkoutOrder;
      return SafeArea(
        child: Material(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20,
              24,
              20,
              MediaQuery.viewInsetsOf(context).bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Xác nhận thanh toán',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                if (state.isProcessing) const LinearProgressIndicator(),
                if (order != null) ...[
                  Text('Đơn #${order.id} • ${order.status}'),
                  Text(
                    '${order.total.toStringAsFixed(0)} đ',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  Text(
                    'Giảm giá: ${order.discountAmount.toStringAsFixed(0)} đ • VAT: ${order.taxAmount.toStringAsFixed(0)} đ',
                  ),
                  const Text(
                    'Số tiền đã được máy chủ tính. Tiền mặt: thu đủ đúng số tiền trên.',
                  ),
                ],
                if (state.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      state.errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                if (order == null)
                  TextButton(
                    onPressed: state.isProcessing
                        ? null
                        : () => context.read<PosBloc>().add(
                            const PosPrepareCheckout(),
                          ),
                    child: const Text('Đối chiếu / thử tải lại đơn'),
                  ),
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
                  onChanged: state.isProcessing
                      ? null
                      : (value) => setState(() {
                          _method = value!;
                          _received = false;
                        }),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _received,
                  title: const Text(
                    'Tôi đã nhận đủ tiền / xác nhận giao dịch thành công',
                  ),
                  onChanged: state.isProcessing
                      ? null
                      : (value) => setState(() => _received = value ?? false),
                ),
                FilledButton(
                  onPressed:
                      state.isProcessing ||
                          order == null ||
                          !_received ||
                          order.status != 'draft'
                      ? null
                      : () => context.read<PosBloc>().add(
                          PosOrderSubmitted(paymentMethod: _method),
                        ),
                  child: const Text('Xác nhận đã thu tiền'),
                ),
                TextButton(
                  onPressed: state.isProcessing
                      ? null
                      : () => Navigator.pop(context),
                  child: const Text('Đóng — giữ đơn nháp để kiểm tra'),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
