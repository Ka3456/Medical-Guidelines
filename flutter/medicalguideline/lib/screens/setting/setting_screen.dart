import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../utils/colors.dart';
import '../../provider/auth_provider.dart';
import '../../models/auth_result.dart' show AuthState;
import '../pdfs/pdf_screen.dart';

class SettingScreen extends ConsumerWidget {
  const SettingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 認証状態の変更を監視
    ref.listen(authStatusProvider, (previous, next) {
      next.when(
        data: (status) {
          if (status.state == AuthState.unauthenticated) {
            // ログアウト成功時は自動的にUIが変わるので、ここでは何もしない
            // メイン画面のConsumerが自動的に認証状態を検知して画面を切り替える
          }
        },
        loading: () {},
        error: (error, stack) {},
      );
    });

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withValues(alpha: 0.3),
                Colors.white.withValues(alpha: 0.5),
              ],
            ),
          ),
          child: ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: AppBar(
                title: const Text(
                  '設定',
                  style: TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                    fontSize: 20,
                  ),
                ),
                backgroundColor: Colors.transparent,
                elevation: 0,
                surfaceTintColor: Colors.transparent,
                shadowColor: Colors.transparent,
                scrolledUnderElevation: 0,
                centerTitle: true,
                leading: Container(
                  margin: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.7),
                        Colors.white.withValues(alpha: 0.5),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.6),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                        spreadRadius: 1,
                      ),
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.9),
                        blurRadius: 20,
                        offset: const Offset(0, -8),
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.5),
                                width: 1.5,
                              ),
                            ),
                            child: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: Colors.black87,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                _buildSectionCard(
                  context,
                  title: 'ガイドライン',
                  children: [
                    _buildSettingButton(
                      context,
                      icon: Icons.description,
                      title: 'ガイドライン一覧',
                      subtitle: 'PDFガイドラインを閲覧',
                      onTap: () => _openGuidelineList(context),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildSectionCard(
                  context,
                  title: 'アカウント',
                  children: [
                    _buildSettingButton(
                      context,
                      icon: Icons.logout,
                      title: 'ログアウト',
                      subtitle: 'アプリからログアウトします',
                      onTap: () => _showLogoutDialog(context, ref),
                    ),
                    const Divider(height: 1),
                    _buildSettingButton(
                      context,
                      icon: Icons.edit,
                      title: 'アカウント編集',
                      subtitle: 'プロフィールや設定を変更します',
                      onTap: () => _showEditAccountDialog(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.7),
            Colors.white.withValues(alpha: 0.5),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.6),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 30,
            offset: const Offset(0, 12),
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.9),
            blurRadius: 30,
            offset: const Offset(0, -12),
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 50,
            offset: const Offset(0, 20),
            spreadRadius: 5,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    fontSize: 18,
                  ),
                ),
              ),
              ...children,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingButton(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? textColor,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.4),
            Colors.white.withValues(alpha: 0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 15,
            offset: const Offset(0, 6),
            spreadRadius: 1,
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.7),
            blurRadius: 15,
            offset: const Offset(0, -6),
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20.0,
                  vertical: 16.0,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            (textColor ?? AppColors.primaryRed).withValues(
                              alpha: 0.2,
                            ),
                            (textColor ?? AppColors.primaryRed).withValues(
                              alpha: 0.1,
                            ),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: (textColor ?? AppColors.primaryRed).withValues(
                            alpha: 0.5,
                          ),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (textColor ?? AppColors.primaryRed)
                                .withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Icon(
                        icon,
                        color: textColor ?? AppColors.primaryRed,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                  fontSize: 16,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: Colors.black54, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.5),
                            Colors.white.withValues(alpha: 0.3),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.4),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 16,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openGuidelineList(BuildContext context) {
    // PDFガイドライン画面に遷移
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const PdfScreen(
          pdfPath: 'assets/pdfs/HF.pdf',
          initialPage: 129, // 任意（1始まり）
          highRightText:
              '遺伝学的検査および家族スクリーニング 2022年， 本症に対する遺伝子検査が保険収載されたため， 今後わが国でも肥大型心筋症における遺伝子検査を意識し た診療が重要である', // 任意          // ← 今は無視されます
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.8),
                Colors.white.withValues(alpha: 0.6),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.8),
                blurRadius: 30,
                offset: const Offset(0, -10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.errorRed.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.logout_rounded,
                        color: AppColors.errorRed,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'ログアウト',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'アプリからログアウトしますか？',
                      style: TextStyle(fontSize: 16, color: Colors.black54),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withValues(alpha: 0.4),
                                  Colors.white.withValues(alpha: 0.2),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => Navigator.pop(context),
                                borderRadius: BorderRadius.circular(12),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  child: Text(
                                    'キャンセル',
                                    style: TextStyle(
                                      color: Colors.black54,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.errorRed.withValues(alpha: 0.8),
                                  AppColors.errorRed.withValues(alpha: 0.6),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.errorRed.withValues(
                                    alpha: 0.3,
                                  ),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  Navigator.pop(context);
                                  _performLogout(context, ref);
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  child: Text(
                                    'ログアウト',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showEditAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('アカウント編集'),
        content: const Text('アカウント情報を編集します。\nプロフィールや設定を変更できます。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryRed,
              foregroundColor: AppColors.textWhite,
            ),
            onPressed: () {
              Navigator.pop(context);
              _performEditAccount(context);
            },
            child: const Text('編集する'),
          ),
        ],
      ),
    );
  }

  void _performLogout(BuildContext context, WidgetRef ref) async {
    try {
      // ローディング表示
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // ログアウト実行
      await ref.read(authNotifierProvider.notifier).signOut();

      // ローディングを閉じる
      if (context.mounted) {
        // 成功メッセージ表示
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('ログアウトしました'),
            backgroundColor: AppColors.successGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        Navigator.of(context).pop();
        Navigator.of(context).pop();
      }
    } catch (error) {
      // ローディングを閉じる
      if (context.mounted) {
        Navigator.of(context).pop();

        // エラーメッセージ表示
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ログアウトに失敗しました: $error'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  void _performEditAccount(BuildContext context) {
    // TODO: アカウント編集処理を実装
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('アカウント編集画面に移動します'),
        backgroundColor: AppColors.infoBlue,
      ),
    );
  }
}
