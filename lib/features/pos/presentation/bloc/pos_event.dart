part of 'pos_bloc.dart';

abstract class PosEvent extends Equatable {
  const PosEvent();
  @override
  List<Object?> get props => [];
}

class PosProductAdded extends PosEvent {
  const PosProductAdded(this.product);
  final ProductEntity product;
  @override
  List<Object?> get props => [product];
}

class PosProductRemoved extends PosEvent {
  const PosProductRemoved(this.productId);
  final int productId;
  @override
  List<Object?> get props => [productId];
}

class PosQuantityChanged extends PosEvent {
  const PosQuantityChanged({required this.productId, required this.quantity});
  final int productId;
  final int quantity;
  @override
  List<Object?> get props => [productId, quantity];
}

class PosCartCleared extends PosEvent {
  const PosCartCleared();
}

/// Bấm "Thanh toán" — submit toàn bộ flow: create → confirm → pay
class PosOrderSubmitted extends PosEvent {
  const PosOrderSubmitted({required this.paymentMethod});
  final String paymentMethod; // cash | card | transfer
  @override
  List<Object?> get props => [paymentMethod];
}

class PosPaymentConfirmed extends PosEvent {
  const PosPaymentConfirmed({required this.paymentMethod});
  final String paymentMethod;
  @override
  List<Object?> get props => [paymentMethod];
}

/// NEW: Lưu giỏ hàng thành draft order, không confirm, không pay.
/// Sau khi lưu thành công → cart bị clear để bắt đầu đơn mới.
class PosSaveDraftRequested extends PosEvent {
  const PosSaveDraftRequested();
}

/// NEW: Sau khi lưu nháp thành công, user vào tab Đơn hàng, chọn 1 draft order để tiếp tục đặt hàng.
class PosDraftConsumed extends PosEvent {
  const PosDraftConsumed();
}

class PosReset extends PosEvent {
  const PosReset();
}
