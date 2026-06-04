import re

with open("/Users/stepankutlak/Library/Mobile Documents/com~apple~CloudDocs/dokumenty/webové aplikace/FingoiOS/DashboardView.swift", "r") as f:
    content = f.read()

# 1. Add recurring and state
content = content.replace(
    "@Query private var loans: [FingoLoan]",
    "@Query private var loans: [FingoLoan]\n    @Query private var recurring: [FingoRecurring]\n    \n    enum CategorySortType: String, CaseIterable {\n        case sum = \"Suma\"\n        case date = \"Datum\"\n        case category = \"Kategorie\"\n    }\n    @State private var categorySort: CategorySortType = .sum"
)

# 2. Add futureExpenses
content = content.replace(
    "var totalDebt: Double {\n        loans.filter { $0.remainingAmount > 0 }.reduce(0.0) { $0 + $1.remainingAmount }\n    }",
    "var totalDebt: Double {\n        loans.filter { $0.remainingAmount > 0 }.reduce(0.0) { $0 + $1.remainingAmount }\n    }\n    \n    var futureExpenses: Double {\n        let futureT = transactions.filter { $0.type == \"expense\" && $0.date > Date() }.reduce(0.0) { $0 + $1.amount }\n        let recT = recurring.filter { $0.type == \"expense\" }.reduce(0.0) { $0 + $1.amount }\n        return futureT + recT\n    }"
)

# 3. Replace MiniStatCards HStack with LazyVGrid
old_stats = """                    // Rychlé statistiky
                    HStack(spacing: 10) {
                        MiniStatCard(title: "Příjmy", amount: totalIncomes, color: Color.emerald, icon: "arrow.down.left.circle.fill")
                        MiniStatCard(title: "Výdaje", amount: totalExpenses, color: Color.roseColor, icon: "arrow.up.right.circle.fill")
                        MiniStatCard(title: "Dluhy", amount: totalDebt, color: Color.indigoColor, icon: "landmark.fill")
                    }
                    .padding(.horizontal)"""

new_stats = """                    // Rychlé statistiky
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        MiniStatCard(title: "Příjmy", amount: totalIncomes, color: Color.emerald, icon: "arrow.down.left.circle.fill")
                        MiniStatCard(title: "Výdaje", amount: totalExpenses, color: Color.roseColor, icon: "arrow.up.right.circle.fill")
                        MiniStatCard(title: "Budoucí výdaje", amount: futureExpenses, color: Color.orange, icon: "calendar.badge.clock")
                        MiniStatCard(title: "Dluhy", amount: totalDebt, color: Color.indigoColor, icon: "landmark.fill")
                    }
                    .padding(.horizontal)"""

content = content.replace(old_stats, new_stats)

# 4. Update the chart header
old_chart_header = """                            Text("Vývoj čistého jmění")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.gray)
                                .padding(.horizontal)"""

new_chart_header = """                            HStack {
                                VStack(alignment: .leading) {
                                    Text("Zůstatek po odečtení výdajů")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.gray)
                                    Text(formatCurrency(netBalance - futureExpenses))
                                        .font(.system(size: 20, weight: .black))
                                        .foregroundColor(.white)
                                }
                                Spacer()
                            }
                            .padding(.horizontal)"""

content = content.replace(old_chart_header, new_chart_header)

# 5. Replace 'Poslední transakce' with 'Kategorie a jejich náklady'
# Find the VStack for Poslední transakce and replace it
posledni_transakce_start = content.find("// Seznam posledních transakcí")
posledni_transakce_end = content.find("}\n                .padding(.vertical)")

category_stats_code = """
    struct CategoryStatItem: Identifiable {
        let id = UUID()
        let category: FingoCategory
        let amount: Double
        let latestDate: Date?
    }

    var categoryStats: [CategoryStatItem] {
        var dict: [String: (amount: Double, latestDate: Date?)] = [:]
        for t in transactions.filter({ $0.type == "expense" }) {
            guard let catId = t.category?.id else { continue }
            let current = dict[catId] ?? (0.0, nil)
            let newAmount = current.amount + t.amount
            let newDate: Date?
            if let existingDate = current.latestDate {
                newDate = max(existingDate, t.date)
            } else {
                newDate = t.date
            }
            dict[catId] = (newAmount, newDate)
        }
        
        var items = categories.compactMap { cat -> CategoryStatItem? in
            guard let stat = dict[cat.id], stat.amount > 0 else { return nil }
            return CategoryStatItem(category: cat, amount: stat.amount, latestDate: stat.latestDate)
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
"""

# Insert categoryStats computation property before body
content = content.replace("    var body: some View {", category_stats_code + "\n    var body: some View {")

# New UI for category stats
new_category_section = """                    // Kategorie a jejich náklady
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Náklady podle kategorií")
                                .font(.system(size: 16, weight: .bold))
                            Spacer()
                            Picker("Řazení", selection: $categorySort) {
                                ForEach(CategorySortType.allCases, id: \\.self) { sortType in
                                    Text(sortType.rawValue).tag(sortType)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(Color.indigoColor)
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
                            VStack(spacing: 0) {
                                ForEach(categoryStats) { stat in
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
                                                Text("Poslední: \\(date.formatted(date: .abbreviated, time: .omitted))")
                                                    .font(.system(size: 11))
                                                    .foregroundColor(.gray)
                                            }
                                        }
                                        
                                        Spacer()
                                        
                                        Text(formatCurrency(stat.amount))
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(Color.roseColor)
                                    }
                                    .padding(.vertical, 12)
                                    .padding(.horizontal)
                                    
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
                    }"""

content = content[:posledni_transakce_start] + new_category_section + "\n" + content[posledni_transakce_end:]

with open("/Users/stepankutlak/Library/Mobile Documents/com~apple~CloudDocs/dokumenty/webové aplikace/FingoiOS/DashboardView.swift", "w") as f:
    f.write(content)

