import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medicalguideline/firebase_options.dart';
import 'package:medicalguideline/provider/pdf_provider.dart';
import 'package:medicalguideline/provider/auth_provider.dart';
import 'package:medicalguideline/models/auth_result.dart';
import 'package:medicalguideline/screens/auth/login_screen.dart';
import 'package:medicalguideline/screens/chat_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FirebaseFunctions.instanceFor(region: 'asia-northeast1');

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
      ref.read(preopenedPdfProvider.future);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '診療ガイドライン検索',
      debugShowCheckedModeBanner: false,
      home: Consumer(
        builder: (context, ref, child) {
          final authStatus = ref.watch(authStatusProvider);

          // 認証状態の変更をデバッグログで確認
          authStatus.when(
            data: (status) {
              print('メイン画面: 認証状態 - ${status.state}');
            },
            loading: () {
              print('メイン画面: 認証状態読み込み中');
            },
            error: (error, stack) {
              print('メイン画面: 認証状態エラー - $error');
            },
          );

          return authStatus.when(
            data: (status) {

              switch (status.state) {
                case AuthState.authenticated:

                  return const ChatScreen();
                case AuthState.unauthenticated:
                case AuthState.initial:
                case AuthState.error:

                  return const LoginScreen();
                case AuthState.loading:

                  return const Scaffold(
                    body: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text(
                            '認証状態を確認中...',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  );
              }
            },
            loading: () => const Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      '認証状態を確認中...',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
            error: (error, stack) {
              // エラーが発生した場合はログイン画面を表示
              return const LoginScreen();
            },
          );
        },
      ),
    );
  }
}
