import SwiftUI

struct TransactionsView: View {
    var allTransactions: [FingoTransaction] {
        FingoDataManager.shared.database.transactions.sorted(by: { $0.date > $1.date })
    }
    var categories: [FingoCategory] {
        FingoDataManager.shared.database.categories
    }
    
    @State private var filterType = "all" // "all", "income", "expense"
    @State private var selectedCategoryFilter: FingoCategory? = nil
    @State private var showingAddTransaction = false
    @State private var showingEditCategories = false
    @State private var transactionToEdit: FingoTransaction? = nil
    
    var filteredTransactions: [FingoTransaction] {
        allTransactions.filter { t in
            let matchesType = filterType == "all" || t.type == filterType
            let matchesCategory = selectedCategoryFilter == nil || t.category?.id == selectedCategoryFilter?.id
            return matchesType && matchesCategory
        }
    }
    
    var categorySpendings: [(category: FingoCategory, amount: Double)] {
        var spendings: [String: Double] = [:]
        let expenseTransactions = allTransactions.filter { $0.type == "expense" }
        
        for t in expenseTransactions {
            if let catId = t.category?.id {
                spendings[catId, default: 0.0] += t.amount
            }
        }
        
        return categories.map { cat in
            (category: cat, amount: spendings[cat.id, default: 0.0])
        }
        .filter { $0.amount > 0 }
        .sorted { $0.amount > $1.amount }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Filtr", selection: $filterType) {
                    Text("Vše").tag("all")
                    Text("Příjmy").tag("income")
                    Text("Výdaje").tag("expense")
                }
                .pickerStyle(.segmented)
                .padding()
                
                if filterType != "income" && !categorySpendings.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ÚTRATA PODLE KATEGORIÍ")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.gray)
                            .tracking(1.0)
                            .padding(.horizontal)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                Button(action: { selectedCategoryFilter = nil }) {
                                    Text("Všechny")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(selectedCategoryFilter == nil ? .white : .gray)
                                        .padding(.vertical, 12)
                                        .padding(.horizontal, 20)
                                        .background(selectedCategoryFilter == nil ? Color.indigoColor : Color.darkCard)
                                        .cornerRadius(16)
                                }
                                
                                ForEach(categorySpendings, id: \.category.id) { item in
                                    Button(action: {
                                        if selectedCategoryFilter?.id == item.category.id {
                                            selectedCategoryFilter = nil
                                        } else {
                                            selectedCategoryFilter = item.category
                                        }
                                    }) {
                                        HStack(spacing: 8) {
                                            Image(systemName: item.category.icon)
                                                .font(.system(size: 16))
                                            Text(item.category.name)
                                                .font(.system(size: 15, weight: .bold))
                                            Text(fingoFormatCurrency(item.amount))
                                                .font(.system(size: 14, weight: .black))
                                                .opacity(0.8)
                                        }
                                        .foregroundColor(selectedCategoryFilter?.id == item.category.id ? .white : Color(hex: item.category.color))
                                        .padding(.vertical, 12)
                                        .padding(.horizontal, 18)
                                        .background(
                                            selectedCategoryFilter?.id == item.category.id
                                            ? Color(hex: item.category.color)
                                            : Color(hex: item.category.color).opacity(0.12)
                                        )
                                        .cornerRadius(16)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(Color(hex: item.category.color).opacity(0.3), lineWidth: 1)
                                        )
                                    }
                                }
                                
                                Button(action: { showingEditCategories = true }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "pencil")
                                            .font(.system(size: 16))
                                        Text("Upravit")
                                            .font(.system(size: 15, weight: .bold))
                                    }
                                    .foregroundColor(.white)
                                    .padding(.vertical, 12)
                                    .padding(.horizontal, 18)
                                    .background(Color.white.opacity(0.15))
                                    .cornerRadius(16)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.bottom, 12)
                }
                
                List {
                    if filteredTransactions.isEmpty {
                        VStack(spacing: 12) {
                            Spacer()
                            Image(systemName: "tray.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.gray)
                            Text("Žádné odpovídající platby")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.gray)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, minHeight: 300)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    } else {
                        ForEach(filteredTransactions) { transaction in
                            TransactionRow(transaction: transaction)
                                .listRowBackground(Color.darkCard)
                                .listRowSeparatorTint(Color.gray.opacity(0.2))
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        deleteTransaction(transaction)
                                    } label: {
                                        Label("Smazat", systemImage: "trash")
                                    }
                                    
                                    Button {
                                        transactionToEdit = transaction
                                        showingAddTransaction = true
                                    } label: {
                                        Label("Upravit", systemImage: "pencil")
                                    }
                                    .tint(Color.indigoColor)
                                }
                        }
                    }
                }
                .listStyle(.plain)
                .background(Color.black)
                .refreshable {
                    await reloadData()
                }
            }
            .navigationTitle("Historie plateb")
            .background(Color.black.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingAddTransaction.toggle() }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 26))
                            .foregroundColor(Color.indigoColor)
                    }
                }
            }
            .sheet(isPresented: $showingAddTransaction, onDismiss: {
                transactionToEdit = nil
            }) {
                AddTransactionSheet(transactionToEdit: transactionToEdit)
            }
            .sheet(isPresented: $showingEditCategories) {
                CategoriesView()
            }
        }
    }
    
    private func deleteTransaction(_ transaction: FingoTransaction) {
        FingoDataManager.shared.database.transactions.removeAll { $0.id == transaction.id }
        FingoDataManager.shared.saveDatabase()
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
}
