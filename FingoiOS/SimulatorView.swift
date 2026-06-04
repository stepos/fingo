import SwiftUI
import UniformTypeIdentifiers

struct SimulatorView: View {
    var loans: [FingoLoan] {
        FingoDataManager.shared.database.loans
    }
    
    @State private var activeTab = "planning" // "planning" or "calculators"
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Zobrazení", selection: $activeTab) {
                    Text("Renta & Dluhy").tag("planning")
                    Text("Kalkulačky").tag("calculators")
                }
                .pickerStyle(.segmented)
                .padding()
                
                ScrollView {
                    if activeTab == "planning" {
                        PlanningSubView(loans: loans)
                            .padding(.horizontal)
                    } else {
                        CalculatorsSubView(loans: loans)
                            .padding(.horizontal)
                    }
                }
            }
            .navigationTitle("Simulátor svobody")
            .background(Color.black.ignoresSafeArea())
        }
    }
}

// ================= SUB-VIEW 1: RENTA & DLUHY (FIRE) =================
struct PlanningSubView: View {
    let loans: [FingoLoan]
    
    @State private var fireExpenses = 50000.0
    @State private var fireSavings = 500000.0
    @State private var fireMonthly = 10000.0
    @State private var fireYield = 7.0
    
    var fireTargetPortfolio: Double {
        fireExpenses * 12.0 / 0.04
    }
    
    var fireProgressPct: Double {
        guard fireTargetPortfolio > 0 else { return 0 }
        return min(100.0, (fireSavings / fireTargetPortfolio) * 100.0)
    }
    
    var monthsToFIRE: Double {
        let target = fireTargetPortfolio
        let monthly = fireMonthly
        let monthlyRate = (fireYield / 100.0) / 12.0
        
        var current = fireSavings
        var months = 0.0
        
        if current >= target { return 0 }
        if monthly <= 0 && monthlyRate <= 0 { return Double.infinity }
        
        while current < target && months < 1200 {
            months += 1
            current = current * (1 + monthlyRate)
            current += monthly
        }
        
        return months
    }
    
    var fireTimeText: String {
        let m = monthsToFIRE
        if m == Double.infinity {
            return "Nedosažitelné"
        }
        if m == 0 {
            return "Již dosaženo!"
        }
        let totalMonths = Int(m)
        let y = totalMonths / 12
        let remMonths = totalMonths % 12
        
        var parts: [String] = []
        if y > 0 {
            parts.append("\(y) \(y == 1 ? "rok" : (y >= 2 && y <= 4 ? "roky" : "let"))")
        }
        if remMonths > 0 || parts.isEmpty {
            parts.append("\(remMonths) \(remMonths == 1 ? "měsíc" : (remMonths >= 2 && remMonths <= 4 ? "měsíce" : "měsíců"))")
        }
        return parts.joined(separator: " a ")
    }
    
    var body: some View {
        VStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(LinearGradient(colors: [Color.orange, Color.red], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 40, height: 40)
                        Image(systemName: "flame.fill")
                            .foregroundColor(.white)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Kalkulačka nezávislosti (FIRE)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                        Text("Kdy budete moci přestat pracovat?")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                    }
                }
                
                VStack(spacing: 16) {
                    SliderRow(title: "Cílové výdaje v rentě", value: $fireExpenses, range: 10000...250000, step: 5000, suffix: "Kč")
                    SliderRow(title: "Zainvestované úspory", value: $fireSavings, range: 0...10000000, step: 50000, suffix: "Kč")
                    SliderRow(title: "Měsíční investice", value: $fireMonthly, range: 0...150000, step: 2000, suffix: "Kč")
                    SliderRow(title: "Roční výnos portfolia", value: $fireYield, range: 0...20, step: 0.5, suffix: "%")
                }
                
                VStack(spacing: 12) {
                    HStack {
                        Text("Potřebné portfolio (4% pravidlo):")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.gray)
                        Spacer()
                        Text(fingoFormatCurrency(fireTargetPortfolio))
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    Divider().background(Color.white.opacity(0.1))
                    
                    VStack(spacing: 4) {
                        Text("RENTY DOSÁHNETE ZA")
                            .font(.system(size: 9, weight: .black))
                            .foregroundColor(.gray)
                        Text(fireTimeText)
                            .font(.system(size: 20, weight: .black))
                            .foregroundColor(.orange)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    
                    VStack(spacing: 6) {
                        HStack {
                            Text("Pokrok k rentě")
                            Spacer()
                            Text(String(format: "%.1f %%", fireProgressPct))
                        }
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.gray)
                        
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.white.opacity(0.1))
                                Capsule().fill(LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing))
                                    .frame(width: geo.size.width * CGFloat(fireProgressPct / 100.0))
                            }
                        }
                        .frame(height: 6)
                    }
                }
                .padding(16)
                .background(Color.black.opacity(0.4))
                .cornerRadius(18)
            }
            .padding(18)
            .background(Color.darkCard)
            .cornerRadius(22)
            
            Spacer().frame(height: 20)
        }
    }
}

