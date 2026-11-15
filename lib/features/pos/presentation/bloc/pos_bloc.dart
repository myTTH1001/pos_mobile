import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/network/api_error.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../../core/utils/request_key.dart';
import '../../../orders/domain/entities/order_entity.dart';
import '../../../orders/data/models/order_model.dart';
import '../../../products/domain/entities/product_entity.dart';

part 'pos_event.dart';
part 'pos_state.dart';

class PosBloc extends Bloc<PosEvent, PosState> {
  PosBloc({Dio? dio})
    : _dio = dio ?? DioClient.instance.dio,
      super(const PosState()) {
    on<PosProductAdded>((event, emit) {
      if (_locked) return;
      final cart = Map<int, CartItem>.from(state.cart);
      cart[event.product.id] =
          cart[event.product.id]?.copyWith(
            quantity: cart[event.product.id]!.quantity + 1,
          ) ??
          CartItem(product: event.product, quantity: 1);
      emit(state.copyWith(cart: cart));
    });
    on<PosProductRemoved>((event, emit) {
      if (_locked) return;
      emit(
        state.copyWith(
          cart: Map<int, CartItem>.from(state.cart)..remove(event.productId),
        ),
      );
    });
    on<PosQuantityChanged>((event, emit) {
      if (_locked) return;
      final cart = Map<int, CartItem>.from(state.cart);
      if (event.quantity <= 0) {
        cart.remove(event.productId);
      } else if (cart.containsKey(event.productId)) {
        cart[event.productId] = cart[event.productId]!.copyWith(
          quantity: event.quantity,
        );
      }
      emit(state.copyWith(cart: cart));
    });
    on<PosCartCleared>((event, emit) {
      if (!_locked) emit(state.copyWith(cart: {}, clearOrderDiscount: true));
    });
    on<PosItemDiscountChanged>((event, emit) {
      if (_locked || !state.cart.containsKey(event.productId)) return;
      final discount = event.discount;
      if (discount != null &&
          (!discount.value.isFinite || discount.value < 0)) {
        return;
      }
      final cart = Map<int, CartItem>.from(state.cart);
      cart[event.productId] = cart[event.productId]!.copyWith(
        discount: discount,
        clearDiscount: discount == null,
      );
      emit(state.copyWith(cart: cart));
    });
    on<PosOrderDiscountChanged>((event, emit) {
      if (_locked) return;
      if (event.discount != null &&
          (!event.discount!.value.isFinite || event.discount!.value < 0)) {
        return;
      }
      emit(
        state.copyWith(
          orderDiscount: event.discount,
          clearOrderDiscount: event.discount == null,
        ),
      );
    });
    on<PosDiscountReasonChanged>((event, emit) {
      if (!_locked) emit(state.copyWith(discountReason: event.reason));
    });
    on<PosCustomerChanged>((event, emit) {
      if (!_locked) {
        emit(
          state.copyWith(
            customerId: event.id,
            customerName: event.name,
            clearCustomer: event.id == null,
          ),
        );
      }
    });
    on<PosPrepareCheckout>((event, emit) => _prepare(emit));
    on<PosSaveDraftRequested>((event, emit) => _save(emit));
    on<PosOrderSubmitted>((event, emit) => _pay(event.paymentMethod, emit));
    on<PosPaymentConfirmed>((event, emit) => _pay(event.paymentMethod, emit));
    on<PosDraftConsumed>(
      (event, emit) =>
          emit(state.copyWith(status: PosStatus.idle, clearSavedDraft: true)),
    );
    on<PosRestorePending>((event, emit) => _restore(emit));
    on<PosReset>((event, emit) async {
      if (_busy || state.checkoutOrder != null || _unresolved != null) return;
      emit(PosState(canDiscount: _canDiscount));
    });
  }
  final Dio _dio;
  bool _busy = false;
  String? _journalKey;
  bool _canDiscount = false;
  Map<String, dynamic>? _unresolved;
  bool get _locked =>
      _busy || state.checkoutOrder != null || _unresolved != null;

  Map<int, CartItem> _cartFrom(Order order) => {
    for (final item in order.items)
      item.productId: CartItem(
        product: ProductEntity(
          id: item.productId,
          name: item.productName,
          price: item.price,
        ),
        quantity: item.quantity,
      ),
  };

