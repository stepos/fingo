import SwiftUI
import Charts

struct ExportItem: Identifiable {
    let id = UUID()
    let url: URL
}

struct DashboardView: View {
    var transactions: [FingoTransaction] {
        FingoDataManager.shared.database.transactions.sorted(by: { $0.date > $1.date })
    }
    var categories: [FingoCategory] {
        FingoDataManager.shared.database.categories
    }
    var loans: [FingoLoan] {
        FingoDataManager.shared.database.loans
    }
    var recurring: [FingoRecurring] {
        FingoDataManager.shared.database.recurring
    }
    
    enum CategorySortType: String, CaseIterable {
        case sum = "Suma"
        case date = "Datum"
        case category = "Kategorie"
    }
    
    @State private var showingAddTransaction = false
    @State private var categorySort: CategorySortType = .sum
    @State private var expandedCategories: Set<String> = []
    @State private var transactionToEdit: FingoTransaction? = nil
    @State private var transactionToDelete: FingoTransaction? = nil
    
    @State private var exportItem: ExportItem? = nil
    
    @State private var selectedMonth: Date = {
        let components = Calendar.current.dateComponents([.year, .month], from: Date())
        return Calendar.current.date(from: components) ?? Date()
    }()
    
    var availableMonths: [Date] {
        let calendar = Calendar.current
        var dates = Set<Date>()
        
        let components = calendar.dateComponents([.year, .month], from: Date())
        if let currentMonth = calendar.date(from: components) {
            dates.insert(currentMonth)
        }
        
        for t in transactions {
            let comps = calendar.dateComponents([.year, .month], from: t.date)
            if let d = calendar.date(from: comps) { dates.insert(d) }
        }
        
        return Array(dates).sorted(by: >)
    }
    
    func formatMonthYear(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        formatter.locale = Locale(identifier: "cs_CZ")
        return formatter.string(from: date).capitalized
    }
    
    var netBalance: Double {
        let calendar = Calendar.current
        let isFutureMonth = selectedMonth > calendar.date(from: calendar.dateComponents([.year, .month], from: Date()))!
        let isCurrentMonth = calendar.isDate(selectedMonth, equalTo: Date(), toGranularity: .month)
        
        let targetDate: Date
        if isCurrentMonth || isFutureMonth {
            targetDate = Date()
        } else {
            let nextMonth = calendar.date(byAdding: .month, value: 1, to: selectedMonth)!
            targetDate = calendar.date(byAdding: .second, value: -1, to: nextMonth)!
        }
        
        let pastTransactions = transactions.filter { $0.date <= targetDate }
        let incomes = pastTransactions.filter { $0.type == "income" }.reduce(0.0) { $0 + $1.amount }
        let expenses = pastTransactions.filter { $0.type == "expense" }.reduce(0.0) { $0 + $1.amount }
        return incomes - expenses
    }
    
    var totalIncomes: Double {
        let calendar = Calendar.current
        return transactions.filter { 
            $0.type == "income" && calendar.isDate($0.date, equalTo: selectedMonth, toGranularity: .month)
        }.reduce(0.0) { $0 + $1.amount }
    }
    
    var totalExpenses: Double {
        let calendar = Calendar.current
        return transactions.filter { 
            $0.type == "expense" && calendar.isDate($0.date, equalTo: selectedMonth, toGranularity: .month)
        }.reduce(0.0) { $0 + $1.amount }
    }
    
    var upcomingRecurringExpenses: Double {
        let calendar = Calendar.current
        let isCurrentMonth = calendar.isDate(selectedMonth, equalTo: Date(), toGranularity: .month)
        let isPastMonth = selectedMonth < calendar.date(from: calendar.dateComponents([.year, .month], from: Date()))!
        
        if isPastMonth { return 0.0 }
        
        let now = Date()
        return recurring.filter { 
            $0.type == "expense" && 
            calendar.isDate($0.nextDueDate, equalTo: selectedMonth, toGranularity: .month) &&
            (!isCurrentMonth || $0.nextDueDate > now)
        }.reduce(0.0) { $0 + $1.amount }
    }
    
    var upcomingRecurringIncomes: Double {
        let calendar = Calendar.current
        let isCurrentMonth = calendar.isDate(selectedMonth, equalTo: Date(), toGranularity: .month)
        let isPastMonth = selectedMonth < calendar.date(from: calendar.dateComponents([.year, .month], from: Date()))!
        
        if isPastMonth { return 0.0 }
        
        let now = Date()
        return recurring.filter { 
            $0.type == "income" && 
            calendar.isDate($0.nextDueDate, equalTo: selectedMonth, toGranularity: .month) &&
            (!isCurrentMonth || $0.nextDueDate > now)
        }.reduce(0.0) { $0 + $1.amount }
    }
    
