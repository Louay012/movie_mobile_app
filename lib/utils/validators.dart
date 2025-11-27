class FormValidators {
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please Enter Your Email';
    }
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
      return 'Please Enter a Valid Email';
    }
    return null;
  }

  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please Enter Your Password';
    }
    if (value.length < 6) {
      return 'Password Must Be At Least 6 Characters';
    }
    return null;
  }

  static String? validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please Enter Your Name';
    }
    if (value.trim().length < 2) {
      return 'Name Must Be At Least 2 Characters';
    }
    return null;
  }

  static String? validateAge(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please Enter Your Age';
    }
    final age = int.tryParse(value);
    if (age == null || age < 13) {
      return 'You Must Be At Least 13 Years Old';
    }
    return null;
  }

  static String? validateDateFormat(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please Enter Your Birth Date';
    }
    // Check format dd/mm/yyyy
    final regex = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$');
    if (!regex.hasMatch(value)) {
      return 'Invalid Date Format (dd/mm/yyyy)';
    }
    return null;
  }

  static DateTime? parseDateFromDDMMYYYY(String value) {
    final regex = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$');
    final match = regex.firstMatch(value);
    if (match == null) return null;
    
    final day = int.tryParse(match.group(1)!);
    final month = int.tryParse(match.group(2)!);
    final year = int.tryParse(match.group(3)!);
    
    if (day == null || month == null || year == null) return null;
    if (day < 1 || day > 31 || month < 1 || month > 12) return null;
    
    try {
      final date = DateTime(year, month, day);
      // Validate the date is real (e.g., not Feb 30)
      if (date.day != day || date.month != month || date.year != year) {
        return null;
      }
      // Validate date is not in the future
      if (date.isAfter(DateTime.now())) {
        return null;
      }
      return date;
    } catch (e) {
      return null;
    }
  }
}
