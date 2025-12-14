import 'package:flutter/material.dart';

class SafeChainLogo extends StatelessWidget {
  const SafeChainLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: const TextSpan(
        style: TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.bold,
        ),
        children: <TextSpan>[
          TextSpan(
              text: 'SAFE',
              style: TextStyle(color: Color(0xFF20C997))),
          TextSpan(
              text: 'CHAIN', style: TextStyle(color: Colors.black)),
        ],
      ),
    );
  }
}