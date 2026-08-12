import Combine
import Foundation
import OSLog
import StoreKit

/// Optional tip purchases.
///
/// Apple requires payments to the developer to go through in-app purchase —
/// linking out to Ko-fi or PayPal from inside the app (a QR code counts) is a
/// standard rejection under guideline 3.1.1. Those channels live in the
/// repository instead, where no App Store rule applies.
///
/// The products are consumables: they unlock nothing, can be bought repeatedly,
/// and therefore need no "restore purchases" flow.
@MainActor
final class TipJar: ObservableObject {
    @Published private(set) var products: [Product] = []
    @Published private(set) var isLoading = false
    @Published private(set) var purchasingProductID: String?
    @Published private(set) var didThank = false
    @Published var errorMessage: String?

    static let productIDs = [
        "io.github.jan620.homedash.tip.small",
        "io.github.jan620.homedash.tip.medium",
        "io.github.jan620.homedash.tip.large",
    ]

    private let logger = Logger(subsystem: "io.github.jan620.homedash", category: "tipjar")
    private var updatesTask: Task<Void, Never>?

    init() {
        // Transactions can also arrive outside a purchase — an interrupted
        // payment finishing later, or one made on another device. Unfinished
        // transactions are re-delivered until they are finished.
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                guard let self else { return }
                await self.finish(update)
            }
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    var isAvailable: Bool { !products.isEmpty }

    func load() async {
        guard products.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            products = try await Product.products(for: Self.productIDs)
                .sorted { $0.price < $1.price }
        } catch {
            logger.error("Produkte nicht geladen: \(error.localizedDescription, privacy: .public)")
            errorMessage = "Die Trinkgeld-Optionen konnten nicht geladen werden."
        }
    }

    func purchase(_ product: Product) async {
        purchasingProductID = product.id
        defer { purchasingProductID = nil }

        do {
            switch try await product.purchase() {
            case .success(let verification):
                await finish(verification)
            case .userCancelled:
                break
            case .pending:
                // Ask-to-buy and similar: the sale is not done yet, and the
                // transaction listener will pick it up when it is.
                errorMessage = "Der Kauf wartet noch auf eine Bestätigung."
            @unknown default:
                break
            }
        } catch {
            logger.error("Kauf fehlgeschlagen: \(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
        }
    }

    private func finish(_ verification: VerificationResult<Transaction>) async {
        switch verification {
        case .verified(let transaction):
            await transaction.finish()
            didThank = true
            errorMessage = nil
        case .unverified(let transaction, let error):
            // The signature did not check out; finish it anyway so StoreKit
            // stops re-delivering it, but do not celebrate.
            logger.error("Transaktion nicht verifiziert: \(error.localizedDescription, privacy: .public)")
            await transaction.finish()
            errorMessage = "Der Kauf konnte nicht verifiziert werden."
        }
    }

    func dismissThanks() {
        didThank = false
    }
}
