import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../utils/colors.dart';
import '../../widgets/common/glass_container.dart';
import '../../widgets/common/liquid_background.dart';
import '../../widgets/common/back_button.dart';
import '../../widgets/setting/username_input.dart';
import '../../widgets/setting/department_selector.dart';
import '../../provider/auth_provider.dart';
import '../../services/firestore_service.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final Set<String> _selectedSpecialties = <String>{};
  final FirestoreService _firestoreService = FirestoreService();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentUserData();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUserData() async {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser != null) {
      try {
        final userData = await _firestoreService.getUser(currentUser.uid);
        if (userData != null) {
          setState(() {
            _usernameController.text = userData.displayName ?? '';
            _selectedSpecialties.clear();
            if (userData.specialties != null) {
              _selectedSpecialties.addAll(userData.specialties!);
            }
            _isLoading = false;
          });
        } else {
          setState(() {
            _isLoading = false;
          });
        }
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('ユーザー情報の読み込みに失敗しました: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _handleSave() async {
    if (_formKey.currentState!.validate()) {
      final currentUser = ref.read(currentUserProvider);
      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ユーザーがログインしていません'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      try {
        // ローディング表示
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) =>
              const Center(child: CircularProgressIndicator()),
        );

        final selectedSpecialtiesList = _selectedSpecialties.toList();

        // Firestoreに更新データを保存
        await _firestoreService.updateUser(currentUser.uid, {
          'displayName': _usernameController.text.trim(),
          'specialties': selectedSpecialtiesList,
        });

        // ダイアログを閉じる
        if (mounted) {
          Navigator.of(context).pop();

          // 成功メッセージを表示
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'プロファイルを更新しました\n選択された専門領域: ${selectedSpecialtiesList.join(', ')}',
              ),
              backgroundColor: AppColors.successGreen,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } catch (e) {
        // ダイアログを閉じる
        if (mounted) {
          Navigator.of(context).pop();

          // エラーメッセージを表示
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('プロファイルの更新に失敗しました: $e'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      }
    }
  }

  void _toggleSpecialty(String specialty) {
    setState(() {
      if (_selectedSpecialties.contains(specialty)) {
        _selectedSpecialties.remove(specialty);
      } else {
        _selectedSpecialties.add(specialty);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LiquidBackground(
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: GlassContainer(
                          blur: 15,
                          opacity: 0.1,
                          child: Form(
                            key: _formKey,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text(
                                  'プロフィール情報',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 32),
                                UsernameInput(controller: _usernameController),
                                const SizedBox(height: 24),
                                DepartmentSelector(
                                  selectedDepartments: _selectedSpecialties,
                                  onDepartmentToggle: _toggleSpecialty,
                                ),
                                const SizedBox(height: 32),
                                ElevatedButton(
                                  onPressed: _handleSave,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white.withOpacity(
                                      0.3,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: const Text(
                                    '保存',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
              ),
              // 戻るボタン
              const Positioned(top: 20, left: 16, child: CustomBackButton()),
            ],
          ),
        ),
      ),
    );
  }
}
