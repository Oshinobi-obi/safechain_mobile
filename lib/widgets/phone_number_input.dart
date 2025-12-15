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
      autovalidateMode: AutovalidateMode.onUserInteraction,
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
    final String digitsOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    final int textLength = digitsOnly.length;

    if (textLength == 0) {
      return const TextEditingValue();
    }

    final StringBuffer buffer = StringBuffer();
    if (textLength > 0) {
      buffer.write(digitsOnly.substring(0, textLength.clamp(0, 3)));
    }
    if (textLength > 3) {
      buffer.write('-');
      buffer.write(digitsOnly.substring(3, textLength.clamp(3, 6)));
    }
    if (textLength > 6) {
      buffer.write('-');
      buffer.write(digitsOnly.substring(6, textLength.clamp(6, 10)));
    }
    
    String newText = buffer.toString();
    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}