    var upcomingLoans: Double {
        let calendar = Calendar.current
        let isCurrentMonth = calendar.isDate(selectedMonth, equalTo: Date(), toGranularity: .month)
        let isPastMonth = selectedMonth < calendar.date(from: calendar.dateComponents([.year, .month], from: Date()))!
        
        if isPastMonth { return 0.0 }
        
        let currentDay = calendar.component(.day, from: Date())
        return loans.filter { loan in
            if let day = Int(loan.startDate) {
                return !isCurrentMonth || day > currentDay
            }
            return false
        }.reduce(0.0) { $0 + $1.monthlyPayment }
    }
    
    var expectedEndOfMonthBalance: Double {
        return netBalance + upcomingRecurringIncomes - upcomingRecurringExpenses - upcomingLoans
    }
    
    struct CategoryStatItem: Identifiable {
        var id: String { category.id }
        let category: FingoCategory
        let amount: Double
        let latestDate: Date?
        let pastTransactions: [FingoTransaction]
        let futureRecurring: [FingoRecurring]
        let futureLoans: [FingoLoan]
    }

    var categoryStats: [CategoryStatItem] {
        var dict: [String: (amount: Double, latestDate: Date?, past: [FingoTransaction], recurring: [FingoRecurring], loans: [FingoLoan])] = [:]
        let calendar = Calendar.current
        let isCurrentMonth = calendar.isDate(selectedMonth, equalTo: Date(), toGranularity: .month)
        let isPastMonth = selectedMonth < calendar.date(from: calendar.dateComponents([.year, .month], from: Date()))!
        
        let monthTransactions = transactions.filter { 
            $0.type == "expense" && calendar.isDate($0.date, equalTo: selectedMonth, toGranularity: .month)
        }
        
        for t in monthTransactions {
            let catId = t.categoryId
            var current = dict[catId] ?? (0.0, nil, [], [], [])
            current.amount += t.amount
            if let existingDate = current.latestDate {
                current.latestDate = max(existingDate, t.date)
            } else {
                current.latestDate = t.date
            }
            current.past.append(t)
            dict[catId] = current
        }
        
        if !isPastMonth {
            let now = Date()
            let futureRecurring = recurring.filter { 
                $0.type == "expense" && 
                calendar.isDate($0.nextDueDate, equalTo: selectedMonth, toGranularity: .month) &&
                (!isCurrentMonth || $0.nextDueDate > now)
            }
            for r in futureRecurring {
                let catId = r.categoryId
                var current = dict[catId] ?? (0.0, nil, [], [], [])
                current.amount += r.amount
                current.recurring.append(r)
                dict[catId] = current
            }
            
            let currentDay = calendar.component(.day, from: Date())
            let futureLoans = loans.filter { loan in
                if let day = Int(loan.startDate) {
                    return !isCurrentMonth || day > currentDay
                }
                return false
            }
            for l in futureLoans {
                let catId = l.categoryId
                var current = dict[catId] ?? (0.0, nil, [], [], [])
                current.amount += l.monthlyPayment
                current.loans.append(l)
                dict[catId] = current
            }
        }
        
        var items = categories.compactMap { cat -> CategoryStatItem? in
            guard let stat = dict[cat.id], stat.amount > 0 else { return nil }
            return CategoryStatItem(category: cat, amount: stat.amount, latestDate: stat.latestDate, pastTransactions: stat.past, futureRecurring: stat.recurring, futureLoans: stat.loans)
        }
        
        switch categorySort {
        case .sum:
            items.sort { $0.amount > $1.amount }
        case .date:
            items.sort { ($0.latestDate ?? Date.distantPast) > ($1.latestDate ?? Date.distantPast) }
        case .category:
            items.sort { $0.category.name < $1.category.name }
        }
        
        return items
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    HStack {
                        Menu {
                            ForEach(availableMonths, id: \.self) { month in
                                Button(action: {
                                    selectedMonth = month
                                }) {
                                    HStack {
                                        Text(formatMonthYear(month))
                                        if Calendar.current.isDate(month, equalTo: selectedMonth, toGranularity: .month) {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Text(formatMonthYear(selectedMonth))
                                    .font(.system(size: 20, weight: .black))
                                    .foregroundColor(.white)
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.indigoColor)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(Color.darkCard)
                            .cornerRadius(12)
                        }
                        
                        Spacer()
                        
                        Menu {
                            Button(action: {
                                generatePDF()
                            }) {
                                Label("Exportovat jako PDF", systemImage: "doc.richtext")
                            }
                            Button(action: {
                                generateCSV()
                            }) {
                                Label("Exportovat pro Excel (CSV)", systemImage: "tablecells")
                            }
                        } label: {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 16, weight: .bold))
                                Text("Report")
                                    .font(.system(size: 14, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(Color.indigoColor)
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                    
                    NetBalanceCard(balance: netBalance)
                        .padding(.horizontal)
                    
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        MiniStatCard(title: "Příjmy", amount: totalIncomes, color: Color.emerald, icon: "arrow.down.left.circle.fill")
                        MiniStatCard(title: "Výdaje", amount: totalExpenses, color: Color.roseColor, icon: "arrow.up.right.circle.fill")
                        MiniStatCard(title: "Trvalé platby před splatností", amount: upcomingRecurringExpenses, color: Color.orange, icon: "calendar.badge.clock")
                        MiniStatCard(title: "Úvěry a hypotéky před splatností", amount: upcomingLoans, color: Color.indigoColor, icon: "building.columns.fill")
                    }
                    .padding(.horizontal)
                    
                    DashboardBudgetsGoalsView(
                        budgets: FingoDataManager.shared.database.budgets,
                        goals: FingoDataManager.shared.database.savingsGoals,
                        transactions: transactions
                    )
                    .padding(.top, 10)

                    // Graf vývoje financí
                    VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("Očekávaný zůstatek (konec měsíce)")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.gray)
                                    Text(fingoFormatCurrency(expectedEndOfMonthBalance))
                                        .font(.system(size: 20, weight: .black))
                                        .foregroundColor(.white)
                                }
                                Spacer()
                            }
                            .padding(.horizontal)
                            
                            BalanceHistoryChart(transactions: transactions, recurring: recurring, loans: loans, selectedMonth: selectedMonth)
                                .frame(height: 180)
                                .padding()
                                .background(Color.darkCard)
                                .cornerRadius(20)
                                .padding(.horizontal)
                        }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Rozdělení výdajů")
                                .font(.system(size: 16, weight: .bold))
                            Spacer()
                        }
                        .padding(.horizontal)
                        
