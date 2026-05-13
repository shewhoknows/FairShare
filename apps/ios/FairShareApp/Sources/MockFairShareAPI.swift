import Foundation

actor MockFairShareAPI {
    static let shared = MockFairShareAPI()

    private let alice: UserDTO
    private let bob: UserDTO
    private let carol: UserDTO
    private let dave: UserDTO

    private var currentUserId = "user-alice"
    private var groups: [GroupDTO]
    private var expenses: [ExpenseDTO]
    private var transactions: [TransactionDTO] = []

    private init() {
        let fixture = Self.loadFixture()
        let usersById = Dictionary(uniqueKeysWithValues: fixture.users.map { ($0.id, $0.userDTO) })
        let groupNames = Dictionary(uniqueKeysWithValues: fixture.groups.map { ($0.id, $0.name) })
        let membersByGroupId = Dictionary(uniqueKeysWithValues: fixture.groups.map { group in
            (
                group.id,
                group.members.map { member in
                    MemberDTO(
                        userId: member.userId,
                        role: member.role,
                        joinedAt: member.joinedAt,
                        user: usersById[member.userId] ?? UserDTO(id: member.userId, name: nil, email: nil, image: nil)
                    )
                }
            )
        })

        alice = usersById["user-alice"] ?? UserDTO(id: "user-alice", name: "Alice Johnson", email: "alice@example.com", image: nil)
        bob = usersById["user-bob"] ?? UserDTO(id: "user-bob", name: "Bob Smith", email: "bob@example.com", image: nil)
        carol = usersById["user-carol"] ?? UserDTO(id: "user-carol", name: "Carol White", email: "carol@example.com", image: nil)
        dave = usersById["user-dave"] ?? UserDTO(id: "user-dave", name: "Dave Brown", email: "dave@example.com", image: nil)

        let fixtureExpenses = fixture.expenses.map { expense in
            let members = membersByGroupId[expense.groupId] ?? []
            return ExpenseDTO(
                id: expense.id,
                description: expense.description,
                amount: expense.amount,
                currency: expense.currency,
                date: expense.date,
                category: expense.category,
                groupId: expense.groupId,
                group: GroupSummaryDTO(id: expense.groupId, name: groupNames[expense.groupId] ?? expense.groupId),
                paidById: expense.paidById,
                paidBy: usersById[expense.paidById],
                splitType: SplitType(rawValue: expense.splitType) ?? .equal,
                notes: expense.notes,
                splits: expense.splits.map { split in
                    ExpenseSplitDTO(
                        userId: split.userId,
                        amount: split.amount,
                        percentage: split.percentage,
                        shares: split.shares,
                        user: members.first(where: { $0.userId == split.userId })?.user ?? usersById[split.userId]
                    )
                }
            )
        }
        expenses = fixtureExpenses

        groups = fixture.groups.map { group in
            let members = membersByGroupId[group.id] ?? []
            return GroupDTO(
                id: group.id,
                name: group.name,
                description: group.description,
                image: nil,
                currency: group.currency,
                category: group.category,
                memberCount: members.count,
                expenseCount: fixtureExpenses.filter { $0.groupId == group.id }.count,
                members: members,
                expenses: nil
            )
        }
    }

    func requestData(path: String, method: String, body: Data?, hasToken: Bool) async throws -> Data {
        guard path.hasPrefix("/api/mobile/auth") || hasToken else { throw APIError.unauthorized }

        let value: Encodable
        switch (method, path) {
        case ("POST", "/api/mobile/auth/login"):
            let request = try decode(AuthCredentials.self, from: body)
            guard request.email.lowercased() == "alice@example.com", request.password == "password123" else {
                throw APIError.server("Invalid email or password")
            }
            currentUserId = alice.id
            value = AuthResponse(token: "mock-token-alice", user: alice)

        case ("POST", "/api/mobile/auth/register"):
            let request = try decode(AuthCredentials.self, from: body)
            let name = request.name?.isEmpty == false ? request.name : "Demo User"
            let user = UserDTO(id: "user-demo", name: name, email: request.email, image: nil)
            currentUserId = user.id
            value = AuthResponse(token: "mock-token-demo", user: user)

        case ("GET", "/api/mobile/auth/me"):
            value = UserResponse(user: currentUser)

        case ("GET", "/api/mobile/dashboard"):
            value = dashboard()

        case ("GET", "/api/mobile/groups"):
            value = GroupsResponse(groups: groups.map(summaryGroup))

        case ("POST", "/api/mobile/groups"):
            let request = try decode(CreateGroupRequest.self, from: body)
            let member = MemberDTO(userId: currentUser.id, role: "ADMIN", joinedAt: today, user: currentUser)
            let group = GroupDTO(
                id: "group-\(UUID().uuidString)",
                name: request.name,
                description: request.description,
                image: nil,
                currency: request.currency,
                category: request.category,
                memberCount: 1,
                expenseCount: 0,
                members: [member],
                expenses: nil
            )
            groups.insert(group, at: 0)
            value = GroupResponse(group: group, balances: emptyBalances())

        case ("POST", let groupMemberPath) where groupMemberPath.hasSuffix("/members"):
            let groupId = pathComponents(path).dropLast().last ?? ""
            let request = try decode(AddMemberRequest.self, from: body)
            let user = user(email: request.email) ?? bob
            guard let index = groups.firstIndex(where: { $0.id == groupId }) else {
                throw APIError.server("Group not found")
            }
            if groups[index].members.contains(where: { $0.userId == user.id }) {
                throw APIError.server("User is already a member of this group")
            }
            let member = MemberDTO(userId: user.id, role: "MEMBER", joinedAt: today, user: user)
            let group = groups[index]
            groups[index] = GroupDTO(
                id: group.id,
                name: group.name,
                description: group.description,
                image: group.image,
                currency: group.currency,
                category: group.category,
                memberCount: group.memberCount + 1,
                expenseCount: group.expenseCount,
                members: group.members + [member],
                expenses: nil
            )
            value = MemberResponse(member: member)

        case ("GET", let groupPath) where groupPath.hasPrefix("/api/mobile/groups/"):
            let groupId = pathComponents(groupPath).last ?? ""
            guard let group = detailedGroup(id: groupId) else { throw APIError.server("Group not found") }
            value = GroupResponse(group: group, balances: balances(for: group))

        case ("POST", "/api/mobile/expenses"):
            let request = try decode(CreateExpenseRequest.self, from: body)
            let expense = makeExpense(from: request)
            expenses.insert(expense, at: 0)
            value = ExpenseResponse(expense: expense)

        case ("PUT", let expensePath) where expensePath.hasPrefix("/api/mobile/expenses/"):
            let request = try decode(CreateExpenseRequest.self, from: body)
            let expense = makeExpense(id: pathComponents(expensePath).last, from: request)
            if let index = expenses.firstIndex(where: { $0.id == expense.id }) {
                expenses[index] = expense
            }
            value = ExpenseResponse(expense: expense)

        case ("DELETE", let expensePath) where expensePath.hasPrefix("/api/mobile/expenses/"):
            let id = pathComponents(expensePath).last
            expenses.removeAll { $0.id == id }
            value = SuccessResponse(success: true)

        case ("POST", "/api/mobile/transactions"):
            let request = try decode(CreateTransactionRequest.self, from: body)
            let sender = request.senderId.flatMap(user(id:)) ?? currentUser
            let receiver = request.receiverId.flatMap(user(id:)) ?? currentUser
            let transaction = TransactionDTO(
                id: "transaction-\(UUID().uuidString)",
                amount: request.amount,
                currency: request.currency,
                note: request.note,
                group: request.groupId.flatMap(groupSummary(id:)),
                sender: sender,
                receiver: receiver,
                createdAt: today
            )
            transactions.insert(transaction, at: 0)
            value = TransactionResponse(transaction: transaction)

        default:
            throw APIError.server("Mock API has no route for \(method) \(path)")
        }

        return try JSONEncoder.fairShare.encode(AnyEncodable(value))
    }

    private var currentUser: UserDTO {
        user(id: currentUserId) ?? alice
    }

    private var today: String {
        ISO8601DateFormatter().string(from: Date())
    }

    private func dashboard() -> DashboardResponse {
        let visibleExpenses = expenses.filter { expense in
            expense.paidById == currentUser.id || expense.splits.contains { $0.userId == currentUser.id }
        }
        let balances = balances(from: visibleExpenses)
        let totalOwed = balances.filter { $0.amount > 0 }.reduce(0) { $0 + $1.amount }
        let totalOwe = balances.filter { $0.amount < 0 }.reduce(0) { $0 + abs($1.amount) }
        return DashboardResponse(
            balances: balances,
            totalOwed: totalOwed.roundedToCents,
            totalOwe: totalOwe.roundedToCents,
            currency: "USD",
            recentExpenses: Array(visibleExpenses.prefix(5)),
            groups: groups.map(summaryGroup)
        )
    }

    private func detailedGroup(id: String) -> GroupDTO? {
        guard let group = groups.first(where: { $0.id == id }) else { return nil }
        let groupExpenses = expenses.filter { $0.groupId == id }
        return GroupDTO(
            id: group.id,
            name: group.name,
            description: group.description,
            image: group.image,
            currency: group.currency,
            category: group.category,
            memberCount: group.members.count,
            expenseCount: groupExpenses.count,
            members: group.members,
            expenses: groupExpenses
        )
    }

    private func summaryGroup(_ group: GroupDTO) -> GroupDTO {
        GroupDTO(
            id: group.id,
            name: group.name,
            description: group.description,
            image: group.image,
            currency: group.currency,
            category: group.category,
            memberCount: group.members.count,
            expenseCount: expenses.filter { $0.groupId == group.id }.count,
            members: group.members,
            expenses: nil
        )
    }

    private func balances(for group: GroupDTO) -> GroupBalancesDTO {
        let netBalances = group.members.map { member in
            let net = expenses
                .filter { $0.groupId == group.id }
                .reduce(0.0) { total, expense in
                    var next = total
                    if expense.paidById == member.userId { next += expense.amount }
                    next -= expense.splits.first(where: { $0.userId == member.userId })?.amount ?? 0
                    return next
                }
            return NetBalanceDTO(userId: member.userId, name: member.user.name, image: member.user.image, netAmount: net.roundedToCents)
        }
        let debts = netBalances.filter { abs($0.netAmount) > 0.005 && $0.userId != currentUser.id }.map { balance in
            SimplifiedDebtDTO(
                fromId: balance.netAmount > 0 ? currentUser.id : balance.userId,
                toId: balance.netAmount > 0 ? balance.userId : currentUser.id,
                amount: abs(balance.netAmount),
                fromName: balance.netAmount > 0 ? "You" : balance.name,
                toName: balance.netAmount > 0 ? balance.name : "You"
            )
        }
        return GroupBalancesDTO(netBalances: netBalances, simplifiedDebts: debts)
    }

    private func balances(from visibleExpenses: [ExpenseDTO]) -> [BalanceDTO] {
        [bob, carol, dave].compactMap { other in
            var amount = 0.0
            for expense in visibleExpenses {
                if expense.paidById == currentUser.id {
                    amount += expense.splits.first(where: { $0.userId == other.id })?.amount ?? 0
                }
                if expense.paidById == other.id {
                    amount -= expense.splits.first(where: { $0.userId == currentUser.id })?.amount ?? 0
                }
            }
            return abs(amount) > 0.005 ? BalanceDTO(user: other, amount: amount.roundedToCents) : nil
        }
    }

    private func emptyBalances() -> GroupBalancesDTO {
        GroupBalancesDTO(netBalances: [], simplifiedDebts: [])
    }

    private func makeExpense(id: String? = nil, from request: CreateExpenseRequest) -> ExpenseDTO {
        let group = request.groupId.flatMap { groupId in groups.first(where: { $0.id == groupId }) }
        let members = group?.members ?? [MemberDTO(userId: currentUser.id, role: "ADMIN", joinedAt: today, user: currentUser)]
        let paidBy = user(id: request.paidById) ?? currentUser
        return ExpenseDTO(
            id: id ?? "expense-\(UUID().uuidString)",
            description: request.description,
            amount: request.amount,
            currency: request.currency,
            date: "\(request.date)T00:00:00Z",
            category: request.category,
            groupId: request.groupId,
            group: request.groupId.flatMap(groupSummary(id:)),
            paidById: request.paidById,
            paidBy: paidBy,
            splitType: SplitType(rawValue: request.splitType) ?? .equal,
            notes: request.notes,
            splits: request.splits.map { split in
                ExpenseSplitDTO(
                    userId: split.userId,
                    amount: split.amount,
                    percentage: split.percentage,
                    shares: split.shares,
                    user: members.first(where: { $0.userId == split.userId })?.user ?? user(id: split.userId)
                )
            }
        )
    }

    private func user(id: String) -> UserDTO? {
        [alice, bob, carol, dave].first { $0.id == id }
    }

    private func user(email: String) -> UserDTO? {
        [alice, bob, carol, dave].first { $0.email?.lowercased() == email.lowercased() }
    }

    private func groupSummary(id: String) -> GroupSummaryDTO? {
        groups.first { $0.id == id }.map { GroupSummaryDTO(id: $0.id, name: $0.name) }
    }

    private func pathComponents(_ path: String) -> [String] {
        path.split(separator: "/").map(String.init)
    }

    private func decode<T: Decodable>(_ type: T.Type, from body: Data?) throws -> T {
        guard let body else { throw APIError.invalidResponse }
        return try JSONDecoder.fairShare.decode(T.self, from: body)
    }

    private static func loadFixture() -> MockFixtureBundle {
        guard let data = ParityFixtures.json.data(using: .utf8) else {
            fatalError("Unable to encode shared parity fixtures.")
        }

        do {
            return try JSONDecoder.fairShare.decode(MockFixtureBundle.self, from: data)
        } catch {
            fatalError("Unable to decode shared parity fixtures: \(error.localizedDescription)")
        }
    }
}

