/// Documents what HISAAB stores locally and what (if anything) leaves the device.
abstract final class LocalDataPolicy {
  static const headline = 'Your data stays on this phone';

  static const summary =
      'Transactions, categories, and preferences are stored in a local SQLite '
      'database on your device. HISAAB has no backend server and does not upload '
      'your spending history.';

  static const storedLocally = [
    'Parsed transactions (amount, merchant, category, date)',
    'Optional raw alert text used for review in the app',
    'App preferences (budget, account name for self-transfer detection)',
  ];

  static const neverUploaded = [
    'SMS or notification content',
    'Transaction history',
    'Contacts or personal chats',
  ];

  static const userControlledExit = [
    'Export backup — you choose where the file goes when you share it',
  ];

  static const thirdPartyNetwork = [
    'Google Fonts may download font files (no personal data)',
  ];
}
