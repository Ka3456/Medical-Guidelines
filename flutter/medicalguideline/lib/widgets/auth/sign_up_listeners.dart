import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../provider/auth_provider.dart';
import '../../models/auth_result.dart' show AuthState;
import '../../utils/colors.dart';

class SignUpListeners extends ConsumerWidget {
  const SignUpListeners({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 認証状態の変更を監視
    ref.listen(authStatusProvider, (previous, next) {
      next.when(
        data: (status) {
          if (status.state == AuthState.authenticated) {
            // 認証成功時は自動的にUIが変わるので、ここでは何もしない
            // メイン画面のConsumerが自動的に認証状態を検知して画面を切り替える
          }
        },
        loading: () {},
        error: (error, stack) {},
      );
    });

    // 認証操作の結果を監視
    ref.listen(authNotifierProvider, (previous, next) {
      next.when(
        data: (result) {
          if (result != null) {
            if (result.isSuccess) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('アカウントを作成しました。'),
                  backgroundColor: AppColors.successGreen,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(result.errorMessage ?? 'アカウント作成に失敗しました'),
                  backgroundColor: Colors.red,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            }
          }
        },
        loading: () {},
        error: (error, stack) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('エラーが発生しました: $error'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        },
      );
    });

    return const SizedBox.shrink();
  }
}
