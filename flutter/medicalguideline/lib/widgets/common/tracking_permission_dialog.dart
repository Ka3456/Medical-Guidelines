import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

class TrackingPermissionDialog extends StatelessWidget {
  final VoidCallback onAllow;
  final VoidCallback onDeny;

  const TrackingPermissionDialog({
    super.key,
    required this.onAllow,
    required this.onDeny,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoAlertDialog(
      title: const Text(
        '"Medical Guideline"が他社のAppやWebサイトを横断してあなたのアクティビティの追跡を許可しますか？',
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: CupertinoColors.label,
        ),
        textAlign: TextAlign.center,
      ),
      content: const Text(
        'これによりアプリのAIの精度向上が期待されます',
        style: TextStyle(
          fontSize: 13,
          color: CupertinoColors.secondaryLabel,
          height: 1.4,
        ),
        textAlign: TextAlign.center,
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: onDeny,
          child: const Text(
            'Appにトラッキングしないように要求',
            style: TextStyle(
              color: CupertinoColors.systemBlue,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: onAllow,
          child: const Text(
            '許可',
            style: TextStyle(
              color: CupertinoColors.systemBlue,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  /// ダイアログを表示する静的メソッド
  static Future<bool?> show(BuildContext context) {
    return showCupertinoDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => TrackingPermissionDialog(
        onAllow: () => Navigator.of(context).pop(true),
        onDeny: () => Navigator.of(context).pop(false),
      ),
    );
  }
}
