// import 'package:flutter/material.dart';
// import 'package:google_fonts/google_fonts.dart';

// class PrintReceiptItem {
//   const PrintReceiptItem({
//     required this.name,
//     required this.quantity,
//     required this.unitPrice,
//   });

//   final String name;
//   final int quantity;
//   final double unitPrice;

//   double get subtotal => quantity * unitPrice;
// }

// class ReceiptWidget extends StatelessWidget {
//   const ReceiptWidget({
//     super.key,
//     required this.invoiceId,
//     required this.orderId,
//     required this.paymentMethod,
//     required this.total,
//     required this.items,
//     this.cashierName,
//     this.paidAt,
//   });

//   final int invoiceId;
//   final int orderId;
//   final String paymentMethod;
//   final double total;
//   final List<PrintReceiptItem> items;

//   final String? cashierName;
//   final DateTime? paidAt;

//   @override
//   Widget build(BuildContext context) {
//     return Material(
//       color: Colors.white,
//       child: Container(
//         width: 320, // FIX: chuẩn cho máy 58mm
//         padding: const EdgeInsets.all(12),
//         color: Colors.white,
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           crossAxisAlignment: CrossAxisAlignment.stretch,
//           children: [
//             Text(
//               'ĐẶC SẢN QUÊ HƯƠNG',
//               textAlign: TextAlign.center,
//               style: GoogleFonts.roboto(
//                 fontSize: 20,
//                 fontWeight: FontWeight.bold,
//                 color: Colors.black,
//               ),
//             ),

//             const SizedBox(height: 4),

//             Text(
//               'HÓA ĐƠN BÁN HÀNG',
//               textAlign: TextAlign.center,
//               style: GoogleFonts.roboto(
//                 fontSize: 16,
//                 fontWeight: FontWeight.w600,
//                 color: Colors.black,
//               ),
//             ),

//             const SizedBox(height: 16),

//             _line(),

//             const SizedBox(height: 10),

//             _infoRow('Hóa đơn', '#$invoiceId'),
//             _infoRow('Đơn hàng', '#$orderId'),
//             _infoRow('Thanh toán', paymentMethod),

//             if (cashierName != null) _infoRow('Thu ngân', cashierName!),

//             if (paidAt != null) _infoRow('Thời gian', _formatDateTime(paidAt!)),

//             const SizedBox(height: 10),

//             _line(),

//             const SizedBox(height: 12),

//             ...items.map(
//               (item) => Padding(
//                 padding: const EdgeInsets.only(bottom: 12),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       item.name,
//                       maxLines: 2, // FIX overflow
//                       overflow: TextOverflow.ellipsis,
//                       style: GoogleFonts.roboto(
//                         fontSize: 16,
//                         fontWeight: FontWeight.w700,
//                         color: Colors.black,
//                       ),
//                     ),

//                     const SizedBox(height: 4),

//                     Row(
//                       children: [
//                         Expanded(
//                           child: Text(
//                             '${item.quantity} × ${_fmtPrice(item.unitPrice)}',
//                             style: GoogleFonts.roboto(
//                               fontSize: 14,
//                               color: Colors.black,
//                             ),
//                           ),
//                         ),

//                         Text(
//                           _fmtPrice(item.subtotal),
//                           style: GoogleFonts.roboto(
//                             fontSize: 14,
//                             fontWeight: FontWeight.bold,
//                             color: Colors.black,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ],
//                 ),
//               ),
//             ),

//             _line(),

//             const SizedBox(height: 16),

//             Row(
//               children: [
//                 Expanded(
//                   child: Text(
//                     'TỔNG CỘNG',
//                     style: GoogleFonts.roboto(
//                       fontSize: 18,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                 ),

//                 Text(
//                   _fmtPrice(total),
//                   style: GoogleFonts.roboto(
//                     fontSize: 20,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//               ],
//             ),

//             const SizedBox(height: 16),

//             _line(),

//             const SizedBox(height: 16),

//             Text(
//               'Cảm ơn quý khách!',
//               textAlign: TextAlign.center,
//               style: GoogleFonts.roboto(
//                 fontSize: 16,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),

//             const SizedBox(height: 4),

//             Text(
//               'Hẹn gặp lại',
//               textAlign: TextAlign.center,
//               style: GoogleFonts.roboto(fontSize: 14),
//             ),

//             const SizedBox(height: 16),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _line() {
//     return Container(height: 1, color: Colors.black);
//   }

//   Widget _infoRow(String left, String right) {
//     return Padding(
//       padding: const EdgeInsets.only(bottom: 6),
//       child: Row(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Expanded(
//             child: Text(
//               left,
//               style: GoogleFonts.roboto(fontSize: 14, color: Colors.black),
//             ),
//           ),

//           const SizedBox(width: 8),

//           Flexible(
//             child: Text(
//               right,
//               textAlign: TextAlign.right,
//               style: GoogleFonts.roboto(
//                 fontSize: 14,
//                 fontWeight: FontWeight.w600,
//                 color: Colors.black,
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   String _fmtPrice(double value) {
//     final text = value.toInt().toString();

//     final result = StringBuffer();

//     for (int i = 0; i < text.length; i++) {
//       if (i > 0 && (text.length - i) % 3 == 0) {
//         result.write('.');
//       }

//       result.write(text[i]);
//     }

//     return '${result.toString()}đ';
//   }

//   String _formatDateTime(DateTime dt) {
//     final h = dt.hour.toString().padLeft(2, '0');
//     final m = dt.minute.toString().padLeft(2, '0');
//     final d = dt.day.toString().padLeft(2, '0');
//     final mo = dt.month.toString().padLeft(2, '0');

//     return '$h:$m $d/$mo/${dt.year}';
//   }
// }
