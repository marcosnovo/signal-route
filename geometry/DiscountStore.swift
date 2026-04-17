import Foundation
import Combine

// MARK: - DiscountCode
//
// ⚠️  App-layer discount simulation only.
//     The actual App Store purchase price is always the price set in App Store Connect.
//     This system controls the *displayed* price in the paywall UI and is intended for
//     marketing/testing use only — not a real App Store promotional offer.
//
struct DiscountCode: Codable, Identifiable, Equatable {
    var id: String { code }

    /// The redemption code string (case-insensitive matching on validation).
    let code: String

    /// Percentage off: 1…100. A value of 100 means "effectively free" in the display.
    var percentageOff: Int

    /// If false, the code cannot be applied — without deleting it from the catalog.
    var isActive: Bool

    /// Optional expiry. nil = no expiry.
    var expiresAt: Date?

    /// Maximum number of times this code may be applied. nil = unlimited.
    var usageLimit: Int?

    /// How many times the code has been successfully applied this session / across sessions.
    var usageCount: Int

    // MARK: - Derived

    var isExpired: Bool {
        guard let exp = expiresAt else { return false }
        return Date() >= exp
    }

    var isExhausted: Bool {
        guard let limit = usageLimit else { return false }
        return usageCount >= limit
    }
}

// MARK: - DiscountStore

/// Single source of truth for discount codes.
///
/// ## Architecture note
/// This is an **app-layer UI simulation**. Discount codes control what price is
/// *displayed* in the paywall UI. The underlying StoreKit purchase price is always
/// the price set in App Store Connect. This is intentional and by design.
@MainActor
final class DiscountStore: ObservableObject {

    static let shared = DiscountStore()

    // MARK: - Validation result

    enum ValidationResult: Equatable {
        case valid(DiscountCode)
        case invalid      // code not found in catalog
        case inactive     // code exists but isActive == false
        case expired      // code has passed its expiresAt
        case exhausted    // code has reached its usageLimit
    }

    // MARK: - Persistence

    private let key = "discountStore.codes.v1"

    @Published private(set) var codes: [DiscountCode] = []

    private init() {
        load()
    }

    // MARK: - Public API

    /// Validate a code without consuming a usage.
    func validate(_ input: String) -> ValidationResult {
        let normalized = input.trimmingCharacters(in: .whitespaces).uppercased()
        guard let code = codes.first(where: { $0.code.uppercased() == normalized }) else {
            return .invalid
        }
        if !code.isActive  { return .inactive }
        if code.isExpired  { return .expired }
        if code.isExhausted { return .exhausted }
        return .valid(code)
    }

    /// Validate and consume a usage (increments usageCount). Returns the code on success.
    @discardableResult
    func redeem(_ input: String) -> DiscountCode? {
        let normalized = input.trimmingCharacters(in: .whitespaces).uppercased()
        guard let idx = codes.firstIndex(where: { $0.code.uppercased() == normalized }) else {
            return nil
        }
        let result = validate(input)
        guard case .valid(let code) = result else { return nil }
        codes[idx].usageCount += 1
        save()
        return code
    }

    // MARK: - Dev CRUD

    func add(_ code: DiscountCode) {
        // Prevent duplicates (case-insensitive)
        guard !codes.contains(where: { $0.code.uppercased() == code.code.uppercased() }) else { return }
        codes.append(code)
        save()
    }

    func update(_ code: DiscountCode) {
        guard let idx = codes.firstIndex(where: { $0.id == code.id }) else { return }
        codes[idx] = code
        save()
    }

    func toggleActive(_ code: DiscountCode) {
        guard let idx = codes.firstIndex(where: { $0.id == code.id }) else { return }
        codes[idx].isActive.toggle()
        save()
    }

    func delete(_ code: DiscountCode) {
        codes.removeAll { $0.id == code.id }
        save()
    }

    func resetUsage(_ code: DiscountCode) {
        guard let idx = codes.firstIndex(where: { $0.id == code.id }) else { return }
        codes[idx].usageCount = 0
        save()
    }

    func deleteAll() {
        codes.removeAll()
        save()
    }

    // MARK: - Persistence

    private func save() {
        if let data = try? JSONEncoder().encode(codes) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([DiscountCode].self, from: data) else {
            return
        }
        codes = decoded
    }
}
