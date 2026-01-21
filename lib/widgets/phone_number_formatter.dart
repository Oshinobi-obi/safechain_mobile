import 'package:flutter/services.dart';

class PhoneNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue, 
    TextEditingValue newValue
  ) {
    final text = newValue.text.replaceAll(RegExp(r'\D'), '');
    var formatted = '';
    if (text.length <= 3) {
      formatted = text;
    } else if (text.length <= 6) {
      formatted = '${text.substring(0, 3)}-${text.substring(3)}';
    } else if (text.length <= 10) {
      formatted = '${text.substring(0, 3)}-${text.substring(3, 6)}-${text.substring(6)}';
    }

    // If the text is longer than 10 digits, cap it.
    if (text.length > 10) {
      formatted = '${text.substring(0, 3)}-${text.substring(3, 6)}-${text.substring(6, 10)}';
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
