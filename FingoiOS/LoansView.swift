import SwiftUI

enum PlanTab: String, CaseIterable {
    case loans = "Úvěry"
    case recurring = "Platby"
    case budgets = "Rozpočty"
    case goals = "Cíle"
}

struct PlansView: View {
    @State private var selectedTab: PlanTab = .loans
    @State private var showingAddSheet = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Záložka", selection: $selectedTab) {
                    ForEach(PlanTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                
                ScrollView {
                    switch selectedTab {
                    case .loans:
                        LoansSubView()
                    case .recurring:
                        RecurringSubView()
                    case .budgets:
                        BudgetsSubView()
                    case .goals:
                        GoalsSubView()
                    }
                }
            }
            .navigationTitle("Plány a Cíle")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color.black.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingAddSheet.toggle() }) {
                        Image(systemName: "plus")
                            .foregroundColor(.white)
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                switch selectedTab {
                case .loans:
                    AddLoanSheet()
                case .recurring:
                    AddRecurringSheet()
                case .budgets:
                    AddBudgetSheet()
                case .goals:
                    AddGoalSheet()
                }
            }
        }
    }
}

// MARK: - LOANS

struct LoansSubView: View {
    var loans: [FingoLoan] { FingoDataManager.shared.database.loans }
    var transactions: [FingoTransaction] { FingoDataManager.shared.database.transactions.sorted(by: { $0.date > $1.date }) }
    @State private var selectedLoanForPayment: FingoLoan? = nil
    @State private var loanToEdit: FingoLoan? = nil
    @State private var loanToDelete: FingoLoan? = nil
    
    var totalDebt: Double {
        loans.filter { $0.remainingAmount > 0 }.reduce(0.0) { $0 + $1.remainingAmount }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 4) {
                Text("CELKOVÝ DLUH")
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(.gray)
                    .tracking(1.5)
                Text(fingoFormatCurrency(totalDebt))
                    .font(.system(size: 32, weight: .black))
                    .foregroundColor(Color.roseColor)
            }
            .padding(.vertical, 10)
            
            if loans.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "building.columns.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    Text("Žádné evidované úvěry")
                        .font(.system(size: 16, weight: .bold))
                    Text("Zadejte své úvěry nebo hypotéku tlačítkem + vpravo nahoře.")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .background(Color.darkCard)
                .cornerRadius(20)
                .padding(.horizontal)
            } else {
                VStack(spacing: 16) {
                    ForEach(loans) { loan in
                        LoanCard(loan: loan, onPayment: {
                            selectedLoanForPayment = loan
                        }, onEdit: {
                            loanToEdit = loan
                        }, onDelete: {
                            loanToDelete = loan
                        })
                    }
                }
                .padding(.horizontal)
            }
            
            LoanPaymentsHistory(transactions: transactions)
        }
        .padding(.vertical)
        .sheet(item: $selectedLoanForPayment) { loan in
            AddLoanPaymentSheet(loan: loan)
        }
        .sheet(item: $loanToEdit) { loan in
            AddLoanSheet(loanToEdit: loan)
        }
        .alert("Smazat úvěr?", isPresented: Binding(
            get: { loanToDelete != nil },
            set: { if !$0 { loanToDelete = nil } }
        )) {
            Button("Smazat", role: .destructive) {
                if let loan = loanToDelete {
                    FingoDataManager.shared.database.loans.removeAll { $0.id == loan.id }
                    FingoDataManager.shared.saveDatabase()
                }
                loanToDelete = nil
            }
            Button("Zrušit", role: .cancel) {
                loanToDelete = nil
            }
        } message: {
            if let loan = loanToDelete {
                Text("Opravdu chcete smazat úvěr \"\(loan.name)\"? Přidružené transakce (splátky) v historii zůstanou.")
            }
        }
    }
}

struct LoanCard: View {
    let loan: FingoLoan
    let onPayment: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var remainingMonths: Int {
        let calendar = Calendar.current
        let today = Date()
        let components = calendar.dateComponents([.month], from: today, to: loan.endDate)
        return max(0, components.month ?? 0)
    }
    
    var remainingYearsAndMonthsText: String {
        let months = remainingMonths
        let years = months / 12
        let remMonths = months % 12
        
        var parts: [String] = []
        if years > 0 {
            parts.append("\(years) \(years == 1 ? "rok" : (years >= 2 && years <= 4 ? "roky" : "let"))")
        }
        if remMonths > 0 || parts.isEmpty {
            parts.append("\(remMonths) \(remMonths == 1 ? "měsíc" : (remMonths >= 2 && remMonths <= 4 ? "měsíce" : "měsíců"))")
        }
        return parts.joined(separator: " a ")
    }
    