// ================= SUB-VIEW 2: KALKULAČKY =================
struct CalculatorsSubView: View {
    let loans: [FingoLoan]
    
    @State private var calculatorSelection = "consolidation"
    
    var body: some View {
        VStack(spacing: 20) {
            Picker("Kalkulačka", selection: $calculatorSelection) {
                Text("Složené úročení").tag("compound")
                Text("Úvěry").tag("simple_loan")
                Text("Konsolidace").tag("consolidation")
            }
            .pickerStyle(.segmented)
            .padding(.bottom, 10)
            
            if calculatorSelection == "compound" {
                CompoundInterestCalculatorView()
            } else if calculatorSelection == "simple_loan" {
                SimpleLoanCalculatorView()
            } else {
                ConsolidationCalculatorView(loans: loans)
            }
        }
    }
}

struct CompoundInterestCalculatorView: View {
    @State private var initialDeposit = 100000.0
    @State private var monthlyContribution = 5000.0
    @State private var years = 20.0
    @State private var interestRate = 8.0
    
    var totalDeposited: Double {
        initialDeposit + (monthlyContribution * 12.0 * years)
    }
    
    var futureValue: Double {
        let monthlyRate = (interestRate / 100.0) / 12.0
        let months = years * 12.0
        
        var total = initialDeposit
        guard months > 0 else { return initialDeposit }
        
        for _ in 0..<Int(months) {
            total = total * (1 + monthlyRate)
            total += monthlyContribution
        }
        return total
    }
    
    var earnedInterest: Double {
        max(0.0, futureValue - totalDeposited)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(LinearGradient(colors: [Color.emerald, Color.teal], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 40, height: 40)
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .foregroundColor(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Složené úročení")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                    Text("Jak porostou Vaše investice v čase?")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                }
            }
            
            VStack(spacing: 16) {
                SliderRow(title: "Počáteční vklad", value: $initialDeposit, range: 0...5000000, step: 10000, suffix: "Kč")
                SliderRow(title: "Měsíční příspěvek", value: $monthlyContribution, range: 0...100000, step: 1000, suffix: "Kč")
                SliderRow(title: "Doba investování", value: $years, range: 1...50, step: 1, suffix: "let")
                SliderRow(title: "Roční zhodnocení", value: $interestRate, range: 0.1...20, step: 0.1, suffix: "%")
            }
            
            VStack(spacing: 12) {
                VStack(spacing: 4) {
                    Text("BUDOUCÍ HODNOTA CELKEM")
                        .font(.system(size: 9, weight: .black))
                        .foregroundColor(.gray)
                    Text(fingoFormatCurrency(futureValue))
                        .font(.system(size: 24, weight: .black))
                        .foregroundColor(Color.emerald)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                
                Divider().background(Color.white.opacity(0.1))
                
                HStack {
                    VStack(alignment: .leading) {
                        Text("Vložené prostředky:")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                        Text(fingoFormatCurrency(totalDeposited))
                            .font(.system(size: 13, weight: .bold))
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("Získané úroky:")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                        Text(fingoFormatCurrency(earnedInterest))
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Color.emerald)
                    }
                }
            }
            .padding(16)
            .background(Color.black.opacity(0.4))
            .cornerRadius(18)
        }
        .padding(18)
        .background(Color.darkCard)
        .cornerRadius(22)
    }
}

struct SimpleLoanCalculatorView: View {
    @State private var amount = 1000000.0
    @State private var interestRate = 5.0
    @State private var years = 20.0
    
    var monthlyAnnuity: Double {
        let monthlyRate = (interestRate / 100.0) / 12.0
        let months = years * 12.0
        
        guard amount > 0 else { return 0 }
        guard monthlyRate > 0 else { return amount / months }
        
        return amount * monthlyRate * pow(1 + monthlyRate, months) / (pow(1 + monthlyRate, months) - 1)
    }
    
    var totalPaid: Double {
        monthlyAnnuity * (years * 12.0)
    }
    
