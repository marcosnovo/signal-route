import Foundation
import Combine

// MARK: - CodeEnvironment

/// Where an unlock code is valid. Evaluated at runtime.
enum CodeEnvironment: String, Codable, CaseIterable {
    /// DEBUG builds only.
    case debug
    /// DEBUG and TestFlight (sandbox receipt) — not App Store production.
    case preRelease
    /// All environments including App Store.
    case production

    /// True when the code is allowed to be used in the current runtime environment.
    var isAllowed: Bool {
        switch self {
        case .production:
            return true
        case .preRelease:
            #if DEBUG
            return true
            #else
            // TestFlight uses a sandbox receipt; App Store uses a production receipt.
            return Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
            #endif
        case .debug:
            #if DEBUG
            return true
            #else
            return false
            #endif
        }
    }

    var label: String {
        switch self {
        case .debug:      return "DEBUG"
        case .preRelease: return "PRE-RELEASE"
        case .production: return "PRODUCTION"
        }
    }
}

// MARK: - UnlockCodeType

/// The effect applied when a code is successfully redeemed.
/// Modelled as an enum so new effects can be added in future without breaking persistence.
enum UnlockCodeType: String, Codable, CaseIterable {
    case fullUnlock

    var label: String {
        switch self {
        case .fullUnlock: return "FULL UNLOCK"
        }
    }
}

// MARK: - UnlockCode

struct UnlockCode: Codable, Identifiable, Equatable {
    var id: String { code }

    /// Normalised key — always stored UPPERCASE, trimmed.
    let code: String
    var type: UnlockCodeType
    var isActive: Bool
    /// Runtime environment where this code is valid. Defaults to `.production` (all).
    var environment: CodeEnvironment = .production

    /// Optional hard expiry. nil = no expiry.
    var expiresAt: Date?
    /// Maximum redemptions. nil = unlimited.
    var maxUses: Int?
    /// How many times this code has been successfully redeemed.
    var usesCount: Int
    /// Developer note (never shown to users).
    var note: String?

    // MARK: - Derived

    var isExpired: Bool {
        guard let exp = expiresAt else { return false }
        return Date() >= exp
    }

    var isExhausted: Bool {
        guard let max = maxUses else { return false }
        return usesCount >= max
    }
}

// MARK: - UnlockCodeStore

/// Manages game unlock codes — separate from DiscountStore (which handles price display only).
///
/// Unlock codes grant real in-game effects (e.g. full premium access) without an App Store
/// purchase. They are intended for press/reviewers, testing, and manual promotions.
///
/// ## Coexistence with StoreKit
///   - If the player already has premium via a real purchase, `activateByCode()` is a no-op
///     from the player's perspective (they remain premium; the source flag is not overwritten).
///   - If a code is applied first, the player is premium via code. A subsequent real purchase
///     simply leaves `isPremium` true and updates the source flag to `purchase`.
///   - `EntitlementStore.checkEntitlements()` (StoreKit restore flow) never clears code premium,
///     so code-granted access persists even after restore attempts.
@MainActor
final class UnlockCodeStore: ObservableObject {

    static let shared = UnlockCodeStore()

    // MARK: - Validation result

    enum ValidationResult: Equatable {
        case valid(UnlockCode)
        case invalid      // code not in catalog
        case inactive     // code exists but isActive == false
        case expired      // code past its expiresAt
        case exhausted    // code reached its maxUses
    }

    // MARK: - Built-in codes (shipped with every build — available to all players)

    /// Add codes here so every player has them.  To retire a code, set `isActive: false`.
    /// The dev menu is useful for testing locally; once confirmed, move the code here.
    static let builtInCodes: [UnlockCode] = [
        UnlockCode(code: "SIGNALRM", type: .fullUnlock, isActive: true,
                   environment: .preRelease,
                   maxUses: nil, usesCount: 0,
                   note: "Full unlock — TestFlight/DEBUG only"),
    ]

    // MARK: - Persistence

