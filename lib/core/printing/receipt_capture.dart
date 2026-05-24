// import 'dart:typed_data';

// import 'package:flutter/material.dart';
// import 'package:screenshot/screenshot.dart';

// class ReceiptCapture {
//   ReceiptCapture._();

//   static final ReceiptCapture instance = ReceiptCapture._();

//   final ScreenshotController _controller = ScreenshotController();

//   Future<Uint8List> capture(Widget widget) async {
//     final bytes = await _controller.captureFromWidget(
//       MediaQuery(
//         data: const MediaQueryData(),
//         child: Directionality(
//           textDirection: TextDirection.ltr,
//           child: Material(color: Colors.white, child: widget),
//         ),
//       ),

//       // FIX:
//       // 1.5 là đẹp nhất cho PT-210
//       // 2.0 gây nặng bitmap
//       pixelRatio: 1.5,
//     );

//     return bytes;
//   }
// }
