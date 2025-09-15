import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../provider/auth_provider.dart';
import '../../models/auth_result.dart' show AuthState;
import '../pdfs/all_pdf_screen.dart';
import 'edit_profile_screen.dart';
import '../../widgets/common/liquid_background.dart';
import '../../widgets/common/back_button.dart';
import '../../widgets/setting/section_card.dart';
import '../../widgets/setting/setting_button.dart';
import '../../widgets/setting/logout_dialog.dart';
import '../../widgets/setting/delete_account_dialog.dart';
import 'technical_issue_screen.dart';

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
      body: LiquidBackground(
        child: SafeArea(
          top: true,
          left: true,
          right: true,
          bottom: false,
          child: Column(
            children: [
              // ヘッダー部分
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 20.0,
                ),
                child: Row(
                  children: [
                    const CustomBackButton(),
                    const Expanded(
                      child: Text(
                        '設定',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 50), // 戻るボタンと同じ幅でバランスを取る
                  ],
                ),
              ),
              // メインコンテンツ
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SectionCard(
                        title: 'ガイドライン',
                        children: [
                          SettingButton(
                            icon: Icons.description,
                            title: 'ガイドライン一覧',
                            subtitle: 'PDFガイドラインを閲覧',
                            onTap: () => _openGuidelineList(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      SectionCard(
                        title: 'サポート',
                        children: [
                          SettingButton(
                            icon: Icons.bug_report,
                            title: '技術的問題を報告',
                            subtitle: 'バグや問題を報告します',
                            onTap: () => _openTechnicalIssueScreen(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      SectionCard(
                        title: 'アカウント',
                        children: [
                          SettingButton(
                            icon: Icons.logout,
                            title: 'ログアウト',
                            subtitle: 'アプリからログアウトします',
                            onTap: () => LogoutDialog.show(context, ref),
                          ),
                          const Divider(height: 1),
                          SettingButton(
                            icon: Icons.edit,
                            title: 'アカウント編集',
                            subtitle: 'プロフィールや設定を変更します',
                            onTap: () => _performEditAccount(context),
                          ),
                          const Divider(height: 1),
                          SettingButton(
                            icon: Icons.person_remove,
                            title: 'アカウント削除',
                            subtitle: 'アカウントを完全に削除します',
                            onTap: () => DeleteAccountDialog.show(context, ref),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20), // 下部に余白を追加
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openGuidelineList(BuildContext context) {
    // ガイドライン一覧画面に遷移
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AllPdfScreen()),
    );
  }

  void _performEditAccount(BuildContext context) {
    // プロフィール編集画面に遷移
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const EditProfileScreen()),
    );
  }

  void _openTechnicalIssueScreen(BuildContext context) {
    // 技術的問題報告画面に遷移
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TechnicalIssueScreen()),
    );
  }
}
