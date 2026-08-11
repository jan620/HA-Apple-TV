import StoreKit
import SwiftUI

/// "Buy me a coffee", as an in-app purchase.
struct TipJarView: View {
    @StateObject private var tipJar = TipJar()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 34) {
                header

                if tipJar.didThank {
                    thanks
                } else if tipJar.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if tipJar.isAvailable {
                    options
                } else {
                    unavailable
                }

                if let error = tipJar.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.callout)
                        .foregroundStyle(Theme.unavailable)
                        .fixedSize(horizontal: false, vertical: true)
                        .focusableCard()
                }

                Button("Schließen") { dismiss() }
                    .padding(.top, 10)
            }
            .padding(.horizontal, Theme.screenInset)
            .padding(.vertical, 50)
            .frame(maxWidth: 1200, alignment: .leading)
        }
        .task { await tipJar.load() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Kauf mir einen Kaffee")
                .font(.largeTitle.bold())
            Text("""
            Diese App ist kostenlos und quelloffen. Wenn sie dir etwas wert ist, \
            freue ich mich über ein Trinkgeld — es schaltet nichts frei und \
            ändert nichts an der App.
            """)
            .font(.title3)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var options: some View {
        VStack(alignment: .leading, spacing: 20) {
            ForEach(tipJar.products, id: \.id) { product in
                Button {
                    Task { await tipJar.purchase(product) }
                } label: {
                    HStack(spacing: 20) {
                        Image(systemName: "cup.and.saucer.fill")
                            .font(.title2)
                            .foregroundStyle(Theme.active)
                            .frame(width: 50)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(product.displayName)
                                .font(.headline)
                            Text(product.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        Spacer(minLength: 20)
                        if tipJar.purchasingProductID == product.id {
                            ProgressView()
                        } else {
                            Text(product.displayPrice)
                                .font(.title3.weight(.semibold))
                        }
                    }
                    .padding(.vertical, 10)
                }
                .buttonStyle(.card)
                .disabled(tipJar.purchasingProductID != nil)
            }

            // Consumables are not restorable, so there is deliberately no
            // "restore purchases" button here.
            Text("Trinkgelder sind einmalige Käufe und lassen sich beliebig oft wiederholen.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var thanks: some View {
        VStack(spacing: 18) {
            Image(systemName: "heart.fill")
                .font(.system(size: 70))
                .foregroundStyle(.pink)
            Text("Danke!")
                .font(.largeTitle.bold())
            Text("Das bedeutet mir viel.")
                .font(.title3)
                .foregroundStyle(.secondary)
            Button("Weiter") { tipJar.dismissThanks() }
                .padding(.top, 10)
        }
        .frame(maxWidth: .infinity, minHeight: 320)
    }

    private var unavailable: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Aktuell nicht verfügbar")
                .font(.headline)
            Text("""
            Die Trinkgeld-Optionen kommen aus dem App Store. In einem selbst \
            gebauten Debug-Build erscheinen sie nur, wenn im Schema eine \
            StoreKit-Konfiguration hinterlegt ist — Resources/Products.storekit \
            liegt dafür bereit.
            """)
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .focusableCard()
    }
}
