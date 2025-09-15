import 'package:flutter/material.dart';
import '../../utils/colors.dart';
import '../../widgets/common/liquid_background.dart';
import '../../widgets/common/glass_container.dart';
import '../../widgets/common/back_button.dart';
import 'pdf_screen.dart';

class AllPdfScreen extends StatelessWidget {
  const AllPdfScreen({super.key});

  // スケーラビリティを考慮してPDFデータをモデル化
  static const List<PdfGuideline> _guidelines = [
    PdfGuideline(
      id: 'heart_failure_2025',
      title: '心不全・心筋疾患',
      subtitle: '2025年改訂版 心不全診療ガイドライン',
      organization: '日本循環器学会 / 日本心不全学会合同ガイドライン',
      pdfPath: 'assets/pdfs/heart_failure_2025.pdf', // 実際のPDFパス
      year: 2025,
      category: '循環器',
    ),
    // 今後ここに新しいガイドラインを追加
    // PdfGuideline(
    //   id: 'diabetes_2025',
    //   title: '糖尿病',
    //   subtitle: '2025年改訂版 糖尿病診療ガイドライン',
    //   organization: '日本糖尿病学会',
    //   pdfPath: 'assets/pdfs/diabetes_2025.pdf',
    //   year: 2025,
    //   category: '内分泌',
    // ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LiquidBackground(
        child: Column(
          children: [
            // 透明なAppBar
            Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 8,
                left: 16,
                right: 16,
                bottom: 8,
              ),
              child: Row(
                children: [
                  const CustomBackButton(),
                  Expanded(
                    child: Text(
                      '医療ガイドライン',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.w600,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 50), // バランス調整（CustomBackButtonと同じ幅）
                ],
              ),
            ),

            // PDFリスト
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _guidelines.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final guideline = _guidelines[index];
                  return _PdfGuidelineCard(
                    guideline: guideline,
                    onTap: () => _navigateToPdf(context, guideline),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToPdf(BuildContext context, PdfGuideline guideline) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PdfScreen(
          pdfPath: guideline.pdfPath,
          highRightText: '${guideline.year}年改訂版',
        ),
      ),
    );
  }
}

// PDFガイドラインのデータモデル
class PdfGuideline {
  final String id;
  final String title;
  final String subtitle;
  final String organization;
  final String pdfPath;
  final int year;
  final String category;

  const PdfGuideline({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.organization,
    required this.pdfPath,
    required this.year,
    required this.category,
  });
}

// PDFガイドラインカードウィジェット
class _PdfGuidelineCard extends StatelessWidget {
  final PdfGuideline guideline;
  final VoidCallback onTap;

  const _PdfGuidelineCard({required this.guideline, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      blur: 12,
      opacity: 0.2,
      borderRadius: BorderRadius.circular(16),
      padding: const EdgeInsets.all(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // カテゴリータグ
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primaryRed.withOpacity(0.2),
                    AppColors.primaryRedLight.withOpacity(0.15),
                  ],
                ),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.primaryRed.withOpacity(0.4),
                  width: 1,
                ),
              ),
              child: Text(
                guideline.category,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryRed,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // タイトル
            Text(
              guideline.title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),

            const SizedBox(height: 8),

            // サブタイトル
            Text(
              guideline.subtitle,
              style: TextStyle(
                fontSize: 14,
                color: Colors.black54,
                height: 1.4,
              ),
            ),

            const SizedBox(height: 12),

            // 学会名
            Row(
              children: [
                Icon(Icons.business, size: 16, color: Colors.black54),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    guideline.organization,
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // フッター（年とアクション）
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    '${guideline.year}年改訂版',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryRed.withOpacity(0.3),
                        offset: const Offset(0, 2),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.picture_as_pdf,
                        size: 16,
                        color: AppColors.textWhite,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '閲覧',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textWhite,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
