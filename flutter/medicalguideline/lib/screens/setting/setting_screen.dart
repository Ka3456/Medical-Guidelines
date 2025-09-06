import 'package:flutter/material.dart';
import '../../utils/colors.dart';
import '../pdfs/pdf_screen.dart';

class SettingScreen extends StatelessWidget {
  const SettingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('設定', style: TextStyle(color: AppColors.textWhite)),
        backgroundColor: AppColors.primaryRed,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textWhite),
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
                      onTap: () => _showLogoutDialog(context),
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
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textBlack,
              ),
            ),
          ),
          ...children,
        ],
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (textColor ?? AppColors.primaryRed).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
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
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textBlackSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: AppColors.textBlackSecondary,
            ),
          ],
        ),
      ),
    );
  }

  void _openGuidelineList(BuildContext context) {
    // PDFガイドライン画面に遷移
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PdfScreen(
          docId: '心不全診療ガイドライン',
          version: 'v1.0',
          initialPage: 129,
          initialChunk: 0,
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ログアウト'),
        content: const Text('アプリからログアウトしますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _performLogout(context);
            },
            child: const Text('ログアウト'),
          ),
        ],
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

  void _performLogout(BuildContext context) {
    // TODO: ログアウト処理を実装
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('ログアウトしました'),
        backgroundColor: AppColors.successGreen,
      ),
    );
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
