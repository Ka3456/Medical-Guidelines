import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medicalguideline/provider/pdf_provider.dart';
import 'package:pdfx/pdfx.dart';
import '../../utils/colors.dart';
import '../../widgets/common/liquid_background.dart';
import '../../widgets/common/glass_container.dart';
import '../../widgets/common/back_button.dart';
import '../../widgets/pdf/error_view.dart';

class PdfScreen extends ConsumerStatefulWidget {
  const PdfScreen({
    super.key,
    required this.pdfPath,
    this.initialPage,
    this.initialChunk, // 受け取るが今は使わない
    this.highRightText,
  });

  final String pdfPath; // いまは表示用ラベル程度に利用（Doc自体はProviderから取得）
  final int? initialPage;
  final int? initialChunk; // 無視
  final String? highRightText;

  @override
  ConsumerState<PdfScreen> createState() => _PdfScreenState();
}

class _PdfScreenState extends ConsumerState<PdfScreen> {
  PdfControllerPinch? _controller;
  int _pageCount = 0;
  int _currentPage = 1;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  // initialPageの簡易正規化（pageCount確定前は最低限の防御だけ）
  int _normalizeInitialPage(int? target) {
    if (target == null) return 1;
    if (target < 1) return 1;
    return target;
  }

  void _jumpTo(int page) {
    if (_controller == null || _pageCount <= 0) return;
    final clamped = page.clamp(1, _pageCount);
    _controller!.jumpToPage(clamped);
    setState(() => _currentPage = clamped);
  }

  @override
  Widget build(BuildContext context) {
    // 事前に温めてある PdfDocument を購読
    final asyncDoc = ref.watch(preopenedPdfProvider);

    return Scaffold(
      body: LiquidBackground(
        child: Stack(
          children: [
            Column(
              children: [
                // カスタムヘッダー
                Padding(
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 20,
                    left: 16.0,
                    right: 16.0,
                    bottom: 20.0,
                  ),
                  child: Row(
                    children: [
                      const CustomBackButton(),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (widget.highRightText != null)
                              Text(
                                widget.highRightText!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            const SizedBox(height: 2),
                            Text(
                              '心不全診療ガイドライン',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // ページカウンター
                      if (_pageCount > 0)
                        GlassContainer(
                          blur: 8,
                          opacity: 0.2,
                          borderRadius: BorderRadius.circular(12),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          child: Text(
                            '$_currentPage/$_pageCount',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        )
                      else
                        const SizedBox(width: 50), // バランス調整
                    ],
                  ),
                ),

                // PDFビューアー（全画面）
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, -5),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                      child: asyncDoc.when(
                        loading: () => Container(
                          width: double.infinity,
                          decoration: const BoxDecoration(color: Colors.white),
                          child: const Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.primaryRed,
                              ),
                            ),
                          ),
                        ),
                        error: (e, _) => Container(
                          width: double.infinity,
                          decoration: const BoxDecoration(color: Colors.white),
                          child: ErrorView(error: e),
                        ),
                        data: (doc) {
                          // PdfControllerPinch を一度だけ生成（docが変わるケースは今は想定しない）
                          _controller ??= PdfControllerPinch(
                            document: Future.value(doc),
                            initialPage: _normalizeInitialPage(
                              widget.initialPage,
                            ),
                          );

                          return Container(
                            width: double.infinity,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                            ),
                            child: PdfViewPinch(
                              controller: _controller!,
                              onDocumentLoaded: (loadedDoc) async {
                                // 総ページ数は初期表示のブロックを避けるため後追いで取得
                                final count = await loadedDoc.pagesCount;
                                if (mounted) {
                                  setState(() {
                                    _pageCount = count;
                                    // initialPage が総ページ超過だった場合、ここで一度だけ補正ジャンプしてもOK
                                    final init = _normalizeInitialPage(
                                      widget.initialPage,
                                    );
                                    if (init > count) {
                                      _currentPage = count;
                                      _controller!.jumpToPage(count);
                                    } else {
                                      _currentPage = init;
                                    }
                                  });
                                }
                              },
                              onPageChanged: (page) {
                                if (mounted)
                                  setState(() => _currentPage = page);
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // ナビゲーションボタン
            if (_controller != null && (_pageCount > 0)) _buildGlassFab(),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassFab() {
    return Positioned(
      bottom: 20,
      left: 0,
      right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          if (widget.initialPage != null)
            _buildCustomFab(
              heroTag: 'fab_init',
              icon: Icons.my_location,
              onPressed: () {
                final initial = _normalizeInitialPage(widget.initialPage);
                _jumpTo(initial);
              },
            ),
          _buildCustomFab(
            heroTag: 'fab_first',
            icon: Icons.first_page,
            onPressed: () => _jumpTo(1),
          ),
          _buildCustomFab(
            heroTag: 'fab_prev',
            icon: Icons.keyboard_arrow_up,
            onPressed: () => _jumpTo(_currentPage - 1),
          ),
          _buildCustomFab(
            heroTag: 'fab_next',
            icon: Icons.keyboard_arrow_down,
            onPressed: () => _jumpTo(_currentPage + 1),
          ),
          _buildCustomFab(
            heroTag: 'fab_last',
            icon: Icons.last_page,
            onPressed: () => _jumpTo(_pageCount),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomFab({
    required String heroTag,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.grey.shade100.withValues(alpha: 0.9),
            Colors.grey.shade200.withValues(alpha: 0.8),
          ],
        ),
        border: Border.all(
          color: Colors.grey.shade300.withValues(alpha: 0.6),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 1,
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.8),
            blurRadius: 20,
            offset: const Offset(0, -4),
            spreadRadius: 1,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(25),
          onTap: onPressed,
          child: SizedBox(
            width: 50,
            height: 50,
            child: Icon(icon, color: Colors.grey.shade800, size: 24),
          ),
        ),
      ),
    );
  }
}