  Future<void> _cartWrites = Future.value();
  @override
  void onChange(Change<PosState> change) {
    super.onChange(change);
    if (change.currentState.cart == change.nextState.cart &&
        change.currentState.orderDiscount == change.nextState.orderDiscount &&
        change.currentState.discountReason == change.nextState.discountReason &&
        change.currentState.customerId == change.nextState.customerId) {
      return;
    }
    final snapshot = change.nextState;
    _cartWrites = _cartWrites
        .then((_) async {
          final key = await _scope();
          await SecureStorage.instance.writeValue(
            '${key}_cart',
            jsonEncode({
              'customer_id': snapshot.customerId,
              'customer_name': snapshot.customerName,
              'reason': snapshot.discountReason,
              'order_discount': snapshot.orderDiscount == null
                  ? null
                  : {
                      'type': snapshot.orderDiscount!.type.index,
                      'value': snapshot.orderDiscount!.value,
                    },
              'items': snapshot.cart.values
                  .map(
                    (item) => {
                      'id': item.product.id,
                      'name': item.product.name,
                      'price': item.unitPrice,
                      'quantity': item.quantity,
                      'discount': item.discount == null
                          ? null
                          : {
                              'type': item.discount!.type.index,
                              'value': item.discount!.value,
                            },
                    },
                  )
                  .toList(),
            }),
          );
        })
        .catchError((Object error) {
          // Never change a completed payment result when local persistence fails.
          // Surface on next restore; server order remains authoritative.
        });
  }

  Discount? _readDiscount(dynamic value) => value == null
      ? null
      : Discount(
          type: DiscountType.values[value['type'] as int],
          value: (value['value'] as num).toDouble(),
        );

  Future<String> _scope() async {
    if (_journalKey != null) return _journalKey!;
    final profile = (await _dio.get('/auth/me')).data as Map;
    _canDiscount = (profile['permissions'] as List? ?? []).contains(
      'order:discount',
    );
    return _journalKey =
        'pending_checkout_${profile['tenant_id']}_${profile['store_id']}_${profile['user_id']}';
  }

  Future<void> _journal(Map<String, dynamic>? value) async {
    await SecureStorage.instance.writeValue(
      await _scope(),
      value == null ? null : jsonEncode(value),
    );
  }

  Future<Order> _get(int id) async => OrderModel.fromJson(
    (await _dio.get('/orders/$id')).data as Map<String, dynamic>,
  ).toEntity();

  Future<void> _restore(Emitter<PosState> emit) async {
    if (_busy) return;
    _busy = true;
    try {
      final key = await _scope();
      emit(state.copyWith(canDiscount: _canDiscount));
      final rawCart = await SecureStorage.instance.readValue('${key}_cart');
      if (rawCart != null) {
        final stored = jsonDecode(rawCart) as Map<String, dynamic>;
        final cart = <int, CartItem>{};
        for (final item in (stored['items'] as List)) {
          final product = ProductEntity(
            id: item['id'] as int,
            name: item['name'] as String,
            price: (item['price'] as num).toDouble(),
          );
          cart[product.id] = CartItem(
            product: product,
            quantity: item['quantity'] as int,
            discount: _readDiscount(item['discount']),
          );
        }
        emit(
          state.copyWith(
            cart: cart,
            customerId: stored['customer_id'] as int?,
            customerName: stored['customer_name'] as String?,
            discountReason: stored['reason'] as String?,
            orderDiscount: _readDiscount(stored['order_discount']),
          ),
        );
      }
      final raw = await SecureStorage.instance.readValue(key);
      if (raw == null) return;
      final pending = jsonDecode(raw) as Map<String, dynamic>;
      if (pending['id'] == null) {
        _unresolved = pending;
        emit(state.copyWith(pendingRecovery: true));
        emit(
          state.copyWith(
            status: PosStatus.error,
            errorMessage:
                'Có yêu cầu tạo đơn chưa rõ kết quả. Bấm Tiếp tục để đối chiếu bằng cùng mã yêu cầu.',
          ),
        );
      } else {
        final order = await _get(pending['id'] as int);
        if (order.status == 'paid' || order.status == 'cancelled') {
          await _journal(null);
          emit(PosState(canDiscount: _canDiscount));
        } else {
          emit(
            state.copyWith(
              checkoutOrder: order,
              cart: _cartFrom(order),
              status: PosStatus.idle,
            ),
          );
        }
      }
    } catch (error) {
      // Block new writes until recovery can read the saved journal.
      _unresolved = {'recovery_required': true};
      emit(state.copyWith(pendingRecovery: true));
      emit(
        state.copyWith(status: PosStatus.error, errorMessage: apiError(error)),
      );
    } finally {
      _busy = false;
    }
  }

  Map<String, dynamic> _payload() {
    if (state.cart.isEmpty) throw StateError('Giỏ hàng trống.');
    if ((state.orderDiscountAmount > 0 ||
            state.cart.values.any((item) => item.discountAmount > 0)) &&
        state.discountReason.trim().isEmpty) {
      throw StateError('Vui lòng nhập lý do giảm giá.');
    }
    return {
      'idempotency_key': requestKey(),
      'customer_id': state.customerId,
      'discount_type': state.orderDiscount?.type == DiscountType.percent
          ? 'percent'
          : 'fixed',
      'discount_value': state.orderDiscount?.type == DiscountType.fixedPrice
          ? state.orderDiscountAmount
          : state.orderDiscount?.value ?? 0,
      'discount_reason': state.discountReason.trim(),
      'items': state.cart.values
          .map(
            (item) => {
              'product_id': item.product.id, 'quantity': item.quantity,
              // Catalog prices are authoritative. Do not submit a discounted price.
              'discount_type': item.discount?.type == DiscountType.percent
                  ? 'percent'
                  : 'fixed',
              'discount_value': item.discount?.type == DiscountType.fixedPrice
                  ? (item.unitPrice - item.discount!.value).clamp(
                          0,
                          item.unitPrice,
                        ) *
                        item.quantity
                  : item.discount?.value ?? 0,
            },
          )
          .toList(),
    };
  }

