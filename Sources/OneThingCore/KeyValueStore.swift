import Foundation

/// The part of UserDefaults the settings of the app use. The tests keep the settings in memory behind it, so a test run
/// leaves no preference file on the disk.
public protocol KeyValueStore: AnyObject {
    func object(forKey key: String) -> Any?
    func string(forKey key: String) -> String?
    func bool(forKey key: String) -> Bool
    func set(_ value: Any?, forKey key: String)
    func removeObject(forKey key: String)
}

extension UserDefaults: KeyValueStore {}