    var progress: Double {
        guard loan.totalAmount > 0 else { return 0 }
        let paid = loan.totalAmount - loan.remainingAmount
        return min(1.0, paid / loan.totalAmount)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.12))
                        .frame(width: 38, height: 38)
                    Image(systemName: loan.type == "mortgage" ? "house.fill" : (loan.type == "car_loan" ? "car.fill" : "creditcard.fill"))
                        .foregroundColor(.blue)
                        .font(.system(size: 16))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(loan.name)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                    Text(loan.type == "mortgage" ? "Hypotéka" : (loan.type == "car_loan" ? "Autoúvěr" : "Spotřebitelský úvěr"))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(fingoFormatCurrency(loan.monthlyPayment))
                        .font(.system(size: 14, weight: .black))
                        .foregroundColor(.white)
                    Text("/ měsíc")
                        .font(.system(size: 9))
                        .foregroundColor(.gray)
                }
            }
            
            Divider().background(Color.gray.opacity(0.15))
            
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ZBÝVÁ DOPLATIT")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.gray)
                    Text(fingoFormatCurrency(loan.remainingAmount))
                        .font(.system(size: 20, weight: .black))
                        .foregroundColor(.white)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("ÚROKOVÁ SAZBA")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.gray)
                    Text(String(format: "%.2f %% p.a.", loan.interestRate))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.indigoColor)
                }
            }
            
            VStack(spacing: 6) {
                HStack {
                    Text("Splaceno: \(Int(progress * 100))%")
                    Spacer()
                    Text("Zbývá: \(remainingYearsAndMonthsText)")
                }
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.gray)
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.gray.opacity(0.15))
                        Capsule()
                            .fill(Color.indigoColor)
                            .frame(width: geo.size.width * CGFloat(progress))
                    }
                }
                .frame(height: 6)
            }
            
            HStack {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.gray)
                        .frame(width: 32, height: 32)
                        .background(Color.white.opacity(0.06))
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.roseColor)
                        .frame(width: 32, height: 32)
                        .background(Color.roseColor.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                
                Button(action: onPayment) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle")
                        Text("Zapsat splátku")
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(Color.indigoColor)
                    .cornerRadius(12)
                }
            }
            .padding(.top, 4)
        }
        .padding(18)
        .background(Color.darkCard)
        .cornerRadius(22)
        .contextMenu {
            Button {
                onEdit()
            } label: {
                Label("Upravit", systemImage: "pencil")
            }
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Smazat", systemImage: "trash")
            }
        }
    }
}

struct LoanPaymentsHistory: View {
    let transactions: [FingoTransaction]
    
    var loanTransactions: [FingoTransaction] {
        transactions.filter { t in
            t.category?.id == "cat-uvery"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Historie plateb úvěrů")
                .font(.system(size: 16, weight: .bold))
                .padding(.horizontal)
            
            if loanTransactions.isEmpty {
                Text("Žádné evidované splátky v historii transakcí")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
                    .background(Color.darkCard)
                    .cornerRadius(20)
                    .padding(.horizontal)
            } else {
                VStack(spacing: 0) {
                    ForEach(loanTransactions.prefix(5)) { t in
                        TransactionRow(transaction: t)
                            .padding(.vertical, 12)
                            .padding(.horizontal)
                        
                        if t.id != loanTransactions.prefix(5).last?.id {
                            Divider()
                                .background(Color.gray.opacity(0.15))
                                .padding(.horizontal)
                        }
                    }
                }
                .background(Color.darkCard)
                .cornerRadius(20)
                .padding(.horizontal)
            }
        }
        .padding(.top, 10)
    }
}