  Future<Order> _draft() async {
    if (state.checkoutOrder != null) return await _get(state.checkoutOrder!.id);
    if (_unresolved?['recovery_required'] == true) {
      _journalKey = null;
      final raw = await SecureStorage.instance.readValue(await _scope());
      _unresolved = raw == null
          ? null
          : jsonDecode(raw) as Map<String, dynamic>;
      if (_unresolved?['id'] != null) return _get(_unresolved!['id'] as int);
    }
    final payload = _unresolved ?? _payload();
    await _journal(payload); // persist request key before sending a write
    _unresolved = payload;
    late Response<dynamic> response;
    try {
      response = await _dio.post('/orders', data: payload);
    } on DioException catch (error) {
      if ([400, 402, 403, 422].contains(error.response?.statusCode)) {
        await _journal(null);
        _unresolved = null;
      }
      rethrow;
    }
    final order = OrderModel.fromJson(
      response.data as Map<String, dynamic>,
    ).toEntity();
    await _journal({'id': order.id});
    _unresolved = null;
    return order;
  }

  Future<void> _prepare(Emitter<PosState> emit) async {
    if (_busy) return;
    _busy = true;
    emit(state.copyWith(status: PosStatus.loading, clearErrorMessage: true));
    try {
      final order = await _draft();
      emit(
        state.copyWith(
          checkoutOrder: order,
          pendingRecovery: false,
          canDiscount: _canDiscount,
          cart: _cartFrom(order),
          status: PosStatus.idle,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(status: PosStatus.error, errorMessage: apiError(error)),
      );
    } finally {
      _busy = false;
    }
  }

  Future<void> _save(Emitter<PosState> emit) async {
    if (_busy) return;
    _busy = true;
    emit(state.copyWith(status: PosStatus.savingDraft));
    try {
      final draft = await _draft();
      if (draft.status == 'paid') {
        await _journal(null);
        emit(
          PosState(
            canDiscount: _canDiscount,
          ).copyWith(status: PosStatus.success, completedOrder: draft),
        );
        return;
      }
      if (draft.status != 'draft') {
        await _journal(null);
        emit(
          PosState(canDiscount: _canDiscount).copyWith(
            status: PosStatus.error,
            errorMessage:
                'Đơn #${draft.id} đã ${draft.status}. Kiểm tra tại danh sách đơn hàng.',
          ),
        );
        return;
      }
      await _journal(null);
      _unresolved = null;
      emit(
        PosState(
          canDiscount: _canDiscount,
        ).copyWith(status: PosStatus.saveDraftSuccess, savedDraftOrder: draft),
      );
    } catch (error) {
      emit(
        state.copyWith(status: PosStatus.error, errorMessage: apiError(error)),
      );
    } finally {
      _busy = false;
    }
  }

  Future<void> _pay(String method, Emitter<PosState> emit) async {
    if (_busy ||
        state.checkoutOrder == null ||
        !['cash', 'card', 'transfer'].contains(method)) {
      return;
    }
    _busy = true;
    emit(state.copyWith(status: PosStatus.loading));
    final expected = state.checkoutOrder!;
    try {
      final current = await _get(expected.id);
      if (current.status == 'paid') {
        await _journal(null);
        emit(
          PosState(
            canDiscount: _canDiscount,
          ).copyWith(status: PosStatus.success, completedOrder: current),
        );
        return;
      }
      if (current.status != 'draft' ||
          current.version != expected.version ||
          current.total != expected.total) {
        emit(
          state.copyWith(
            checkoutOrder: current,
            status: PosStatus.error,
            errorMessage:
                'Đơn đã thay đổi. Kiểm tra lại số tiền và trạng thái trước khi xác nhận.',
          ),
        );
        return;
      }
      await _dio.post(
        '/orders/${current.id}/quick-checkout',
        data: {
          'version': current.version,
          'expected_total': current.total.toStringAsFixed(2),
          'payment_method': method,
          'money_received': true,
        },
      );
      final paid = await _get(current.id);
      if (paid.status != 'paid' || paid.invoice?.status != 'paid') {
        throw StateError(
          'Chưa xác nhận được thanh toán. Kiểm tra đơn #${current.id}.',
        );
      }
      await _journal(null);
      emit(
        PosState(
          canDiscount: _canDiscount,
        ).copyWith(status: PosStatus.success, completedOrder: paid),
      );
    } catch (error) {
      // Keep the exact order ID. Next attempt always reads its status first.
      emit(
        state.copyWith(
          status: PosStatus.error,
          errorMessage: 'Đơn #${expected.id}: ${apiError(error)}',
        ),
      );
    } finally {
      _busy = false;
    }
  }
}
