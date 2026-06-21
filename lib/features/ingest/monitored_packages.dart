/// Finance-app detection for notification capture. Any bank, wallet, UPI, or
/// payment app should match via [keywords] or [ids]. Keep aligned with
/// [IngestPlugin.kt] on Android.
abstract final class MonitoredPackages {
  /// System / social apps — never capture.
  static const excludedPrefixes = [
    'com.android.systemui',
    'com.android.settings',
    'com.android.vending',
    'com.android.chrome',
    'com.google.android.apps.messaging',
    'com.google.android.youtube',
    'com.google.android.dialer',
    'com.google.android.apps.maps',
    'com.google.android.calendar',
    'com.samsung.android.messaging',
    'com.samsung.android.app.health',
    'com.facebook.',
    'com.instagram.',
    'com.twitter.',
    'com.zhiliaoapp.musically', // TikTok
    'com.spotify.',
    'com.netflix.',
    'com.discord',
    'com.snapchat.',
    'com.reddit.',
    'com.linkedin.',
    'com.careem.',
    'in.swiggy.',
    'com.application.zomato',
    'com.foodpanda.',
    'com.flipkart.',
    'com.miui.home',
  ];

  /// Email clients — capture only when notification text looks like a txn.
  static const emailClientPrefixes = [
    'com.google.android.gm',
  ];

  /// Explicit package ids — Google Wallet, global wallets, major banks.
  static const ids = {
    // Google Pay / Wallet
    'com.google.android.apps.nbu.paisa.user',
    'com.google.android.apps.nbu.paisa',
    'com.google.android.apps.walletnfcrel',
    'com.google.commerce.tapandpay',
    // India UPI & wallets
    'com.phonepe.app',
    'net.one97.paytm',
    'in.org.npci.upiapp',
    'com.dreamplug.androidapp',
    'com.whatsapp',
    'com.amazon.mShop.android.shopping',
    // India banks
    'com.csam.icici.bank.imobile',
    'com.sbi.lotusintouch',
    'com.sbi.SBIFreedomPlus',
    'com.axis.mobile',
    'com.hdfcbank.android.now',
    'com.snapwork.hdfc',
    'com.bankofbaroda.mconnect',
    'com.fss.pnbpsp',
    'com.kotak.mobile',
    'com.konylabs.cbplpat',
    'com.YES.YESbank',
    'com.idbibank.mpassbook',
    'com.infrasofttech.indianbank',
    'com.canarabank.mobility',
    'com.rblbank.mobbanking',
    'com.indusind.mobilebanking',
    'com.federalbank.mobile',
    'com.unionbankofindia.mobilebanking',
    'com.centralbank.mobile',
    // Global wallets
    'com.paypal.android.p2pmobile',
    'com.squareup.cash',
    'com.venmo',
    'com.revolut.revolut',
    'com.transferwise.android',
    'com.wise.android',
    'com.samsung.android.spay',
    'com.samsung.android.spaylite',
    'com.chase.sig.android',
    'com.wf.wellsfargomobile',
    'com.bankofamerica.cashpromobile',
    'com.citi.citimobile',
    'com.usabank.mobilebanking',
    'com.capitalone.mobile',
    'com.starlingbank.android',
    'com.monzo',
    'com.n26',
    // Pakistan banks & wallets
    'app.com.brd',
    'com.ubluk.dc',
    'com.techlogix.mobilinkcustomer',
    'pk.com.telenor.phoenix',
    'com.sadaPay.sadaPay',
    'com.sadapay.app',
    'com.nayapay.app',
    'com.hbl.android.hblmobilebanking',
    'com.mcb.mobile',
    'com.mcb.mobilebanking',
    'com.bankalfalah',
    'com.alfalah.mobile',
    'com.meezanbank.mobile',
    'com.faysalbank.mobile',
    'com.sc.mobilebanking.pk',
    'com.askari.mobile',
    'com.standardchartered.mobile',
    'com.bop.mobilebanking',
    // Digital Islamic / newer PK banks
    'com.raqamidigital.cbt',
    'com.bopdigital.bop',
  };

  /// Substrings in package names that indicate a bank / wallet / payment app.
  static const keywords = [
    'bank',
    'banking',
    'wallet',
    'walletnfcrel',
    'upi',
    'finance',
    'financial',
    'mobilebank',
    'passbook',
    'paisa',
    'gpay',
    'tapandpay',
    'nfc',
    'paytm',
    'phonepe',
    'bhim',
    'hdfc',
    'icici',
    'sbi',
    'axis',
    'kotak',
    'yesbank',
    'idbi',
    'pnb',
    'baroda',
    'canara',
    'rbl',
    'indus',
    'federal',
    'razorpay',
    'payu',
    'mobikwik',
    'freecharge',
    'cred',
    'paypal',
    'venmo',
    'cashapp',
    'squareup',
    'revolut',
    'transferwise',
    'stripe',
    'remit',
    'remittance',
    'spay',
    'ubl',
    'brd',
    'jazzcash',
    'mobilink',
    'easypaisa',
    'sadapay',
    'nayapay',
    'alfalah',
    'hbl',
    'mcb',
    'meezan',
    'faysal',
    'chase',
    'wellsfargo',
    'citibank',
    'citi',
    'monzo',
    'starling',
    // Pakistan — catch-all for wallet / digital bank package names
    'raqami',
    'raqamidigital',
    'telenor',
    'phoenix',
    'mobilink',
    'pk.',
    '.pk',
    'fintech',
    'ewallet',
    'zelle',
    'wise',
    'mpesa',
    'momo',
  ];

  static bool isExcluded(String? packageName) {
    if (packageName == null || packageName.isEmpty) return false;
    final pkg = packageName.toLowerCase();
    for (final prefix in excludedPrefixes) {
      if (pkg == prefix || pkg.startsWith('$prefix')) return true;
    }
    return false;
  }

  static bool isEmailClient(String? packageName) {
    if (packageName == null || packageName.isEmpty) return false;
    final pkg = packageName.toLowerCase();
    for (final prefix in emailClientPrefixes) {
      if (pkg == prefix || pkg.startsWith('$prefix')) return true;
    }
    return false;
  }

  /// True for any bank, wallet, UPI, or payment app notification source.
  static bool matches(String? packageName) {
    if (packageName == null || packageName.isEmpty) return false;
    if (isExcluded(packageName)) return false;
    if (isEmailClient(packageName)) return false;
    final pkg = packageName.toLowerCase();
    for (final id in ids) {
      if (pkg.contains(id.toLowerCase())) return true;
    }
    for (final kw in keywords) {
      if (pkg.contains(kw)) return true;
    }
    return false;
  }
}
