import Foundation

/// Lets the phone's backup include the spending database so a restore of the
/// phone can bring transactions back. The flag is cleared on every launch
/// because older builds marked the file as excluded.
enum LocalStore {
  static func includeSqliteInBackup() {
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
      values.isExcludedFromBackup = false
      try? url.setResourceValues(values)
    }
  }
}