struct AddLoanSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    var categories: [FingoCategory] { FingoDataManager.shared.database.categories }
    
    var loanToEdit: FingoLoan?
    
    init(loanToEdit: FingoLoan? = nil) {
        self.loanToEdit = loanToEdit
        if let loan = loanToEdit {
            _name = State(initialValue: loan.name)
            _type = State(initialValue: loan.type)
            _totalAmountString = State(initialValue: String(Int(loan.totalAmount)))
            _remainingAmountString = State(initialValue: String(Int(loan.remainingAmount)))
            _monthlyPaymentString = State(initialValue: String(Int(loan.monthlyPayment)))
            _interestRateString = State(initialValue: String(format: \"%.2f\", loan.interestRate))
            _yearsString = State(initialValue: String(loan.duration ?? 20))
            let formatter = DateFormatter()
            formatter.dateFormat = \"yyyy-MM-dd\"
            if let d = formatter.date(from: loan.startDate) { _startDate = State(initialValue: d) }
        }
    }
    
    @State private var name = ""
    @State private var type = "mortgage"
    @State private var totalAmountString = ""
    @State private var remainingAmountString = ""
    @State private var monthlyPaymentString = ""
    @State private var interestRateString = ""
    @State private var yearsString = "20"
    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var notes = ""
    @State private var selectedCategory: FingoCategory?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("ZÁKLADNÍ ÚDAJE")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.gray)
                            .padding(.leading, 8)
                            
                        VStack(spacing: 0) {
                            TextField("Název (např. Hypotéka KB)", text: $name)
                                .padding()
                                .foregroundColor(.white)
                            
                            Divider().background(Color.gray.opacity(0.2))
                            
                            Picker("Typ", selection: $type) {
                                Text("Hypotéka").tag("mortgage")
                                Text("Autoúvěr").tag("car_loan")
                                Text("Spotřebák").tag("consumer")
                                Text("Jiný").tag("other")
                            }
                            .pickerStyle(.segmented)
                            .padding()
                        }
                        .background(Color(white: 0.08))
                        .cornerRadius(16)
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("FINANČNÍ PARAMETRY")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.gray)
                            .padding(.leading, 8)
                            
                        VStack(spacing: 0) {
                            HStack {
                                Text("Původní výše")
                                    .foregroundColor(.white)
                                Spacer()
                                TextField("Kč", text: $totalAmountString)
                                    .keyboardType(.numberPad)
                                    .multilineTextAlignment(.trailing)
                                    .foregroundColor(.white)
                            }
                            .padding()
                            
                            Divider().background(Color.gray.opacity(0.2))
                            
                            HStack {
                                Text("Zbývá doplatit")
                                    .foregroundColor(.white)
                                Spacer()
                                TextField("Kč", text: $remainingAmountString)
                                    .keyboardType(.numberPad)
                                    .multilineTextAlignment(.trailing)
                                    .foregroundColor(Color.roseColor)
                            }
                            .padding()
                            
                            Divider().background(Color.gray.opacity(0.2))
                            
                            HStack {
                                Text("Měsíční splátka")
                                    .foregroundColor(.white)
                                Spacer()
                                TextField("Kč", text: $monthlyPaymentString)
                                    .keyboardType(.numberPad)
                                    .multilineTextAlignment(.trailing)
                                    .foregroundColor(.white)
                            }
                            .padding()
                            
                            Divider().background(Color.gray.opacity(0.2))
                            
                            HStack {
                                Text("Úroková sazba")
                                    .foregroundColor(.white)
                                Spacer()
                                TextField("% p.a.", text: $interestRateString)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .foregroundColor(Color.indigoColor)
                            }
                            .padding()
                        }
                        .background(Color(white: 0.08))
                        .cornerRadius(16)
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("DOPLŇUJÍCÍ")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.gray)
                            .padding(.leading, 8)
                            
                        VStack(spacing: 0) {
                            DatePicker("Konec splácení", selection: $endDate, displayedComponents: .date)
                                .colorScheme(.dark)
                                .padding()
                                
                            Divider().background(Color.gray.opacity(0.2))
                            
                            HStack {
                                Text("Kategorie")
                                    .foregroundColor(.white)
                                Spacer()
                                Menu {
                                    ForEach(categories) { category in
                                        Button(action: { selectedCategory = category }) {
                                            Label(category.name, systemImage: category.icon)
                                        }
                                    }
                                } label: {
                                    HStack {
                                        if let cat = selectedCategory {
                                            Image(systemName: cat.icon)
                                            Text(cat.name)
                                        } else {
                                            Text("Vyberte")
                                        }
                                        Image(systemName: "chevron.up.chevron.down").font(.system(size: 12))
                                    }
                                    .foregroundColor(Color.indigoColor)
                                }
                            }
                            .padding()
                        }
                        .background(Color(white: 0.08))
                        .cornerRadius(16)
                    }
                    
                    Button(action: saveLoan) {
                        Text("Uložit úvěr")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.indigoColor)
                            .cornerRadius(16)
                    }
                    .padding(.top, 10)
                    .disabled(name.isEmpty || totalAmountString.isEmpty || remainingAmountString.isEmpty || monthlyPaymentString.isEmpty)
                    .opacity((name.isEmpty || totalAmountString.isEmpty || remainingAmountString.isEmpty || monthlyPaymentString.isEmpty) ? 0.5 : 1.0)
                }
                .padding()
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Nový úvěr")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Zrušit") { dismiss() }.foregroundColor(.gray)
                }
            }
            .onAppear {
                selectedCategory = categories.first(where: { $0.id == "cat-uvery" }) ?? categories.first
            }
        }
    }
    
    private func saveLoan() {
        guard let totalAmount = Double(totalAmountString),
              let remainingAmount = Double(remainingAmountString),
              let monthlyPayment = Double(monthlyPaymentString),
              let interestRate = Double(interestRateString.replacingOccurrences(of: ",", with: ".")),
              let duration = Int(yearsString) else { return }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let startDateStr = formatter.string(from: startDate)
        
        let id = loanToEdit?.id ?? (\"l-\" + String(Int(Date().timeIntervalSince1970)) + \"-\" + UUID().uuidString.prefix(6).lowercased())
        let newLoan = FingoLoan(id: id, name: name, type: type, totalAmount: totalAmount, remainingAmount: remainingAmount, interestRate: interestRate, monthlyPayment: monthlyPayment, duration: duration, durationUnit: \"years\", startDate: startDateStr, endDate: endDate, notes: notes, categoryId: selectedCategory?.id ?? \"cat-uvery\")
        if loanToEdit != nil {
            if let idx = FingoDataManager.shared.database.loans.firstIndex(where: { $0.id == id }) {
                FingoDataManager.shared.database.loans[idx] = newLoan
            }
        } else {
            FingoDataManager.shared.database.loans.append(newLoan)
        }
        FingoDataManager.shared.saveDatabase()
        dismiss()
    }
}


struct AddLoanPaymentSheet: View {
    @Environment(\.dismiss) private var dismiss
    let loan: FingoLoan
    
    @State private var paymentAmountString = ""
    @State private var date = Date()
    @State private var isExtraPayment = false
    @State private var amountStringPrefill = ""
    
    init(loan: FingoLoan) {
        self.loan = loan
        _amountStringPrefill = State(initialValue: String(Int(loan.monthlyPayment)))
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("ÚVĚR")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.gray)
                            .padding(.leading, 8)
                            
                        VStack(spacing: 0) {
                            HStack {
                                Text("Název")
                                    .foregroundColor(.gray)
                                Spacer()
                                Text(loan.name)
                                    .foregroundColor(.white)
                            }
                            .padding()
                            
                            Divider().background(Color.gray.opacity(0.2))
                            
                            HStack {
                                Text("Zbývá doplatit")
                                    .foregroundColor(.gray)
                                Spacer()
                                Text(fingoFormatCurrency(loan.remainingAmount))
                                    .foregroundColor(.white)
                            }
                            .padding()
                        }
                        .background(Color(white: 0.08))
                        .cornerRadius(16)
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("SPLÁTKA")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.gray)
                            .padding(.leading, 8)
                            
                        VStack(spacing: 0) {
                            HStack {
                                Text("Kč")
                                    .font(.headline)
                                    .foregroundColor(.gray)
                                TextField("Částka splátky", text: $amountStringPrefill)
                                    .keyboardType(.decimalPad)
                                    .font(.system(size: 28, weight: .black))
                                    .foregroundColor(.white)
                            }
                            .padding()
                            
                            Divider().background(Color.gray.opacity(0.2))
                            
                            Toggle("Mimořádná splátka", isOn: $isExtraPayment)
                                .foregroundColor(.white)
                                .padding()
                                
                            Divider().background(Color.gray.opacity(0.2))
                            
                            DatePicker("Datum úhrady", selection: $date, displayedComponents: .date)
                                .colorScheme(.dark)
                                .padding()
                        }
                        .background(Color(white: 0.08))
                        .cornerRadius(16)
                    }
                    
                    Button(action: savePayment) {
                        Text("Uložit splátku")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.indigoColor)
                            .cornerRadius(16)
                    }
                    .padding(.top, 10)
                    .disabled(amountStringPrefill.isEmpty)
                    .opacity(amountStringPrefill.isEmpty ? 0.5 : 1.0)
                }
                .padding()
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Zapsat splátku")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Zrušit") { dismiss() }.foregroundColor(.gray)
                }
            }
        }
    }
    
    private func savePayment() {
        guard let amount = Double(amountStringPrefill) else { return }
        
        if let index = FingoDataManager.shared.database.loans.firstIndex(where: { $0.id == loan.id }) {
            FingoDataManager.shared.database.loans[index].remainingAmount = max(0.0, FingoDataManager.shared.database.loans[index].remainingAmount - amount)
        }
        
        let newTransaction = FingoTransaction(
            type: "expense",
            amount: amount,
            date: date,
            notes: (isExtraPayment ? "Mimořádná splátka: " : "Splátka: ") + loan.name,
            categoryId: loan.categoryId
        )
        FingoDataManager.shared.database.transactions.append(newTransaction)
        FingoDataManager.shared.saveDatabase()
        dismiss()
    }
}


