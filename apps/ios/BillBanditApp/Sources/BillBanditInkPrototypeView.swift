import SwiftUI
import UIKit

enum InkScreen: String, CaseIterable, Identifiable {
    case welcome = "01"
    case newMember = "02"
    case tripsEmpty = "03"
    case yourTrips = "04"
    case newLedger = "05"
    case liveLedger = "06"
    case settle = "07"
    case recordPayment = "08"
    case finalBill = "09"
    case addEntry = "10"
    case addFriend = "11"

    var id: String { rawValue }

    static func fromLaunchArguments(_ arguments: [String] = ProcessInfo.processInfo.arguments) -> InkScreen {
        for argument in arguments where argument.hasPrefix("--ink-screen=") {
            let value = String(argument.dropFirst("--ink-screen=".count))
            if value == "12" { return .addFriend }
            return InkScreen(rawValue: value) ?? .welcome
        }
        return .welcome
    }
}

struct InkFriend: Identifiable, Hashable {
    let id: String
    var name: String
    var contact: String

    init(id: String = UUID().uuidString, name: String, contact: String = "") {
        self.id = id
        self.name = name
        self.contact = contact
    }
}

struct InkExpense: Identifiable, Hashable {
    let id: String
    var title: String
    var amount: Double
    var paidByID: String
    var splitWithIDs: Set<String>
    var day: String

    init(
        id: String = UUID().uuidString,
        title: String,
        amount: Double,
        paidByID: String,
        splitWithIDs: Set<String>,
        day: String = "D1"
    ) {
        self.id = id
        self.title = title
        self.amount = amount
        self.paidByID = paidByID
        self.splitWithIDs = splitWithIDs
        self.day = day
    }
}

struct InkTrip: Identifiable, Hashable {
    enum Status: String {
        case open
        case final
    }

    let id: String
    var title: String
    var location: String
    var dates: String
    var currency: String
    var status: Status
    var friends: [InkFriend]
    var expenses: [InkExpense]
    var remoteBalances: [String: Double]?
    var remoteSettlements: [InkSettlement]?

    init(
        id: String = UUID().uuidString,
        title: String,
        location: String,
        dates: String,
        currency: String = "INR",
        status: Status,
        friends: [InkFriend],
        expenses: [InkExpense],
        remoteBalances: [String: Double]? = nil,
        remoteSettlements: [InkSettlement]? = nil
    ) {
        self.id = id
        self.title = title
        self.location = location
        self.dates = dates
        self.currency = currency
        self.status = status
        self.friends = friends
        self.expenses = expenses
        self.remoteBalances = remoteBalances
        self.remoteSettlements = remoteSettlements
    }
}

struct InkLedgerSummary: Equatable {
    var total: Double
    var userShare: Double
    var userNet: Double
    var balances: [String: Double]
}

struct InkSettlement: Identifiable, Equatable, Hashable {
    let id = UUID().uuidString
    var fromID: String
    var toID: String
    var amount: Double
}

struct InkTripDraft: Equatable {
    var title = "Goa, December"
    var location = "Goa, India"
    var dates = "4–8 Dec 2026"
    var startDate = DateComponents(calendar: .current, year: 2026, month: 12, day: 4).date ?? Date()
    var endDate = DateComponents(calendar: .current, year: 2026, month: 12, day: 8).date ?? Date()
    var friendNames: [String] = ["You"]

    static let fresh = InkTripDraft()

    init() {}

    init(trip: InkTrip) {
        title = trip.title
        location = trip.location
        dates = trip.dates
        friendNames = trip.friends.map(\.name)
    }

    init(title: String, location: String, dates: String, friendNames: [String]) {
        self.title = title
        self.location = location
        self.dates = dates
        self.friendNames = friendNames
    }

    mutating func updateDates(start: Date, end: Date) {
        startDate = start
        endDate = max(start, end)
        dates = Self.formattedDateRange(start: startDate, end: endDate)
    }

    static func formattedDateRange(start: Date, end: Date) -> String {
        let calendar = Calendar.current
        let startDay = calendar.component(.day, from: start)
        let endDay = calendar.component(.day, from: end)
        let year = calendar.component(.year, from: end)
        let monthFormatter = DateFormatter()
        monthFormatter.locale = Locale(identifier: "en_IN")
        monthFormatter.dateFormat = "MMM"
        if calendar.component(.month, from: start) == calendar.component(.month, from: end), calendar.component(.year, from: start) == year {
            return "\(startDay)–\(endDay) \(monthFormatter.string(from: end)) \(year)"
        }
        let startMonth = monthFormatter.string(from: start)
        let endMonth = monthFormatter.string(from: end)
        return "\(startDay) \(startMonth)–\(endDay) \(endMonth) \(year)"
    }
}

struct InkExpenseDraft: Equatable {
    var title = "Dinner at the dhaba"
    var amount = "1560"
    var paidByID: String?
    var splitWithIDs: Set<String> = []

    init(trip: InkTrip, expense: InkExpense? = nil) {
        if let expense {
            title = expense.title
            amount = String(format: "%.0f", expense.amount)
            paidByID = expense.paidByID
            splitWithIDs = expense.splitWithIDs
        } else {
            paidByID = trip.friends.first?.id
            splitWithIDs = Set(trip.friends.map(\.id))
        }
    }
}

@MainActor
final class InkTripStore: ObservableObject {
    @Published private(set) var trips: [InkTrip]
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let localUserID: String
    private var apiClient: APIClient?
    private var remoteUser: UserDTO?

    init(trips: [InkTrip] = []) {
        self.trips = trips
        self.localUserID = trips.first?.friends.first?.id ?? UUID().uuidString
    }

    static func demoTrips() -> [InkTrip] {
        seedTrips()
    }

    var currentUserID: String { remoteUser?.id ?? localUserID }
    var currentUserName: String { remoteUser?.displayName ?? "You" }
    var isRemoteBacked: Bool { apiClient != nil && remoteUser != nil }

    func configure(apiClient: APIClient, currentUser: UserDTO) async {
        self.apiClient = apiClient
        self.remoteUser = currentUser
        BillBanditLog.ledger(
            "event=ledger.store.configure remote_backed=true profile_complete=\(BillBanditLog.bool(currentUser.isProfileComplete == true))"
        )
        await reloadTrips()
    }

    func reloadTrips() async {
        guard let apiClient else { return }
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil
        BillBanditLog.ledger("event=ledger.groups.reload.start")

        do {
            let response: GroupsResponse = try await apiClient.get("/api/mobile/groups")
            var loadedTrips: [InkTrip] = []
            for group in response.groups {
                if let refreshed = await fetchTrip(id: group.id) {
                    loadedTrips.append(refreshed)
                } else {
                    loadedTrips.append(inkTrip(from: group))
                }
            }
            trips = loadedTrips
            errorMessage = nil
            BillBanditLog.ledger("event=ledger.groups.reload.result success=true count=\(loadedTrips.count)")
        } catch {
            BillBanditLog.ledger("event=ledger.groups.reload.result success=false error=\(BillBanditLog.sanitizedError(error))")
            setError(error)
        }
    }

    func trip(id: String?) -> InkTrip? {
        guard let id else { return trips.first }
        return trips.first { $0.id == id }
    }

    @discardableResult
    func createTrip(from draft: InkTripDraft) async -> InkTrip? {
        if let apiClient {
            errorMessage = nil
            BillBanditLog.ledger(
                "event=ledger.group.create.start friend_count=\(draft.friendNames.uniqued().count)"
            )
            do {
                let response: GroupResponse = try await apiClient.post(
                    "/api/mobile/groups",
                    body: CreateGroupRequest(
                        name: draft.title.trimmedOrDefault("Untitled ledger"),
                        description: encodedDescription(location: draft.location, dates: draft.dates),
                        currency: "INR",
                        category: "TRIP"
                    )
                )
                let trip = inkTrip(from: response.group)
                upsert(trip)
                errorMessage = nil
                BillBanditLog.ledger(
                    "event=ledger.group.create.result success=true group=\(BillBanditLog.redactedID(trip.id)) member_count=\(trip.friends.count)"
                )
                return trip
            } catch {
                BillBanditLog.ledger("event=ledger.group.create.result success=false error=\(BillBanditLog.sanitizedError(error))")
                setError(error)
                return nil
            }
        }

        let friends = draft.friendNames.uniqued().map { name in
            localFriend(named: name)
        }
        let normalizedFriends = friends.isEmpty ? [InkFriend(id: localUserID, name: currentUserName)] : friends
        let trip = InkTrip(
            title: draft.title.trimmedOrDefault("Untitled ledger"),
            location: draft.location.trimmedOrDefault("Somewhere"),
            dates: draft.dates.trimmedOrDefault("Dates TBD"),
            status: .open,
            friends: normalizedFriends,
            expenses: []
        )
        trips.insert(trip, at: 0)
        return trip
    }

    func updateTrip(_ updatedTrip: InkTrip) {
        guard let index = trips.firstIndex(where: { $0.id == updatedTrip.id }) else { return }
        trips[index] = updatedTrip
    }

    func updateTrip(id: String, from draft: InkTripDraft) {
        guard let index = trips.firstIndex(where: { $0.id == id }) else { return }
        let existingTrip = trips[index]
        let names = draft.friendNames.uniqued()
        let friends = names.map { name in
            localFriend(named: name, existingFriends: existingTrip.friends)
        }
        let normalizedFriends = friends.isEmpty ? [InkFriend(id: localUserID, name: currentUserName)] : friends
        let validIDs = Set(normalizedFriends.map(\.id))
        let fallbackID = normalizedFriends.first?.id
        let normalizedExpenses = existingTrip.expenses.compactMap { expense -> InkExpense? in
            guard let fallbackID else { return nil }
            var updated = expense
            if validIDs.contains(updated.paidByID) == false {
                updated.paidByID = fallbackID
            }
            updated.splitWithIDs = updated.splitWithIDs.intersection(validIDs)
            if updated.splitWithIDs.isEmpty {
                updated.splitWithIDs = validIDs
            }
            return updated
        }
        trips[index] = InkTrip(
            id: existingTrip.id,
            title: draft.title.trimmedOrDefault("Untitled ledger"),
            location: draft.location.trimmedOrDefault("Somewhere"),
            dates: draft.dates.trimmedOrDefault("Dates TBD"),
            status: existingTrip.status,
            friends: normalizedFriends,
            expenses: normalizedExpenses
        )
    }

    @discardableResult
    func addFriend(named rawName: String, contact: String, to tripID: String) async -> Bool {
        if let apiClient {
            let normalizedContact = contact.trimmingCharacters(in: .whitespacesAndNewlines)
            guard normalizedContact.isEmpty == false else {
                setValidationError("Enter your friend’s BillBandit email.")
                return false
            }
            errorMessage = nil
            BillBanditLog.ledger(
                "event=ledger.member.add.start group=\(BillBanditLog.redactedID(tripID)) contact_present=\(BillBanditLog.bool(normalizedContact.isEmpty == false))"
            )
            do {
                let _: MemberResponse = try await apiClient.post(
                    "/api/mobile/groups/\(tripID)/members",
                    body: AddMemberRequest(email: normalizedContact)
                )
                _ = await fetchTrip(id: tripID)
                errorMessage = nil
                BillBanditLog.ledger("event=ledger.member.add.result success=true group=\(BillBanditLog.redactedID(tripID))")
                return true
            } catch {
                BillBanditLog.ledger(
                    "event=ledger.member.add.result success=false group=\(BillBanditLog.redactedID(tripID)) error=\(BillBanditLog.sanitizedError(error))"
                )
                setError(error)
                return false
            }
        }

        guard let index = trips.firstIndex(where: { $0.id == tripID }) else { return false }
        let name = rawName.trimmedOrDefault(contact.trimmedOrDefault("New friend"))
        guard trips[index].friends.contains(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) == false else { return true }
        trips[index].friends.append(InkFriend(name: name, contact: contact))
        return true
    }

