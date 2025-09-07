import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medicalguideline/provider/pdf_provider.dart';
import 'package:pdfx/pdfx.dart';
import '../../widgets/pdf/error_view.dart';
import '../../widgets/pdf/jump_fab.dart';

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
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('2025年改訂版', style: TextStyle(fontSize: 12)),
            // 表示タイトルとして pdfPath を流用（必要に応じて任意の文字列に）
            Text('心不全診療ガイドライン', style: const TextStyle(fontSize: 16)),
          ],
        ),
        actions: [
          if (_pageCount > 0)
            Text(
              '$_currentPage/$_pageCount',
              style: const TextStyle(fontSize: 12),
            ),
          const SizedBox(width: 12),
        ],
      ),
      body: asyncDoc.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(error: e),
        data: (doc) {
          // PdfControllerPinch を一度だけ生成（docが変わるケースは今は想定しない）
          _controller ??= PdfControllerPinch(
            document: Future.value(doc),
            initialPage: _normalizeInitialPage(widget.initialPage),
          );

          return PdfViewPinch(
            controller: _controller!,
            onDocumentLoaded: (loadedDoc) async {
              // 総ページ数は初期表示のブロックを避けるため後追いで取得
              final count = await loadedDoc.pagesCount;
              if (mounted) {
                setState(() {
                  _pageCount = count;
                  // initialPage が総ページ超過だった場合、ここで一度だけ補正ジャンプしてもOK
                  final init = _normalizeInitialPage(widget.initialPage);
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
              if (mounted) setState(() => _currentPage = page);
            },
          );
        },
      ),
      floatingActionButton: (_controller != null && (_pageCount > 0))
          ? JumpFab(
              onFirst: () => _jumpTo(1),
              onPrev: () => _jumpTo(_currentPage - 1),
              onNext: () => _jumpTo(_currentPage + 1),
              onLast: () => _jumpTo(_pageCount),
              onBackToInitial: () {
                final initial = _normalizeInitialPage(widget.initialPage);
                _jumpTo(initial);
              },
              showBackToInitial: (widget.initialPage != null),
            )
          : null,
    );
  }
}
