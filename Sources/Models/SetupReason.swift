import Foundation

/// First-launch / configuration state (not a network fetch failure).
enum SetupReason: Equatable {
    /// No key in env / OpenClaw paths.
    case missingAPIKey
    /// Key present but does not look like a Token Plan key.
    case invalidTokenPlanKeyFormat
}