    @discardableResult
    func saveExpense(_ draft: InkExpenseDraft, in tripID: String, editing expenseID: String?) async -> Bool {
        guard let tripIndex = trips.firstIndex(where: { $0.id == tripID }) else { return false }
        let trip = trips[tripIndex]
        let amount = Double(draft.amount.filter { "0123456789.".contains($0) }) ?? 0
        guard amount > 0 else {
            setValidationError("Enter an amount greater than zero.")
            return false
        }
        guard let participants = normalizedExpenseParticipants(draft: draft, trip: trip) else {
            setValidationError("Add at least one person before saving an expense.")
            return false
        }
        let paidByID = participants.paidByID
        let splitIDs = participants.splitIDs

        if let apiClient {
            errorMessage = nil
            BillBanditLog.ledger(
                "event=ledger.expense.save.start group=\(BillBanditLog.redactedID(tripID)) editing=\(BillBanditLog.bool(expenseID != nil)) split_count=\(splitIDs.count) amount_present=\(BillBanditLog.bool(amount > 0))"
            )
            do {
                let request = expenseRequest(
                    draft: draft,
                    trip: trip,
                    amount: amount,
                    paidByID: paidByID,
                    splitIDs: splitIDs
                )
                if let expenseID {
                    let _: ExpenseResponse = try await apiClient.put("/api/mobile/expenses/\(expenseID)", body: request)
                } else {
                    let _: ExpenseResponse = try await apiClient.post("/api/mobile/expenses", body: request)
                }
                _ = await fetchTrip(id: tripID)
                errorMessage = nil
                BillBanditLog.ledger(
                    "event=ledger.expense.save.result success=true group=\(BillBanditLog.redactedID(tripID)) editing=\(BillBanditLog.bool(expenseID != nil))"
                )
                return true
            } catch {
                BillBanditLog.ledger(
                    "event=ledger.expense.save.result success=false group=\(BillBanditLog.redactedID(tripID)) editing=\(BillBanditLog.bool(expenseID != nil)) error=\(BillBanditLog.sanitizedError(error))"
                )
                setError(error)
                return false
            }
        }

        let expense = InkExpense(
            id: expenseID ?? UUID().uuidString,
            title: draft.title.trimmedOrDefault("Untitled expense"),
            amount: amount,
            paidByID: paidByID,
            splitWithIDs: splitIDs,
            day: "D\(min(9, max(1, trip.expenses.count + 1)))"
        )
        if let expenseID, let expenseIndex = trips[tripIndex].expenses.firstIndex(where: { $0.id == expenseID }) {
            trips[tripIndex].expenses[expenseIndex] = expense
        } else {
            trips[tripIndex].expenses.append(expense)
        }
        return true
    }

    @discardableResult
    func deleteExpense(_ expenseID: String, in tripID: String) async -> Bool {
        if let apiClient {
            BillBanditLog.ledger(
                "event=ledger.expense.delete.start group=\(BillBanditLog.redactedID(tripID)) expense=\(BillBanditLog.redactedID(expenseID))"
            )
            do {
                let _: SuccessResponse = try await apiClient.delete("/api/mobile/expenses/\(expenseID)")
                _ = await fetchTrip(id: tripID)
                errorMessage = nil
                BillBanditLog.ledger(
                    "event=ledger.expense.delete.result success=true group=\(BillBanditLog.redactedID(tripID)) expense=\(BillBanditLog.redactedID(expenseID))"
                )
                return true
            } catch {
                BillBanditLog.ledger(
                    "event=ledger.expense.delete.result success=false group=\(BillBanditLog.redactedID(tripID)) expense=\(BillBanditLog.redactedID(expenseID)) error=\(BillBanditLog.sanitizedError(error))"
                )
                setError(error)
                return false
            }
        }

        guard let tripIndex = trips.firstIndex(where: { $0.id == tripID }) else { return false }
        trips[tripIndex].expenses.removeAll { $0.id == expenseID }
        return true
    }

    @discardableResult
    func recordSettlement(_ settlement: InkSettlement, in tripID: String) async -> Bool {
        if let apiClient {
            BillBanditLog.ledger(
                "event=ledger.settlement.record.start group=\(BillBanditLog.redactedID(tripID)) from=\(BillBanditLog.redactedID(settlement.fromID)) to=\(BillBanditLog.redactedID(settlement.toID)) amount_present=\(BillBanditLog.bool(settlement.amount > 0))"
            )
            do {
                let receiverId = settlement.fromID == currentUserID ? settlement.toID : nil
                let senderId = settlement.toID == currentUserID ? settlement.fromID : nil
                let _: TransactionResponse = try await apiClient.post(
                    "/api/mobile/transactions",
                    body: CreateTransactionRequest(
                        receiverId: receiverId,
                        senderId: senderId,
                        amount: settlement.amount,
                        currency: trip(id: tripID)?.currency ?? "INR",
                        groupId: tripID,
                        note: "BillBandit settlement"
                    )
                )
                _ = await fetchTrip(id: tripID)
                errorMessage = nil
                BillBanditLog.ledger("event=ledger.settlement.record.result success=true group=\(BillBanditLog.redactedID(tripID))")
                return true
            } catch {
                BillBanditLog.ledger(
                    "event=ledger.settlement.record.result success=false group=\(BillBanditLog.redactedID(tripID)) error=\(BillBanditLog.sanitizedError(error))"
                )
                setError(error)
                return false
            }
        }

        return true
    }

    func summary(for trip: InkTrip) -> InkLedgerSummary {
        var summary = Self.summary(for: trip, currentUserID: currentUserID)
        if let remoteBalances = trip.remoteBalances {
            summary.balances = remoteBalances
            summary.userNet = remoteBalances[currentUserID] ?? 0
        }
        return summary
    }

    func settlements(for trip: InkTrip) -> [InkSettlement] {
        trip.remoteSettlements ?? Self.settlements(for: trip)
    }

    static func summary(for trip: InkTrip, currentUserID: String? = nil) -> InkLedgerSummary {
        var balances = Dictionary(uniqueKeysWithValues: trip.friends.map { ($0.id, 0.0) })
        for expense in trip.expenses {
            balances[expense.paidByID, default: 0] += expense.amount
            let splitIDs = expense.splitWithIDs.isEmpty ? Set(trip.friends.map(\.id)) : expense.splitWithIDs
            let share = splitIDs.isEmpty ? 0 : expense.amount / Double(splitIDs.count)
            for friendID in splitIDs {
                balances[friendID, default: 0] -= share
            }
        }
        let total = trip.expenses.reduce(0) { $0 + $1.amount }
        let currentUser = currentUserID ?? trip.friends.first?.id
        let userShare = trip.expenses.reduce(0) { partial, expense in
            let splitIDs = expense.splitWithIDs.isEmpty ? Set(trip.friends.map(\.id)) : expense.splitWithIDs
            guard let currentUser, splitIDs.contains(currentUser), splitIDs.isEmpty == false else { return partial }
            return partial + expense.amount / Double(splitIDs.count)
        }
        return InkLedgerSummary(total: total, userShare: userShare, userNet: balances[currentUser ?? UUID().uuidString] ?? 0, balances: balances)
    }

    static func settlements(for trip: InkTrip) -> [InkSettlement] {
        let balances = summary(for: trip).balances
        var debtors = balances.filter { $0.value < -0.005 }.map { ($0.key, -$0.value) }.sorted { $0.1 > $1.1 }
        var creditors = balances.filter { $0.value > 0.005 }.map { ($0.key, $0.value) }.sorted { $0.1 > $1.1 }
        var transfers: [InkSettlement] = []
        var debtorIndex = 0
        var creditorIndex = 0
        while debtorIndex < debtors.count, creditorIndex < creditors.count {
            let amount = min(debtors[debtorIndex].1, creditors[creditorIndex].1)
            if amount > 0.005 {
                transfers.append(InkSettlement(fromID: debtors[debtorIndex].0, toID: creditors[creditorIndex].0, amount: amount))
            }
            debtors[debtorIndex].1 -= amount
            creditors[creditorIndex].1 -= amount
            if debtors[debtorIndex].1 <= 0.005 { debtorIndex += 1 }
            if creditors[creditorIndex].1 <= 0.005 { creditorIndex += 1 }
        }
        return transfers
    }

    @discardableResult
    private func fetchTrip(id: String) async -> InkTrip? {
        guard let apiClient else { return nil }
        BillBanditLog.ledger("event=ledger.group.fetch.start group=\(BillBanditLog.redactedID(id))")
        do {
            let response: GroupResponse = try await apiClient.get("/api/mobile/groups/\(id)")
            let trip = inkTrip(from: response.group, balances: response.balances)
            upsert(trip)
            BillBanditLog.ledger(
                "event=ledger.group.fetch.result success=true group=\(BillBanditLog.redactedID(id)) member_count=\(trip.friends.count) expense_count=\(trip.expenses.count)"
            )
            return trip
        } catch {
            BillBanditLog.ledger(
                "event=ledger.group.fetch.result success=false group=\(BillBanditLog.redactedID(id)) error=\(BillBanditLog.sanitizedError(error))"
            )
            setError(error)
            return nil
        }
    }

    private func upsert(_ trip: InkTrip) {
        if let index = trips.firstIndex(where: { $0.id == trip.id }) {
            trips[index] = trip
        } else {
            trips.insert(trip, at: 0)
        }
    }

