/// Replace with your Google Cloud OAuth client IDs before shipping.
abstract final class GmailConfig {
  /// Web client ID from Google Cloud Console (required for Android Gmail scope).
  static const String serverClientId =
      'YOUR_WEB_CLIENT_ID.apps.googleusercontent.com';

  /// Transaction alert senders — India banks + PK wallets/banks.
  static const searchQuery =
      'from:(alerts@hdfcbank.com OR noreply@paytm.com OR '
      'no-reply@phonepe.com OR alerts@icicibank.com OR '
      'alerts@sbi.co.in OR statement@axisbank.com OR '
      'alerts@ubl.com OR noreply@hbl.com OR alerts@mcb.com.pk OR '
      'noreply@bankalfalah.com OR no-reply@jazzcash.com OR '
      'noreply@easypaisa.com.pk OR alerts@sadapay.com OR '
      'noreply@nayapay.com) newer_than:30d';
}
