import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../orders/domain/entities/order_entity.dart';
import '../../../orders/domain/repositories/order_repository.dart';
import '../../../orders/data/repositories/order_repository_impl.dart';
import '../../../products/domain/entities/product_entity.dart';

part 'pos_event.dart';
part 'pos_state.dart';

class PosBloc extends Bloc<PosEvent, PosState> {
  PosBloc({OrderRepository? orderRepo})
    : _repo = orderRepo ?? OrderRepositoryImpl(),
      super(const PosState()) {
    on<PosProductAdded>(_onProductAdded);
    on<PosProductRemoved>(_onProductRemoved);
    on<PosQuantityChanged>(_onQuantityChanged);
    on<PosCartCleared>(_onCartCleared);
    on<PosOrderSubmitted>(_onOrderSubmitted);
    on<PosPaymentConfirmed>(_onPaymentConfirmed);
    on<PosSaveDraftRequested>(_onSaveDraft);
    on<PosDraftConsumed>(_onDraftConsumed);
    on<PosReset>(_onReset);
    on<PosItemDiscountChanged>(_onItemDiscountChanged);
    on<PosOrderDiscountChanged>(_onOrderDiscountChanged);
  }

  final OrderRepository _repo;

  // ── Thêm sản phẩm vào giỏ ──────────────────────────────
  void _onProductAdded(PosProductAdded event, Emitter<PosState> emit) {
    final cart = Map<int, CartItem>.from(state.cart);
    final exist = cart[event.product.id];

    if (exist != null) {
      cart[event.product.id] = exist.copyWith(quantity: exist.quantity + 1);
    } else {
      cart[event.product.id] = CartItem(product: event.product, quantity: 1);
    }
    emit(state.copyWith(cart: cart));
  }

  // ── Xoá 1 sản phẩm khỏi giỏ ───────────────────────────
  void _onProductRemoved(PosProductRemoved event, Emitter<PosState> emit) {
    final cart = Map<int, CartItem>.from(state.cart)..remove(event.productId);
    emit(state.copyWith(cart: cart));
  }

  // ── Đổi số lượng ───────────────────────────────────────
  void _onQuantityChanged(PosQuantityChanged event, Emitter<PosState> emit) {
    final cart = Map<int, CartItem>.from(state.cart);
    if (event.quantity <= 0) {
      cart.remove(event.productId);
    } else {
      final exist = cart[event.productId];
      if (exist != null) {
        cart[event.productId] = exist.copyWith(quantity: event.quantity);
      }
    }
    emit(state.copyWith(cart: cart));
  }

  // ── Xoá toàn bộ giỏ ────────────────────────────────────
  void _onCartCleared(PosCartCleared event, Emitter<PosState> emit) {
    emit(state.copyWith(cart: {}));
  }

  // ── Lưu nháp ───────────────────────────────────────────
  // Chỉ tạo draft order, không confirm, không pay.
  // Clear cart sau khi lưu xong để bắt đầu đơn mới.
  Future<void> _onSaveDraft(
    PosSaveDraftRequested event,
    Emitter<PosState> emit,
  ) async {
    if (state.cart.isEmpty) return;

    emit(state.copyWith(status: PosStatus.savingDraft));

    try {
      final items = state.cart.values.map((c) {
        final effectiveUnitPrice = c.quantity > 0
            ? c.subtotal / c.quantity
            : c.unitPrice;
        return OrderItem(
          productId: c.product.id,
          productName: c.product.name,
          quantity: c.quantity,
          price: effectiveUnitPrice,
        );
      }).toList();

      final draft = await _repo.createOrder(items);

      emit(
        state.copyWith(
          status: PosStatus.saveDraftSuccess,
          savedDraftOrder: draft,
          cart: {},
          clearOrderDiscount: true,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: PosStatus.error,
          errorMessage: e.toString().replaceFirst('Exception: ', ''),
          clearCompletedOrder: true,
        ),
      );
    }
  }

  // THÊM MỚI
  Future<void> _onDraftConsumed(
    PosDraftConsumed event,
    Emitter<PosState> emit,
  ) async {
    emit(
      state.copyWith(
        status: PosStatus.idle,
        clearSavedDraft: true,
        clearErrorMessage: true,
      ),
    );
  }

