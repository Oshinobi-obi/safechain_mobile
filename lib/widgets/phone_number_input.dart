import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PhoneNumberInput extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;

  const PhoneNumberInput({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.phone,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(10),
        _PhoneNumberFormatter(),
      ],
      decoration: InputDecoration(
        alignLabelWithHint: true,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        label: _buildRequiredLabel(label),
        hintText: hint,
        prefix: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('images/philippine_flag.png', height: 24, width: 24),
            const SizedBox(width: 8),
            const Text('+63 |', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
          ],
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'This field cannot be empty';
        }
        if (value.replaceAll('-', '').length != 10) {
          return 'Please enter a valid 10-digit number';
        }
        return null;
      },
    );
  }

  RichText _buildRequiredLabel(String label) {
    return RichText(
      text: TextSpan(
        text: label,
        style: TextStyle(color: Colors.grey[600], fontSize: 16),
        children: const <TextSpan>[
          TextSpan(text: ' *', style: TextStyle(color: Colors.red)),
        ],
      ),
    );
  }
}

class _PhoneNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (newValue.selection.baseOffset == 0) {
      return newValue;
    }

    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      if ((i == 2 || i == 5) && i != text.length - 1) {
        buffer.write('-');
      }
    }

    String newText = buffer.toString();
    return newValue.copyWith(
        text: newText,
        selection: TextSelection.collapsed(offset: newText.length));
  }
}