                        if categoryStats.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "chart.pie")
                                    .font(.system(size: 32))
                                    .foregroundColor(.gray)
                                Text("Žádné výdaje")
                                    .font(.system(size: 14, weight: .bold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 30)
                            .background(Color.darkCard)
                            .cornerRadius(20)
                            .padding(.horizontal)
                        } else {
                            // Sloupcový graf kategorií
                            Chart(categoryStats) { stat in
                                BarMark(
                                    x: .value("Částka", stat.amount),
                                    y: .value("Kategorie", "\(stat.category.name): \(fingoFormatCurrency(stat.amount))")
                                )
                                .foregroundStyle(Color(hex: stat.category.color))
                                .cornerRadius(4)
                            }
                            .chartXAxis(.hidden)
                            .frame(height: max(150, CGFloat(categoryStats.count * 45)))
                            .padding()
                            .background(Color.darkCard)
                            .cornerRadius(20)
                            .padding(.horizontal)
                            
                            HStack {
                                Text("Náklady podle kategorií")
                                    .font(.system(size: 16, weight: .bold))
                                
                                Button(action: {
                                    withAnimation {
                                        if !expandedCategories.isEmpty {
                                            expandedCategories.removeAll()
                                        } else {
                                            expandedCategories = Set(categoryStats.map { $0.id })
                                        }
                                    }
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: !expandedCategories.isEmpty ? "chevron.up.double" : "chevron.down.double")
                                        Text(!expandedCategories.isEmpty ? "Sbalit vše" : "Rozbalit vše")
                                    }
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(Color.indigoColor)
                                    .padding(.vertical, 4)
                                    .padding(.horizontal, 8)
                                    .background(Color.indigoColor.opacity(0.12))
                                    .cornerRadius(6)
                                }
                                .padding(.leading, 6)
                                
                                Spacer()
                                
                                Picker("Řazení", selection: $categorySort) {
                                    ForEach(CategorySortType.allCases, id: \.self) { sortType in
                                        Text(sortType.rawValue).tag(sortType)
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(Color.indigoColor)
                            }
                            .padding(.horizontal)
                            .padding(.top, 8)
                            
                            VStack(spacing: 0) {
                                ForEach(categoryStats) { stat in
                                    VStack(spacing: 0) {
                                        Button(action: {
                                            withAnimation {
                                                if expandedCategories.contains(stat.id) {
                                                    expandedCategories.remove(stat.id)
                                                } else {
                                                    expandedCategories.insert(stat.id)
                                                }
                                            }
                                        }) {
                                            HStack(spacing: 12) {
                                                ZStack {
                                                    Circle()
                                                        .fill(Color(hex: stat.category.color).opacity(0.15))
                                                        .frame(width: 40, height: 40)
                                                    Image(systemName: stat.category.icon)
                                                        .foregroundColor(Color(hex: stat.category.color))
                                                        .font(.system(size: 16))
                                                }
                                                
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text(stat.category.name)
                                                        .font(.system(size: 14, weight: .bold))
                                                        .foregroundColor(.white)
                                                    if let date = stat.latestDate {
                                                        Text("Poslední: \(date.formatted(date: .abbreviated, time: .omitted))")
                                                            .font(.system(size: 11))
                                                            .foregroundColor(.gray)
                                                    }
                                                }
                                                
                                                Spacer()
                                                
                                                VStack(alignment: .trailing, spacing: 4) {
                                                    Text(fingoFormatCurrency(stat.amount))
                                                        .font(.system(size: 14, weight: .bold))
                                                        .foregroundColor(Color.roseColor)
                                                    Image(systemName: expandedCategories.contains(stat.id) ? "chevron.up" : "chevron.down")
                                                        .font(.system(size: 10, weight: .bold))
                                                        .foregroundColor(.gray)
                                                }
                                            }
                                            .padding(.vertical, 12)
                                            .padding(.horizontal)
                                            .contentShape(Rectangle())
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                        
                                        if expandedCategories.contains(stat.id) {
                                            VStack(alignment: .leading, spacing: 14) {
                                                if !stat.pastTransactions.isEmpty {
                                                    Text("Již zaplaceno")
                                                        .font(.system(size: 11, weight: .black))
                                                        .foregroundColor(.gray)
                                                        .tracking(1)
                                                        .padding(.top, 4)
                                                        .padding(.bottom, -6)
                                                    
                                                    ForEach(stat.pastTransactions.sorted(by: { $0.date > $1.date })) { t in
                                                        SwipeActionRow(onEdit: {
                                                            transactionToEdit = t
                                                            showingAddTransaction = true
                                                        }, onDelete: {
                                                            transactionToDelete = t
                                                        }) {
                                                            TransactionRow(transaction: t)
                                                        }
                                                    }
                                                }
                                                
                                                if !stat.futureRecurring.isEmpty || !stat.futureLoans.isEmpty {
                                                    Text("Čeká na zaplacení")
                                                        .font(.system(size: 11, weight: .black))
                                                        .foregroundColor(.orange)
                                                        .tracking(1)
                                                        .padding(.top, stat.pastTransactions.isEmpty ? 4 : 8)
                                                        .padding(.bottom, -6)
                                                    
                                                    ForEach(stat.futureRecurring) { r in
                                                        FutureRecurringRow(recurring: r)
                                                    }
                                                    ForEach(stat.futureLoans) { l in
                                                        FutureLoanRow(loan: l)
                                                    }
                                                }
                                            }
                                            .padding(.horizontal, 16)
                                            .padding(.bottom, 16)
                                            .padding(.leading, 12)
                                        }
                                    }
                                    
                                    if stat.id != categoryStats.last?.id {
                                        Divider()
                                            .background(Color.gray.opacity(0.2))
                                            .padding(.horizontal)
                                    }
                                }
                            }
                            .background(Color.darkCard)
                            .cornerRadius(20)
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
            .refreshable {
                await reloadData()
            }
            .navigationTitle("Fingo")
            .background(Color.black.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingAddTransaction.toggle() }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(Color.indigoColor)
                    }
                }
            }
            .sheet(isPresented: $showingAddTransaction, onDismiss: {
                transactionToEdit = nil
            }) {
                AddTransactionSheet(transactionToEdit: transactionToEdit)
            }
            .sheet(item: $exportItem) { item in
                ShareSheet(activityItems: [item.url])
            }
            .alert("Smazat transakci?", isPresented: Binding(
                get: { transactionToDelete != nil },
                set: { if !$0 { transactionToDelete = nil } }
            )) {
                Button("Zrušit", role: .cancel) {}
                Button("Smazat", role: .destructive) {
                    if let t = transactionToDelete {
                        deleteTransaction(t)
                    }
                }
            } message: {
                Text("Opravdu chcete smazat tuto transakci? Tato akce je nevratná.")
            }
        }
    }
    
    private func reloadData() async {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                FingoDataManager.shared.reloadDatabase {
                    continuation.resume()
                }
            }
        }
    }
    
    private func deleteTransaction(_ transaction: FingoTransaction) {
        FingoDataManager.shared.database.transactions.removeAll { $0.id == transaction.id }
        FingoDataManager.shared.saveDatabase()
    }
    
    @MainActor
    private func generatePDF() {
        let title = formatMonthYear(selectedMonth)
        let reportView = DashboardReportView(
            selectedMonth: selectedMonth,
            netBalance: netBalance,
            totalIncomes: totalIncomes,
            totalExpenses: totalExpenses,
            upcomingRecurringExpenses: upcomingRecurringExpenses,
            upcomingLoans: upcomingLoans,
            expectedEndOfMonthBalance: expectedEndOfMonthBalance,
            transactions: transactions,
            recurring: recurring,
            loans: loans,
            categoryStats: categoryStats,
            titleString: title
        )
        
        let fileName = "Fingo_Report_\(title.replacingOccurrences(of: " ", with: "_")).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        let controller = UIHostingController(rootView: reportView)
        guard let view = controller.view else { return }
        
        let targetSize = controller.sizeThatFits(in: CGSize(width: 800, height: UIView.layoutFittingCompressedSize.height))
        view.bounds = CGRect(origin: .zero, size: targetSize)
        view.backgroundColor = .white
        
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: targetSize))
        do {
            try renderer.writePDF(to: url) { context in
                context.beginPage()
                view.layer.render(in: context.cgContext)
            }
            self.exportItem = ExportItem(url: url)
        } catch {
            print("Chyba při generování PDF: \(error)")
        }
    }
    
    private func generateCSV() {
        let calendar = Calendar.current
        let monthTransactions = transactions.filter { calendar.isDate($0.date, equalTo: selectedMonth, toGranularity: .month) }.sorted(by: { $0.date > $1.date })
        
        var csvString = "Datum,Typ,Castka (Kc),Kategorie,Poznamka\n"
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd.MM.yyyy"
        
        for t in monthTransactions {
            let dateStr = dateFormatter.string(from: t.date)
            let typeStr = t.type == "income" ? "Prijem" : "Vydaj"
            let amountStr = String(format: "%.2f", t.amount).replacingOccurrences(of: ".", with: ",")
            let catStr = t.category?.name ?? "Bez kategorie"
            let notesStr = t.notes.contains(",") ? "\"\(t.notes)\"" : t.notes
            
            csvString += "\(dateStr),\(typeStr),\(amountStr),\(catStr),\(notesStr)\n"
        }
        
        let title = formatMonthYear(selectedMonth)
        let fileName = "Fingo_Export_\(title.replacingOccurrences(of: " ", with: "_")).csv"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try csvString.write(to: tempURL, atomically: true, encoding: .utf8)
            self.exportItem = ExportItem(url: tempURL)
        } catch {
            print("Chyba při generování CSV: \(error)")
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct DashboardReportView: View {
    let selectedMonth: Date
    let netBalance: Double
    let totalIncomes: Double
    let totalExpenses: Double
    let upcomingRecurringExpenses: Double
    let upcomingLoans: Double
    let expectedEndOfMonthBalance: Double
    let transactions: [FingoTransaction]
    let recurring: [FingoRecurring]
    let loans: [FingoLoan]
    let categoryStats: [DashboardView.CategoryStatItem]
    let titleString: String
    
    var body: some View {
        VStack(spacing: 24) {
            Text("Finanční report - \(titleString)")
                .font(.system(size: 32, weight: .black))
                .foregroundColor(.black)
                .padding(.top, 20)
                
            NetBalanceCard(balance: netBalance)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ReportMiniStatCard(title: "Příjmy", amount: totalIncomes, color: Color.emerald, icon: "arrow.down.left.circle.fill")
                ReportMiniStatCard(title: "Výdaje", amount: totalExpenses, color: Color.roseColor, icon: "arrow.up.right.circle.fill")
                ReportMiniStatCard(title: "Trvalé platby před splatností", amount: upcomingRecurringExpenses, color: Color.orange, icon: "calendar.badge.clock")
                ReportMiniStatCard(title: "Úvěry a hypotéky před splatností", amount: upcomingLoans, color: Color.indigoColor, icon: "building.columns.fill")
            }
            
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Očekávaný zůstatek (konec měsíce)")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.gray)
                        Text(fingoFormatCurrency(expectedEndOfMonthBalance))
                            .font(.system(size: 24, weight: .black))
                            .foregroundColor(.black)
                    }
                    Spacer()
                }
                
                BalanceHistoryChart(transactions: transactions, recurring: recurring, loans: loans, selectedMonth: selectedMonth)
                    .frame(height: 250)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
            }
            Spacer()
        }
        .padding(40)
        .frame(width: 800)
        .background(Color.white)
        .environment(\.colorScheme, .light)
    }
}
struct ReportMiniStatCard: View {
    let title: String
    let amount: Double
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.system(size: 16))
                    .padding(.top, 2)
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.gray)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(fingoFormatCurrency(amount))
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.black)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
    }
}

