/// Package ids / keywords for known bank & wallet apps. Keep aligned with
/// [IngestPlugin.kt] on Android so capture-time and parse-time filters match.
abstract final class MonitoredPackages {
  static const ids = {
    'com.google.android.apps.nbu.paisa.user',
    'com.phonepe.app',
    'net.one97.paytm',
    'in.org.npci.upiapp',
    'com.dreamplug.androidapp',
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
    'com.amazon.mShop.android.shopping',
    'com.whatsapp',
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
  };

  static const keywords = [
    'bank',
    'upi',
    'wallet',
    'paytm',
    'phonepe',
    'bhim',
    'gpay',
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
    'paisa',
    'razorpay',
    'payu',
    'mobikwik',
    'freecharge',
    'cred',
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
  ];

  static bool matches(String? packageName) {
    if (packageName == null || packageName.isEmpty) return false;
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
