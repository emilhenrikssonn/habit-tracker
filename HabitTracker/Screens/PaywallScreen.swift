import SwiftUI
import SwiftData
import StoreKit

/// Shown after onboarding and whenever there is no active subscription. Habits and logs are kept underneath.
struct PaywallScreen: View {
    @Environment(\.openURL) private var openURL
    @Query private var habits: [Habit]
    private var store: Store { Store.shared }

    @State private var selectedID = Store.yearlyID
    @State private var working = false
    @State private var message: String? = nil

    static let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    static let privacyURL = URL(string: "https://emilhenrikssonn.github.io/habit-tracker/privacy-policy.html")!

    private var selected: Product? { store.products.first { $0.id == selectedID } }
    private func trial(_ product: Product?) -> String? { store.trialEligible ? product?.freeTrialLength : nil }

    var body: some View {
        ScreenScaffold {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Keep your habits going")
                            .font(AppFont.serif(40)).foregroundStyle(AppColor.ink)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 22)
                        Text(headline)
                            .font(AppFont.serifItalic(22)).foregroundStyle(AppColor.accent)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 8).padding(.bottom, 20)

                        benefit("Unlimited habits, tracked your way")
                        benefit("Streaks, rest days and reminders")
                        benefit("Statistics for any habit or category")
                        benefit("Private: everything stays on this iPhone")

                        plans.padding(.top, 14)

                        if let selected { worthIt(selected).padding(.top, 18) }