struct NetBalanceCard: View {
    let balance: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("AKTUÁLNÍ ČISTÝ ZŮSTATEK")
                .font(.system(size: 10, weight: .black))
                .foregroundColor(.white.opacity(0.6))
                .tracking(1.5)
            
            Text(fingoFormatCurrency(balance))
                .font(.system(size: 36, weight: .black))
                .foregroundColor(.white)
                .tracking(-0.5)
            
            HStack {
                Image(systemName: "checkmark.shield.fill")
                Text("Všechna data jsou uložena v iCloudu")
            }
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.white.opacity(0.8))
            .padding(.top, 10)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(LinearGradient(colors: [Color.indigoColor.opacity(0.8), Color.purple.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(
                    Image(systemName: "banknote.fill")
                        .font(.system(size: 140))
                        .foregroundColor(.white.opacity(0.06))
                        .offset(x: 100, y: 30)
                )
        )
        .shadow(color: Color.indigoColor.opacity(0.3), radius: 15, x: 0, y: 10)
    }
}

struct MiniStatCard: View {
    let title: String
    let amount: Double
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.system(size: 14))
                    .padding(.top, 2)
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.gray)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(fingoFormatCurrency(amount))
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.darkCard)
        .cornerRadius(18)
    }
}

struct BalanceHistoryChart: View {
    let transactions: [FingoTransaction]
    let recurring: [FingoRecurring]
    let loans: [FingoLoan]
    let selectedMonth: Date
    
