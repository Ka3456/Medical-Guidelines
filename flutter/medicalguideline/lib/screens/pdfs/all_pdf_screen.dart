import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import '../../utils/colors.dart';
import '../../widgets/common/liquid_background.dart';
import '../../widgets/common/glass_container.dart';
import '../../widgets/common/back_button.dart';
import 'pdf_screen.dart';

class AllPdfScreen extends StatefulWidget {
  const AllPdfScreen({super.key});

  @override
  State<AllPdfScreen> createState() => _AllPdfScreenState();
}

class _AllPdfScreenState extends State<AllPdfScreen> {
  List<PdfGuideline> _guidelines = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPdfList();
  }

  Future<void> _loadPdfList() async {
    try {
      print('Loading PDF list...');
      final String jsonString = await rootBundle.loadString(
        'assets/pdf/junkanki_title.json',
      );
      print('JSON loaded: ${jsonString.length} characters');

      final Map<String, dynamic> jsonData = json.decode(jsonString);
      final List<dynamic> pdfs = jsonData['pdfs'];
      print('Found ${pdfs.length} PDFs');

      setState(() {
        _guidelines = pdfs
            .map(
              (pdf) => PdfGuideline(
                title: pdf['title'],
                pdfPath: 'assets/pdf/${pdf['name']}',
              ),
            )
            .toList();
        _isLoading = false;
        print('Loaded ${_guidelines.length} guidelines');
      });
    } catch (e, stackTrace) {
      print('Error loading PDF list: $e');
      print('Stack trace: $stackTrace');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: LiquidBackground(
          child: Center(
            child: CircularProgressIndicator(color: AppColors.primaryRed),
          ),
        ),
      );
    }
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
          pdfTitle: guideline.title,
          highRightText: '',
        ),
      ),
    );
  }
}

// PDFガイドラインのデータモデル
class PdfGuideline {
  final String title;
  final String pdfPath;

  const PdfGuideline({required this.title, required this.pdfPath});
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
        child: Text(
          guideline.title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }
}