    private func localFriend(named rawName: String, existingFriends: [InkFriend] = []) -> InkFriend {
        let name = rawName.trimmedOrDefault("Friend")
        if let existing = existingFriends.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
            return existing
        }
        let isCurrentUser = name.caseInsensitiveCompare("You") == .orderedSame || name.caseInsensitiveCompare(currentUserName) == .orderedSame
        return InkFriend(id: isCurrentUser ? localUserID : UUID().uuidString, name: name)
    }

    private func inkTrip(from group: GroupDTO, balances: GroupBalancesDTO? = nil) -> InkTrip {
        let description = decodedDescription(group.description)
        var friends = group.members.map { member in
            InkFriend(
                id: member.user.id,
                name: member.user.displayName,
                contact: member.user.email ?? member.user.phone ?? ""
            )
        }
        if friends.isEmpty {
            friends = [InkFriend(id: currentUserID, name: currentUserName, contact: remoteUser?.email ?? "")]
        }
        friends.sort { lhs, rhs in
            if lhs.id == currentUserID { return true }
            if rhs.id == currentUserID { return false }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }

        let expenses = (group.expenses ?? []).map { expense in
            InkExpense(
                id: expense.id,
                title: expense.description,
                amount: expense.amount,
                paidByID: expense.paidById,
                splitWithIDs: Set(expense.splits.map(\.userId)),
                day: BillBanditFormatters.day(expense.date)
            )
        }

        return InkTrip(
            id: group.id,
            title: group.name,
            location: description.location,
            dates: description.dates,
            currency: group.currency,
            status: .open,
            friends: friends,
            expenses: expenses,
            remoteBalances: balances.map { groupBalances in
                Dictionary(uniqueKeysWithValues: groupBalances.netBalances.map { ($0.userId, $0.netAmount) })
            },
            remoteSettlements: balances?.simplifiedDebts.map {
                InkSettlement(fromID: $0.fromId, toID: $0.toId, amount: $0.amount)
            }
        )
    }

    private func expenseRequest(
        draft: InkExpenseDraft,
        trip: InkTrip,
        amount: Double,
        paidByID: String,
        splitIDs: Set<String>
    ) -> CreateExpenseRequest {
        let normalizedSplitIDs = splitIDs.isEmpty ? Set(trip.friends.map(\.id)) : splitIDs
        return CreateExpenseRequest(
            description: draft.title.trimmedOrDefault("Untitled expense"),
            amount: amount,
            currency: trip.currency,
            date: ISO8601DateFormatter().string(from: Date()),
            category: "general",
            groupId: trip.id,
            paidById: paidByID,
            splitType: SplitType.equal.rawValue,
            splits: equalSplits(total: amount, splitIDs: normalizedSplitIDs),
            notes: nil
        )
    }

    private func normalizedExpenseParticipants(draft: InkExpenseDraft, trip: InkTrip) -> (paidByID: String, splitIDs: Set<String>)? {
        let validIDs = Set(trip.friends.map(\.id))
        guard validIDs.isEmpty == false else { return nil }

        let fallbackID = validIDs.contains(currentUserID) ? currentUserID : trip.friends[0].id
        let requestedPaidByID = draft.paidByID ?? fallbackID
        let paidByID = validIDs.contains(requestedPaidByID) ? requestedPaidByID : fallbackID

        var splitIDs = draft.splitWithIDs.isEmpty ? validIDs : draft.splitWithIDs.intersection(validIDs)
        if splitIDs.isEmpty {
            splitIDs = validIDs
        }

        return (paidByID, splitIDs)
    }

    private func equalSplits(total: Double, splitIDs: Set<String>) -> [CreateSplitRequest] {
        let sortedIDs = splitIDs.sorted()
        guard sortedIDs.isEmpty == false else { return [] }
        let cents = Int((total * 100).rounded())
        let base = cents / sortedIDs.count
        let remainder = cents - (base * sortedIDs.count)

        return sortedIDs.enumerated().map { index, userID in
            let amountInCents = base + (index < remainder ? 1 : 0)
            return CreateSplitRequest(userId: userID, amount: Double(amountInCents) / 100, percentage: nil, shares: nil)
        }
    }

    private func encodedDescription(location: String, dates: String) -> String {
        "\(location.trimmedOrDefault("Somewhere")) | \(dates.trimmedOrDefault("Dates TBD"))"
    }

    private func decodedDescription(_ value: String?) -> (location: String, dates: String) {
        guard let value, value.isEmpty == false else {
            return ("Somewhere", "Dates TBD")
        }
        let parts = value.components(separatedBy: " | ")
        if parts.count >= 2 {
            return (parts[0].trimmedOrDefault("Somewhere"), parts[1].trimmedOrDefault("Dates TBD"))
        }
        return (value.trimmedOrDefault("Somewhere"), "Dates TBD")
    }

    private func setError(_ error: Error) {
        BillBanditLog.ledger("event=ledger.error.presented error=\(BillBanditLog.sanitizedError(error))")
        if let localized = error as? LocalizedError, let description = localized.errorDescription {
            errorMessage = description
        } else {
            errorMessage = error.localizedDescription
        }
    }

    private func setValidationError(_ message: String) {
        BillBanditLog.ledger("event=ledger.error.presented error=validation")
        errorMessage = message
    }

    private static func seedTrips() -> [InkTrip] {
        let you = InkFriend(name: "You", contact: "meera@billbandit.local")
        let meera = InkFriend(name: "Meera")
        let arjun = InkFriend(name: "Arjun")
        let kabir = InkFriend(name: "Kabir")
        let nidhi = InkFriend(name: "Nidhi")
        let goaFriends = [you, meera, arjun, kabir, nidhi]
        let goa = InkTrip(
            title: "Goa, India",
            location: "Goa, India",
            dates: "4–8 Dec 2026",
            status: .open,
            friends: goaFriends,
            expenses: [
                InkExpense(title: "Beach shack lunch", amount: 1250, paidByID: you.id, splitWithIDs: Set(goaFriends.map(\.id)), day: "D2"),
                InkExpense(title: "Scooter rentals", amount: 900, paidByID: meera.id, splitWithIDs: Set(goaFriends.map(\.id)), day: "D2"),
                InkExpense(title: "Check-in groceries", amount: 2100, paidByID: arjun.id, splitWithIDs: Set(goaFriends.map(\.id)), day: "D1"),
                InkExpense(title: "Villa advance", amount: 5600, paidByID: you.id, splitWithIDs: Set(goaFriends.map(\.id)), day: "D1"),
                InkExpense(title: "Airport taxi", amount: 2550, paidByID: you.id, splitWithIDs: Set(goaFriends.map(\.id)), day: "D1")
            ]
        )

        let palampurFriends = [you, meera, arjun, kabir]
        let palampur = InkTrip(
            title: "Palampur, Himachal",
            location: "Palampur, Himachal",
            dates: "12–16 Jun 2026",
            status: .final,
            friends: palampurFriends,
            expenses: [
                InkExpense(title: "Taxi to Bir", amount: 3200, paidByID: you.id, splitWithIDs: Set(palampurFriends.map(\.id))),
                InkExpense(title: "Lunch at landing site", amount: 2840, paidByID: meera.id, splitWithIDs: Set(palampurFriends.map(\.id))),
                InkExpense(title: "Homestay advance", amount: 9600, paidByID: you.id, splitWithIDs: Set(palampurFriends.map(\.id))),
                InkExpense(title: "Bonfire supplies", amount: 3280, paidByID: arjun.id, splitWithIDs: Set(palampurFriends.map(\.id)))
            ]
        )

        let coorgFriends = [you, meera, arjun, kabir, nidhi, InkFriend(name: "Rhea")]
        let coorg = InkTrip(
            title: "Offsite, Coorg",
            location: "Coorg",
            dates: "3–5 Apr 2026",
            status: .final,
            friends: coorgFriends,
            expenses: [
                InkExpense(title: "Estate stay", amount: 7800, paidByID: you.id, splitWithIDs: Set(coorgFriends.map(\.id))),
                InkExpense(title: "Coffee tasting", amount: 1850, paidByID: nidhi.id, splitWithIDs: Set(coorgFriends.map(\.id))),
                InkExpense(title: "Dinner spread", amount: 5000, paidByID: you.id, splitWithIDs: Set(coorgFriends.map(\.id)))
            ]
        )
        return [goa, palampur, coorg]
    }
}

struct BillBanditInkPrototypeView: View {
    @EnvironmentObject private var liveOverrides: LiveDesignOverrides
    @State private var screen: InkScreen
    @StateObject private var store: InkTripStore
    @State private var selectedTripID: String?
    @State private var editingTripID: String?
    @State private var tripDraft = InkTripDraft.fresh
    @State private var editingExpenseID: String?
    @State private var friendReturnScreen = InkScreen.newLedger
    @State private var pendingSettlement: InkSettlement?
    @State private var didConfigureStore = false
    private let apiClient: APIClient?
    private let currentUser: UserDTO?
    private let onWelcomeLogin: (() -> Void)?
    private let onWelcomeCreateAccount: (() -> Void)?