    struct ChartDataPoint: Identifiable {
        var id: String { date.description }
        let date: Date
        let balance: Double
    }
    
    var chartPoints: [ChartDataPoint] {
        let calendar = Calendar.current
        let now = Date()
        
        guard let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedMonth)),
              let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth) else {
            return []
        }
        
        let pastTransactions = transactions.filter { $0.date < startOfMonth }
        let startBalance = pastTransactions.reduce(0.0) { result, t in
            result + (t.type == "income" ? t.amount : -t.amount)
        }
        
        var points: [ChartDataPoint] = []
        points.append(ChartDataPoint(date: startOfMonth, balance: startBalance))
        
        var currentBalance = startBalance
        let daysInMonth = calendar.component(.day, from: endOfMonth)
        
        let isPastMonth = startOfMonth < calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        let isFutureMonth = startOfMonth > calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        let currentDay = calendar.component(.day, from: now)
        
        for day in 1...daysInMonth {
            guard let date = calendar.date(byAdding: .day, value: day - 1, to: startOfMonth) else { continue }
            
            var dayNet = 0.0
            
            let isPastDay: Bool
            if isPastMonth {
                isPastDay = true
            } else if isFutureMonth {
                isPastDay = false
            } else {
                isPastDay = day <= currentDay
            }
            
            if isPastDay {
                let dayTransactions = transactions.filter { calendar.isDate($0.date, inSameDayAs: date) }
                dayNet += dayTransactions.reduce(0.0) { $0 + ($1.type == "income" ? $1.amount : -$1.amount) }
            } else {
                let futureTransactions = transactions.filter { calendar.isDate($0.date, inSameDayAs: date) }
                dayNet += futureTransactions.reduce(0.0) { $0 + ($1.type == "income" ? $1.amount : -$1.amount) }
                
                let futureRecurring = recurring.filter { 
                    calendar.component(.month, from: $0.nextDueDate) == calendar.component(.month, from: selectedMonth) &&
                    calendar.component(.year, from: $0.nextDueDate) == calendar.component(.year, from: selectedMonth) &&
                    calendar.component(.day, from: $0.nextDueDate) == day
                }
                dayNet += futureRecurring.reduce(0.0) { $0 + ($1.type == "income" ? $1.amount : -$1.amount) }
                
                let futureLoans = loans.filter { loan in
                    if let loanDay = Int(loan.startDate) {
                        return loanDay == day
                    }
                    return false
                }
                dayNet -= futureLoans.reduce(0.0) { $0 + $1.monthlyPayment }
            }
            
            currentBalance += dayNet
            points.append(ChartDataPoint(date: date, balance: currentBalance))
        }
        
        return points
    }
    
    var body: some View {
        Chart(chartPoints) { point in
            AreaMark(
                x: .value("Datum", point.date),
                y: .value("Zůstatek", point.balance)
            )
            .foregroundStyle(
                .linearGradient(
                    colors: [Color.indigoColor.opacity(0.3), Color.indigoColor.opacity(0.0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .interpolationMethod(.monotone)
            
            LineMark(
                x: .value("Datum", point.date),
                y: .value("Zůstatek", point.balance)
            )
            .foregroundStyle(Color.indigoColor)
            .lineStyle(StrokeStyle(lineWidth: 3))
            .interpolationMethod(.monotone)
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: 5)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(Color.gray.opacity(0.1))
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(Color.gray.opacity(0.1))
                if let balance = value.as(Double.self) {
                    AxisValueLabel("\(Int(balance)) Kč")
                }
            }
        }
    }
}

struct TransactionRow: View {
    let transaction: FingoTransaction
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(hex: transaction.category?.color ?? "#6b7280").opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: transaction.category?.icon ?? "questionmark")
                    .foregroundColor(Color(hex: transaction.category?.color ?? "#6b7280"))
                    .font(.system(size: 16))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.notes.isEmpty ? (transaction.category?.name ?? "Bez kategorie") : transaction.notes)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                Text(transaction.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Text((transaction.type == "income" ? "+" : "-") + fingoFormatCurrency(transaction.amount))
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(transaction.type == "income" ? Color.emerald : Color.roseColor)
        }
    }
}

