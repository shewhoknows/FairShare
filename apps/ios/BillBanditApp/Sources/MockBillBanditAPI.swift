import Foundation

actor MockBillBanditAPI {
    static let shared = MockBillBanditAPI()

    private let alice: UserDTO
    private let bob: UserDTO
    private let carol: UserDTO
    private let dave: UserDTO

    private var currentUserId = "user-alice"
    private var dynamicUsers: [String: UserDTO] = [:]
    private var otpChallenges: [String: String] = [:]
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
            let user = UserDTO(id: "user-demo", name: name, email: request.email, image: nil, isProfileComplete: false)
            dynamicUsers[user.id] = user
            currentUserId = user.id
            value = AuthResponse(token: "mock-token-demo", user: user)

        case ("GET", "/api/mobile/auth/me"):
            value = UserResponse(user: currentUser)

        case ("GET", let lookupPath) where lookupPath.hasPrefix("/api/mobile/users/lookup"):
            let username = URLComponents(string: lookupPath)?
                .queryItems?
                .first(where: { $0.name == "username" })?
                .value ?? ""
            let foundUser = user(username: username)
            value = UsernameLookupResponse(exists: foundUser != nil, user: foundUser)

        case ("POST", "/api/mobile/auth/otp/start"):
            let request = try decode(OTPStartRequest.self, from: body)
            let challengeID = "mock-challenge-\(UUID().uuidString)"
            otpChallenges[challengeID] = request.identifier
            value = OTPChallengeResponse(
                challengeID: challengeID,
                maskedIdentifier: request.identifier,
                deliveryChannel: request.identifier.contains("@") ? "email" : "phone",
                expiresInSeconds: 600
            )

        case ("POST", "/api/mobile/auth/otp/verify"):
            let request = try decode(OTPVerifyRequest.self, from: body)
            guard request.code.count == 6, let identifier = otpChallenges.removeValue(forKey: request.challengeID) else {
                throw APIError.server("Invalid code")
            }
            let user = mockAuthUser(identifier: identifier)
            dynamicUsers[user.id] = user
            currentUserId = user.id
            value = AuthResponse(token: "mock-token-\(user.id)", user: user)

        case ("POST", "/api/mobile/auth/apple"):
            let request = try decode(AppleSignInRequest.self, from: body)
            let user = UserDTO(
                id: "user-apple",
                name: request.fullName ?? "Meera Kapoor",
                email: request.email ?? "meera.apple@example.com",
                image: nil,
                preferredName: nil,
                upiID: nil,
                isProfileComplete: false
            )
            dynamicUsers[user.id] = user
            currentUserId = user.id
            value = AuthResponse(token: "mock-token-apple", user: user)

        case ("PUT", "/api/mobile/auth/profile"):
            let request = try decode(CompleteProfileRequest.self, from: body)
            let existing = currentUser
            let user = UserDTO(
                id: existing.id,
                name: request.name,
                email: existing.email,
                image: existing.image,
                phone: existing.phone,
                preferredName: request.preferredName,
                upiID: request.upiID,
                isProfileComplete: true
            )
            dynamicUsers[user.id] = user
            value = UserResponse(user: user)

        case ("GET", "/api/mobile/dashboard"):
            value = dashboard()

        case ("GET", "/api/mobile/groups"):
            value = GroupsResponse(groups: visibleGroups().map(summaryGroup))

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
            let user: UserDTO?
            if let username = request.username?.trimmingCharacters(in: .whitespacesAndNewlines),
               username.isEmpty == false {
                user = self.user(username: username)
            } else if let email = request.email?.trimmingCharacters(in: .whitespacesAndNewlines),
                      email.isEmpty == false {
                user = self.user(email: email)
            } else {
                user = nil
            }
            guard let user else {
                throw APIError.server("No user found with that username")
            }
            guard let index = groups.firstIndex(where: { $0.id == groupId }) else {
                throw APIError.server("Group not found")
            }
            guard groups[index].members.contains(where: { $0.userId == currentUser.id }) else {
                throw APIError.server("Forbidden")
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
            try validateExpenseRequest(request)
            let expense = makeExpense(from: request)
            expenses.insert(expense, at: 0)
            value = ExpenseResponse(expense: expense)

        case ("PUT", let expensePath) where expensePath.hasPrefix("/api/mobile/expenses/"):
            let request = try decode(CreateExpenseRequest.self, from: body)
            guard let expenseId = pathComponents(expensePath).last,
                  let index = expenses.firstIndex(where: { $0.id == expenseId }) else {
                throw APIError.server("Not found")
            }
            guard expenses[index].paidById == currentUser.id else {
                throw APIError.server("Only the payer can edit an expense")
            }
            try validateExpenseRequest(request)
            let expense = makeExpense(id: expenseId, from: request)
            expenses[index] = expense
            value = ExpenseResponse(expense: expense)

        case ("DELETE", let expensePath) where expensePath.hasPrefix("/api/mobile/expenses/"):
            guard let id = pathComponents(expensePath).last,
                  let index = expenses.firstIndex(where: { $0.id == id }) else {
                throw APIError.server("Not found")
            }
            guard expenses[index].paidById == currentUser.id else {
                throw APIError.server("Only the payer can delete an expense")
            }
            expenses.remove(at: index)
            value = SuccessResponse(success: true)

        case ("POST", "/api/mobile/transactions"):
            let request = try decode(CreateTransactionRequest.self, from: body)
            let (sender, receiver) = try transactionParties(from: request)
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

        return try JSONEncoder.billBandit.encode(AnyEncodable(value))
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
            groups: visibleGroups().map(summaryGroup)
        )
    }

    private func detailedGroup(id: String) -> GroupDTO? {
        guard let group = groups.first(where: { $0.id == id }) else { return nil }
        guard group.members.contains(where: { $0.userId == currentUser.id }) else { return nil }
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

    private func visibleGroups() -> [GroupDTO] {
        groups.filter { group in
            group.members.contains { $0.userId == currentUser.id }
        }
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
            var net = expenses
                .filter { $0.groupId == group.id }
                .reduce(0.0) { total, expense in
                    var next = total
                    if expense.paidById == member.userId { next += expense.amount }
                    next -= expense.splits.first(where: { $0.userId == member.userId })?.amount ?? 0
                    return next
                }
            for transaction in transactions where transaction.group?.id == group.id {
                if transaction.sender.id == member.userId { net += transaction.amount }
                if transaction.receiver.id == member.userId { net -= transaction.amount }
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

    private func validateExpenseRequest(_ request: CreateExpenseRequest) throws {
        let splitTotal = request.splits.reduce(0.0) { $0 + $1.amount }
        guard abs(splitTotal - request.amount) <= 0.02 else {
            throw APIError.server("Split amounts (\(String(format: "%.2f", splitTotal))) don't match expense total (\(String(format: "%.2f", request.amount)))")
        }

        guard let groupId = request.groupId else { return }
        guard let group = groups.first(where: { $0.id == groupId }) else {
            throw APIError.server("Group not found")
        }
        let memberIDs = Set(group.members.map(\.userId))
        guard memberIDs.contains(currentUser.id) else {
            throw APIError.server("Forbidden")
        }
        guard memberIDs.contains(request.paidById) else {
            throw APIError.server("Payer is not a member of this group")
        }
        for split in request.splits where memberIDs.contains(split.userId) == false {
            throw APIError.server("User \(split.userId) is not a member of this group")
        }
    }

    private func transactionParties(from request: CreateTransactionRequest) throws -> (sender: UserDTO, receiver: UserDTO) {
        guard (request.senderId == nil) != (request.receiverId == nil) else {
            throw APIError.server("Provide exactly one of receiverId or senderId")
        }

        let senderId = request.senderId ?? currentUser.id
        let receiverId = request.senderId == nil ? request.receiverId! : currentUser.id
        guard senderId != receiverId else {
            throw APIError.server("You can't settle with yourself")
        }
        guard let sender = user(id: senderId) else {
            throw APIError.server("Sender not found")
        }
        guard let receiver = user(id: receiverId) else {
            throw APIError.server("Receiver not found")
        }

        if let groupId = request.groupId {
            guard let group = groups.first(where: { $0.id == groupId }) else {
                throw APIError.server("Group not found")
            }
            let memberIDs = Set(group.members.map(\.userId))
            let requiredMemberIDs = Set([currentUser.id, senderId, receiverId])
            guard requiredMemberIDs.isSubset(of: memberIDs) else {
                throw APIError.server("Both settlement parties must belong to the group")
            }
        }

        return (sender, receiver)
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
        dynamicUsers[id] ?? [alice, bob, carol, dave].first { $0.id == id }
    }

    private func user(email: String) -> UserDTO? {
        dynamicUsers.values.first { $0.email?.lowercased() == email.lowercased() }
            ?? [alice, bob, carol, dave].first { $0.email?.lowercased() == email.lowercased() }
    }

    private func user(username: String) -> UserDTO? {
        let normalizedUsername = username.normalizedMockUsername
        return dynamicUsers.values.first { $0.matches(username: normalizedUsername) }
            ?? [alice, bob, carol, dave].first { $0.matches(username: normalizedUsername) }
    }

    private func mockAuthUser(identifier: String) -> UserDTO {
        if identifier.contains("@") {
            return UserDTO(
                id: "user-auth-\(abs(identifier.hashValue))",
                name: nil,
                email: identifier,
                image: nil,
                isProfileComplete: false
            )
        }

        return UserDTO(
            id: "user-auth-\(abs(identifier.hashValue))",
            name: nil,
            email: nil,
            image: nil,
            phone: identifier,
            isProfileComplete: false
        )
    }

    private func groupSummary(id: String) -> GroupSummaryDTO? {
        groups.first { $0.id == id }.map { GroupSummaryDTO(id: $0.id, name: $0.name) }
    }

    private func pathComponents(_ path: String) -> [String] {
        path.split(separator: "/").map(String.init)
    }

    private func decode<T: Decodable>(_ type: T.Type, from body: Data?) throws -> T {
        guard let body else { throw APIError.invalidResponse }
        return try JSONDecoder.billBandit.decode(T.self, from: body)
    }

    private static func loadFixture() -> MockFixtureBundle {
        guard let data = ParityFixtures.json.data(using: .utf8) else {
            fatalError("Unable to encode shared parity fixtures.")
        }

        do {
            return try JSONDecoder.billBandit.decode(MockFixtureBundle.self, from: data)
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

private extension UserDTO {
    func matches(username normalizedUsername: String) -> Bool {
        [
            preferredName,
            name,
            email?.split(separator: "@").first.map(String.init),
            email
        ]
        .compactMap { $0?.normalizedMockUsername }
        .contains(normalizedUsername)
    }
}

private extension String {
    var normalizedMockUsername: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .filter { $0.isLetter || $0.isNumber }
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
