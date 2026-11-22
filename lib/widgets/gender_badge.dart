import 'package:flutter/material.dart';

import '../services/dewiktionary_parser.dart' show articleFor;

/// der = blue, die = red, das = green (a common learner convention).
Color genderColor(String g) => switch (g) {
  'm' => const Color(0xFF1E6FD9),
  'f' => const Color(0xFFD7263D),
  'n' => const Color(0xFF2E9E44),
  _ => Colors.grey,
};

class GenderBadge extends StatelessWidget {
  final String gender;
  final TextStyle? style;
  const GenderBadge(this.gender, {super.key, this.style});

  @override
  Widget build(BuildContext context) {
    final base = style ?? Theme.of(context).textTheme.titleMedium;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: genderColor(gender),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        articleFor(gender),
        style: base?.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
      ),
    );
  }
}
