/// Replace with your Google Cloud OAuth client IDs before shipping.
abstract final class GmailConfig {
  /// Web client ID from Google Cloud Console (required for Android Gmail scope).
  static const String serverClientId =
      'YOUR_WEB_CLIENT_ID.apps.googleusercontent.com';

  static const searchQuery =
      'from:(alerts@hdfcbank.com OR noreply@paytm.com OR '
      'no-reply@phonepe.com OR alerts@icicibank.com OR '
      'alerts@sbi.co.in OR statement@axisbank.com) newer_than:30d';
}