struct RecurringSubView: View {
    var recurring: [FingoRecurring] { FingoDataManager.shared.database.recurring }
    @State private var recurringToEdit: FingoRecurring? = nil
    @State private var recurringToDelete: FingoRecurring? = nil
    
    var body: some View {
        VStack(spacing: 20) {
            if recurring.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "repeat")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    Text("Žádné trvalé platby")
                        .font(.system(size: 16, weight: .bold))
                    Text("Zadejte pravidelné platby tlačítkem + vpravo nahoře.")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .background(Color.darkCard)
                .cornerRadius(20)
                .padding(.horizontal)
            } else {
                VStack(spacing: 16) {
                    ForEach(recurring) { rec in
                        RecurringCard(recurring: rec, onEdit: {
                            recurringToEdit = rec
                        }, onDelete: {
                            recurringToDelete = rec
                        })
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
        .sheet(item: $recurringToEdit) { rec in
            AddRecurringSheet(recurringToEdit: rec)
        }
        .alert("Smazat trvalou platbu?", isPresented: Binding(
            get: { recurringToDelete != nil },
            set: { if !$0 { recurringToDelete = nil } }
        )) {
            Button("Smazat", role: .destructive) {
                if let rec = recurringToDelete {
                    FingoDataManager.shared.database.recurring.removeAll { $0.id == rec.id }
                    FingoDataManager.shared.saveDatabase()
                }
                recurringToDelete = nil
            }
            Button("Zrušit", role: .cancel) {
                recurringToDelete = nil
            }
        } message: {
            if let rec = recurringToDelete {
                Text("Opravdu chcete smazat pravidelnou platbu \"\(rec.name)\"?")
            }
        }
    }
}

struct RecurringCard: View {
    let recurring: FingoRecurring
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color(hex: recurring.category?.color ?? "#gray").opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: recurring.category?.icon ?? "repeat")
                        .foregroundColor(Color(hex: recurring.category?.color ?? "#gray"))
                        .font(.system(size: 18))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(recurring.name)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    Text("Frekvence: \(recurring.frequency == "monthly" ? "Měsíčně" : (recurring.frequency == "yearly" ? "Ročně" : "Týdně"))")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(fingoFormatCurrency(recurring.amount))
                        .font(.system(size: 16, weight: .black))
                        .foregroundColor(recurring.type == "income" ? Color.emerald : Color.roseColor)
                    Text("Další: \(recurring.nextDueDate.formatted(.dateTime.day().month()))")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                }
            }
            
            Divider().background(Color.gray.opacity(0.15))
            
            HStack {
                Button(action: onEdit) {
                    HStack(spacing: 6) {
                        Image(systemName: "pencil")
                        Text("Upravit")
                    }
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.gray)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(10)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: onDelete) {
                    HStack(spacing: 6) {
                        Image(systemName: "trash")
                        Text("Smazat")
                    }
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.roseColor)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .background(Color.roseColor.opacity(0.1))
                    .cornerRadius(10)
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
            }
        }
        .padding(18)
        .background(Color.darkCard)
        .cornerRadius(22)
        .contextMenu {
            Button {
                onEdit()
            } label: {
                Label("Upravit", systemImage: "pencil")
            }
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Smazat", systemImage: "trash")
            }
        }
    }
}

