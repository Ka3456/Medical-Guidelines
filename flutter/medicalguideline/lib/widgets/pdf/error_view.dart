import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final msg = kDebugMode ? error.toString() : 'PDFを開けませんでした。';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Text(
          msg,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.red),
        ),
      ),
    );
  }
}


