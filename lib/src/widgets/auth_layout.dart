import 'dart:math' as math;

import 'package:flutter/material.dart';

class AuthViewport extends StatelessWidget {
  const AuthViewport({super.key, this.maxWidth = 420, required this.builder});

  final double maxWidth;
  final Widget Function(bool compactHeight) builder;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compactHeight = constraints.maxHeight < 640;
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: compactHeight ? 12 : 20,
                    ),
                    child: builder(compactHeight),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class PinKeypad extends StatelessWidget {
  const PinKeypad({
    super.key,
    required this.compactHeight,
    required this.onDigit,
    required this.onBackspace,
    this.showBiometric = false,
    this.onBiometric,
  });

  final bool compactHeight;
  final ValueChanged<String>? onDigit;
  final VoidCallback? onBackspace;
  final bool showBiometric;
  final VoidCallback? onBiometric;

  static const _digitRows = [
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxSize = compactHeight ? 56.0 : 72.0;
        final buttonSize = math.min(maxSize, constraints.maxWidth / 3);
        final rowSpacing = compactHeight ? 6.0 : 10.0;
        final buttonStyle = FilledButton.styleFrom(
          shape: const CircleBorder(),
          padding: EdgeInsets.zero,
          backgroundColor: Colors.grey.shade100,
          foregroundColor: Colors.black87,
          elevation: 0,
        );

        Widget keyButton(Widget label, VoidCallback? onPressed) {
          return SizedBox.square(
            dimension: buttonSize,
            child: FilledButton(
              onPressed: onPressed,
              style: buttonStyle,
              child: FittedBox(fit: BoxFit.scaleDown, child: label),
            ),
          );
        }

        final digitPressed = onDigit;
        Widget digitKey(String digit) {
          return keyButton(
            Text(
              digit,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w500),
            ),
            digitPressed == null ? null : () => digitPressed(digit),
          );
        }

        return Column(
          children: [
            for (final digits in _digitRows) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: digits.map(digitKey).toList(),
              ),
              SizedBox(height: rowSpacing),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (showBiometric)
                  keyButton(
                    const Icon(Icons.fingerprint, semanticLabel: 'Биометрия'),
                    onBiometric,
                  )
                else
                  SizedBox.square(dimension: buttonSize),
                digitKey('0'),
                keyButton(
                  const Icon(
                    Icons.backspace_outlined,
                    semanticLabel: 'Удалить цифру',
                  ),
                  onBackspace,
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