    init(
        initialScreen: InkScreen = InkScreen.fromLaunchArguments(),
        apiClient: APIClient? = nil,
        currentUser: UserDTO? = nil,
        onWelcomeLogin: (() -> Void)? = nil,
        onWelcomeCreateAccount: (() -> Void)? = nil
    ) {
        _screen = State(initialValue: initialScreen)
        let demoTrips = ProcessInfo.processInfo.arguments.contains("--ink-demo-data") ? InkTripStore.demoTrips() : []
        _store = StateObject(wrappedValue: InkTripStore(trips: demoTrips))
        self.apiClient = apiClient
        self.currentUser = currentUser
        self.onWelcomeLogin = onWelcomeLogin
        self.onWelcomeCreateAccount = onWelcomeCreateAccount
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    liveOverrides.color("theme.screen.start", fallback: Ink.Blue.blue),
                    liveOverrides.color("theme.screen.middle", fallback: Ink.Blue.blue2),
                    liveOverrides.color("theme.screen.end", fallback: Color(red: 0.04, green: 0.12, blue: 0.64))
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
                .ignoresSafeArea()

            currentScreen
        }
        .overlay(alignment: .top) {
            storeStatusBanner
        }
        .tint(Ink.Blue.cream)
        .preferredColorScheme(.dark)
        .task {
            await configureStoreIfNeeded()
        }
    }

    @ViewBuilder
    private var currentScreen: some View {
        switch screen {
        case .welcome:
            WelcomeInkScreen(
                onLogin: {
                    if let onWelcomeLogin {
                        onWelcomeLogin()
                    } else {
                        screen = store.trips.isEmpty ? .tripsEmpty : .yourTrips
                    }
                },
                onCreateAccount: {
                    if let onWelcomeCreateAccount {
                        onWelcomeCreateAccount()
                    } else {
                        screen = .newMember
                    }
                }
            )
        case .newMember:
            NewMemberInkScreen(
                onClose: { screen = store.trips.isEmpty ? .tripsEmpty : .yourTrips },
                onCreate: { screen = store.trips.isEmpty ? .tripsEmpty : .yourTrips }
            )
        case .tripsEmpty:
            TripsEmptyInkScreen(
                onStart: {
                    editingTripID = nil
                    tripDraft = .fresh
                    screen = .newLedger
                },
                onTrips: { screen = .yourTrips }
            )
        case .yourTrips:
            YourTripsInkScreen(
                trips: store.trips,
                summary: { store.summary(for: $0) },
                onAdd: {
                    editingTripID = nil
                    tripDraft = .fresh
                    screen = .newLedger
                },
                onOpen: { trip in
                    selectedTripID = trip.id
                    screen = trip.status == .final ? .finalBill : .liveLedger
                },
                onTab: handleTab
            )
        case .newLedger:
            NewLedgerInkScreen(
                draft: $tripDraft,
                isEditing: editingTripID != nil,
                isRemoteBacked: store.isRemoteBacked,
                onClose: { screen = .yourTrips },
                onOpen: {
                    Task {
                        if let editingTripID {
                            store.updateTrip(id: editingTripID, from: tripDraft)
                            selectedTripID = editingTripID
                            self.editingTripID = nil
                            tripDraft = .fresh
                            screen = .liveLedger
                        } else if let trip = await store.createTrip(from: tripDraft) {
                            selectedTripID = trip.id
                            self.editingTripID = nil
                            tripDraft = .fresh
                            screen = .liveLedger
                        }
                    }
                },
                onAddFriend: {
                    friendReturnScreen = .newLedger
                    screen = .addFriend
                }
            )
        case .liveLedger:
            if let trip = store.trip(id: selectedTripID) {
                LiveLedgerInkScreen(
                    trip: trip,
                    summary: store.summary(for: trip),
                    isRemoteBacked: store.isRemoteBacked,
                    onBack: { screen = .yourTrips },
                    onAdd: {
                        editingExpenseID = nil
                        screen = .addEntry
                    },
                    onEditTrip: {
                        editingTripID = trip.id
                        tripDraft = InkTripDraft(trip: trip)
                        screen = .newLedger
                    },
                    onEditExpense: { expense in
                        editingExpenseID = expense.id
                        screen = .addEntry
                    },
                    onAddFriend: {
                        friendReturnScreen = .liveLedger
                        screen = .addFriend
                    },
                    onTab: handleTab
                )
            }
        case .settle:
            if let trip = store.trip(id: selectedTripID) ?? store.trips.first {
                SettleInkScreen(
                    trip: trip,
                    settlements: store.settlements(for: trip),
                    onRecord: { settlement in
                        pendingSettlement = settlement
                        screen = .recordPayment
                    },
                    onTab: handleTab
                )
            }
        case .recordPayment:
            if let trip = store.trip(id: selectedTripID) ?? store.trips.first,
               let settlement = pendingSettlement ?? store.settlements(for: trip).first {
                RecordPaymentInkScreen(
                    trip: trip,
                    settlement: settlement,
                    currentUserID: store.currentUserID,
                    errorMessage: store.errorMessage,
                    onClose: { screen = .settle },
                    onStamp: {
                        let didRecord = await store.recordSettlement(settlement, in: trip.id)
                        if didRecord {
                            pendingSettlement = nil
                            if let refreshedTrip = store.trip(id: trip.id), store.settlements(for: refreshedTrip).isEmpty {
                                screen = .finalBill
                            } else {
                                screen = .settle
                            }
                        }
                        return didRecord
                    }
                )
            }
        case .finalBill:
            if let trip = store.trip(id: selectedTripID) ?? store.trips.first {
                FinalBillInkScreen(
                    trip: trip,
                    summary: store.summary(for: trip),
                    onBack: { screen = .settle },
                    onTab: handleTab
                )
            }
        case .addEntry:
            if let trip = store.trip(id: selectedTripID) ?? store.trips.first {
                AddEntryInkScreen(
                    trip: trip,
                    editingExpense: trip.expenses.first { $0.id == editingExpenseID },
                    errorMessage: store.errorMessage,
                    onClose: { screen = .liveLedger },
                    onDelete: { expense in
                        let deleted = await store.deleteExpense(expense.id, in: trip.id)
                        if deleted {
                            editingExpenseID = nil
                            screen = .liveLedger
                        }
                        return deleted
                    },
                    onSave: { draft in
                        let saved = await store.saveExpense(draft, in: trip.id, editing: editingExpenseID)
                        if saved {
                            editingExpenseID = nil
                            screen = .liveLedger
                        }
                        return saved
                    }
                )
            }
        case .addFriend:
            AddFriendInkScreen(
                errorMessage: store.errorMessage,
                requiresContact: friendReturnScreen != .newLedger && store.isRemoteBacked,
                onClose: { screen = friendReturnScreen },
                onAdd: { name, contact in
                    if friendReturnScreen == .newLedger {
                        tripDraft.friendNames.append(name.trimmedOrDefault(contact.trimmedOrDefault("New friend")))
                        return true
                    } else if let selectedTripID {
                        return await store.addFriend(named: name, contact: contact, to: selectedTripID)
                    }
                    return false
                }
            )
        }
    }

    @ViewBuilder
    private var storeStatusBanner: some View {
        if store.isLoading {
            InkStatusBanner(title: "Syncing", message: "Refreshing your ledgers", systemImage: "arrow.triangle.2.circlepath")
                .padding(.horizontal, 18)
                .padding(.top, 10)
                .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private func handleTab(_ tab: InkBottomTab) {
        switch tab {
        case .ledger:
            if selectedTripID == nil { selectedTripID = store.trips.first?.id }
            screen = .liveLedger
        case .trips:
            screen = .yourTrips
        case .settle:
            if selectedTripID == nil { selectedTripID = store.trips.first?.id }
            screen = .settle
        case .profile:
            screen = .newMember
        }
    }

    private func configureStoreIfNeeded() async {
        guard didConfigureStore == false else { return }
        didConfigureStore = true
        guard let apiClient, let currentUser else { return }
        await store.configure(apiClient: apiClient, currentUser: currentUser)
        if screen == .tripsEmpty, store.trips.isEmpty == false {
            screen = .yourTrips
        }
    }
}

private extension String {
    func trimmedOrDefault(_ fallback: String) -> String {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }
}

private extension Array where Element == String {
    func uniqued() -> [String] {
        var seen = Set<String>()
        return filter { seen.insert($0.lowercased()).inserted }
    }
}

private enum Ink {
    enum Blue {
        static let canvas1 = Color(red: 0.05, green: 0.09, blue: 0.34)
        static let canvas2 = Color(red: 0.03, green: 0.05, blue: 0.20)
        static let blue = Color(red: 0.14, green: 0.19, blue: 0.88)
        static let blue2 = Color(red: 0.11, green: 0.16, blue: 0.82)
        static let cream = Color(red: 0.96, green: 0.94, blue: 0.88)
        static let cream2 = Color(red: 0.93, green: 0.89, blue: 0.78)
        static let ink = Color(red: 0.14, green: 0.14, blue: 0.17)
        static let inkSoft = Color(red: 0.42, green: 0.42, blue: 0.44)
        static let rule = Color(red: 0.80, green: 0.76, blue: 0.63)
        static let cobalt = Color(red: 0.13, green: 0.19, blue: 0.90)
        static let peri = Color(red: 0.64, green: 0.68, blue: 0.94)
        static let periDim = Color(red: 0.49, green: 0.53, blue: 0.85)

        static let screen = LinearGradient(
            colors: [blue, blue2, Color(red: 0.04, green: 0.12, blue: 0.64)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func mono(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    static func serif(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    static func script(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .custom("Noteworthy-Bold", size: size).weight(weight)
    }
}

private struct InkAppShell<Content: View>: View {
    var title: String
    var leftIcon: String?
    var rightIcon: String?
    var onLeft: (() -> Void)?
    var onRight: (() -> Void)?
    var activeTab: InkBottomTab?
    var onTab: ((InkBottomTab) -> Void)?
    var contentSpacing: CGFloat = 18
    var showsTopBar = true
    @ViewBuilder var content: Content
    private let statusBarTopOffset: CGFloat = -38
    private let topBarTopSpacing: CGFloat = 60

    var body: some View {
        VStack(spacing: 0) {
            InkStatusBar()
                .padding(.horizontal, 22)
                .padding(.top, statusBarTopOffset)

            if showsTopBar {
                InkTopBar(
                    title: title,
                    leftIcon: leftIcon,
                    rightIcon: rightIcon,
                    onLeft: onLeft,
                    onRight: onRight
                )
                .padding(.horizontal, 20)
                .padding(.top, topBarTopSpacing)
            }

            ScrollView(showsIndicators: false) {
                VStack(spacing: contentSpacing) {
                    content
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, activeTab == nil ? 28 : 108)
            }
        }
        .overlay(alignment: .bottom) {
            if let activeTab, let onTab {
                InkBottomTabs(active: activeTab, onSelect: onTab)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            }
        }
    }
}

private struct InkStatusBar: View {
    var body: some View {
        HStack {
            Text("9:41")
                .font(.system(size: 14, weight: .bold, design: .rounded))
            Spacer()
            HStack(spacing: 5) {
                Image(systemName: "cellularbars")
                Image(systemName: "wifi")
                Image(systemName: "battery.100")
            }
            .font(.system(size: 12, weight: .bold))
        }
        .foregroundStyle(Ink.Blue.cream)
    }
}

private struct InkTopBar: View {
    let title: String
    var leftIcon: String?
    var rightIcon: String?
    var onLeft: (() -> Void)?
    var onRight: (() -> Void)?

    var body: some View {
        ZStack {
            HStack {
                if let leftIcon {
                    Button(action: { onLeft?() }) {
                        Image(systemName: leftIcon)
                            .font(.system(size: 21, weight: .semibold))
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("top.left")
                } else {
                    Color.clear.frame(width: 36, height: 36)
                }

                Spacer()

                if let rightIcon {
                    Button(action: { onRight?() }) {
                        Image(systemName: rightIcon)
                            .font(.system(size: 21, weight: .semibold))
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("top.right")
                } else {
                    Color.clear.frame(width: 36, height: 36)
                }
            }

            Text(title.uppercased())
                .font(Ink.mono(13, weight: .heavy))
                .tracking(5.2)
                .foregroundStyle(Ink.Blue.cream)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .foregroundStyle(Ink.Blue.cream)
    }
}

private enum InkBottomTab: CaseIterable {
    case ledger
    case settle
    case trips
    case profile

    var title: String {
        switch self {
        case .ledger: "LEDGER"
        case .settle: "SETTLE"
        case .trips: "TRIPS"
        case .profile: "PROFILE"
        }
    }

    var icon: String {
        switch self {
        case .ledger: "list.bullet.rectangle"
        case .settle: "arrow.left.arrow.right"
        case .trips: "briefcase"
        case .profile: "person"
        }
    }
}

private struct InkBottomTabs: View {
    let active: InkBottomTab
    let onSelect: (InkBottomTab) -> Void

    private var tabs: [InkBottomTab] {
        [.ledger, .settle, .trips, .profile]
    }

    var body: some View {
        HStack {
            ForEach(tabs, id: \.self) { tab in
                Button { onSelect(tab) } label: {
                    VStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 18, weight: .medium))
                            .frame(height: 20)
                        Text(tab.title)
                            .font(Ink.mono(9, weight: .heavy))
                            .tracking(1.4)
                        Circle()
                            .fill(tab == active ? Ink.Blue.cream : .clear)
                            .frame(width: 5, height: 5)
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(tab == active ? Ink.Blue.cream : Ink.Blue.cream.opacity(0.70))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Ink.Blue.cobalt.opacity(0.19))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Ink.Blue.cream.opacity(0.10), lineWidth: 1)
                )
        }
    }
}

private struct InkReceipt<Content: View>: View {
    var topScallop = true
    var bottomScallop = true
    var padding: CGFloat = 20
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            if topScallop {
                PerforatedEdge(color: Ink.Blue.cream, holeColor: Ink.Blue.blue, inverted: true)
            }
            content
                .padding(padding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Ink.Blue.cream)
            if bottomScallop {
                PerforatedEdge(color: Ink.Blue.cream, holeColor: Ink.Blue.blue, inverted: false)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .shadow(color: Color.black.opacity(0.20), radius: 18, x: 0, y: 10)
    }
}

private struct PerforatedEdge: View {
    let color: Color
    let holeColor: Color
    var inverted: Bool

    var body: some View {
        ZStack {
            color.frame(height: 10)
            GeometryReader { proxy in
                let count = max(12, Int(proxy.size.width / 11))
                HStack(spacing: 5) {
                    ForEach(0..<count, id: \.self) { _ in
                        Circle()
                            .fill(holeColor)
                            .frame(width: 5.5, height: 5.5)
                    }
                }
                .frame(maxWidth: .infinity)
                .offset(y: inverted ? -3 : 3)
            }
        }
        .frame(height: 10)
    }
}

private struct DashedRule: View {
    var body: some View {
        Line()
            .stroke(Ink.Blue.rule, style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
            .frame(height: 1)
    }

    private struct Line: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            return path
        }
    }
}

private struct SolidRule: View {
    var body: some View {
        VStack(spacing: 3) {
            Rectangle().fill(Ink.Blue.ink.opacity(0.65)).frame(height: 1)
            Rectangle().fill(Ink.Blue.ink.opacity(0.45)).frame(height: 1)
        }
    }
}

private struct ReceiptLabel: View {
    let text: String
    var color: Color = Ink.Blue.ink

    var body: some View {
        Text(text.uppercased())
            .font(Ink.mono(10, weight: .heavy))
            .tracking(1.9)
            .foregroundStyle(color)
    }
}

private struct SerifTitle: View {
    @EnvironmentObject private var liveOverrides: LiveDesignOverrides

    let text: String
    var size: CGFloat = 34
    var color: Color = Ink.Blue.cream
    var overrideID: String?

    var body: some View {
        if liveOverrides.bool("\(overrideID ?? "").hidden") == false {
            Text(liveOverrides.text("\(overrideID ?? "").title", fallback: text))
                .font(Ink.serif(liveOverrides.number("\(overrideID ?? "").fontSize", fallback: size), weight: .regular))
                .foregroundStyle(liveOverrides.color("\(overrideID ?? "").color", fallback: color))
                .lineLimit(nil)
                .minimumScaleFactor(0.78)
        }
    }
}

private struct ScriptText: View {
    let text: String
    var size: CGFloat = 28

    var body: some View {
        Text(text)
            .font(Ink.script(size, weight: .bold))
            .foregroundStyle(Ink.Blue.cobalt)
            .lineLimit(1)
            .minimumScaleFactor(0.65)
    }
}

private struct InkStamp: View {
    let text: String
    var angle: Double = -5

    var body: some View {
        Text(text.uppercased())
            .font(Ink.mono(12, weight: .heavy))
            .tracking(2.0)
            .foregroundStyle(Ink.Blue.cobalt)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .overlay(
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .stroke(Ink.Blue.cobalt, lineWidth: 1.6)
            )
            .rotationEffect(.degrees(angle))
    }
}

private struct RoundSeal: View {
    @EnvironmentObject private var liveOverrides: LiveDesignOverrides

    let text: String
    var size: CGFloat = 62
    var tone: Color = Ink.Blue.cobalt
    var overrideID: String?

    var body: some View {
        if liveOverrides.bool("\(overrideID ?? "").hidden") == false {
            let resolvedSize = liveOverrides.number("\(overrideID ?? "").size", fallback: size)
            let resolvedTone = liveOverrides.color("\(overrideID ?? "").color", fallback: tone)
            ZStack {
                Circle().stroke(resolvedTone, lineWidth: 1.5)
                Circle().stroke(resolvedTone.opacity(0.65), lineWidth: 1).padding(5)
                Text(liveOverrides.text("\(overrideID ?? "").title", fallback: text).uppercased())
                    .font(Ink.mono(resolvedSize > 50 ? 10 : 7, weight: .heavy))
                    .tracking(1.0)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(resolvedTone)
                    .padding(10)
            }
            .frame(width: resolvedSize, height: resolvedSize)
        }
    }
}

private struct PrimaryCreamButton: View {
    @EnvironmentObject private var liveOverrides: LiveDesignOverrides

    let title: String
    var isLoading = false
    var isDisabled = false
    var overrideID: String?
    var action: () -> Void

    @ViewBuilder
    var body: some View {
        if liveOverrides.bool("\(overrideID ?? "").hidden") == false {
            Button {
                guard isDisabled == false, isLoading == false else { return }
                action()
            } label: {
                HStack(spacing: 9) {
                    if isLoading {
                        ProgressView()
                            .tint(Ink.Blue.ink)
                            .controlSize(.small)
                    }
                    Text(isLoading ? "Saving" : liveOverrides.text("\(overrideID ?? "").title", fallback: title))
                        .font(Ink.serif(liveOverrides.number("\(overrideID ?? "").fontSize", fallback: 18), weight: .semibold))
                }
                    .foregroundStyle(
                        liveOverrides
                            .color("\(overrideID ?? "").foreground", fallback: Ink.Blue.ink)
                            .opacity(isDisabled ? 0.52 : 1)
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, liveOverrides.number("\(overrideID ?? "").paddingVertical", fallback: 15))
                    .background(
                        liveOverrides
                            .color("\(overrideID ?? "").background", fallback: Ink.Blue.cream)
                            .opacity(isDisabled ? 0.55 : 1),
                        in: Capsule()
                    )
            }
            .buttonStyle(.plain)
            .disabled(isDisabled || isLoading)
        }
    }
}

private struct InkStatusBanner: View {
    let title: String
    let message: String
    var systemImage = "exclamationmark.triangle.fill"

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .bold))
            VStack(alignment: .leading, spacing: 2) {
                Text(title.uppercased())
                    .font(Ink.mono(10, weight: .heavy))
                    .tracking(1.2)
                Text(message)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(Ink.Blue.cream)
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Ink.Blue.ink.opacity(0.82))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Ink.Blue.cream.opacity(0.16), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 7)
    }
}

private struct OutlineCreamButton: View {
    @EnvironmentObject private var liveOverrides: LiveDesignOverrides

    let title: String
    var overrideID: String?
    var action: () -> Void

    @ViewBuilder
    var body: some View {
        if liveOverrides.bool("\(overrideID ?? "").hidden") == false {
            Button(action: action) {
                let foreground = liveOverrides.color("\(overrideID ?? "").foreground", fallback: Ink.Blue.cream)
                Text(liveOverrides.text("\(overrideID ?? "").title", fallback: title))
                    .font(Ink.serif(liveOverrides.number("\(overrideID ?? "").fontSize", fallback: 17), weight: .semibold))
                    .foregroundStyle(foreground)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, liveOverrides.number("\(overrideID ?? "").paddingVertical", fallback: 15))
                    .overlay(Capsule().stroke(foreground, lineWidth: 1.3))
            }
            .buttonStyle(.plain)
        }
    }
}