private struct AuthCredentials: Codable {
    let name: String?
    let email: String
    let password: String
}

private struct MockFixtureBundle: Decodable {
    let users: [MockFixtureUser]
    let groups: [MockFixtureGroup]
    let expenses: [MockFixtureExpense]
}

private struct MockFixtureUser: Decodable {
    let id: String
    let name: String?
    let email: String?
    let image: String?

    var userDTO: UserDTO {
        UserDTO(id: id, name: name, email: email, image: image)
    }
}

private struct MockFixtureGroup: Decodable {
    let id: String
    let name: String
    let description: String?
    let currency: String
    let category: String
    let members: [MockFixtureMember]
}

private struct MockFixtureMember: Decodable {
    let userId: String
    let role: String
    let joinedAt: String?
}

private struct MockFixtureExpense: Decodable {
    let id: String
    let description: String
    let amount: Double
    let currency: String
    let date: String
    let category: String
    let groupId: String
    let paidById: String
    let splitType: String
    let notes: String?
    let splits: [MockFixtureSplit]
}

private struct MockFixtureSplit: Decodable {
    let userId: String
    let amount: Double
    let percentage: Double?
    let shares: Int?
}

private struct AnyEncodable: Encodable {
    private let encodeValue: (Encoder) throws -> Void

    init(_ value: Encodable) {
        encodeValue = value.encode
    }

    func encode(to encoder: Encoder) throws {
        try encodeValue(encoder)
    }
}

private extension Double {
    var roundedToCents: Double {
        (self * 100).rounded() / 100
    }
}
