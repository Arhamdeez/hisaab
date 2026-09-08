import Foundation

/// Matches Android `allowBackup="false"` for spending SQLite (not iCloud).
enum LocalStore {
  static func excludeSqliteFromBackup() {
    let names = [
      "spend_tracker.sqlite",
      "spend_tracker.sqlite-wal",
      "spend_tracker.sqlite-shm",
    ]
    let fm = FileManager.default
    guard let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first else {
      return
    }
    for name in names {
      var url = docs.appendingPathComponent(name)
      guard fm.fileExists(atPath: url.path) else { continue }
      var values = URLResourceValues()
      values.isExcludedFromBackup = true
      try? url.setResourceValues(values)
    }
  }
}
