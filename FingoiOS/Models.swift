import Foundation
import SwiftUI

struct FingoCategory: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var color: String
    var icon: String
    
    init(id: String = UUID().uuidString, name: String, color: String, icon: String) {
        self.id = id
        self.name = name
        self.color = color
        self.icon = icon
    }
    
    static var defaultCategories: [FingoCategory] {
        return [
            FingoCategory(id: "cat-jidlo", name: "Jídlo & Potraviny", color: "#ef4444", icon: "cart"),
            FingoCategory(id: "cat-bydleni", name: "Bydlení & Energie", color: "#3b82f6", icon: "house"),
            FingoCategory(id: "cat-doprava", name: "Doprava & Auto", color: "#eab308", icon: "car"),
            FingoCategory(id: "cat-zabava", name: "Zábava & Volný čas", color: "#a855f7", icon: "gamecontroller"),
            FingoCategory(id: "cat-uvery", name: "Úvěrové produkty", color: "#6366f1", icon: "landmark"),
            FingoCategory(id: "cat-vyplata", name: "Pravidelný příjem / Výplata", color: "#10b981", icon: "dollarsign"),
            FingoCategory(id: "cat-ostatni", name: "Ostatní", color: "#6b7280", icon: "ellipsis")
        ]
    }
}

struct FingoTransaction: Identifiable, Codable {
    let id: String
    var type: String // "income" or "expense"
    var amount: Double
    var date: Date
    var notes: String // Mapped to "description" in JSON
    var categoryId: String // Mapped to "category" in JSON
    
    enum CodingKeys: String, CodingKey {
        case id, type, amount, date
        case notes = "description"
        case categoryId = "category"
    }
    
    init(id: String = "t-" + String(Int(Date().timeIntervalSince1970)) + "-" + UUID().uuidString.prefix(6).lowercased(), type: String, amount: Double, date: Date, notes: String, categoryId: String) {
        self.id = id
        self.type = type
        self.amount = amount
        self.date = date
        self.notes = notes
        self.categoryId = categoryId
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.type = try container.decode(String.self, forKey: .type)
        self.amount = try container.decode(Double.self, forKey: .amount)
        self.date = try container.decode(Date.self, forKey: .date)
        self.notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        self.categoryId = try container.decodeIfPresent(String.self, forKey: .categoryId) ?? "cat-ostatni"
    }
    
    var category: FingoCategory? {
        FingoDataManager.shared.category(for: categoryId)
    }
}

struct FingoRecurring: Identifiable, Codable {
    let id: String
    var name: String
    var type: String
    var amount: Double
    var frequency: String
    var nextDueDate: Date
    var endDate: Date?
    var bookingDay: String?
    var categoryId: String
    
    enum CodingKeys: String, CodingKey {
        case id, name, type, amount, frequency, nextDueDate, endDate, bookingDay
        case categoryId = "category"
    }
    
    init(id: String = "r-" + String(Int(Date().timeIntervalSince1970)) + "-" + UUID().uuidString.prefix(6).lowercased(), name: String, type: String, amount: Double, frequency: String, nextDueDate: Date, endDate: Date? = nil, bookingDay: String? = nil, categoryId: String) {
        self.id = id
        self.name = name
        self.type = type
        self.amount = amount
        self.frequency = frequency
        self.nextDueDate = nextDueDate
        self.endDate = endDate
        self.bookingDay = bookingDay
        self.categoryId = categoryId
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.type = try container.decode(String.self, forKey: .type)
        self.amount = try container.decode(Double.self, forKey: .amount)
        self.frequency = try container.decode(String.self, forKey: .frequency)
        self.nextDueDate = try container.decode(Date.self, forKey: .nextDueDate)
        self.endDate = try container.decodeIfPresent(Date.self, forKey: .endDate)
        self.bookingDay = try container.decodeIfPresent(String.self, forKey: .bookingDay)
        self.categoryId = try container.decodeIfPresent(String.self, forKey: .categoryId) ?? "cat-ostatni"
    }
    
    var category: FingoCategory? {
        FingoDataManager.shared.category(for: categoryId)
    }
}

struct FingoLoan: Identifiable, Codable {
    let id: String
    var name: String
    var type: String
    var totalAmount: Double
    var remainingAmount: Double
    var interestRate: Double
    var monthlyPayment: Double
    var duration: Int?
    var durationUnit: String?
    var startDate: String // String to handle "23" (day of month) as well as full date strings
    var endDate: Date
    var notes: String
    var categoryId: String
    