    var totalInterestPaid: Double {
        max(0.0, totalPaid - amount)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(LinearGradient(colors: [Color.indigoColor, Color.purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 40, height: 40)
                    Image(systemName: "percent")
                        .foregroundColor(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Úvěrová kalkulačka")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                    Text("Spočtěte si měsíční splátku anuitního úvěru")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                }
            }
            
            VStack(spacing: 16) {
                SliderRow(title: "Výše úvěru", value: $amount, range: 100000...20000000, step: 100000, suffix: "Kč")
                SliderRow(title: "Úroková sazba", value: $interestRate, range: 0.1...25, step: 0.1, suffix: "% p.a.")
                SliderRow(title: "Doba splácení", value: $years, range: 1...40, step: 1, suffix: "let")
            }
            
            VStack(spacing: 12) {
                VStack(spacing: 4) {
                    Text("MĚSÍČNÍ ANUITNÍ SPLÁTKA")
                        .font(.system(size: 9, weight: .black))
                        .foregroundColor(.gray)
                    Text(fingoFormatCurrency(monthlyAnnuity))
                        .font(.system(size: 24, weight: .black))
                        .foregroundColor(Color.indigoColor)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                
                Divider().background(Color.white.opacity(0.1))
                
                HStack {
                    VStack(alignment: .leading) {
                        Text("Celková jistina:")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                        Text(fingoFormatCurrency(amount))
                            .font(.system(size: 13, weight: .bold))
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("Přeplatek na úrocích:")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                        Text(fingoFormatCurrency(totalInterestPaid))
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Color.roseColor)
                    }
                }
            }
            .padding(16)
            .background(Color.black.opacity(0.4))
            .cornerRadius(18)
        }
        .padding(18)
        .background(Color.darkCard)
        .cornerRadius(22)
    }
}

struct ConsolidationCalculatorView: View {
    let loans: [FingoLoan]
    
    @State private var selectedLoanIds = Set<String>()
    @State private var extraCash = 0.0
    @State private var newRate = 5.5
    @State private var newYears = 10.0
    
    var totalRemainingOriginal: Double {
        loans.filter { selectedLoanIds.contains($0.id) }
             .reduce(0.0) { $0 + $1.remainingAmount }
    }
    
    var totalOriginalMonthlyPayment: Double {
        loans.filter { selectedLoanIds.contains($0.id) }
             .reduce(0.0) { $0 + $1.monthlyPayment }
    }
    
    var totalOriginalRemainingPayout: Double {
        loans.filter { selectedLoanIds.contains($0.id) }
             .reduce(0.0) { sum, loan in
                 let calendar = Calendar.current
                 let components = calendar.dateComponents([.month], from: Date(), to: loan.endDate)
                 let remainingMonths = max(0, components.month ?? 0)
                 return sum + (loan.monthlyPayment * Double(remainingMonths))
             }
    }
    
    var newConsolidatedLoanAmount: Double {
        totalRemainingOriginal + extraCash
    }
    
    var newConsolidatedMonthlyPayment: Double {
        let amount = newConsolidatedLoanAmount
        let rate = (newRate / 100.0) / 12.0
        let months = newYears * 12.0
        
        guard amount > 0 else { return 0 }
        guard rate > 0 else { return amount / months }
        
        return amount * rate * pow(1 + rate, months) / (pow(1 + rate, months) - 1)
    }
    
    var newTotalPaid: Double {
        newConsolidatedMonthlyPayment * (newYears * 12.0)
    }
    
    var monthlySavings: Double {
        totalOriginalMonthlyPayment - newConsolidatedMonthlyPayment
    }
    
