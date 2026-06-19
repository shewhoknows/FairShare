import XCTest
@testable import BillBandit

final class BillBanditTests: XCTestCase {
    func testCurrencyFormatterProducesValue() {
        let formatted = BillBanditFormatters.currency(12.5, code: "INR")
        XCTAssertFalse(formatted.isEmpty)
    }

    func testProfileDraftReadinessUsesTrimmedNameAndUPI() {
        XCTAssertFalse(InkAuthProfileDraft(name: "Meera Kapoor", upiID: "").isReady)
        XCTAssertFalse(InkAuthProfileDraft(name: "   ", upiID: "meera@upi").isReady)
        XCTAssertTrue(InkAuthProfileDraft(name: " Meera Kapoor ", upiID: " meera@upi ").isReady)

        let normalized = InkAuthProfileDraft(
            name: " Meera Kapoor ",
            preferredName: " Meera ",
            upiID: " meera@upi "
        ).normalized
        XCTAssertEqual(normalized.name, "Meera Kapoor")
        XCTAssertEqual(normalized.preferredName, "Meera")
        XCTAssertEqual(normalized.upiID, "meera@upi")
    }

    @MainActor
    func testInkStoreRunsLedgerFlowThroughMobileAPIClient() async throws {
        let client = APIClient(baseURL: try XCTUnwrap(URL(string: "mock://billbandit"))) { "mock-token" }
        let auth: AuthResponse = try await client.post(
            "/api/mobile/auth/apple",
            body: AppleSignInRequest(
                identityToken: "mock-token",
                authorizationCode: nil,
                nonce: nil,
                fullName: "Meera Kapoor",
                email: "meera.ledger@example.com"
            )
        )

        let store = InkTripStore()
        await store.configure(apiClient: client, currentUser: auth.user)
        XCTAssertTrue(store.isRemoteBacked)

        let createdTrip = await store.createTrip(
            from: InkTripDraft(
                title: "MVP Ledger",
                location: "Goa",
                dates: "4-8 Dec 2026",
                friendNames: ["You"]
            )
        )
        var trip = try XCTUnwrap(createdTrip)

        let didAddFriend = await store.addFriend(named: "Bob Smith", contact: "bob@example.com", to: trip.id)
        XCTAssertTrue(didAddFriend)

        trip = try XCTUnwrap(store.trip(id: trip.id))
        let bob = try XCTUnwrap(trip.friends.first { $0.contact == "bob@example.com" })
        XCTAssertEqual(trip.friends.count, 2)

        var dinnerDraft = InkExpenseDraft(trip: trip)
        dinnerDraft.title = "Dinner"
        dinnerDraft.amount = "100"
        dinnerDraft.paidByID = store.currentUserID
        dinnerDraft.splitWithIDs = Set(trip.friends.map(\.id))

        let didSaveDinner = await store.saveExpense(dinnerDraft, in: trip.id, editing: nil)
        XCTAssertTrue(didSaveDinner)

        trip = try XCTUnwrap(store.trip(id: trip.id))
        let dinner = try XCTUnwrap(trip.expenses.first { $0.title == "Dinner" })
        XCTAssertEqual(dinner.paidByID, store.currentUserID)

        let settlement = try XCTUnwrap(store.settlements(for: trip).first)
        XCTAssertEqual(settlement.fromID, bob.id)
        XCTAssertEqual(settlement.toID, store.currentUserID)
        XCTAssertEqual(settlement.amount, 50, accuracy: 0.01)

        let didRecordSettlement = await store.recordSettlement(settlement, in: trip.id)
        XCTAssertTrue(didRecordSettlement)

        let settledTrip = try XCTUnwrap(store.trip(id: trip.id))
        XCTAssertTrue(store.settlements(for: settledTrip).isEmpty)

        let didDeleteDinner = await store.deleteExpense(dinner.id, in: trip.id)
        XCTAssertTrue(didDeleteDinner)

        trip = try XCTUnwrap(store.trip(id: trip.id))
        XCTAssertFalse(trip.expenses.contains { $0.id == dinner.id })

        var bobPaidDraft = InkExpenseDraft(trip: trip)
        bobPaidDraft.title = "Bob snacks"
        bobPaidDraft.amount = "80"
        bobPaidDraft.paidByID = bob.id
        bobPaidDraft.splitWithIDs = Set(trip.friends.map(\.id))

        let didSaveBobExpense = await store.saveExpense(bobPaidDraft, in: trip.id, editing: nil)
        XCTAssertTrue(didSaveBobExpense)

        trip = try XCTUnwrap(store.trip(id: trip.id))
        let bobExpense = try XCTUnwrap(trip.expenses.first { $0.title == "Bob snacks" })
        bobPaidDraft.amount = "90"

        let didEditBobExpense = await store.saveExpense(bobPaidDraft, in: trip.id, editing: bobExpense.id)
        XCTAssertFalse(didEditBobExpense)
        XCTAssertEqual(store.errorMessage, "Only the payer can edit an expense")

        let didDeleteBobExpense = await store.deleteExpense(bobExpense.id, in: trip.id)
        XCTAssertFalse(didDeleteBobExpense)
        XCTAssertEqual(store.errorMessage, "Only the payer can delete an expense")
    }
}
