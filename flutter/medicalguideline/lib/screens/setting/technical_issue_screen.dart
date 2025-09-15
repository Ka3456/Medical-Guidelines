import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/firestore_service.dart';
import '../../widgets/common/liquid_background.dart';
import '../../widgets/common/back_button.dart';
import '../../widgets/common/liquid_glass_dialog.dart';
import '../../widgets/setting/technical_issue_category_chips.dart';
import '../../widgets/setting/technical_issue_form_fields.dart';

class TechnicalIssueScreen extends ConsumerStatefulWidget {
  const TechnicalIssueScreen({super.key});
  @override
  ConsumerState<TechnicalIssueScreen> createState() =>
      _TechnicalIssueScreenState();
}

class _TechnicalIssueScreenState extends ConsumerState<TechnicalIssueScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _stepsController = TextEditingController();
  final Set<String> _selectedCategories = {'バグ'};
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _stepsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LiquidBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const CustomBackButton(),
                    const Expanded(
                      child: Text(
                        '技術的問題を報告',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 50),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          '問題のカテゴリ',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TechnicalIssueCategoryChips(
                          selectedCategories: _selectedCategories,
                          onCategoryToggle: (category) => setState(() {
                            if (_selectedCategories.contains(category)) {
                              _selectedCategories.remove(category);
                            } else {
                              _selectedCategories.add(category);
                            }
                          }),
                        ),
                        const SizedBox(height: 24),
                        TechnicalIssueFormFields(
                          titleController: _titleController,
                          descriptionController: _descriptionController,
                          stepsController: _stepsController,
                        ),
                        const SizedBox(height: 32),
                        ElevatedButton(
                          onPressed: _isSubmitting ? null : _submitReport,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: _isSubmitting
                              ? const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Text('送信中...'),
                                  ],
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.send, size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      '問題を報告する',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('少なくとも1つのカテゴリを選択してください'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      await FirestoreService().submitTechnicalIssue(
        categories: _selectedCategories.toList(),
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        stepsToReproduce: _stepsController.text.trim(),
      );
      if (mounted) {
        LiquidGlassDialog.show(
          context: context,
          title: '報告完了',
          message: '問題を報告しました。ご協力ありがとうございます。',
          buttonText: 'OK',
          icon: Icons.check_circle,
          iconColor: Colors.green,
          onPressed: () {
            Navigator.of(context).pop();
            Navigator.of(context).pop();
          },
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('報告に失敗しました: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}