struct FutureRecurringRow: View {
    let recurring: FingoRecurring
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: "calendar.badge.clock")
                    .foregroundColor(Color.orange)
                    .font(.system(size: 16))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(recurring.name)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                Text("Trvalá platba")
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Text("-" + fingoFormatCurrency(recurring.amount))
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Color.roseColor)
        }
    }
}

struct FutureLoanRow: View {
    let loan: FingoLoan
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.indigoColor.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: "building.columns.fill")
                    .foregroundColor(Color.indigoColor)
                    .font(.system(size: 16))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(loan.name)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                Text("Úvěr / Hypotéka")
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Text("-" + fingoFormatCurrency(loan.monthlyPayment))
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Color.roseColor)
        }
    }
}

struct AddTransactionSheet: View {
    @Environment(\.dismiss) var dismiss
    var transactionToEdit: FingoTransaction? = nil
    
    var categories: [FingoCategory] {
        FingoDataManager.shared.database.categories
    }
    
    @State private var type = "expense"
    @State private var amountString = ""
    @State private var date = Date()
    @State private var selectedCategory: FingoCategory?
    @State private var notes = ""
    @State private var showingAddCategory = false
    
    @FocusState private var isAmountFocused: Bool
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 16) {
                        Picker("Typ", selection: $type) {
                            Text("Výdaj").tag("expense")
                            Text("Příjem").tag("income")
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                        
                        HStack(alignment: .lastTextBaseline, spacing: 8) {
                            TextField("0", text: $amountString)
                                .keyboardType(.decimalPad)
                                .focused($isAmountFocused)
                                .font(.system(size: 60, weight: .black))
                                .multilineTextAlignment(.center)
                                .foregroundColor(type == "income" ? .emerald : .roseColor)
                            Text("Kč")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 10)
                    }
                    .padding(.top, 20)
                    
                    VStack(spacing: 0) {
                        HStack {
                            Text("Kategorie")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.gray)
                            Spacer()
                            Menu {
                                ForEach(categories) { category in
                                    Button(action: { selectedCategory = category }) {
                                        Label(category.name, systemImage: category.icon)
                                    }
                                }
                            } label: {
                                if let cat = selectedCategory {
                                    HStack {
                                        Image(systemName: cat.icon)
                                        Text(cat.name)
                                    }
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(Color(hex: cat.color))
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 16)
                                    .background(Color(hex: cat.color).opacity(0.15))
                                    .cornerRadius(12)
                                } else {
                                    Text("Vybrat")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.indigoColor)
                                }
                            }
                            
                            Button(action: { showingAddCategory = true }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.indigoColor)
                            }
                            .padding(.leading, 8)
                        }
                        .padding()
                        
                        Divider().background(Color.gray.opacity(0.2)).padding(.horizontal)
                        
                        DatePicker("Datum", selection: $date, displayedComponents: .date)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.gray)
                            .colorScheme(.dark)
                            .padding()
                        
                        Divider().background(Color.gray.opacity(0.2)).padding(.horizontal)
                        
                        TextField("Poznámka / Popis", text: $notes)
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                            .padding()
                    }
                    .background(Color(white: 0.08))
                    .cornerRadius(20)
                    .padding(.horizontal)
                    
                    Spacer(minLength: 40)
                    
                    Button(action: saveTransaction) {
                        Text(transactionToEdit != nil ? "Uložit změny" : "Uložit transakci")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(amountString.isEmpty || selectedCategory == nil ? Color.gray : Color.indigoColor)
                            .cornerRadius(20)
                            .shadow(color: (amountString.isEmpty || selectedCategory == nil ? Color.clear : Color.indigoColor.opacity(0.4)), radius: 10, x: 0, y: 5)
                    }
                    .disabled(amountString.isEmpty || selectedCategory == nil)
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle(transactionToEdit != nil ? "Upravit transakci" : "Nová transakce")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Zrušit") { dismiss() }.foregroundColor(.gray)
                }
            }
            .sheet(isPresented: $showingAddCategory) {
                AddCategorySheet()
            }
            .onAppear {
                if let transaction = transactionToEdit {
                    self.type = transaction.type
                    let amountVal = transaction.amount
                    self.amountString = amountVal.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", amountVal) : String(amountVal)
                    self.date = transaction.date
                    self.selectedCategory = categories.first { $0.id == transaction.categoryId }
                    self.notes = transaction.notes
                } else if selectedCategory == nil {
                    selectedCategory = categories.first
                }
                // Automatically focus the amount text field to show the numeric keyboard
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isAmountFocused = true
                }
            }
            .colorScheme(.dark)
        }
    }
    
    private func saveTransaction() {
        guard let amount = Double(amountString.replacingOccurrences(of: ",", with: ".")),
              let category = selectedCategory else { return }
        
        if let transaction = transactionToEdit {
            if let index = FingoDataManager.shared.database.transactions.firstIndex(where: { $0.id == transaction.id }) {
                FingoDataManager.shared.database.transactions[index].type = type
                FingoDataManager.shared.database.transactions[index].amount = amount
                FingoDataManager.shared.database.transactions[index].date = date
                FingoDataManager.shared.database.transactions[index].notes = notes
                FingoDataManager.shared.database.transactions[index].categoryId = category.id
            }
        } else {
            let newTransaction = FingoTransaction(
                type: type,
                amount: amount,
                date: date,
                notes: notes,
                categoryId: category.id
            )
            FingoDataManager.shared.database.transactions.append(newTransaction)
        }
        FingoDataManager.shared.saveDatabase()
        dismiss()
    }
}

