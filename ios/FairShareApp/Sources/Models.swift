import Foundation

struct UserDTO: Codable, Identifiable, Hashable {
    let id: String
    let name: String?
    let email: String?
    let image: String?

    var displayName: String { name ?? email ?? "Unknown" }
}

struct MemberDTO: Codable, Identifiable, Hashable {
    var id: String { userId }
    let userId: String
    let role: String
    let joinedAt: String?
    let user: UserDTO
}

struct GroupDTO: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let description: String?
    let image: String?
    let currency: String
    let category: String
    let memberCount: Int
    let expenseCount: Int
    let members: [MemberDTO]
    let expenses: [ExpenseDTO]?
}

struct ExpenseDTO: Codable, Identifiable, Hashable {
    let id: String
    let description: String
    let amount: Double
    let currency: String
    let date: String
    let category: String
    let groupId: String?
    let group: GroupSummaryDTO?
    let paidById: String
    let paidBy: UserDTO?
    let splitType: SplitType
    let notes: String?
    let splits: [ExpenseSplitDTO]
}

struct GroupSummaryDTO: Codable, Hashable {
    let id: String
    let name: String
}

struct ExpenseSplitDTO: Codable, Identifiable, Hashable {
    var id: String { userId }
    let userId: String
    let amount: Double
    let percentage: Double?
    let shares: Int?
    let user: UserDTO?
}

enum SplitType: String, Codable, CaseIterable, Identifiable {
    case equal = "EQUAL"
    case exact = "EXACT"
    case percentage = "PERCENTAGE"
    case shares = "SHARES"

    var id: String { rawValue }
    var title: String {
        switch self {
        case .equal: "Equal"
        case .exact: "Exact"
        case .percentage: "Percent"
        case .shares: "Shares"
        }
    }
}

struct BalanceDTO: Codable, Identifiable, Hashable {
    var id: String { user.id }
    let user: UserDTO
    let amount: Double
}

struct NetBalanceDTO: Codable, Identifiable, Hashable {
    var id: String { userId }
    let userId: String
    let name: String?
    let image: String?
    let netAmount: Double
}

struct SimplifiedDebtDTO: Codable, Identifiable, Hashable {
    var id: String { "\(fromId)-\(toId)-\(amount)" }
    let fromId: String
    let toId: String
    let amount: Double
    let fromName: String?
    let toName: String?
}

struct GroupBalancesDTO: Codable, Hashable {
    let netBalances: [NetBalanceDTO]
    let simplifiedDebts: [SimplifiedDebtDTO]
}

struct AuthResponse: Codable {
    let token: String
    let user: UserDTO
}

struct UserResponse: Codable {
    let user: UserDTO
}

struct DashboardResponse: Codable {
    let balances: [BalanceDTO]
    let totalOwed: Double
    let totalOwe: Double
    let currency: String
    let recentExpenses: [ExpenseDTO]
    let groups: [GroupDTO]
}

struct GroupsResponse: Codable {
    let groups: [GroupDTO]
}

struct GroupResponse: Codable {
    let group: GroupDTO
    let balances: GroupBalancesDTO?
}

struct MemberResponse: Codable {
    let member: MemberDTO
}

struct ExpenseResponse: Codable {
    let expense: ExpenseDTO
}

struct TransactionResponse: Codable {
    let transaction: TransactionDTO
}

struct TransactionDTO: Codable, Identifiable, Hashable {
    let id: String
    let amount: Double
    let currency: String
    let note: String?
    let group: GroupSummaryDTO?
    let sender: UserDTO
    let receiver: UserDTO
    let createdAt: String
}

struct SuccessResponse: Codable {
    let success: Bool
}

struct CreateGroupRequest: Codable {
    let name: String
    let description: String?
    let currency: String
    let category: String
}

struct AddMemberRequest: Codable {
    let email: String
}

struct CreateTransactionRequest: Codable {
    let receiverId: String?
    let senderId: String?
    let amount: Double
    let currency: String
    let groupId: String?
    let note: String?
}

struct CreateExpenseRequest: Codable {
    let description: String
    let amount: Double
    let currency: String
    let date: String
    let category: String
    let groupId: String?
    let paidById: String
    let splitType: String
    let splits: [CreateSplitRequest]
    let notes: String?
}

struct CreateSplitRequest: Codable, Hashable {
    let userId: String
    let amount: Double
    let percentage: Double?
    let shares: Int?
}