private struct InkBlackButton: View {
    @EnvironmentObject private var liveOverrides: LiveDesignOverrides

    let title: String
    var overrideID: String?
    var action: () -> Void

    @ViewBuilder
    var body: some View {
        if liveOverrides.bool("\(overrideID ?? "").hidden") == false {
            Button(action: action) {
                Text(liveOverrides.text("\(overrideID ?? "").title", fallback: title))
                    .font(Ink.serif(liveOverrides.number("\(overrideID ?? "").fontSize", fallback: 18), weight: .semibold))
                    .foregroundStyle(liveOverrides.color("\(overrideID ?? "").foreground", fallback: Ink.Blue.cream))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, liveOverrides.number("\(overrideID ?? "").paddingVertical", fallback: 15))
                    .background(liveOverrides.color("\(overrideID ?? "").background", fallback: Ink.Blue.ink), in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }
}

private struct ChipLine: View {
    let items: [String]
    var selected: String?
    var selectedItems: Set<String> = []
    var onTap: ((String) -> Void)?

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(items, id: \.self) { item in
                let isSelected = item == selected || selectedItems.contains(item)
                Button {
                    onTap?(item)
                } label: {
                    Text(item)
                        .font(Ink.mono(12, weight: .bold))
                        .foregroundStyle(isSelected ? Ink.Blue.cream : Ink.Blue.ink)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 8)
                        .background(isSelected ? Ink.Blue.ink : Color.clear, in: Capsule())
                        .overlay(Capsule().stroke(Ink.Blue.ink.opacity(0.8), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityValue(isSelected ? "selected" : "not selected")
            }
        }
    }
}

private struct FlowLayout<Content: View>: View {
    var spacing: CGFloat = 8
    @ViewBuilder var content: Content

    var body: some View {
        HStack(spacing: spacing) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct AvatarStack: View {
    var size: CGFloat = 22
    var names: [String] = ["Y", "M", "A", "K", "N"]
    private let colors: [Color] = [
        Ink.Blue.cobalt,
        Color(red: 0.96, green: 0.55, blue: 0.28),
        Color(red: 0.34, green: 0.68, blue: 0.66),
        Color(red: 0.75, green: 0.58, blue: 0.90),
        Color(red: 0.95, green: 0.78, blue: 0.28)
    ]

    var body: some View {
        HStack(spacing: -6) {
            ForEach(Array(names.prefix(colors.count).enumerated()), id: \.offset) { index, name in
                Circle()
                    .fill(colors[index])
                    .frame(width: size, height: size)
                    .overlay {
                        Text(name)
                            .font(Ink.mono(size * 0.40, weight: .heavy))
                            .foregroundStyle(Ink.Blue.cream)
                    }
                    .overlay(Circle().stroke(Ink.Blue.cream, lineWidth: 1.2))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(names.count) friends")
    }
}

private struct BarcodeStrip: View {
    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<34, id: \.self) { index in
                Rectangle()
                    .fill(Ink.Blue.ink)
                    .frame(width: index % 5 == 0 ? 2.5 : 1.2, height: CGFloat([18, 25, 14, 30, 20][index % 5]))
            }
        }
        .frame(maxWidth: .infinity)
        .clipped()
    }
}

private struct WelcomeInkScreen: View {
    @EnvironmentObject private var liveOverrides: LiveDesignOverrides

    let onLogin: () -> Void
    let onCreateAccount: () -> Void

    var body: some View {
        InkAppShell(
            title: "",
            contentSpacing: liveOverrides.number("welcome.contentSpacing", fallback: 14),
            showsTopBar: false
        ) {
            Spacer(minLength: liveOverrides.number("welcome.topSpacer", fallback: 34))
            if liveOverrides.bool("welcome.brand.hidden") == false {
                Text(liveOverrides.text("welcome.brand.title", fallback: "BillBandit"))
                    .font(Ink.serif(liveOverrides.number("welcome.brand.fontSize", fallback: 29), weight: .semibold))
                    .foregroundStyle(liveOverrides.color("welcome.brand.color", fallback: Ink.Blue.cream))
            }

            if liveOverrides.bool("welcome.mascot.hidden") == false {
                MascotWelcome(size: liveOverrides.number("welcome.mascot.size", fallback: 204))
                    .frame(maxWidth: .infinity)
            }

            VStack(spacing: liveOverrides.number("welcome.hero.spacing", fallback: 9)) {
                if liveOverrides.bool("welcome.tagline.hidden") == false {
                    Text(liveOverrides.text("welcome.tagline.title", fallback: "he used to steal, now he settles"))
                        .font(Ink.mono(liveOverrides.number("welcome.tagline.fontSize", fallback: 10), weight: .heavy))
                        .tracking(1.4)
                        .foregroundStyle(liveOverrides.color("welcome.tagline.color", fallback: Ink.Blue.peri))
                }
                VStack(spacing: liveOverrides.number("welcome.titleStack.spacing", fallback: 10)) {
                    SerifTitle(text: "The trip ends", size: 38, overrideID: "welcome.primaryTitle")
                    if liveOverrides.bool("welcome.secondaryTitle.hidden") == false {
                        Text(liveOverrides.text("welcome.secondaryTitle.title", fallback: "The tab settles itself"))
                            .font(Ink.serif(liveOverrides.number("welcome.secondaryTitle.fontSize", fallback: 34)).italic())
                            .foregroundStyle(liveOverrides.color("welcome.secondaryTitle.color", fallback: Ink.Blue.cream))
                            .multilineTextAlignment(.center)
                    }
                }
                .multilineTextAlignment(.center)

                if liveOverrides.bool("welcome.divider.hidden") == false {
                    HStack {
                        Rectangle().fill(liveOverrides.color("welcome.divider.color", fallback: Ink.Blue.cream).opacity(0.7)).frame(height: 1)
                        Text("✦").foregroundStyle(liveOverrides.color("welcome.divider.color", fallback: Ink.Blue.cream))
                        Rectangle().fill(liveOverrides.color("welcome.divider.color", fallback: Ink.Blue.cream).opacity(0.7)).frame(height: 1)
                    }
                    .frame(width: liveOverrides.number("welcome.divider.width", fallback: 240))
                    .padding(.vertical, 2)
                }
            }

            RoundSeal(text: "NO MORE MONEY\nDRAMA | EST.\n2026", size: 76, tone: Ink.Blue.cream.opacity(0.55), overrideID: "welcome.seal")
                .padding(.top, 2)

            VStack(spacing: liveOverrides.number("welcome.actions.spacing", fallback: 12)) {
                PrimaryCreamButton(title: "Login", overrideID: "welcome.loginButton", action: onLogin)
                    .accessibilityIdentifier("welcome.login")
                OutlineCreamButton(title: "Create an account", overrideID: "welcome.createAccountButton", action: onCreateAccount)
                    .accessibilityIdentifier("welcome.createAccount")
            }
            .padding(.top, liveOverrides.number("welcome.actions.topPadding", fallback: 4))
        }
    }
}

private struct NewMemberInkScreen: View {
    let onClose: () -> Void
    let onCreate: () -> Void

    var body: some View {
        InkAppShell(title: "New Member", leftIcon: "xmark", onLeft: onClose) {
            MascotPeek(size: 128)
                .frame(maxWidth: .infinity)
                .padding(.bottom, -20)
                .zIndex(2)

            InkReceipt {
                VStack(alignment: .leading, spacing: 16) {
                    ReceiptLabel(text: "Create your account")
                        .frame(maxWidth: .infinity)
                    DashedRule()

                    ReceiptField(label: "Full name", value: "Meera Kapoor")
                    ReceiptField(label: "Phone or email", value: "meera.kapoor@gmail.com")
                    ReceiptField(label: "Preferred name (optional)", value: "Meera")

                    HStack {
                        Spacer()
                        RoundSeal(text: "Fair\nShare", size: 64)
                    }
                }
            }

            PrimaryCreamButton(title: "Create account", action: onCreate)
                .accessibilityIdentifier("newMember.create")
        }
    }
}

private struct ReceiptField: View {
    let label: String
    let value: String
    var script = true

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(Ink.mono(11, weight: .bold))
                .foregroundStyle(Ink.Blue.ink)
            if script {
                ScriptText(text: value, size: 23)
            } else {
                Text(value)
                    .font(Ink.mono(15, weight: .semibold))
                    .foregroundStyle(Ink.Blue.ink)
            }
            DashedRule()
        }
    }
}

private struct ReceiptTextField: View {
    let label: String
    @Binding var value: String
    var keyboardType: UIKeyboardType = .default
    var autocapitalization: TextInputAutocapitalization = .words
    var submitLabel: SubmitLabel = .return
    var script = true
    var identifier: String?
    var onSubmit: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(Ink.mono(11, weight: .bold))
                .foregroundStyle(Ink.Blue.ink)
            TextField(label, text: $value)
                .font(script ? Ink.script(23, weight: .bold) : Ink.mono(15, weight: .semibold))
                .foregroundStyle(script ? Ink.Blue.cobalt : Ink.Blue.ink)
                .keyboardType(keyboardType)
                .textInputAutocapitalization(autocapitalization)
                .autocorrectionDisabled()
                .submitLabel(submitLabel)
                .onSubmit {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    onSubmit()
                }
                .accessibilityIdentifier(identifier ?? "field.\(label)")
            DashedRule()
        }
    }
}

