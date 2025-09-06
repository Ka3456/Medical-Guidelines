import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

/// =========================
/// Citation meta + parser
/// =========================
class CitationMeta {
  final int page; // 1-based
  final int chunk;
  final String? section;
  final double? score;
  final String? content;

  const CitationMeta({
    required this.page,
    required this.chunk,
    this.section,
    this.score,
    this.content,
  });
}

final _rePageChunk = RegExp(r'ページ\s*(\d+)\s*,\s*チャンク\s*(\d+)', multiLine: true);
final _reSection = RegExp(r'関連章:\s*([^\n\r]+)');
final _reScore = RegExp(r'関連度:\s*([0-9.]+)');
final _reContent = RegExp(r'内容:\s*(.+)$', multiLine: true);

CitationMeta parseCitation(String raw) {
  final m = _rePageChunk.firstMatch(raw);
  if (m == null) {
    throw const FormatException('ページ/チャンク行を解釈できません');
  }
  final page = int.parse(m.group(1)!);
  final chunk = int.parse(m.group(2)!);

  String? section;
  final ms = _reSection.firstMatch(raw);
  if (ms != null) section = ms.group(1)!.trim();

  double? score;
  final msc = _reScore.firstMatch(raw);
  if (msc != null) score = double.tryParse(msc.group(1)!.trim());

  String? content;
  final mc = _reContent.firstMatch(raw);
  if (mc != null) content = mc.group(1)!.trim();

  return CitationMeta(
    page: page,
    chunk: chunk,
    section: section,
    score: score,
    content: content,
  );
}

/// =========================
/// PDF Screen with jump-to-page
/// =========================
class PdfScreen extends StatefulWidget {
  /// Either provide [pdfPath], or provide [docId] + [version] so the screen

  final String? pdfPath;
  final String? docId;
  final String? version;

  /// Initial jump target.
  final int? initialPage; // 1-based
  final int? initialChunk; // optional, for UI badge

  /// Raw citation text. If present, it will be parsed and override
  /// [initialPage]/[initialChunk] if those are null.
  final String? initialCitationRaw;

  const PdfScreen({
    super.key,
    this.pdfPath,
    this.docId,
    this.version,
    this.initialPage,
    this.initialChunk,
    this.initialCitationRaw,
  }) : assert(
         pdfPath != null || (docId != null && version != null),
         'Provide either pdfPath, or (docId + version).',
       );

  /// Factory for convenience when you only have the raw citation string.
  factory PdfScreen.fromCitation({
    required String citationRaw,
    String? pdfPath,
    String? docId,
    String? version,
    Key? key,
  }) {
    final meta = parseCitation(citationRaw);
    return PdfScreen(
      key: key,
      pdfPath: pdfPath,
      docId: docId,
      version: version,
      initialPage: meta.page,
      initialChunk: meta.chunk,
      initialCitationRaw: citationRaw,
    );
  }

  @override
  State<PdfScreen> createState() => _PdfScreenState();
}

class _PdfScreenState extends State<PdfScreen> {
  PdfControllerPinch? _controller;
  String? _resolvedPath;
  int _targetPage = 1;
  int _targetChunk = 0;
  String? _sectionTitle;
  String? _snippet;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      // Determine target page from provided fields or citation.
      if (widget.initialPage != null) _targetPage = widget.initialPage!;
      if (widget.initialChunk != null) _targetChunk = widget.initialChunk!;

      if (widget.initialCitationRaw != null) {
        try {
          final meta = parseCitation(widget.initialCitationRaw!);
          _targetPage = widget.initialPage ?? meta.page;
          _targetChunk = widget.initialChunk ?? meta.chunk;
          _sectionTitle = meta.section;
          _snippet = meta.content;
        } catch (_) {
          // ignore parse errors; fallback to provided page.
        }
      }

      // Resolve PDF path.
      final path =
          widget.pdfPath ??
          await resolvePdfPath(docId: widget.docId!, version: widget.version!);
      _resolvedPath = path;

      // Create controller.
      final controller = PdfControllerPinch(
        document: path.startsWith('assets/')
            ? PdfDocument.openAsset(path)
            : PdfDocument.openFile(path),
        initialPage: _targetPage.clamp(1, 100000),
      );

      setState(() => _controller = controller);

      // Optionally: ensure jump after first frame (for safety)
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 150));
        if (mounted && _controller != null) {
          _controller!.jumpToPage(_targetPage);
        }
      });
    } catch (e) {
      // Handle PDF file not found or other errors
      setState(() {
        _resolvedPath = null;
        _controller = null;
      });

      // Show error dialog
      if (mounted) {
        _showErrorDialog(e.toString());
      }
    }
  }

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('PDFファイルの読み込みエラー'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('PDFファイルの読み込み中にエラーが発生しました。'),
            const SizedBox(height: 8),
            const Text('使用中のファイル:'),
            const SizedBox(height: 4),
            const Text('• assets/pdfs/HF.pdf'),
            const SizedBox(height: 8),
            const Text('エラー詳細:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              error,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = _controller;
    final path = _resolvedPath;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _sectionTitle == null
              ? 'ページ $_targetPage'
              : '${_sectionTitle!} | p.$_targetPage',
        ),
        actions: [
          if (path != null)
            IconButton(
              tooltip: '再ジャンプ',
              icon: const Icon(Icons.my_location),
              onPressed: () => ctrl?.jumpToPage(_targetPage),
            ),
        ],
      ),
      body: path == null || ctrl == null
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'PDFファイルを読み込み中...',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            )
          : Stack(
              children: [
                PdfViewPinch(controller: ctrl),
                // Simple badge for chunk info / snippet
                Positioned(
                  top: 12,
                  right: 12,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.45),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Chunk $_targetChunk',
                            style: const TextStyle(color: Colors.white),
                          ),
                          if (_snippet != null)
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 260),
                              child: Text(
                                _snippet!,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
      floatingActionButton: (_resolvedPath != null && _controller != null)
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.arrow_downward),
              label: const Text('該当ページへ'),
              onPressed: () => _controller!.jumpToPage(_targetPage),
            )
          : null,
    );
  }
}

/// =========================
/// PDF resolver (assets or local path)
/// =========================
Future<String> resolvePdfPath({
  required String docId,
  required String version,
}) async {
  // First, try to find the file in assets
  const assetPath = 'assets/pdfs/HF.pdf';

  // Return asset path as default
  return assetPath;
}

/// =========================
/// Example: how to navigate here
/// =========================
void openPdfFromCitation(
  BuildContext context, {
  required String citationRaw,
  String? localPdfPath,
  String? docId,
  String? version,
}) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => PdfScreen.fromCitation(
        citationRaw: citationRaw,
        pdfPath: localPdfPath,
        docId: docId,
        version: version,
      ),
    ),
  );
}
