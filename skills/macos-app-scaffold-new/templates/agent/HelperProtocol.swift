import Foundation

/// Shared XPC protocol. Compile this file into BOTH the app target and the
/// helper target. Adding a method here without updating both sides will fail
/// silently at runtime (the connection invalidates instead of throwing).
///
/// Rules:
/// - Every method must have a `@escaping` reply handler OR be marked `oneway`.
/// - Argument and return types must conform to `NSSecureCoding`.
/// - Custom types must be allowed via `setClasses(_:for:)` on the interface.
@objc public protocol HelperProtocol {
    /// Smoke test. Returns the helper's pid so the caller can verify it ran
    /// out-of-process.
    func ping(reply: @escaping (Int32) -> Void)

    /// Example of a real method. Replace with whatever your helper does.
    func performWork(input: String, reply: @escaping (String) -> Void)
}

/// Mach service name. Must match the `MachServices` key in the launchd plist
/// AND the `plistName` passed to `SMAppService.agent(plistName:)`.
///
/// Convention: same string as the helper bundle identifier.
public enum HelperConstants {
    public static let machServiceName = "{{HelperBundleID}}"
}