private struct TripsEmptyInkScreen: View {
    let onStart: () -> Void
    let onTrips: () -> Void

    var body: some View {
            InkAppShell(
                title: "My Trips",
                rightIcon: "plus",
                onRight: onStart,
                activeTab: .trips,
                onTab: { tab in
                    if tab == .trips {
                        onTrips()
                    }
                }
            ) {
            Spacer(minLength: 40)
            MascotThinking(size: 172)
                .frame(maxWidth: .infinity)

            VStack(spacing: 14) {
                SerifTitle(text: "No tabs running", size: 36)
                    .multilineTextAlignment(.center)
                HStack {
                    Rectangle().fill(Ink.Blue.cream.opacity(0.7)).frame(height: 1)
                    Text("✦").foregroundStyle(Ink.Blue.cream)
                    Rectangle().fill(Ink.Blue.cream.opacity(0.7)).frame(height: 1)
                }
                .frame(width: 180)
                Text("When you start a trip, it’ll show up here\nAdd friends, jot expenses, and let BillBandit do the math")
                    .font(.system(size: 15, design: .rounded))
                    .foregroundStyle(Ink.Blue.cream.opacity(0.82))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 18)
            }
            .frame(maxWidth: .infinity)

            PrimaryCreamButton(title: "Start a trip", action: onStart)
                .padding(.top, 24)
        }
    }
}

private struct YourTripsInkScreen: View {
    let trips: [InkTrip]
    let summary: (InkTrip) -> InkLedgerSummary
    let onAdd: () -> Void
    let onOpen: (InkTrip) -> Void
    let onTab: (InkBottomTab) -> Void

    var body: some View {
        InkAppShell(title: "Your Trips", rightIcon: "plus", onRight: onAdd, activeTab: .trips, onTab: onTab, contentSpacing: 10) {
            ForEach(trips) { trip in
                let tripSummary = summary(trip)
                TripCard(
                    title: trip.location.uppercased(),
                    meta: "\(trip.dates.uppercased()) · \(trip.friends.count) FRIENDS · \(trip.expenses.count) ENTRIES",
                    stamp: trip.status == .final ? "FINAL" : "OPEN",
                    leftLabel: trip.status == .final ? "Total booked" : "Running tab",
                    leftAmount: trip.status == .final ? rupees(tripSummary.total) : "~\(rupees(tripSummary.total))",
                    rightLabel: tripSummary.userNet >= 0 ? "You’re owed" : "You owe",
                    rightAmount: signedRupees(abs(tripSummary.userNet), sign: tripSummary.userNet >= 0 ? "" : "−"),
                    showsMascotStamp: trip.status == .open,
                    action: { onOpen(trip) }
                )
                .accessibilityIdentifier("tripCard.\(trip.title)")
            }
        }
    }
}

private struct TripCard: View {
    let title: String
    let meta: String
    let stamp: String
    let leftLabel: String
    let leftAmount: String
    let rightLabel: String
    let rightAmount: String
    var showsMascotStamp = false
    var action: (() -> Void)?

    var body: some View {
        Button(action: { action?() }) {
            InkReceipt(topScallop: true, bottomScallop: true, padding: 15) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top) {
                        Text(title)
                            .font(Ink.serif(24, weight: .regular))
                            .foregroundStyle(Ink.Blue.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                        Spacer()
                        InkStamp(text: stamp)
                    }
                    Text(meta)
                        .font(Ink.mono(10, weight: .bold))
                        .tracking(0.9)
                        .foregroundStyle(Ink.Blue.ink)
                    DashedRule()
                    HStack(alignment: .top) {
                        AmountBlock(label: leftLabel, amount: leftAmount)
                        Spacer()
                        AmountBlock(label: rightLabel, amount: rightAmount)
                    }
                    .background(alignment: .bottomTrailing) {
                        if showsMascotStamp {
                            MascotStamp(size: 40)
                                .offset(x: 8, y: 24)
                                .opacity(0.82)
                                .allowsHitTesting(false)
                        }
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }
}

private struct AmountBlock: View {
    let label: String
    let amount: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            ReceiptLabel(text: label)
            ScriptText(text: amount, size: 24)
        }
    }
}

private struct NewLedgerInkScreen: View {
    @Binding var draft: InkTripDraft
    var isEditing = false
    var isRemoteBacked = false
    let onClose: () -> Void
    let onOpen: () -> Void
    let onAddFriend: () -> Void
    @State private var isShowingDatePicker = false
    @State private var proposedStartDate = InkTripDraft.fresh.startDate
    @State private var proposedEndDate = InkTripDraft.fresh.endDate
    private let defaultFriendCandidates = ["You", "Meera", "Arjun", "Kabir"]

    private var friendCandidates: [String] {
        isRemoteBacked ? draft.friendNames.uniqued() : (defaultFriendCandidates + draft.friendNames).uniqued()
    }

    private var selectedFriends: Set<String> {
        Set(draft.friendNames)
    }

    var body: some View {
        InkAppShell(title: isEditing ? "Edit Ledger" : "New Ledger", leftIcon: "xmark", onLeft: onClose) {
            MascotPeek(size: 124)
                .frame(maxWidth: .infinity)
                .padding(.bottom, -40)
                .zIndex(2)

            InkReceipt {
                VStack(alignment: .leading, spacing: 17) {
                    ReceiptTextField(label: "Ledger name", value: $draft.title, identifier: "newLedger.name")
                    ReceiptTextField(label: "Where", value: $draft.location, script: false, identifier: "newLedger.location")
                    ReceiptDateField(label: "Dates", value: draft.dates, action: {
                        proposedStartDate = draft.startDate
                        proposedEndDate = draft.endDate
                        isShowingDatePicker = true
                    })

                    ReceiptLabel(text: "Friends")
                    ChipLine(items: friendCandidates, selectedItems: selectedFriends, onTap: toggleFriend)
                    if isRemoteBacked {
                        Text("Start the ledger first, then add friends from the live ledger with their BillBandit email.")
                            .font(Ink.mono(11, weight: .medium))
                            .foregroundStyle(Ink.Blue.inkSoft)
                            .lineSpacing(3)
                    } else {
                        ChipLine(items: ["+ add"], onTap: { item in
                            if item == "+ add" {
                                onAddFriend()
                            }
                        })
                    }

                    HStack {
                        Spacer()
                        RoundSeal(text: "Fair\nShare", size: 64)
                    }
                }
            }

            PrimaryCreamButton(title: isEditing ? "Update the ledger" : "Open the ledger", action: onOpen)
            .accessibilityIdentifier("newLedger.open")
        }
        .sheet(isPresented: $isShowingDatePicker) {
            NewLedgerDatePickerSheet(
                startDate: $proposedStartDate,
                endDate: $proposedEndDate,
                onCancel: { isShowingDatePicker = false },
                onApply: {
                    draft.updateDates(start: proposedStartDate, end: proposedEndDate)
                    isShowingDatePicker = false
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
                .accessibilityIdentifier("keyboard.done")
            }
        }
    }

    private func toggleFriend(_ name: String) {
        guard isRemoteBacked == false else {
            draft.friendNames = ["You"]
            return
        }
        if name == "You" {
            if draft.friendNames.contains(name) == false {
                draft.friendNames.insert(name, at: 0)
            }
            return
        }
        if let index = draft.friendNames.firstIndex(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) {
            draft.friendNames.remove(at: index)
        } else {
            draft.friendNames.append(name)
        }
    }
}

private struct ReceiptDateField: View {
    let label: String
    let value: String
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(Ink.mono(11, weight: .bold))
                .foregroundStyle(Ink.Blue.ink)
            Button(action: action) {
                HStack {
                    Text(value)
                        .font(Ink.mono(18, weight: .semibold))
                        .foregroundStyle(Ink.Blue.ink)
                    Spacer()
                    Image(systemName: "calendar")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Ink.Blue.cobalt)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("newLedger.dates")
            DashedRule()
        }
    }
}

private struct NewLedgerDatePickerSheet: View {
    @Binding var startDate: Date
    @Binding var endDate: Date
    let onCancel: () -> Void
    let onApply: () -> Void
    @State private var selectionPhase: SelectionPhase = .start

    private enum SelectionPhase {
        case start
        case end
    }

    private var calendar: Calendar {
        Calendar.current
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_IN")
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: startDate)
    }

    private var daysInDisplayedMonth: [Date] {
        guard
            let monthInterval = calendar.dateInterval(of: .month, for: startDate),
            let dayRange = calendar.range(of: .day, in: .month, for: startDate)
        else { return [] }
        return dayRange.compactMap { day in
            calendar.date(byAdding: .day, value: day - 1, to: monthInterval.start)
        }
    }

    var body: some View {
        ZStack {
            Ink.Blue.screen.ignoresSafeArea()
            VStack(spacing: 16) {
                ReceiptLabel(text: "Choose trip dates", color: Ink.Blue.cream)
                    .padding(.top, 18)

                InkReceipt(topScallop: true, bottomScallop: true, padding: 16) {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 12) {
                            dateSummary(label: "Start", date: startDate, isActive: selectionPhase == .start)
                            dateSummary(label: "End", date: endDate, isActive: selectionPhase == .end)
                        }
                        .accessibilityIdentifier("newLedger.dateRangeRow")

                        DashedRule()

                        HStack {
                            ReceiptLabel(text: monthTitle)
                            Spacer()
                            Text(selectionPhase == .start ? "Pick start" : "Pick end")
                                .font(Ink.mono(11, weight: .bold))
                                .foregroundStyle(Ink.Blue.cobalt)
                        }

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(daysInDisplayedMonth, id: \.self) { date in
                                    dateButton(for: date)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                        .accessibilityIdentifier("newLedger.rangeCalendar")
                    }
                }

                HStack(spacing: 12) {
                    OutlineCreamButton(title: "Cancel", action: onCancel)
                    PrimaryCreamButton(title: "Use dates", action: onApply)
                        .accessibilityIdentifier("newLedger.applyDates")
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 18)
            }
        }
        .onAppear {
            if endDate < startDate {
                endDate = startDate
            }
        }
    }

    private func dateSummary(label: String, date: Date, isActive: Bool) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            ReceiptLabel(text: label)
            Text(shortDate(date))
                .font(Ink.mono(16, weight: .semibold))
                .foregroundStyle(isActive ? Ink.Blue.cream : Ink.Blue.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(isActive ? Ink.Blue.ink : Color.clear, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Ink.Blue.ink.opacity(0.45), lineWidth: 1))
    }

    private func dateButton(for date: Date) -> some View {
        let normalizedDate = calendar.startOfDay(for: date)
        let normalizedStart = calendar.startOfDay(for: startDate)
        let normalizedEnd = calendar.startOfDay(for: endDate)
        let isStart = normalizedDate == normalizedStart
        let isEnd = normalizedDate == normalizedEnd
        let isInRange = normalizedDate > normalizedStart && normalizedDate < normalizedEnd
        let isSelected = isStart || isEnd

        return Button {
            select(date)
        } label: {
            VStack(spacing: 5) {
                Text(weekday(date))
                    .font(Ink.mono(9, weight: .bold))
                Text("\(calendar.component(.day, from: date))")
                    .font(Ink.mono(16, weight: .bold))
            }
            .foregroundStyle(isSelected ? Ink.Blue.cream : Ink.Blue.ink)
            .frame(width: 46, height: 54)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? Ink.Blue.cobalt : (isInRange ? Ink.Blue.cobalt.opacity(0.12) : Color.clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected || isInRange ? Ink.Blue.cobalt : Ink.Blue.ink.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("newLedger.date.\(calendar.component(.day, from: date))")
    }

    private func select(_ date: Date) {
        let pickedDate = calendar.startOfDay(for: date)
        switch selectionPhase {
        case .start:
            startDate = pickedDate
            endDate = pickedDate
            selectionPhase = .end
        case .end:
            if pickedDate < startDate {
                endDate = startDate
                startDate = pickedDate
            } else {
                endDate = pickedDate
            }
            selectionPhase = .start
        }
    }

    private func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_IN")
        formatter.dateFormat = "d MMM"
        return formatter.string(from: date)
    }

    private func weekday(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_IN")
        formatter.dateFormat = "EEE"
        return formatter.string(from: date).uppercased()
    }
}

