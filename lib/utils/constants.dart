class AppConstants {
  // TMDB API
  static const String tmdbBaseUrl = 'https://api.themoviedb.org/3';
  static const String tmdbImageBaseUrl = 'https://image.tmdb.org/t/p/w500';
  // Add your TMDB API key in environment variables
  static const String tmdbApiKey = 'YOUR_TMDB_API_KEY';

  // Validation
  static const int minPasswordLength = 6;
  static const int minNameLength = 2;

  // Delays
  static const int splashDuration = 3;
}

class AppMessages {
  static const String signupSuccess = 'Account created successfully!';
  static const String loginSuccess = 'Login successful!';
  static const String logoutSuccess = 'Logged out successfully';
  static const String errorOccurred = 'An error occurred. Please try again.';
  static const String invalidEmail = 'Please enter a valid email';
  static const String passwordTooShort =
      'Password must be at least 6 characters';
  static const String nameRequired = 'Please enter your full name';
  static const String ageRequired = 'Please enter your age';
}
