import XCTest
import StoreKit
import StoreKitTest
@testable import HabitTracker

/// Runs against StoreKit/Products.storekit, so no App Store account is involved.
@MainActor
final class StoreTests: XCTestCase {
    private var session: SKTestSession!

    override func setUp() async throws {
        session = try SKTestSession(configurationFileNamed: "Products")
        session.disableDialogs = true
        session.clearTransactions()
    }

    /// Test purchases are shared with runs from Xcode on the same simulator, so don't leave one behind.
    override func tearDown() async throws {
        session.clearTransactions()
    }

    func testPlansLoadWithAWeekFree() async throws {
        let store = Store()
        await store.start()

        XCTAssertEqual(store.products.map(\.id), [Store.monthlyID, Store.yearlyID])
        XCTAssertEqual(store.access, .notSubscribed)
        XCTAssertTrue(store.trialEligible)
        XCTAssertEqual(store.products.map(\.displayPrice), ["$5.99", "$39.99"])
        XCTAssertEqual(store.products.map(\.periodName), ["month", "year"])
        XCTAssertEqual(store.products.map(\.freeTrialLength), ["1 week", "1 week"])
    }

    func testSubscribingGivesAccess() async throws {
        let store = Store()
        await store.start()
        XCTAssertEqual(store.access, .notSubscribed)

        try await session.buyProduct(identifier: Store.yearlyID)
        await expect(.subscribed, in: store)
    }

    func testExpiredSubscriptionLosesAccess() async throws {
        let store = Store()
        try await session.buyProduct(identifier: Store.monthlyID)
        await expect(.subscribed, in: store)

        try session.expireSubscription(productIdentifier: Store.monthlyID)
        await expect(.notSubscribed, in: store)
    }

    /// StoreKit applies purchases and expiries a moment after the call returns, so check for a few seconds.
    private func expect(_ access: Store.Access, in store: Store, file: StaticString = #filePath, line: UInt = #line) async {
        for _ in 0..<50 {
            await store.refreshAccess()
            if store.access == access { return }
            try? await Task.sleep(for: .milliseconds(100))
        }
        XCTAssertEqual(store.access, access, file: file, line: line)
    }
}