struct AddRecurringSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var amountString = ""
    @State private var type = "expense"
    @State private var frequency = "monthly"
    @State private var nextDueDate = Date()
    @State private var selectedCategory: FingoCategory?
    
    var categories: [FingoCategory] { FingoDataManager.shared.database.categories }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("ZÁKLADNÍ ÚDAJE")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.gray)
                            .padding(.leading, 8)
                            
                        VStack(spacing: 0) {
                            Picker("Typ", selection: $type) {
                                Text("Výdaj").tag("expense")
                                Text("Příjem").tag("income")
                            }
                            .pickerStyle(.segmented)
                            .padding()
                            
                            Divider().background(Color.gray.opacity(0.2))
                            
                            HStack {
                                Text("Kč")
                                    .font(.headline)
                                    .foregroundColor(.gray)
                                TextField("Částka", text: $amountString)
                                    .keyboardType(.decimalPad)
                                    .font(.system(size: 28, weight: .black))
                                    .foregroundColor(type == "income" ? Color.emerald : Color.roseColor)
                            }
                            .padding()
                            
                            Divider().background(Color.gray.opacity(0.2))
                            
                            TextField("Název (např. Nájem, Netflix)", text: $name)
                                .foregroundColor(.white)
                                .padding()
                        }
                        .background(Color(white: 0.08))
                        .cornerRadius(16)
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("FREKVENCE A KATEGORIE")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.gray)
                            .padding(.leading, 8)
                            
                        VStack(spacing: 0) {
                            HStack {
                                Text("Frekvence")
                                    .foregroundColor(.white)
                                Spacer()
                                Picker("Frekvence", selection: $frequency) {
                                    Text("Měsíčně").tag("monthly")
                                    Text("Ročně").tag("yearly")
                                    Text("Týdně").tag("weekly")
                                }
                                .accentColor(Color.indigoColor)
                            }
                            .padding()
                            
                            Divider().background(Color.gray.opacity(0.2))
                            
                            DatePicker("Další platba", selection: $nextDueDate, displayedComponents: .date)
                                .colorScheme(.dark)
                                .padding()
                                
                            Divider().background(Color.gray.opacity(0.2))
                            
                            HStack {
                                Text("Kategorie")
                                    .foregroundColor(.white)
                                Spacer()
                                Menu {
                                    ForEach(categories) { category in
                                        Button(action: { selectedCategory = category }) {
                                            Label(category.name, systemImage: category.icon)
                                        }
                                    }
                                } label: {
                                    HStack {
                                        if let cat = selectedCategory {
                                            Image(systemName: cat.icon)
                                            Text(cat.name)
                                        } else {
                                            Text("Vyberte")
                                        }
                                        Image(systemName: "chevron.up.chevron.down").font(.system(size: 12))
                                    }
                                    .foregroundColor(Color.indigoColor)
                                }
                            }
                            .padding()
                        }
                        .background(Color(white: 0.08))
                        .cornerRadius(16)
                    }
                    
                    Button(action: saveRecurring) {
                        Text("Uložit trvalou platbu")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.indigoColor)
                            .cornerRadius(16)
                    }
                    .padding(.top, 10)
                    .disabled(name.isEmpty || amountString.isEmpty || selectedCategory == nil)
                    .opacity((name.isEmpty || amountString.isEmpty || selectedCategory == nil) ? 0.5 : 1.0)
                }
                .padding()
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Nová platba")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Zrušit") { dismiss() }.foregroundColor(.gray)
                }
            }
        }
    }
    
    private func saveRecurring() {
        guard let amount = Double(amountString), let cat = selectedCategory else { return }
        let rec = FingoRecurring(name: name, type: type, amount: amount, frequency: frequency, nextDueDate: nextDueDate, categoryId: cat.id)
        FingoDataManager.shared.database.recurring.append(rec)
        FingoDataManager.shared.saveDatabase()
        dismiss()
    }
}


struct BudgetsSubView: View {
    var budgets: [FingoBudget] { FingoDataManager.shared.database.budgets }
    var transactions: [FingoTransaction] { FingoDataManager.shared.database.transactions }
    var categories: [FingoCategory] { FingoDataManager.shared.database.categories }
    