    private let storageKey = "unlockCodeStore.codes.v1"

    @Published private(set) var codes: [UnlockCode] = []

    private init() { load() }

    // MARK: - Public API

    /// Validate a code without consuming a use.
    func validate(_ input: String) -> ValidationResult {
        let normalized = input.trimmingCharacters(in: .whitespaces).uppercased()
        guard let code = codes.first(where: { $0.code == normalized }) else {
            return .invalid
        }
        if !code.isActive              { return .inactive }
        if !code.environment.isAllowed { return .inactive }
        if code.isExpired              { return .expired }
        if code.isExhausted            { return .exhausted }
        return .valid(code)
    }

    /// Validate, apply the effect, and increment usesCount. Returns the code on success.
    ///
    /// For `.fullUnlock` codes this calls `EntitlementStore.shared.activateByCode(_:)`,
    /// which sets premium, clears any active cooldown, and cancels cooldown notifications.
    @discardableResult
    func redeem(_ input: String) -> UnlockCode? {
        let normalized = input.trimmingCharacters(in: .whitespaces).uppercased()
        guard let idx = codes.firstIndex(where: { $0.code == normalized }) else { return nil }
        guard case .valid(let code) = validate(input) else { return nil }

        codes[idx].usesCount += 1
        save()

        switch code.type {
        case .fullUnlock:
            // Only activate if not already premium via a real purchase
            if !EntitlementStore.shared.isPremium {
                EntitlementStore.shared.activateByCode(code.code)
            }
        }

        return code
    }

    // MARK: - Dev CRUD

    /// Add a new code. Silently ignored if a code with the same text already exists.
    func add(_ code: UnlockCode) {
        guard !codes.contains(where: { $0.code == code.code.uppercased() }) else { return }
        let c = UnlockCode(
            code:        code.code.trimmingCharacters(in: .whitespaces).uppercased(),
            type:        code.type,
            isActive:    code.isActive,
            environment: code.environment,
            expiresAt:   code.expiresAt,
            maxUses:     code.maxUses,
            usesCount:   code.usesCount,
            note:        code.note
        )
        codes.append(c)
        save()
    }

    func update(_ code: UnlockCode) {
        guard let idx = codes.firstIndex(where: { $0.id == code.id }) else { return }
        codes[idx] = code
        save()
    }

    func toggleActive(_ code: UnlockCode) {
        guard let idx = codes.firstIndex(where: { $0.id == code.id }) else { return }
        codes[idx].isActive.toggle()
        save()
    }

    func delete(_ code: UnlockCode) {
        codes.removeAll { $0.id == code.id }
        save()
    }

    func deleteAll() {
        codes.removeAll()
        save()
    }

    func resetUsage(_ code: UnlockCode) {
        guard let idx = codes.firstIndex(where: { $0.id == code.id }) else { return }
        codes[idx].usesCount = 0
        save()
    }

    // MARK: - Persistence

    private func save() {
        if let data = try? JSONEncoder().encode(codes) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func load() {
        // Local codes (dev-menu created, per-device)
        var local: [UnlockCode] = []
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([UnlockCode].self, from: data) {
            local = decoded
        }

        // Index persisted codes by key for fast lookup
        let persistedByCode = Dictionary(local.map { ($0.code, $0) }, uniquingKeysWith: { a, _ in a })

        // Merge: built-in codes always present; local codes kept alongside.
        // Shipped definition wins for config fields (type, isActive, environment,
        // expiresAt, maxUses, note). Persisted state wins for runtime-mutable
        // fields (usesCount) — so usage history survives app launches.
        var merged: [UnlockCode] = Self.builtInCodes.map { builtIn in
            guard let persisted = persistedByCode[builtIn.code] else { return builtIn }
            var code = builtIn
            code.usesCount = persisted.usesCount
            return code
        }
        let builtInKeys = Set(Self.builtInCodes.map(\.code))
        for c in local where !builtInKeys.contains(c.code) {
            merged.append(c)
        }
        codes = merged
    }
}