    var totalSavings: Double {
        (totalOriginalRemainingPayout + extraCash) - newTotalPaid
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(LinearGradient(colors: [Color.purple, Color.indigoColor], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 40, height: 40)
                    Image(systemName: "square.fill.on.square.fill")
                        .foregroundColor(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Konsolidační kalkulačka")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                    Text("Sloučení stávajících úvěrů z Vaší evidence")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("VYBERTE ÚVĚRY KE KONSOLIDACI:")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.gray)
                
                if loans.isEmpty {
                    Text("Nemáte žádné aktivní úvěry k výběru")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                        .padding(.vertical, 8)
                } else {
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(loans) { loan in
                                Button(action: {
                                    if selectedLoanIds.contains(loan.id) {
                                        selectedLoanIds.remove(loan.id)
                                    } else {
                                        selectedLoanIds.insert(loan.id)
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: selectedLoanIds.contains(loan.id) ? "checkmark.square.fill" : "square")
                                            .foregroundColor(selectedLoanIds.contains(loan.id) ? Color.indigoColor : .gray)
                                            .font(.system(size: 18))
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(loan.name)
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundColor(.white)
                                            Text(String(format: "%.2f %% p.a. • %@/měs", loan.interestRate, fingoFormatCurrency(loan.monthlyPayment)))
                                                .font(.system(size: 9))
                                                .foregroundColor(.gray)
                                        }
                                        Spacer()
                                        Text(fingoFormatCurrency(loan.remainingAmount))
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 12)
                                    .background(Color.black.opacity(0.2))
                                    .cornerRadius(12)
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 140)
                }
            }
            
            VStack(spacing: 16) {
                SliderRow(title: "Peníze navíc", value: $extraCash, range: 0...2000000, step: 10000, suffix: "Kč")
                SliderRow(title: "Nová úroková sazba", value: $newRate, range: 0.1...25, step: 0.1, suffix: "% p.a.")
                SliderRow(title: "Nová doba splácení", value: $newYears, range: 1...30, step: 1, suffix: "let")
            }
            
            VStack(spacing: 14) {
                VStack(spacing: 4) {
                    Text("NOVÁ MĚSÍČNÍ SPLÁTKA ANUITNÍ")
                        .font(.system(size: 9, weight: .black))
                        .foregroundColor(.gray)
                    Text(fingoFormatCurrency(newConsolidatedMonthlyPayment))
                        .font(.system(size: 26, weight: .black))
                        .foregroundColor(Color.indigoColor)
                }
                .frame(maxWidth: .infinity)
                
                Divider().background(Color.white.opacity(0.1))
                
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Úspora na splátce")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                        
                        let label = formatSavingsLabel(monthlySavings)
                        Text(label.text)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(label.color)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Celková úspora")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                        
                        let label = formatSavingsLabel(totalSavings)
                        Text(label.text)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(label.color)
                    }
                }
                
                Divider().background(Color.white.opacity(0.1))
                
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Nová jistina:")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                        Text(fingoFormatCurrency(newConsolidatedLoanAmount))
                            .font(.system(size: 11, weight: .bold))
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Nová celková částka:")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                        Text(fingoFormatCurrency(newTotalPaid))
                            .font(.system(size: 11, weight: .bold))
                    }
                }
            }
            .padding(16)
            .background(Color.black.opacity(0.4))
            .cornerRadius(18)
        }
        .padding(18)
        .background(Color.darkCard)
        .cornerRadius(22)
        .onAppear {
            if selectedLoanIds.isEmpty {
                selectedLoanIds = Set(loans.map { $0.id })
            }
        }
    }
    
    private func formatSavingsLabel(_ value: Double) -> (text: String, color: Color) {
        if selectedLoanIds.isEmpty && extraCash == 0 {
            return ("0 Kč", .gray)
        }
        if value >= 0 {
            return ("+" + fingoFormatCurrency(value), Color.emerald)
        } else {
            return ("-" + fingoFormatCurrency(abs(value)), Color.roseColor)
        }
    }
}

// =========================================================================
// =================== IMPLEMENTACE CATEGORIESVIEW.SWIFT ===================
// =========================================================================

struct CategoriesView: View {
    var categories: [FingoCategory] {
        FingoDataManager.shared.database.categories
    }
    
    @State private var showingAddCategory = false
    @State private var categoryToEdit: FingoCategory? = nil
    
    // Stavy pro iCloud Drive synchronizaci
    @State private var showingFilePicker = false
    @State private var showingRestartAlert = false
    @State private var alertMessage = ""
    @AppStorage("lastBackupDate") private var lastBackupDate: Double = 0
    @AppStorage("backupCount") private var backupCount: Int = 0
    @State private var showBackupSuccess = false
    
    var isCloudSynchronized: Bool {
        FingoDataManager.shared.isCloudSynchronized
    }
    
