part of 'pos_bloc.dart';

enum PosStatus {
  idle,
  loading,
  success,
  error,
  savingDraft, // NEW: đang gửi request lưu nháp
  saveDraftSuccess, // NEW: lưu nháp thành công
}

/// Kiểu giảm giá
enum DiscountType { percent, amount, fixedPrice }

/// Discount áp dụng cho 1 item hoặc toàn đơn
class Discount extends Equatable {
  const Discount({required this.type, required this.value});
  final DiscountType type;
  final double value; // % (0–100) hoặc số tiền tuyệt đối

  /// Tính số tiền được giảm từ [baseAmount]
  double amountOff(double baseAmount) {
    if (type == DiscountType.percent) {
      return (baseAmount * value / 100).clamp(0, baseAmount);
    }
    if (type == DiscountType.amount) {
      return value.clamp(0, baseAmount);
    }
    return 0;
  }

  @override
  List<Object?> get props => [type, value];
}

class CartItem extends Equatable {
  const CartItem({
    required this.product,
    required this.quantity,
    this.discount,
  });
  final ProductEntity product;
  final int quantity;
  final Discount? discount; // giảm giá riêng cho item này

  double get unitPrice => product.price;
  double get baseSubtotal => unitPrice * quantity;
  double get subtotal {
    if (discount == null) return baseSubtotal;

    switch (discount!.type) {
      case DiscountType.percent:
        return baseSubtotal - discount!.amountOff(baseSubtotal);

      case DiscountType.amount:
        return baseSubtotal - discount!.amountOff(baseSubtotal);

      case DiscountType.fixedPrice:
        // value = đơn giá mới
        return discount!.value * quantity;
    }
  }

  double get discountAmount => baseSubtotal - subtotal;

  CartItem copyWith({
    int? quantity,
    Discount? discount,
    bool clearDiscount = false,
  }) => CartItem(
    product: product,
    quantity: quantity ?? this.quantity,
    discount: clearDiscount ? null : (discount ?? this.discount),
  );

  @override
  List<Object?> get props => [product.id, quantity, discount];
}

class PosState extends Equatable {
  const PosState({
    this.cart = const {},
    this.status = PosStatus.idle,
    this.completedOrder,
    this.savedDraftOrder,
    this.errorMessage,
    this.orderDiscount, // giảm giá toàn đơn
  });

  final Map<int, CartItem> cart;
  final PosStatus status;
  final Order? completedOrder;
  final Order? savedDraftOrder;
  final String? errorMessage;
  final Discount? orderDiscount; // NEW

  List<CartItem> get cartItems => cart.values.toList();
  int get itemCount => cart.values.fold(0, (sum, e) => sum + e.quantity);

  /// Tổng trước giảm giá toàn đơn (đã tính giảm từng item)
  double get subtotalAfterItemDiscounts =>
      cart.values.fold(0, (sum, e) => sum + e.subtotal);

  /// Số tiền giảm toàn đơn
  double get orderDiscountAmount => orderDiscount == null
      ? 0
      : orderDiscount!.amountOff(subtotalAfterItemDiscounts);

  /// Tổng cuối cùng
  double get grandTotal => subtotalAfterItemDiscounts - orderDiscountAmount;

  bool get cartEmpty => cart.isEmpty;
  bool get isProcessing =>
      status == PosStatus.loading || status == PosStatus.savingDraft;

  PosState copyWith({
    Map<int, CartItem>? cart,
    PosStatus? status,
    Order? completedOrder,
    bool clearCompletedOrder = false,
    Order? savedDraftOrder,
    bool clearSavedDraft = false,
    String? errorMessage,
    bool clearErrorMessage = false,
    Discount? orderDiscount,
    bool clearOrderDiscount = false,
  }) => PosState(
    cart: cart ?? this.cart,
    status: status ?? this.status,
    completedOrder: clearCompletedOrder
        ? null
        : (completedOrder ?? this.completedOrder),
    savedDraftOrder: clearSavedDraft
        ? null
        : (savedDraftOrder ?? this.savedDraftOrder),
    errorMessage: clearErrorMessage
        ? null
        : (errorMessage ?? this.errorMessage),
    orderDiscount: clearOrderDiscount
        ? null
        : (orderDiscount ?? this.orderDiscount),
  );

  @override
  List<Object?> get props => [
    cart,
    status,
    completedOrder,
    savedDraftOrder,
    errorMessage,
    orderDiscount,
  ];
}
