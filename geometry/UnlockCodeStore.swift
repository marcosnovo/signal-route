import Foundation
import Combine

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
        if !code.isActive   { return .inactive }
        if code.isExpired   { return .expired }
        if code.isExhausted { return .exhausted }
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
        var c = code
        c = UnlockCode(
            code:      code.code.trimmingCharacters(in: .whitespaces).uppercased(),
            type:      code.type,
            isActive:  code.isActive,
            expiresAt: code.expiresAt,
            maxUses:   code.maxUses,
            usesCount: code.usesCount,
            note:      code.note
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
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([UnlockCode].self, from: data)
        else { return }
        codes = decoded
    }
}