    enum CodingKeys: String, CodingKey {
        case id, name, type, totalAmount, remainingAmount, interestRate, monthlyPayment, duration, durationUnit, startDate, endDate, notes
        case categoryId = "category"
    }
    
    init(id: String = "l-" + String(Int(Date().timeIntervalSince1970)) + "-" + UUID().uuidString.prefix(6).lowercased(), name: String, type: String, totalAmount: Double, remainingAmount: Double, interestRate: Double, monthlyPayment: Double, duration: Int? = nil, durationUnit: String? = nil, startDate: String, endDate: Date, notes: String = "", categoryId: String) {
        self.id = id
        self.name = name
        self.type = type
        self.totalAmount = totalAmount
        self.remainingAmount = remainingAmount
        self.interestRate = interestRate
        self.monthlyPayment = monthlyPayment
        self.duration = duration
        self.durationUnit = durationUnit
        self.startDate = startDate
        self.endDate = endDate
        self.notes = notes
        self.categoryId = categoryId
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.type = try container.decode(String.self, forKey: .type)
        self.totalAmount = try container.decode(Double.self, forKey: .totalAmount)
        self.remainingAmount = try container.decode(Double.self, forKey: .remainingAmount)
        self.interestRate = try container.decode(Double.self, forKey: .interestRate)
        self.monthlyPayment = try container.decode(Double.self, forKey: .monthlyPayment)
        self.duration = try container.decodeIfPresent(Int.self, forKey: .duration)
        self.durationUnit = try container.decodeIfPresent(String.self, forKey: .durationUnit)
        self.startDate = try container.decodeIfPresent(String.self, forKey: .startDate) ?? "15"
        self.endDate = try container.decode(Date.self, forKey: .endDate)
        self.notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        self.categoryId = try container.decodeIfPresent(String.self, forKey: .categoryId) ?? "cat-uvery"
    }
    
    var category: FingoCategory? {
        FingoDataManager.shared.category(for: categoryId)
    }
}

struct FingoGoal: Identifiable, Codable {
    let id: String
    var name: String
    var targetAmount: Double
    var currentAmount: Double
    var targetDate: Date
    var notes: String
    var icon: String
    
    enum CodingKeys: String, CodingKey {
        case id, name, targetAmount, currentAmount, targetDate, notes, icon
    }
    
    init(id: String = "g-" + String(Int(Date().timeIntervalSince1970)) + "-" + UUID().uuidString.prefix(6).lowercased(), name: String, targetAmount: Double, currentAmount: Double, targetDate: Date, notes: String = "", icon: String = "target") {
        self.id = id
        self.name = name
        self.targetAmount = targetAmount
        self.currentAmount = currentAmount
        self.targetDate = targetDate
        self.notes = notes
        self.icon = icon
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.targetAmount = try container.decode(Double.self, forKey: .targetAmount)
        self.currentAmount = try container.decode(Double.self, forKey: .currentAmount)
        self.targetDate = try container.decode(Date.self, forKey: .targetDate)
        self.notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        self.icon = try container.decodeIfPresent(String.self, forKey: .icon) ?? "target"
    }
}

struct FingoBudget: Codable, Identifiable {
    var categoryId: String
    var amount: Double
    
    var id: String { categoryId }
    
    enum CodingKeys: String, CodingKey {
        case categoryId, amount
    }
    
    init(categoryId: String, amount: Double) {
        self.categoryId = categoryId
        self.amount = amount
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.categoryId = try container.decode(String.self, forKey: .categoryId)
        self.amount = try container.decode(Double.self, forKey: .amount)
    }
}

struct FingoDatabase: Codable {
    var transactions: [FingoTransaction] = []
    var recurring: [FingoRecurring] = []
    var categories: [FingoCategory] = []
    var loans: [FingoLoan] = []
    var budgets: [FingoBudget] = []
    var savingsGoals: [FingoGoal] = []
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

func fingoFormatCurrency(_ value: Double) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.currencyCode = "CZK"
    formatter.currencySymbol = "Kč"
    formatter.minimumFractionDigits = 2
    formatter.maximumFractionDigits = 2
    return formatter.string(from: NSNumber(value: value)) ?? "\(value) Kč"
}

