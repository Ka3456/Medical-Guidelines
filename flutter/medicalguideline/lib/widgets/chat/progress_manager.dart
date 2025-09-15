import 'dart:async';
import 'package:flutter/material.dart';

class ProgressManager {
  Timer? _progressTimer;
  double _progressValue = 0.0;
  static const int _timeoutSeconds = 30;

  double get progressValue => _progressValue;

  // プログレスタイマーを開始
  void startProgressTimer(VoidCallback onUpdate) {
    _progressTimer?.cancel();
    _progressValue = 0.0;

    _progressTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      _progressValue += 100 / (_timeoutSeconds * 1000);
      if (_progressValue >= 1.0) {
        _progressValue = 1.0;
        timer.cancel();
      }
      onUpdate();
    });
  }

  // プログレスタイマーを停止
  void stopProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = null;
    _progressValue = 0.0;
  }

  // リソースを解放
  void dispose() {
    _progressTimer?.cancel();
  }
}