private struct LiveLedgerInkScreen: View {
    let trip: InkTrip
    let summary: InkLedgerSummary
    let isRemoteBacked: Bool
    let onBack: () -> Void
    let onAdd: () -> Void
    let onEditTrip: () -> Void
    let onEditExpense: (InkExpense) -> Void
    let onAddFriend: () -> Void
    let onTab: (InkBottomTab) -> Void

    var body: some View {
        InkAppShell(
            title: shortTitle(trip.location),
            leftIcon: "chevron.left",
            rightIcon: isRemoteBacked ? "person.badge.plus" : "square.and.pencil",
            onLeft: onBack,
            onRight: isRemoteBacked ? onAddFriend : onEditTrip,
            activeTab: .ledger,
            onTab: onTab
        ) {
            InkReceipt {
                VStack(alignment: .leading, spacing: 13) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(trip.location.uppercased())
                                .font(Ink.serif(31))
                                .foregroundStyle(Ink.Blue.ink)
                                .accessibilityIdentifier("ledger.title")
                            Text("TRIP LEDGER · LIVE")
                                .font(Ink.mono(12, weight: .bold))
                                .tracking(2.2)
                                .foregroundStyle(Ink.Blue.ink.opacity(0.75))
                        }
                        Spacer()
                        MascotStamp(size: 54)
                    }
                    HStack(spacing: 10) {
                        Text(trip.dates.uppercased())
                            .font(Ink.mono(9, weight: .bold))
                            .tracking(0.7)
                            .foregroundStyle(Ink.Blue.ink)
                        Text("·")
                            .font(Ink.mono(9, weight: .bold))
                            .foregroundStyle(Ink.Blue.ink)
                        AvatarStack(size: 20, names: trip.friends.map(\.name))
                    }
                    ReceiptLabel(text: "Kachcha bill")
                    DashedRule()
                    ReceiptLabel(text: "Entries — \(trip.expenses.count) · Last 3 shown")

                    if trip.expenses.isEmpty {
                        Text("No expenses yet.\nAdd friends and jot the first kachcha line.")
                            .font(Ink.mono(12, weight: .medium))
                            .foregroundStyle(Ink.Blue.inkSoft)
                            .frame(maxWidth: .infinity)
                            .multilineTextAlignment(.center)
                            .padding(.vertical, 18)
                            .accessibilityIdentifier("ledger.empty")
                    } else {
                        ForEach(trip.expenses.suffix(3)) { expense in
                            Button {
                                onEditExpense(expense)
                            } label: {
                                LedgerRow(
                                    day: expense.day,
                                    title: expense.title,
                                    meta: "\(friendName(expense.paidByID, in: trip)) paid · split \(expense.splitWithIDs.count) ways",
                                    amount: signedRupees(expense.amount, sign: expense.paidByID == trip.friends.first?.id ? "+" : "−")
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("expenseRow.\(expense.title)")
                        }
                    }

                    SolidRule()
                    SummaryLine(label: "Running tab", amount: "~\(rupees(summary.total))", script: false)
                    SummaryLine(label: "your share", amount: "~\(rupees(summary.userShare))", script: false)
                    SummaryLine(label: summary.userNet >= 0 ? "you’re owed" : "you owe", amount: "~\(rupees(abs(summary.userNet)))", strong: true, script: false)
                    SolidRule()
                }
            }

            PrimaryCreamButton(title: "+ Add entry", action: onAdd)
                .accessibilityIdentifier("ledger.addEntry")
        }
    }
}

private struct LedgerRow: View {
    let day: String
    let title: String
    let meta: String
    let amount: String

    var body: some View {
        VStack(spacing: 9) {
            DashedRule()
            HStack(alignment: .top) {
                Text(day)
                    .font(Ink.mono(13, weight: .heavy))
                    .foregroundStyle(Ink.Blue.ink)
                    .frame(width: 34, alignment: .leading)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(Ink.mono(15, weight: .heavy))
                        .foregroundStyle(Ink.Blue.ink)
                    Text(meta)
                        .font(Ink.mono(11, weight: .medium))
                        .foregroundStyle(Ink.Blue.inkSoft)
                }
                Spacer()
                ScriptText(text: amount, size: 23)
            }
        }
    }
}

private struct SummaryLine: View {
    let label: String
    let amount: String
    var strong = false
    var script = true

    var body: some View {
        HStack {
            Text(label)
                .font(strong ? Ink.mono(14, weight: .heavy) : Ink.mono(13, weight: .medium))
                .foregroundStyle(Ink.Blue.ink)
            Spacer()
            if script {
                ScriptText(text: amount, size: strong ? 25 : 21)
            } else {
                Text(amount)
                    .font(Ink.mono(strong ? 17 : 15, weight: strong ? .heavy : .semibold))
                    .foregroundStyle(Ink.Blue.ink)
            }
        }
    }
}

private struct SettleInkScreen: View {
    let trip: InkTrip
    let settlements: [InkSettlement]
    let onRecord: (InkSettlement) -> Void
    let onTab: (InkBottomTab) -> Void

