import 'package:flutter/material.dart';
import 'dart:ui';

class ConversationItemDecoration extends BoxDecoration {
  ConversationItemDecoration({required bool isSelected})
    : super(
        gradient: isSelected
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.6),
                  Colors.white.withValues(alpha: 0.35),
                  Colors.white.withValues(alpha: 0.5),
                ],
                stops: const [0.0, 0.5, 1.0],
              )
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.15),
                  Colors.white.withValues(alpha: 0.08),
                  Colors.white.withValues(alpha: 0.12),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? Colors.white.withValues(alpha: 0.8)
              : Colors.white.withValues(alpha: 0.25),
          width: isSelected ? 2.5 : 1.0,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 40,
                  offset: const Offset(0, 16),
                  spreadRadius: 0,
                ),
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.4),
                  blurRadius: 20,
                  offset: const Offset(-4, -4),
                  spreadRadius: 0,
                ),
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.15),
                  blurRadius: 50,
                  offset: const Offset(0, 25),
                  spreadRadius: 0,
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 15,
                  offset: const Offset(0, 4),
                  spreadRadius: 0,
                ),
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(-1, -1),
                  spreadRadius: 0,
                ),
              ],
      );
}
