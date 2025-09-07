import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medicalguideline/firebase_options.dart';
import 'package:medicalguideline/provider/pdf_provider.dart';
import 'screens/chat_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Riverpod のスコープを張る
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});
  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  @override
  void initState() {
    super.initState();
    // 初回フレーム描画が終わって UI が安定したタイミングでウォームアップ開始
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // これにより preopenedPdfProvider がバックグラウンドで始動し、
      // 以後どの画面でも .watch/.read で即利用できる可能性が高まる
      // （await はしない＝UIブロックしない）
      ref.read(preopenedPdfProvider.future);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Medical Guideline AI',
      debugShowCheckedModeBanner: false,
      home: const ChatScreen(),
    );
  }
}
