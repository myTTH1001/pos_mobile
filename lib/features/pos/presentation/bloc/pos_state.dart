part of 'pos_bloc.dart';

enum PosStatus {
  idle,
  loading,
  success,
  error,
  savingDraft, // NEW: đang gửi request lưu nháp
  saveDraftSuccess, // NEW: lưu nháp thành công
}

class CartItem extends Equatable {
  const CartItem({required this.product, required this.quantity});
  final ProductEntity product;
  final int quantity;

  double get subtotal => product.price * quantity;

  CartItem copyWith({int? quantity}) =>
      CartItem(product: product, quantity: quantity ?? this.quantity);

  @override
  List<Object?> get props => [product.id, quantity];
}

class PosState extends Equatable {
  const PosState({
    this.cart = const {},
    this.status = PosStatus.idle,
    this.completedOrder,
    this.savedDraftOrder, // NEW: draft order vừa được lưu
    this.errorMessage,
  });

  final Map<int, CartItem> cart;
  final PosStatus status;
  final Order? completedOrder;
  final Order? savedDraftOrder; // NEW
  final String? errorMessage;

  List<CartItem> get cartItems => cart.values.toList();
  int get itemCount => cart.values.fold(0, (sum, e) => sum + e.quantity);
  double get grandTotal => cart.values.fold(0, (sum, e) => sum + e.subtotal);
  bool get cartEmpty => cart.isEmpty;

  // Các trạng thái loading dùng chung để disable button
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
  );

  @override
  List<Object?> get props => [
    cart,
    status,
    completedOrder,
    savedDraftOrder,
    errorMessage,
  ];
}