    var body: some View {
        InkAppShell(title: "Settle", rightIcon: "ellipsis", activeTab: .settle, onTab: onTab) {
            HStack {
                Spacer()
                MascotStamp(size: 52)
            }
            .padding(.bottom, -12)

            VStack(spacing: 4) {
                SerifTitle(text: "The shortest way", size: 30)
                Text("to square up.")
                    .font(Ink.serif(31).italic())
                    .foregroundStyle(Ink.Blue.cream)
                Text("\(settlements.count) payments instead of \(max(settlements.count, trip.friends.count * 2 - 1)).")
                    .font(.system(size: 15, design: .rounded))
                    .foregroundStyle(Ink.Blue.peri)
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity)

            InkReceipt {
                VStack(spacing: 14) {
                    ReceiptLabel(text: "Settlement Slip")
                        .frame(maxWidth: .infinity)
                    ReceiptLabel(text: "\(trip.title) · Who pays whom")
                        .frame(maxWidth: .infinity)
                    DashedRule()
                    if settlements.isEmpty {
                        Text("All square. Nothing left to settle.")
                            .font(Ink.mono(12, weight: .medium))
                            .foregroundStyle(Ink.Blue.ink)
                            .padding(.vertical, 18)
                    } else {
                        ForEach(Array(settlements.enumerated()), id: \.element.id) { index, settlement in
                            Button {
                                onRecord(settlement)
                            } label: {
                                SettlementRow(
                                    from: friendName(settlement.fromID, in: trip),
                                    to: friendName(settlement.toID, in: trip),
                                    amount: rupees(settlement.amount),
                                    highlighted: index == 0
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Text("Tap a line to record it.\nWhen all three clear,\nthe trip stamps itself FINAL.")
                        .font(Ink.mono(11, weight: .medium))
                        .foregroundStyle(Ink.Blue.ink)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

private struct SettlementRow: View {
    let from: String
    let to: String
    let amount: String
    var highlighted = false

    var body: some View {
        HStack {
            Text(from)
            Text("→")
            Text(to)
            Spacer()
            ScriptText(text: amount, size: 22)
        }
        .font(Ink.mono(15, weight: .heavy))
        .foregroundStyle(Ink.Blue.ink)
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(highlighted ? Ink.Blue.cobalt.opacity(0.06) : Color.clear, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(highlighted ? Ink.Blue.cobalt : Ink.Blue.ink.opacity(0.75), lineWidth: highlighted ? 1.4 : 1)
        )
    }
}

private struct RecordPaymentInkScreen: View {
    @State private var isSaving = false

    let trip: InkTrip
    let settlement: InkSettlement
    let currentUserID: String
    let errorMessage: String?
    let onClose: () -> Void
    let onStamp: () async -> Bool

    private var fromName: String {
        settlement.fromID == currentUserID ? "You" : friendName(settlement.fromID, in: trip)
    }

    private var toName: String {
        settlement.toID == currentUserID ? "you" : friendName(settlement.toID, in: trip)
    }

    var body: some View {
        InkAppShell(title: "Record Payment", leftIcon: "xmark", onLeft: onClose) {
            InkReceipt {
                VStack(alignment: .leading, spacing: 16) {
                    ReceiptLabel(text: "No. 0012 · Receipt of Payment")
                        .frame(maxWidth: .infinity)
                    Text("\(fromName) pays \(toName)".uppercased())
                        .font(Ink.serif(28, weight: .regular))
                        .foregroundStyle(Ink.Blue.ink)
                        .frame(maxWidth: .infinity)
                    ScriptText(text: rupees(settlement.amount), size: 42)
                        .frame(maxWidth: .infinity)
                    DashedRule()
                    ReceiptField(label: "For", value: trip.title)
                    ReceiptLabel(text: "Paid via")
                    ChipLine(items: ["UPI", "Cash"], selected: "UPI")
                    DashedRule()
                    Text("Records this settlement on the shared ledger.")
                        .font(Ink.mono(11, weight: .medium))
                        .foregroundStyle(Ink.Blue.ink)
                    if let errorMessage {
                        InkInlineError(message: errorMessage)
                    }
                }
            }

            InkBlackButton(title: isSaving ? "Recording" : "Mark as paid") {
                guard isSaving == false else { return }
                isSaving = true
                Task {
                    _ = await onStamp()
                    isSaving = false
                }
            }
            Button("Not yet", action: onClose)
                .font(Ink.serif(18, weight: .semibold))
                .foregroundStyle(Ink.Blue.cream)
                .buttonStyle(.plain)
                .padding(.top, 4)
        }
    }
}

private struct FinalBillInkScreen: View {
    let trip: InkTrip
    let summary: InkLedgerSummary
    let onBack: () -> Void
    let onTab: (InkBottomTab) -> Void

    var body: some View {
        InkAppShell(title: "Pakka Bill", leftIcon: "chevron.left", onLeft: onBack, activeTab: .ledger, onTab: onTab, contentSpacing: 12) {
            Spacer(minLength: 8)
            InkReceipt(padding: 16) {
                VStack(alignment: .leading, spacing: 9) {
                    Text(trip.location.uppercased())
                        .font(Ink.serif(25))
                        .foregroundStyle(Ink.Blue.ink)
                    HStack(spacing: 10) {
                        Text(trip.dates.uppercased())
                            .font(Ink.mono(9, weight: .bold))
                            .tracking(0.7)
                            .foregroundStyle(Ink.Blue.ink)
                        Text("·")
                            .font(Ink.mono(9, weight: .bold))
                            .foregroundStyle(Ink.Blue.ink)
                        AvatarStack(size: 20, names: trip.friends.map(\.name))
                    }
                    ReceiptLabel(text: "Booked & balanced by BillBandit")
                    DashedRule()
                    ReceiptLabel(text: "Entries — \(trip.expenses.count) · Last 4 shown")
                    ForEach(trip.expenses.suffix(4)) { expense in
                        FormalEntry(title: expense.title, amount: rupees(expense.amount))
                    }
                    SolidRule()
                    SummaryLine(label: "Total", amount: rupees(summary.total), script: false)
                    SummaryLine(label: "your share", amount: rupees(summary.userShare), script: false)
                    SummaryLine(label: summary.userNet >= 0 ? "To collect" : "To pay", amount: rupees(abs(summary.userNet)), strong: true, script: false)
                    HStack {
                        FinalStampAsset(width: 112)
                        Spacer()
                        BarcodeStrip().frame(width: 128, height: 34)
                    }
                }
            }
        }
    }
}

private struct FormalEntry: View {
    let title: String
    let amount: String

    var body: some View {
        VStack(spacing: 5) {
            DashedRule()
            HStack {
                Text(title)
                    .font(Ink.mono(12, weight: .semibold))
                Spacer()
                Text(amount)
                    .font(Ink.mono(12, weight: .heavy))
            }
            .foregroundStyle(Ink.Blue.ink)
        }
    }
}

private struct AddFriendInkScreen: View {
    @State private var name = ""
    @State private var contact = ""
    @State private var localErrorMessage: String?
    @State private var isSaving = false

    let errorMessage: String?
    let requiresContact: Bool
    let onClose: () -> Void
    let onAdd: (String, String) async -> Bool

    private var visibleErrorMessage: String? {
        errorMessage ?? localErrorMessage
    }

    private var canSubmit: Bool {
        let hasName = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        let hasContact = contact.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        return requiresContact ? hasContact : (hasName || hasContact)
    }

    var body: some View {
        InkAppShell(title: "Add Friend", leftIcon: "xmark", onLeft: onClose, contentSpacing: 12) {
            MascotLedger(size: 96)
                .frame(maxWidth: .infinity)
                .padding(.bottom, -18)
                .zIndex(2)

            InkReceipt(padding: 16) {
                VStack(alignment: .leading, spacing: 16) {
                    ReceiptLabel(text: "Find friend on BillBandit")
                        .frame(maxWidth: .infinity)
                    DashedRule()

                    ReceiptTextField(
                        label: "Friend name",
                        value: $name,
                        submitLabel: .next,
                        script: false,
                        identifier: "addFriend.name"
                    )
                    ReceiptTextField(
                        label: requiresContact ? "BillBandit email" : "Phone or email",
                        value: $contact,
                        keyboardType: .emailAddress,
                        autocapitalization: .never,
                        submitLabel: .done,
                        script: false,
                        identifier: "addFriend.contact",
                        onSubmit: {
                            if canSubmit {
                                Task { await save() }
                            }
                        }
                    )

                    Text(requiresContact ? "Use the email address they signed up with. We’ll only add verified BillBandit members to this ledger." : "Add a name now, then invite them when the ledger is live.")
                        .font(Ink.mono(11, weight: .medium))
                        .foregroundStyle(Ink.Blue.inkSoft)
                        .lineSpacing(3)

                    if let visibleErrorMessage {
                        InkInlineError(message: visibleErrorMessage)
                    }

                    HStack {
                        Spacer()
                        RoundSeal(text: "Invite\nVerified", size: 64)
                    }
                }
            }

            PrimaryCreamButton(title: "Add friend", isLoading: isSaving, isDisabled: canSubmit == false) {
                Task { await save() }
            }
                .accessibilityIdentifier("addFriend.save")
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(canSubmit ? "Add friend" : "Done") {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    if canSubmit {
                        Task { await save() }
                    }
                }
                .disabled(isSaving)
                .accessibilityIdentifier(canSubmit ? "addFriend.keyboardSubmit" : "keyboard.done")
            }
        }
    }

    private func save() async {
        guard canSubmit else {
            localErrorMessage = requiresContact ? "Enter your friend’s BillBandit email." : "Enter a name or contact."
            return
        }

        isSaving = true
        localErrorMessage = nil
        defer { isSaving = false }

        if await onAdd(name, contact) {
            onClose()
        } else if visibleErrorMessage == nil {
            localErrorMessage = "Couldn’t add this friend. Check the email and try again."
        }
    }
}

private struct AddEntryInkScreen: View {
    let trip: InkTrip
    let editingExpense: InkExpense?
    let errorMessage: String?
    let onClose: () -> Void
    let onDelete: (InkExpense) async -> Bool
    let onSave: (InkExpenseDraft) async -> Bool

    @State private var draft: InkExpenseDraft
    @State private var localErrorMessage: String?
    @State private var isSaving = false
    @State private var isDeleting = false

    init(
        trip: InkTrip,
        editingExpense: InkExpense?,
        errorMessage: String?,
        onClose: @escaping () -> Void,
        onDelete: @escaping (InkExpense) async -> Bool,
        onSave: @escaping (InkExpenseDraft) async -> Bool
    ) {
        self.trip = trip
        self.editingExpense = editingExpense
        self.errorMessage = errorMessage
        self.onClose = onClose
        self.onDelete = onDelete
        self.onSave = onSave
        _draft = State(initialValue: InkExpenseDraft(trip: trip, expense: editingExpense))
    }

    var body: some View {
        InkAppShell(title: "Kachcha Bill", leftIcon: "xmark", onLeft: onClose, contentSpacing: 12) {
            ReceiptLabel(text: trip.title, color: Ink.Blue.peri)
                .frame(maxWidth: .infinity)

            InkReceipt {
                VStack(alignment: .leading, spacing: 15) {
                    ReceiptLabel(text: "No. 0012 Cash Memo — Day 3")
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("₹")
                            .font(Ink.script(44, weight: .bold))
                            .foregroundStyle(Ink.Blue.cobalt)
                        TextField("0", text: $draft.amount)
                            .font(Ink.script(46, weight: .bold))
                            .foregroundStyle(Ink.Blue.cobalt)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.center)
                            .accessibilityIdentifier("addEntry.amount")
                    }
                    DashedRule()
                    ReceiptTextField(label: "For", value: $draft.title, identifier: "addEntry.title")
                    ReceiptLabel(text: "Paid by")
                    ChipLine(
                        items: trip.friends.map(\.name),
                        selected: friendName(draft.paidByID ?? trip.friends.first?.id ?? UUID().uuidString, in: trip),
                        onTap: { name in draft.paidByID = trip.friends.first { $0.name == name }?.id }
                    )
                    ReceiptLabel(text: "Split style")
                    ChipLine(items: ["Equally", "By Share", "Itemised", "By Percentage"], selected: "Equally")
                    ReceiptLabel(text: "Split — Equally · \(selectedSplitCount) \(selectedSplitCount == 1 ? "person" : "people")")
                    Text("Each selected person pays \(rupees(splitAmount)).")
                        .font(Ink.mono(11, weight: .medium))
                        .foregroundStyle(Ink.Blue.inkSoft)
                    ForEach(trip.friends) { friend in
                        Button {
                            if draft.splitWithIDs.contains(friend.id), draft.splitWithIDs.count > 1 {
                                draft.splitWithIDs.remove(friend.id)
                            } else {
                                draft.splitWithIDs.insert(friend.id)
                            }
                        } label: {
                            SplitPersonRow(
                                name: friend.name,
                                amount: draft.splitWithIDs.contains(friend.id) ? rupees(splitAmount) : "Not split",
                                isSelected: draft.splitWithIDs.contains(friend.id)
                            )
                        }
                        .buttonStyle(.plain)
                            .accessibilityIdentifier("addEntry.split.\(friend.name)")
                    }

                    if let visibleErrorMessage {
                        InkInlineError(message: visibleErrorMessage)
                    }
                }
            }
            PrimaryCreamButton(
                title: editingExpense == nil ? "Add to ledger" : "Update ledger",
                isLoading: isSaving,
                isDisabled: isSaveDisabled
            ) {
                Task { await save() }
            }
                .accessibilityIdentifier("addEntry.save")
            if let editingExpense {
                Button("Delete entry") {
                    Task { await delete(editingExpense) }
                }
                .font(Ink.serif(16, weight: .semibold))
                .foregroundStyle(Ink.Blue.cream.opacity(isDeleting ? 0.55 : 1))
                .buttonStyle(.plain)
                .disabled(isDeleting || isSaving)
                .accessibilityIdentifier("addEntry.delete")
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
                .accessibilityIdentifier("keyboard.done")
            }
        }
    }

    private var splitAmount: Double {
        let amount = amountValue ?? 0
        let count = max(1, selectedSplitCount)
        return amount / Double(count)
    }

    private var amountValue: Double? {
        Double(draft.amount.filter { "0123456789.".contains($0) })
    }

    private var selectedSplitCount: Int {
        draft.splitWithIDs.intersection(Set(trip.friends.map(\.id))).count
    }

    private var visibleErrorMessage: String? {
        errorMessage ?? localErrorMessage
    }

    private var isSaveDisabled: Bool {
        isSaving ||
            isDeleting ||
            trip.friends.isEmpty ||
            draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            (amountValue ?? 0) <= 0 ||
            selectedSplitCount == 0
    }

    private func save() async {
        guard isSaveDisabled == false else {
            localErrorMessage = validationMessage
            return
        }

        isSaving = true
        localErrorMessage = nil
        defer { isSaving = false }

        if await onSave(draft) == false, visibleErrorMessage == nil {
            localErrorMessage = "Couldn’t save this entry. Check the split and try again."
        }
    }

    private func delete(_ expense: InkExpense) async {
        guard isDeleting == false else { return }
        isDeleting = true
        localErrorMessage = nil
        defer { isDeleting = false }

        if await onDelete(expense) == false, visibleErrorMessage == nil {
            localErrorMessage = "Couldn’t delete this entry. Try again."
        }
    }

    private var validationMessage: String {
        if draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Add what this expense was for."
        }
        if (amountValue ?? 0) <= 0 {
            return "Enter an amount greater than zero."
        }
        if selectedSplitCount == 0 {
            return "Keep at least one person in the split."
        }
        return "Review the entry before saving."
    }
}

private struct SplitPersonRow: View {
    let name: String
    let amount: String
    var isSelected = true

    var body: some View {
        HStack {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isSelected ? Ink.Blue.cobalt : Ink.Blue.inkSoft)
            Text(name)
            Spacer()
            Text(amount)
                .foregroundStyle(isSelected ? Ink.Blue.ink : Ink.Blue.inkSoft)
        }
        .font(Ink.mono(13, weight: .semibold))
        .foregroundStyle(Ink.Blue.ink)
        .padding(.vertical, 3)
    }
}

private struct InkInlineError: View {
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 13, weight: .bold))
            Text(message)
                .font(Ink.mono(11, weight: .medium))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(Color(red: 0.66, green: 0.12, blue: 0.20))
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(red: 1.0, green: 0.88, blue: 0.84), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private func rupees(_ amount: Double) -> String {
    let rounded = Int(amount.rounded())
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.groupingSeparator = ","
    formatter.locale = Locale(identifier: "en_IN")
    let value = formatter.string(from: NSNumber(value: rounded)) ?? "\(rounded)"
    return "₹\(value)"
}

private func signedRupees(_ amount: Double, sign: String) -> String {
    "\(sign)\(rupees(amount))"
}

private func shortTitle(_ location: String) -> String {
    location.split(separator: ",").first.map(String.init) ?? location
}

private func friendName(_ id: String, in trip: InkTrip) -> String {
    trip.friends.first { $0.id == id }?.name ?? "Friend"
}

#Preview {
    BillBanditInkPrototypeView()
        .environmentObject(LiveDesignOverrides.disabled)
}