struct DashboardBudgetsGoalsView: View {
    let budgets: [FingoBudget]
    let goals: [FingoGoal]
    let transactions: [FingoTransaction]
    
    var body: some View {
        VStack(spacing: 16) {
            if !budgets.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("AKTIVNÍ ROZPOČTY")
                        .font(.system(size: 11, weight: .black))
                        .foregroundColor(.gray)
                        .tracking(1)
                        .padding(.horizontal)
                    
                    VStack(spacing: 10) {
                        ForEach(budgets) { budget in
                            let spent = transactions.filter { $0.type == "expense" && $0.categoryId == budget.categoryId && Calendar.current.isDate($0.date, equalTo: Date(), toGranularity: .month) }.reduce(0.0) { $0 + $1.amount }
                            let progress = min(1.0, spent / max(1.0, budget.amount))
                            let cat = FingoDataManager.shared.category(for: budget.categoryId)
                            
                            HStack(spacing: 14) {
                                ZStack {
                                    Circle()
                                        .fill(Color(hex: cat?.color ?? "#94a3b8").opacity(0.15))
                                        .frame(width: 40, height: 40)
                                    Image(systemName: cat?.icon ?? "tag.fill")
                                        .foregroundColor(Color(hex: cat?.color ?? "#94a3b8"))
                                        .font(.system(size: 18))
                                }
                                
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(cat?.name ?? "Neznámá")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(.white)
                                        Spacer()
                                        Text("\(fingoFormatCurrency(spent)) z \(fingoFormatCurrency(budget.amount))")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(.gray)
                                    }
                                    
                                    GeometryReader { geo in
                                        ZStack(alignment: .leading) {
                                            Capsule()
                                                .fill(Color.white.opacity(0.1))
                                            Capsule()
                                                .fill(progress > 0.9 ? Color.roseColor : (progress > 0.7 ? Color.orange : Color.emerald))
                                                .frame(width: max(0, geo.size.width * CGFloat(progress)))
                                        }
                                    }
                                    .frame(height: 8)
                                }
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 16)
                            .background(Color.darkCard)
                            .cornerRadius(16)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            
            if !goals.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("SPOŘICÍ CÍLE")
                        .font(.system(size: 11, weight: .black))
                        .foregroundColor(.gray)
                        .tracking(1)
                        .padding(.horizontal)
                        .padding(.top, 4)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(goals) { goal in
                                let progress = min(1.0, goal.currentAmount / max(1.0, goal.targetAmount))
                                
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Image(systemName: goal.icon)
                                            .foregroundColor(.indigoColor)
                                        Text(goal.name)
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(.white)
                                            .lineLimit(1)
                                    }
                                    
                                    GeometryReader { geo in
                                        ZStack(alignment: .leading) {
                                            Capsule()
                                                .fill(Color.white.opacity(0.1))
                                            Capsule()
                                                .fill(Color.indigoColor)
                                                .frame(width: max(0, geo.size.width * CGFloat(progress)))
                                        }
                                    }
                                    .frame(height: 6)
                                    
                                    HStack {
                                        Text(fingoFormatCurrency(goal.currentAmount))
                                            .foregroundColor(.white)
                                        Spacer()
                                        Text(String(format: "%.0f %%", progress * 100))
                                            .foregroundColor(.indigoColor)
                                    }
                                    .font(.system(size: 10, weight: .bold))
                                }
                                .padding(12)
                                .frame(width: 160)
                                .background(Color.darkCard)
                                .cornerRadius(16)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
    }
}