    @State private var budgetToEdit: FingoBudget? = nil
    @State private var budgetToDelete: FingoBudget? = nil
    
    var currentMonthTransactions: [FingoTransaction] {
        let cal = Calendar.current
        return transactions.filter { cal.isDate($0.date, equalTo: Date(), toGranularity: .month) }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            if budgets.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    Text("Žádné rozpočty")
                        .font(.system(size: 16, weight: .bold))
                    Text("Nastavte si měsíční limit pro různé kategorie tlačítkem + vpravo nahoře.")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .background(Color.darkCard)
                .cornerRadius(20)
                .padding(.horizontal)
            } else {
                VStack(spacing: 16) {
                    ForEach(budgets) { budget in
                        BudgetCard(budget: budget, transactions: currentMonthTransactions, categories: categories, onEdit: {
                            budgetToEdit = budget
                        }, onDelete: {
                            budgetToDelete = budget
                        })
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
        .sheet(item: $budgetToEdit) { budget in
            AddBudgetSheet(budgetToEdit: budget)
        }
        .alert("Smazat rozpočet?", isPresented: Binding(
            get: { budgetToDelete != nil },
            set: { if !$0 { budgetToDelete = nil } }
        )) {
            Button("Smazat", role: .destructive) {
                if let b = budgetToDelete {
                    FingoDataManager.shared.database.budgets.removeAll { $0.categoryId == b.categoryId }
                    FingoDataManager.shared.saveDatabase()
                }
                budgetToDelete = nil
            }
            Button("Zrušit", role: .cancel) {
                budgetToDelete = nil
            }
        } message: {
            if let b = budgetToDelete, let cat = categories.first(where: { $0.id == b.categoryId }) {
                Text("Opravdu chcete smazat limit rozpočtu pro kategorii \"\(cat.name)\"?")
            }
        }
    }
}

struct BudgetCard: View {
    let budget: FingoBudget
    let transactions: [FingoTransaction]
    let categories: [FingoCategory]
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var category: FingoCategory? {
        categories.first { $0.id == budget.categoryId }
    }
    
    var spent: Double {
        transactions.filter { $0.categoryId == budget.categoryId && $0.type == "expense" }
            .reduce(0) { $0 + $1.amount }
    }
    
    var progress: Double {
        guard budget.amount > 0 else { return 1.0 }
        return min(1.0, spent / budget.amount)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                ZStack {
                    Circle()
                        .fill(Color(hex: category?.color ?? "#gray").opacity(0.12))
                        .frame(width: 38, height: 38)
                    Image(systemName: category?.icon ?? "tag")
                        .foregroundColor(Color(hex: category?.color ?? "#gray"))
                        .font(.system(size: 16))
                }
                
                Text(category?.name ?? "Neznámá")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(fingoFormatCurrency(spent))
                        .font(.system(size: 14, weight: .black))
                        .foregroundColor(spent > budget.amount ? Color.roseColor : .white)
                    Text("z \(fingoFormatCurrency(budget.amount))")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                }
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.gray.opacity(0.15))
                    Capsule()
                        .fill(spent > budget.amount ? Color.roseColor : (progress > 0.8 ? Color.orange : Color.emerald))
                        .frame(width: geo.size.width * CGFloat(progress))
                }
            }
            .frame(height: 8)
            
            HStack {
                if spent > budget.amount {
                    Text("Překročeno o \(fingoFormatCurrency(spent - budget.amount))")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Color.roseColor)
                } else {
                    Text("Zbývá \(fingoFormatCurrency(budget.amount - spent))")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.gray)
                        .frame(width: 28, height: 28)
                        .background(Color.white.opacity(0.06))
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.roseColor)
                        .frame(width: 28, height: 28)
                        .background(Color.roseColor.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(18)
        .background(Color.darkCard)
        .cornerRadius(22)
        .contextMenu {
            Button {
                onEdit()
            } label: {
                Label("Upravit", systemImage: "pencil")
            }
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Smazat", systemImage: "trash")
            }
        }
    }
}