                        if let message {
                            Text(message)
                                .font(AppFont.sans(13)).foregroundStyle(AppColor.inkDim)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.top, 14)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, AppMetrics.hPadding)
                    .padding(.bottom, 20)
                }
                footer
            }
        }
        .task { if store.products.isEmpty { await store.loadProducts() } }
    }

    private var headline: String {
        if let length = trial(selected) { return "Try it free for \(length)." }
        return "Subscribe to pick up where you left off."
    }

    private func benefit(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("✓").font(AppFont.mono(13, weight: .medium)).foregroundStyle(AppColor.accent)
            Text(text).font(AppFont.sans(16)).foregroundStyle(AppColor.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.bottom, 9)
    }

    // MARK: Plans

    @ViewBuilder
    private var plans: some View {
        if store.products.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text(store.loadFailed ? "Couldn't load the plans. Check your connection and try again." : "Loading plans…")
                    .font(AppFont.sans(14)).foregroundStyle(AppColor.inkDim)
                    .fixedSize(horizontal: false, vertical: true)
                if store.loadFailed {
                    SecondaryButton(title: "TRY AGAIN") { Task { await store.loadProducts() } }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: AppMetrics.cardRadius).fill(AppColor.surface))
        } else {
            VStack(spacing: 10) {
                ForEach(store.products.reversed(), id: \.id) { product in
                    planCard(product)
                }
            }
        }
    }

    private func planCard(_ product: Product) -> some View {
        let on = product.id == selectedID
        return Button { selectedID = product.id } label: {
            HStack(alignment: .center, spacing: 14) {
                CheckCircle(done: on)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(product.id == Store.yearlyID ? "Yearly" : "Monthly")
                            .font(AppFont.serif(22)).foregroundStyle(AppColor.ink)
                        if let saving = saving(product) {
                            Text("SAVE \(saving)%")
                                .font(AppFont.mono(10, weight: .medium))
                                .foregroundStyle(AppColor.inkOnAccent)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Capsule().fill(AppColor.accent))
                        }
                    }
                    Text(detail(product))
                        .font(AppFont.mono(11)).foregroundStyle(AppColor.inkMute)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Text(product.displayPrice)
                    .font(AppFont.mono(18)).foregroundStyle(AppColor.ink)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: AppMetrics.cardRadius)
                .fill(on ? AppColor.surfaceAccent : AppColor.surface))
            .overlay(RoundedRectangle(cornerRadius: AppMetrics.cardRadius)
                .stroke(on ? AppColor.accent : AppColor.border, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func detail(_ product: Product) -> String {
        let price = "\(product.displayPrice) per \(product.periodName)"
        if let length = trial(product) { return "\(length) free, then \(price)" }
        return price
    }

    /// How much cheaper a year is than twelve months, in whole percent.
    private func saving(_ product: Product) -> Int? {
        guard product.id == Store.yearlyID,
              let monthly = store.products.first(where: { $0.id == Store.monthlyID }) else { return nil }
        let twelveMonths = monthly.price * 12
        guard twelveMonths > product.price else { return nil }
        let fraction = (twelveMonths - product.price) / twelveMonths
        return Int((NSDecimalNumber(decimal: fraction).doubleValue * 100).rounded(.down))
    }

    // MARK: Worth it

    /// The selected plan as a price per day, set against what the person is here to change.
    private func worthIt(_ product: Product) -> some View {
        let days: Decimal = product.subscription?.subscriptionPeriod.unit == .year ? 365 : 30
        let perDay = (product.price / days).formatted(product.priceFormatStyle)
        let comparison = product.id == Store.yearlyID ? "One dinner out a year" : "Around one coffee a month"
        return VStack(alignment: .leading, spacing: 6) {
            // The price is in the mono face; the serif's digits make "0.11" hard to read.
            (Text("About ").font(AppFont.serif(24))
             + Text(perDay).font(AppFont.mono(20))
             + Text(" a day").font(AppFont.serif(24)))
                .foregroundStyle(AppColor.ink)
            Text("\(comparison), \(payoff)")
                .font(AppFont.sans(14)).foregroundStyle(AppColor.inkDim)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var payoff: String {
        let active = habits.filter { !$0.archived }
        let quitting = active.contains { $0.type == .quit }
        let building = active.contains { $0.type == .build }
        if quitting && building { return "for the habits you'll keep and the ones you'll finally drop." }
        if quitting { return "to finally drop the habits you want gone." }
        return "for habits that stay with you for years."
    }

    // MARK: Footer

    private var footer: some View {
        VStack(spacing: 0) {
            HRule()
            VStack(spacing: 12) {
                PrimaryButton(title: working ? "One moment…" : (trial(selected) != nil ? "Start free trial" : "Subscribe")) {
                    buy()
                }
                .disabled(working || selected == nil)
                .opacity(working || selected == nil ? 0.5 : 1)

                Text(smallPrint)
                    .font(AppFont.sans(11)).foregroundStyle(AppColor.inkMute)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 18) {
                    link("Restore purchases") { restore() }
                    link("Terms") { openURL(Self.termsURL) }
                    link("Privacy") { openURL(Self.privacyURL) }
                    #if DEBUG
                    link("Skip (debug)") { store.debugUnlock() }
                    #endif
                }
            }
            .padding(.horizontal, AppMetrics.hPadding)
            .padding(.top, 14)
            .padding(.bottom, 18)
        }
        .background(AppColor.bg)
    }

    private var smallPrint: String {
        guard let selected else { return "Payment is handled by Apple. Cancel any time in your App Store settings." }
        let price = "\(selected.displayPrice) per \(selected.periodName)"
        let start = trial(selected).map { "Free for \($0), then \(price)." } ?? "\(price)."
        return "\(start) Renews automatically until cancelled. Cancel any time in your App Store settings, at least a day before renewal."
    }

    private func link(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(AppFont.mono(11)).foregroundStyle(AppColor.inkDim)
        }
        .buttonStyle(.plain)
        .disabled(working)
    }

    private func buy() {
        guard let selected else { return }
        working = true
        message = nil
        Task {
            do {
                _ = try await store.purchase(selected)
            } catch {
                message = "The purchase didn't go through. You haven't been charged. Please try again."
            }
            working = false
        }
    }

    private func restore() {
        working = true
        message = nil
        Task {
            await store.restore()
            if store.access != .subscribed { message = "No active subscription was found for this Apple Account." }
            working = false
        }
    }
}
