import 'package:flutter/material.dart';

/// One verse rendered reader-style: a small bold verse number followed by
/// the verse text, in the user's chosen Bible font. Used by the reader and
/// by the settings sample so the preview matches exactly.
class VerseText extends StatelessWidget {
  final int number;
  final String text;
  final String? fontFamily;
  final double fontSize;

  const VerseText({
    super.key,
    required this.number,
    required this.text,
    required this.fontFamily,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$number  ',
            style: TextStyle(
              fontSize: fontSize * 0.7,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          TextSpan(text: text),
        ],
      ),
      style: TextStyle(fontFamily: fontFamily, fontSize: fontSize, height: 1.6),
    );
  }
}