struct AddBudgetSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var amountString = ""
    @State private var selectedCategory: FingoCategory?
    
    var categories: [FingoCategory] { FingoDataManager.shared.database.categories }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("KATEGORIE A LIMIT")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.gray)
                            .padding(.leading, 8)
                            
                        VStack(spacing: 0) {
                            HStack {
                                Text("Kategorie")
                                    .foregroundColor(.white)
                                Spacer()
                                Menu {
                                    ForEach(categories) { category in
                                        Button(action: { selectedCategory = category }) {
                                            Label(category.name, systemImage: category.icon)
                                        }
                                    }
                                } label: {
                                    HStack {
                                        if let cat = selectedCategory {
                                            Image(systemName: cat.icon)
                                            Text(cat.name)
                                        } else {
                                            Text("Vyberte")
                                        }
                                        Image(systemName: "chevron.up.chevron.down").font(.system(size: 12))
                                    }
                                    .foregroundColor(Color.indigoColor)
                                }
                            }
                            .padding()
                            
                            Divider().background(Color.gray.opacity(0.2))
                            
                            HStack {
                                Text("Kč")
                                    .font(.headline)
                                    .foregroundColor(.gray)
                                TextField("Měsíční limit", text: $amountString)
                                    .keyboardType(.decimalPad)
                                    .font(.system(size: 28, weight: .black))
                                    .foregroundColor(.white)
                            }
                            .padding()
                        }
                        .background(Color(white: 0.08))
                        .cornerRadius(16)
                    }
                    
                    Button(action: saveBudget) {
                        Text("Uložit rozpočet")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.indigoColor)
                            .cornerRadius(16)
                    }
                    .padding(.top, 10)
                    .disabled(amountString.isEmpty || selectedCategory == nil)
                    .opacity((amountString.isEmpty || selectedCategory == nil) ? 0.5 : 1.0)
                }
                .padding()
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Nový rozpočet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Zrušit") { dismiss() }.foregroundColor(.gray)
                }
            }
        }
    }
    
    private func saveBudget() {
        guard let amount = Double(amountString), let cat = selectedCategory else { return }
        if let idx = FingoDataManager.shared.database.budgets.firstIndex(where: { $0.categoryId == cat.id }) {
            FingoDataManager.shared.database.budgets[idx].amount = amount
        } else {
            let budget = FingoBudget(categoryId: cat.id, amount: amount)
            FingoDataManager.shared.database.budgets.append(budget)
        }
        FingoDataManager.shared.saveDatabase()
        dismiss()
    }
}


struct GoalsSubView: View {
    var goals: [FingoGoal] { FingoDataManager.shared.database.savingsGoals }
    @State private var selectedGoalForDeposit: FingoGoal? = nil
    @State private var goalToEdit: FingoGoal? = nil
    @State private var goalToDelete: FingoGoal? = nil
    
    var body: some View {
        VStack(spacing: 20) {
            if goals.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "target")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    Text("Žádné spořicí cíle")
                        .font(.system(size: 16, weight: .bold))
                    Text("Přidejte si svůj první cíl tlačítkem + vpravo nahoře.")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .background(Color.darkCard)
                .cornerRadius(20)
                .padding(.horizontal)
            } else {
                VStack(spacing: 16) {
                    ForEach(goals) { goal in
                        GoalCard(goal: goal, onDeposit: {
                            selectedGoalForDeposit = goal
                        }, onEdit: {
                            goalToEdit = goal
                        }, onDelete: {
                            goalToDelete = goal
                        })
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
        .sheet(item: $selectedGoalForDeposit) { goal in
            AddGoalDepositSheet(goal: goal)
        }
        .sheet(item: $goalToEdit) { goal in
            AddGoalSheet(goalToEdit: goal)
        }
        .alert("Smazat cíl?", isPresented: Binding(
            get: { goalToDelete != nil },
            set: { if !$0 { goalToDelete = nil } }
        )) {
            Button("Smazat", role: .destructive) {
                if let goal = goalToDelete {
                    FingoDataManager.shared.database.savingsGoals.removeAll { $0.id == goal.id }
                    FingoDataManager.shared.saveDatabase()
                }
                goalToDelete = nil
            }
            Button("Zrušit", role: .cancel) {
                goalToDelete = nil
            }
        } message: {
            if let goal = goalToDelete {
                Text("Opravdu chcete smazat spořicí cíl \"\(goal.name)\"?")
            }
        }
    }
}

struct GoalCard: View {
    let goal: FingoGoal
    let onDeposit: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var progress: Double {
        guard goal.targetAmount > 0 else { return 1.0 }
        return min(1.0, goal.currentAmount / goal.targetAmount)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.12))
                        .frame(width: 38, height: 38)
                    Image(systemName: goal.icon)
                        .foregroundColor(.orange)
                        .font(.system(size: 16))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(goal.name)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    Text("Cíl: \(goal.targetDate.formatted(.dateTime.year().month()))")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(fingoFormatCurrency(goal.currentAmount))
                        .font(.system(size: 14, weight: .black))
                        .foregroundColor(.white)
                    Text("z \(fingoFormatCurrency(goal.targetAmount))")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                }
            }
            
            VStack(spacing: 6) {
                HStack {
                    Text("\(Int(progress * 100))%")
                    Spacer()
                    Text("Zbývá naspořit: \(fingoFormatCurrency(max(0, goal.targetAmount - goal.currentAmount)))")
                }
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.gray)
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.gray.opacity(0.15))
                        Capsule()
                            .fill(Color.orange)
                            .frame(width: geo.size.width * CGFloat(progress))
                    }
                }
                .frame(height: 6)
            }
            
            HStack {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.gray)
                        .frame(width: 32, height: 32)
                        .background(Color.white.opacity(0.06))
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.roseColor)
                        .frame(width: 32, height: 32)
                        .background(Color.roseColor.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                
                Button(action: onDeposit) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle")
                        Text("Přidat peníze")
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(Color.orange)
                    .cornerRadius(12)
                }
            }
            .padding(.top, 4)
        }
        .padding(18)
        .background(Color.darkCard)
        .cornerRadius(22)
        .contextMenu {
            Button {
                onEdit()
            } label: {
                Label("Upravit", systemImage: "pencil")
            }
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Smazat", systemImage: "trash")
            }
        }
    }
}

