// main.dart
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfx/pdfx.dart'; // ← pdfx を使用している前提。別パッケージなら適宜置換

const String kPdfPath = 'assets/pdfs/HF.pdf';

/// PDFのパス（将来差し替えやすいようProvider化）
final pdfPathProvider = Provider<String>((_) => kPdfPath);

/// 起動直後に一度だけ PDF をオープンして保持するプロバイダ
/// （初回パースの“待ち”を、画面遷移前に済ませる）
final preopenedPdfProvider = FutureProvider<PdfDocument>((ref) async {
  final path = ref.watch(pdfPathProvider);
  // http/https は非対応ポリシーを踏襲
  if (path.startsWith('http://') || path.startsWith('https://')) {
    throw Exception('HTTP/HTTPSのPDFには対応していません: $path');
  }

  // assets or file を判定してオープン
  if (path.startsWith('assets/')) {
    final data = await rootBundle.load(path);
    final bytes = data.buffer.asUint8List();
    return PdfDocument.openData(bytes);
  } else {
    final file = File(path);
    if (!await file.exists()) {
      throw Exception('PDFが見つかりません: $path');
    }
    return PdfDocument.openFile(file.path);
  }
});
