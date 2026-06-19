import SwiftUI

struct ExpenseEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthStore.self) private var authStore

    let group: GroupDTO
    let expense: ExpenseDTO?
    let onSaved: () -> Void

    @State private var description: String
    @State private var amount: String
    @State private var currency: String
    @State private var category: String
    @State private var date: Date
    @State private var paidById: String
    @State private var splitType: SplitType
    @State private var selectedMemberIds: Set<String>
    @State private var exactAmounts: [String: String]
    @State private var percentages: [String: String]
    @State private var shares: [String: String]
    @State private var errorMessage: String?
    @State private var isSaving = false

    init(group: GroupDTO, expense: ExpenseDTO?, onSaved: @escaping () -> Void) {
        self.group = group
        self.expense = expense
        self.onSaved = onSaved

        let allMemberIds = Set(group.members.map(\.userId))
        let splitIds = Set(expense?.splits.map(\.userId) ?? [])
        _description = State(initialValue: expense?.description ?? "")
        _amount = State(initialValue: expense.map { String(format: "%.2f", $0.amount) } ?? "")
        _currency = State(initialValue: expense?.currency ?? group.currency)
        _category = State(initialValue: expense?.category ?? "general")
        _date = State(initialValue: Self.initialDate(for: expense))
        _paidById = State(initialValue: expense?.paidById ?? group.members.first?.userId ?? "")
        _splitType = State(initialValue: expense?.splitType ?? .equal)
        _selectedMemberIds = State(initialValue: splitIds.isEmpty ? allMemberIds : splitIds)
        _exactAmounts = State(initialValue: Dictionary(uniqueKeysWithValues: (expense?.splits ?? []).map { ($0.userId, String(format: "%.2f", $0.amount)) }))
        _percentages = State(initialValue: Dictionary(uniqueKeysWithValues: (expense?.splits ?? []).compactMap { split in
            guard let percentage = split.percentage else { return nil }
            return (split.userId, String(format: "%.2f", percentage))
        }))
        _shares = State(initialValue: Dictionary(uniqueKeysWithValues: (expense?.splits ?? []).compactMap { split in
            guard let shares = split.shares else { return nil }
            return (split.userId, "\(shares)")
        }))
    }

    var body: some View {
        NavigationStack {
            PaisaScreen {
                PaisaPanel(tint: PaisaTheme.sky.opacity(0.46)) {
                    PaisaSectionHeader(
                        expense == nil ? "Add expense" : "Edit expense",
                        subtitle: group.name,
                        systemImage: expense == nil ? "plus.circle.fill" : "square.and.pencil"
                    )
                }

                PaisaPanel(tint: PaisaTheme.mint.opacity(0.42)) {
                    VStack(alignment: .leading, spacing: 16) {
                        PaisaFieldLabel("Description") {
                            TextField("What was this for?", text: $description)
                                .paisaTextField()
                        }

                        PaisaFieldLabel("Amount") {
                            TextField("0.00", text: $amount)
                                .keyboardType(.decimalPad)
                                .paisaTextField()
                        }

                        HStack(alignment: .top, spacing: 12) {
                            PaisaFieldLabel("Currency") {
                                TextField("INR", text: $currency)
                                    .textInputAutocapitalization(.characters)
                                    .paisaTextField()
                            }

                            PaisaFieldLabel("Category") {
                                TextField("general", text: $category)
                                    .paisaTextField()
                            }
                        }

                        PaisaFieldLabel("Date") {
                            DatePicker("Date", selection: $date, displayedComponents: .date)
                                .labelsHidden()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .paisaTextField()
                        }
                    }
                }

                PaisaPanel(tint: PaisaTheme.blush.opacity(0.36)) {
                    VStack(alignment: .leading, spacing: 16) {
                        PaisaSectionHeader("Paid by", subtitle: "Payer", systemImage: "creditcard.fill")
                        Picker("Payer", selection: $paidById) {
                            ForEach(group.members) { member in
                                Text(member.user.displayName).tag(member.userId)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .paisaTextField()
                    }
                }

                PaisaPanel(tint: PaisaTheme.sky.opacity(0.4)) {
                    VStack(alignment: .leading, spacing: 16) {
                        PaisaSectionHeader("Split", subtitle: "Members and split type", systemImage: "point.topleft.down.curvedto.point.bottomright.up")

                        Picker("Split type", selection: $splitType) {
                            ForEach(SplitType.allCases) { type in
                                Text(type.title).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)

                        VStack(spacing: 12) {
                            ForEach(group.members) { member in
                                VStack(alignment: .leading, spacing: 10) {
                                    Toggle(member.user.displayName, isOn: memberBinding(member.userId))
                                        .toggleStyle(.switch)
                                    if selectedMemberIds.contains(member.userId) {
                                        splitInput(member)
                                    }
                                }
                                .padding(12)
                                .background(PaisaTheme.softSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                        }
                    }
                }

                if let preview = splitPreview {
                    PaisaPanel(tint: PaisaTheme.sun.opacity(0.18)) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Split total")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                Text(BillBanditFormatters.currency(preview, code: currency))
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(PaisaTheme.plum)
                            }
                            Spacer()
                            PaisaPill(
                                title: abs(preview - (amountValue ?? 0)) <= 0.02 ? "Balanced" : "Review",
                                tint: abs(preview - (amountValue ?? 0)) <= 0.02 ? PaisaTheme.leaf : PaisaTheme.coral
                            )
                        }
                    }
                }

                if let errorMessage {
                    PaisaPanel(tint: PaisaTheme.blush.opacity(0.54)) {
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundStyle(PaisaTheme.coral)
                    }
                }

                PaisaPrimaryButton(
                    expense == nil ? "Save expense" : "Update expense",
                    systemImage: expense == nil ? "checkmark.circle.fill" : "square.and.arrow.down.fill",
                    isLoading: isSaving,
                    isDisabled: isSaving || description.isEmpty || amountValue == nil || selectedMemberIds.isEmpty
                ) {
                    Task { await save() }
                }
            }
            .navigationTitle(expense == nil ? "Add expense" : "Edit expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Label("Cancel", systemImage: "xmark")
                            .labelStyle(.iconOnly)
                    }
                    .accessibilityLabel("Cancel")
                }
            }
        }
    }

    @ViewBuilder
    private func splitInput(_ member: MemberDTO) -> some View {
        switch splitType {
        case .equal:
            EmptyView()
        case .exact:
            TextField("Exact amount", text: binding($exactAmounts, member.userId))
                .keyboardType(.decimalPad)
                .paisaTextField()
        case .percentage:
            TextField("Percentage", text: binding($percentages, member.userId))
                .keyboardType(.decimalPad)
                .paisaTextField()
        case .shares:
            TextField("Shares", text: binding($shares, member.userId, defaultValue: "1"))
                .keyboardType(.numberPad)
                .paisaTextField()
        }
    }

    private var amountValue: Double? {
        Double(amount.replacingOccurrences(of: ",", with: "."))
    }

    private var splitPreview: Double? {
        guard let amountValue else { return nil }
        return buildSplits(total: amountValue).reduce(0) { $0 + $1.amount }
    }

    private func memberBinding(_ userId: String) -> Binding<Bool> {
        Binding {
            selectedMemberIds.contains(userId)
        } set: { isSelected in
            if isSelected {
                selectedMemberIds.insert(userId)
            } else {
                selectedMemberIds.remove(userId)
            }
        }
    }

    private func binding(_ dictionary: Binding<[String: String]>, _ key: String, defaultValue: String = "") -> Binding<String> {
        Binding {
            dictionary.wrappedValue[key] ?? defaultValue
        } set: { value in
            dictionary.wrappedValue[key] = value
        }
    }

    private func buildSplits(total: Double) -> [CreateSplitRequest] {
        let ids = group.members.map(\.userId).filter { selectedMemberIds.contains($0) }
        guard !ids.isEmpty else { return [] }

        switch splitType {
        case .equal:
            let cents = Int((total * 100).rounded())
            let base = cents / ids.count
            let remainder = cents - base * ids.count
            return ids.enumerated().map { index, userId in
                let amount = Double(base + (index == 0 ? remainder : 0)) / 100
                return CreateSplitRequest(userId: userId, amount: amount, percentage: nil, shares: nil)
            }
        case .exact:
            return ids.map { userId in
                CreateSplitRequest(userId: userId, amount: Double(exactAmounts[userId] ?? "") ?? 0, percentage: nil, shares: nil)
            }
        case .percentage:
            return ids.map { userId in
                let pct = Double(percentages[userId] ?? "") ?? 0
                return CreateSplitRequest(userId: userId, amount: (total * pct / 100).roundedToCents, percentage: pct, shares: nil)
            }
        case .shares:
            let parsedShares = ids.map { max(Int(shares[$0] ?? "1") ?? 1, 1) }
            let totalShares = parsedShares.reduce(0, +)
            return zip(ids, parsedShares).map { userId, share in
                CreateSplitRequest(userId: userId, amount: (total * Double(share) / Double(totalShares)).roundedToCents, percentage: nil, shares: share)
            }
        }
    }

    private func save() async {
        guard let amountValue else { return }
        let splits = buildSplits(total: amountValue)
        let splitTotal = splits.reduce(0) { $0 + $1.amount }
        guard abs(splitTotal - amountValue) <= 0.02 else {
            errorMessage = "Splits total \(splitTotal.formatted()) but expense is \(amountValue.formatted())."
            return
        }

        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let body = CreateExpenseRequest(
            description: description,
            amount: amountValue,
            currency: currency.uppercased(),
            date: formatter.string(from: date),
            category: category,
            groupId: group.id,
            paidById: paidById,
            splitType: splitType.rawValue,
            splits: splits,
            notes: nil
        )

        do {
            if let expense {
                let _: ExpenseResponse = try await authStore.apiClient.put("/api/mobile/expenses/\(expense.id)", body: body)
            } else {
                let _: ExpenseResponse = try await authStore.apiClient.post("/api/mobile/expenses", body: body)
            }
            onSaved()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private static func initialDate(for expense: ExpenseDTO?) -> Date {
        guard let expense, let parsed = ISO8601DateFormatter().date(from: expense.date) else {
            return Date()
        }
        return parsed
    }
}

private extension Double {
    var roundedToCents: Double {
        (self * 100).rounded() / 100
    }
}