struct AddGoalSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    var goalToEdit: FingoGoal?
    
    init(goalToEdit: FingoGoal? = nil) {
        self.goalToEdit = goalToEdit
        if let g = goalToEdit {
            _name = State(initialValue: g.name)
            _targetAmountString = State(initialValue: String(Int(g.targetAmount)))
            _targetDate = State(initialValue: g.targetDate)
        }
    }
    
    @State private var name = ""
    @State private var targetAmountString = ""
    @State private var currentAmountString = ""
    @State private var targetDate = Date()
    @State private var icon = "target"
    
    let icons = ["target", "car.fill", "house.fill", "airplane", "gift.fill", "gamecontroller.fill", "laptopcomputer", "heart.fill"]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("ZÁKLADNÍ ÚDAJE")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.gray)
                            .padding(.leading, 8)
                            
                        VStack(spacing: 0) {
                            TextField("Název (např. Nové auto)", text: $name)
                                .foregroundColor(.white)
                                .padding()
                                
                            Divider().background(Color.gray.opacity(0.2))
                            
                            HStack {
                                Text("Cílová částka")
                                    .foregroundColor(.white)
                                Spacer()
                                TextField("Kč", text: $targetAmountString)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .foregroundColor(.white)
                            }
                            .padding()
                            
                            Divider().background(Color.gray.opacity(0.2))
                            
                            HStack {
                                Text("Už naspořeno")
                                    .foregroundColor(.white)
                                Spacer()
                                TextField("Kč", text: $currentAmountString)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .foregroundColor(.white)
                            }
                            .padding()
                        }
                        .background(Color(white: 0.08))
                        .cornerRadius(16)
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("DETAILY")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.gray)
                            .padding(.leading, 8)
                            
                        VStack(spacing: 0) {
                            DatePicker("Cílové datum", selection: $targetDate, displayedComponents: .date)
                                .colorScheme(.dark)
                                .padding()
                                
                            Divider().background(Color.gray.opacity(0.2))
                            
                            HStack {
                                Text("Ikona")
                                    .foregroundColor(.white)
                                Spacer()
                                Picker("Ikona", selection: $icon) {
                                    ForEach(icons, id: \.self) { ic in
                                        Image(systemName: ic).tag(ic)
                                    }
                                }
                                .accentColor(Color.orange)
                            }
                            .padding()
                        }
                        .background(Color(white: 0.08))
                        .cornerRadius(16)
                    }
                    
                    Button(action: saveGoal) {
                        Text("Uložit cíl")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.orange)
                            .cornerRadius(16)
                    }
                    .padding(.top, 10)
                    .disabled(name.isEmpty || targetAmountString.isEmpty)
                    .opacity((name.isEmpty || targetAmountString.isEmpty) ? 0.5 : 1.0)
                }
                .padding()
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Nový cíl")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Zrušit") { dismiss() }.foregroundColor(.gray)
                }
            }
        }
    }
    
    private func saveGoal() {
        guard let target = Double(targetAmountString) else { return }
        let current = Double(currentAmountString) ?? 0.0
        
        let goal = FingoGoal(name: name, targetAmount: target, currentAmount: current, targetDate: targetDate, icon: icon)
        FingoDataManager.shared.database.savingsGoals.append(goal)
        FingoDataManager.shared.saveDatabase()
        dismiss()
    }
}


struct AddGoalDepositSheet: View {
    @Environment(\.dismiss) private var dismiss
    let goal: FingoGoal
    
    @State private var amountString = ""
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("CÍL")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.gray)
                            .padding(.leading, 8)
                            
                        VStack(spacing: 0) {
                            HStack {
                                Text(goal.name)
                                    .foregroundColor(.white)
                                Spacer()
                                Text(fingoFormatCurrency(goal.currentAmount))
                                    .foregroundColor(.gray)
                            }
                            .padding()
                        }
                        .background(Color(white: 0.08))
                        .cornerRadius(16)
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("VKLAD")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.gray)
                            .padding(.leading, 8)
                            
                        VStack(spacing: 0) {
                            HStack {
                                Text("Kč")
                                    .font(.headline)
                                    .foregroundColor(.gray)
                                TextField("0,00", text: $amountString)
                                    .keyboardType(.decimalPad)
                                    .font(.system(size: 28, weight: .black))
                                    .foregroundColor(.orange)
                            }
                            .padding()
                        }
                        .background(Color(white: 0.08))
                        .cornerRadius(16)
                    }
                    
                    Button(action: saveDeposit) {
                        Text("Přidat peníze")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.orange)
                            .cornerRadius(16)
                    }
                    .padding(.top, 10)
                    .disabled(amountString.isEmpty)
                    .opacity(amountString.isEmpty ? 0.5 : 1.0)
                }
                .padding()
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Vklad do cíle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Zrušit") { dismiss() }.foregroundColor(.gray)
                }
            }
        }
    }
    
    private func saveDeposit() {
        guard let amount = Double(amountString) else { return }
        
        if let idx = FingoDataManager.shared.database.savingsGoals.firstIndex(where: { $0.id == goal.id }) {
            FingoDataManager.shared.database.savingsGoals[idx].currentAmount += amount
            FingoDataManager.shared.saveDatabase()
        }
        dismiss()
    }
}