extension Color {
    static let emerald = Color(red: 16/255, green: 185/255, blue: 129/255)
    static let roseColor = Color(red: 244/255, green: 63/255, blue: 94/255)
    static let indigoColor = Color(red: 99/255, green: 102/255, blue: 241/255)
    static let darkCard = Color(white: 0.08)
}

struct SwipeActionRow<Content: View>: View {
    let content: Content
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    @State private var offset: CGFloat = 0
    @State private var isSwiped = false
    
    init(onEdit: @escaping () -> Void, onDelete: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.onEdit = onEdit
        self.onDelete = onDelete
    }
    
    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let buttonsWidth: CGFloat = 88 // 40 + 8 + 40
            
            HStack(spacing: 0) {
                content
                    .frame(width: width, alignment: .leading)
                    .contentShape(Rectangle())
                
                // Action Buttons (positioned off-screen behind the right edge)
                HStack(spacing: 8) {
                    Button(action: {
                        withAnimation(.spring()) {
                            offset = 0
                            isSwiped = false
                        }
                        onEdit()
                    }) {
                        Image(systemName: "pencil")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(Color.indigoColor)
                            .cornerRadius(8)
                    }
                    
                    Button(action: {
                        withAnimation(.spring()) {
                            offset = 0
                            isSwiped = false
                        }
                        onDelete()
                    }) {
                        Image(systemName: "trash")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(Color.roseColor)
                            .cornerRadius(8)
                    }
                }
                .frame(width: buttonsWidth, alignment: .trailing)
                .padding(.leading, 8)
            }
            .frame(width: width + buttonsWidth + 8, height: geo.size.height, alignment: .leading)
            .offset(x: offset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let dragAmount = value.translation.width
                        if dragAmount < 0 {
                            // Swiping left
                            offset = dragAmount + (isSwiped ? -96 : 0)
                            if offset < -110 {
                                offset = -110
                            }
                        } else {
                            // Swiping right
                            offset = dragAmount + (isSwiped ? -96 : 0)
                            if offset > 0 {
                                offset = 0
                            }
                        }
                    }
                    .onEnded { value in
                        withAnimation(.spring()) {
                            if value.translation.width < -30 {
                                offset = -96
                                isSwiped = true
                            } else {
                                offset = 0
                                isSwiped = false
                            }
                        }
                    }
            )
        }
        .frame(height: 48)
        .clipped()
    }
}
