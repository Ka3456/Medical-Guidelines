import 'package:flutter/material.dart';

class JumpFab extends StatelessWidget {
  const JumpFab({
    super.key,
    required this.onFirst,
    required this.onPrev,
    required this.onNext,
    required this.onLast,
    required this.onBackToInitial,
    required this.showBackToInitial,
  });

  final VoidCallback onFirst;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onLast;
  final VoidCallback onBackToInitial;
  final bool showBackToInitial;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      direction: Axis.vertical,
      spacing: 10,
      children: [
        if (showBackToInitial)
          FloatingActionButton.extended(
            heroTag: 'fab_init',
            onPressed: onBackToInitial,
            label: const Text('初期位置へ'),
            icon: const Icon(Icons.my_location),
          ),
        FloatingActionButton.small(
          heroTag: 'fab_first',
          onPressed: onFirst,
          child: const Icon(Icons.first_page),
        ),
        FloatingActionButton.small(
          heroTag: 'fab_prev',
          onPressed: onPrev,
          child: const Icon(Icons.navigate_before),
        ),
        FloatingActionButton.small(
          heroTag: 'fab_next',
          onPressed: onNext,
          child: const Icon(Icons.navigate_next),
        ),
        FloatingActionButton.small(
          heroTag: 'fab_last',
          onPressed: onLast,
          child: const Icon(Icons.last_page),
        ),
      ],
    );
  }
}


