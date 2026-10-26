/// Documents what HISAAB stores locally and what (if anything) leaves the device.
abstract final class LocalDataPolicy {
  static const headline = 'Your data stays on this phone';

  static const summary =
      'Transactions, categories, and preferences are saved automatically in a '
      'local database on your phone. HISAAB has no account and no server. '
      'Your phone\'s backup can include that database so a reinstall brings '
      'your transactions back.';

  static const storedLocally = [
    'Parsed transactions (amount, merchant, category, date)',
    'Optional raw alert text used for review in the app',
    'App preferences (budget, account name for self-transfer detection)',
  ];

  static const neverUploaded = [
    'SMS or notification content to a HISAAB server',
    'Contacts or personal chats',
  ];

  static const userControlledExit = [
    'Phone backup — the database is included so a reinstall can restore it',
    'Restore backup — load a file you already saved',
  ];

  static const thirdPartyNetwork = [
    'Google Fonts may download font files (no personal data)',
  ];
}