  // ── Tạo + confirm + pay ─────────────────────────────────
  Future<void> _onOrderSubmitted(
    PosOrderSubmitted event,
    Emitter<PosState> emit,
  ) async {
    if (state.cart.isEmpty) return;

    emit(state.copyWith(status: PosStatus.loading));

    try {
      // Dùng giá đã giảm (subtotal / quantity) để ghi vào OrderItem
      final items = state.cart.values.map((c) {
        // Giá thực tế mỗi đơn vị sau giảm giá item
        final effectiveUnitPrice = c.quantity > 0
            ? c.subtotal / c.quantity
            : c.unitPrice;
        return OrderItem(
          productId: c.product.id,
          productName: c.product.name,
          quantity: c.quantity,
          price: effectiveUnitPrice,
        );
      }).toList();

      // Tổng cuối (đã trừ giảm giá toàn đơn)
      // Ghi chú: API createOrder nhận items; grandTotal tính lại từ items.
      // Nếu backend cần biết order-level discount, truyền thêm param ở đây.
      final draft = await _repo.createOrder(items);

      // 2. Confirm (trừ kho)
      final confirmed = await _repo.confirmOrder(draft.id, event.paymentMethod);

      // Bước 3: Tạo invoice — nếu lỗi ở đây, vẫn clear cart
      // để tránh tạo đơn trùng, và thông báo cho user
      try {
        final paid = await _repo.payOrder(confirmed.id, event.paymentMethod);

        emit(
          state.copyWith(
            status: PosStatus.success,
            completedOrder: paid,
            cart: {}, // clear cart sau khi thành công hoàn toàn
            clearOrderDiscount: true,
          ),
        );
      } catch (payError) {
        // Đơn đã confirmed (kho đã trừ), chỉ chưa có invoice.
        // Clear cart để tránh đặt lại. User vào tab Đơn hàng thanh toán lại.
        emit(
          state.copyWith(
            status: PosStatus.error,
            errorMessage:
                'Đơn #${confirmed.id} đã xác nhận nhưng chưa tạo được hóa đơn. '
                'Vui lòng vào tab Đơn hàng để thanh toán lại.',
            cart: {}, // FIX: clear cart để tránh đặt trùng
            clearOrderDiscount: true,
            clearCompletedOrder: true,
          ),
        );
      }
    } catch (e) {
      // Lỗi ở createOrder hoặc confirmOrder — giữ cart để user thử lại
      emit(
        state.copyWith(
          status: PosStatus.error,
          errorMessage: e.toString().replaceFirst('Exception: ', ''),
          clearCompletedOrder: true,
        ),
      );
    }
  }

  // ── Xác nhận thanh toán (chọn phương thức) ─────────────
  Future<void> _onPaymentConfirmed(
    PosPaymentConfirmed event,
    Emitter<PosState> emit,
  ) async {
    add(PosOrderSubmitted(paymentMethod: event.paymentMethod));
  }

  // ── Reset về trạng thái ban đầu ────────────────────────
  void _onReset(PosReset event, Emitter<PosState> emit) {
    emit(const PosState());
  }

  // ── Sửa giảm giá từng item ──────────────────────────────
  void _onItemDiscountChanged(
    PosItemDiscountChanged event,
    Emitter<PosState> emit,
  ) {
    final cart = Map<int, CartItem>.from(state.cart);
    final item = cart[event.productId];
    if (item == null) return;
    cart[event.productId] = event.discount == null
        ? item.copyWith(clearDiscount: true)
        : item.copyWith(discount: event.discount);
    emit(state.copyWith(cart: cart));
  }

  // ── Sửa giảm giá toàn đơn ──────────────────────────────
  void _onOrderDiscountChanged(
    PosOrderDiscountChanged event,
    Emitter<PosState> emit,
  ) {
    emit(
      event.discount == null
          ? state.copyWith(clearOrderDiscount: true)
          : state.copyWith(orderDiscount: event.discount),
    );
  }
}