    var body: some View {
        NavigationStack {
            List {
                // Sekce 1: Synchronizace přes JSON soubor
                Section(header: Text("Zálohování & Synchronizace")) {
                    HStack {
                        Image(systemName: isCloudSynchronized ? "icloud.checkmark.fill" : "exclamationmark.icloud.fill")
                            .foregroundColor(isCloudSynchronized ? Color.emerald : Color.roseColor)
                            .font(.title2)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(isCloudSynchronized ? "Synchronizovaný JSON soubor" : "Lokální úložiště")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                            Text(isCloudSynchronized ? "Propojeno: \(FingoDataManager.shared.selectedFileURL?.lastPathComponent ?? "")" : "Vyberte Fingo JSON soubor na iCloud Drive pro sdílení dat s webem.")
                                .font(.system(size: 10))
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.vertical, 4)
                    .listRowBackground(Color.darkCard)
                    
                    if isCloudSynchronized {
                        Button(role: .destructive, action: disconnectFromiCloud) {
                            HStack {
                                Image(systemName: "icloud.slash.fill")
                                Text("Odpojit JSON soubor")
                            }
                            .font(.system(size: 13, weight: .bold))
                        }
                        .listRowBackground(Color.darkCard)
                    } else {
                        Button(action: { showingFilePicker.toggle() }) {
                            HStack {
                                Image(systemName: "folder.badge.plus")
                                Text("Vybrat složku s databází...")
                            }
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Color.indigoColor)
                        }
                        .listRowBackground(Color.darkCard)
                    }
                    
                    Button(action: {
                        FingoDataManager.shared.createBackup { success, date in
                            if success, let date = date {
                                lastBackupDate = date.timeIntervalSince1970
                                showBackupSuccess = true
                            }
                        }
                    }) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "arrow.down.doc.fill")
                                Text("Zálohovat databázi nyní")
                            }
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.emerald)
                            
                            if lastBackupDate > 0 {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Poslední záloha: \(Date(timeIntervalSince1970: lastBackupDate).formatted(date: .numeric, time: .shortened))")
                                    Text("Celkem uložených záloh: \(backupCount) z max 10")
                                }
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(Color.darkCard)
                }
                
                // Sekce 2: Správa kategorií
                Section(header: Text("Kategorie transakcí")) {
                    Button(action: {
                        categoryToEdit = nil
                        showingAddCategory = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 18))
                            Text("Přidat novou kategorii")
                                .font(.system(size: 15, weight: .bold))
                        }
                        .foregroundColor(Color.indigoColor)
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(Color.darkCard)
                    
                    ForEach(categories) { category in
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color(hex: category.color).opacity(0.15))
                                    .frame(width: 36, height: 36)
                                Image(systemName: category.icon)
                                    .foregroundColor(Color(hex: category.color))
                                    .font(.system(size: 16))
                            }
                            Text(category.name)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                            Spacer()
                            
                            HStack(spacing: 16) {
                                Button(action: {
                                    categoryToEdit = category
                                    showingAddCategory = true
                                }) {
                                    Image(systemName: "pencil")
                                        .foregroundColor(.gray)
                                        .font(.system(size: 16))
                                }
                                .buttonStyle(BorderlessButtonStyle())
                                
                                if isSystemCategory(category.id) {
                                    Text("Systém")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.gray)
                                        .padding(.vertical, 4)
                                        .padding(.horizontal, 8)
                                        .background(Color.white.opacity(0.06))
                                        .cornerRadius(6)
                                } else {
                                    Button(action: {
                                        deleteCategory(category)
                                    }) {
                                        Image(systemName: "trash")
                                            .foregroundColor(Color.roseColor)
                                            .font(.system(size: 16))
                                    }
                                    .buttonStyle(BorderlessButtonStyle())
                                }
                            }
                        }
                        .padding(.vertical, 4)
                        .listRowBackground(Color.darkCard)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Nastavení")
            .sheet(isPresented: $showingAddCategory) {
                AddCategorySheet(categoryToEdit: categoryToEdit)
            }
            .sheet(isPresented: $showingFilePicker) {
                FilePicker { url in
                    connectToFolder(url: url)
                }
            }
            .alert("Záloha vytvořena", isPresented: $showBackupSuccess) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Kopie databáze byla úspěšně uložena do stejné složky jako originální soubor.")
            }
            .alert("Propojení databáze", isPresented: $showingRestartAlert) {
                Button("OK") {}
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private func isSystemCategory(_ id: String) -> Bool {
        return ["cat-jidlo", "cat-bydleni", "cat-doprava", "cat-zabava", "cat-uvery", "cat-vyplata", "cat-ostatni"].contains(id)
    }
    
    private func deleteCategory(_ category: FingoCategory) {
        FingoDataManager.shared.database.categories.removeAll { $0.id == category.id }
        FingoDataManager.shared.saveDatabase()
    }
    
    private func connectToFolder(url: URL) {
        FingoDataManager.shared.connectToFolder(url: url)
        alertMessage = "Propojení s vybranou složkou bylo úspěšné! Aplikace nyní zálohuje a načítá data přímo z tohoto umístění."
        showingRestartAlert = true
    }
    
    private func disconnectFromiCloud() {
        FingoDataManager.shared.disconnect()
        alertMessage = "Propojení s JSON souborem bylo vypnuto. Aplikace nyní pracuje s lokálním souborem."
        showingRestartAlert = true
    }
}


