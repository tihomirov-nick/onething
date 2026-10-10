import Foundation
import OneThingCore

/// Settings kept in memory: the tests try the app's settings without a preference file on the disk. Numbers are stored
/// as NSNumber, as UserDefaults stores them.
final class MemoryStore: KeyValueStore {
    private var values: [String: Any] = [:]

    func object(forKey key: String) -> Any? { values[key] }
    func string(forKey key: String) -> String? { values[key] as? String }
    func bool(forKey key: String) -> Bool { (values[key] as? NSNumber)?.boolValue ?? false }

    func set(_ value: Any?, forKey key: String) {
        guard let value else { return removeObject(forKey: key) }
        switch value {
        case let int as Int: values[key] = NSNumber(value: int)
        case let double as Double: values[key] = NSNumber(value: double)
        case let bool as Bool: values[key] = NSNumber(value: bool)
        default: values[key] = value
        }
    }

    func removeObject(forKey key: String) { values[key] = nil }
}
