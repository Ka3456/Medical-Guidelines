import 'package:flutter/material.dart';

class DepartmentSelector extends StatelessWidget {
  final Set<String> selectedDepartments;
  final Function(String) onDepartmentToggle;

  const DepartmentSelector({
    super.key,
    required this.selectedDepartments,
    required this.onDepartmentToggle,
  });

  static const Map<String, List<String>> _departmentCategories = {
    '学生・研修医': ['学生', '初期研修医', '後期研修医'],
    '内科系': [
      '総合内科',
      '循環器内科',
      '呼吸器内科',
      '消化器内科',
      '腎臓・内分泌内科',
      '糖尿病・代謝内科',
      '血液・腫瘍内科',
      'アレルギー・リウマチ内科',
      '感染症内科',
      '脳神経内科',
      '老年病科',
      '心療内科',
    ],
    '外科系': [
      '一般外科',
      '胃・食道外科',
      '大腸・肛門外科',
      '肝・胆・膵外科',
      '血管外科',
      '乳腺・内分泌外科',
      '人工臓器・移植外科',
      '心臓外科',
      '呼吸器外科',
      '脳神経外科',
      '麻酔科',
      '麻酔科・痛みセンター',
      '泌尿器科・男性科',
      '女性外科',
    ],
    '感覚・運動系': [
      '皮膚科',
      '眼科',
      '整形外科・脊椎外科',
      '耳鼻咽喉科・頭頸部外科',
      'リハビリテーション科',
      '形成外科・美容外科',
      '口腔顎顔面外科・矯正歯科',
    ],
    '小児・女性系': ['小児科', '小児外科', '女性診療科・産科'],
    'その他': ['精神神経科', '放射線科', '救急科', '救急・集中治療科', '臨床腫瘍科（消化器）', '病理診断科'],
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'あなたの診療科',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${selectedDepartments.length}個選択中',
                style: TextStyle(
                  color: Colors.blue.shade700,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'AIの回答を最適化するために使います',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 12),
        ..._departmentCategories.entries.map((category) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.blue.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  category.key,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.blue.shade700,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: category.value.map((String department) {
                  final isSelected = selectedDepartments.contains(department);
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    child: GestureDetector(
                      onTap: () => onDepartmentToggle(department),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: isSelected
                                ? [
                                    Colors.white.withOpacity(0.8),
                                    Colors.white.withOpacity(0.6),
                                  ]
                                : [
                                    Colors.white.withOpacity(0.2),
                                    Colors.white.withOpacity(0.1),
                                  ],
                          ),
                          border: Border.all(
                            color: isSelected
                                ? Colors.white.withOpacity(0.9)
                                : Colors.white.withOpacity(0.3),
                            width: isSelected ? 2 : 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isSelected
                                  ? Colors.black.withOpacity(0.15)
                                  : Colors.black.withOpacity(0.08),
                              blurRadius: isSelected ? 12 : 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isSelected) ...[
                              Icon(
                                Icons.check_circle,
                                size: 14,
                                color: Colors.blue.shade700,
                              ),
                              const SizedBox(width: 4),
                            ],
                            Text(
                              department,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                color: isSelected
                                    ? Colors.black
                                    : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],
          );
        }).toList(),
      ],
    );
  }
}
