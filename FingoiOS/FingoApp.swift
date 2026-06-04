import SwiftUI
import Observation

@main
struct FingoApp: App {
    init() {
        // Inicializujeme správce dat
        _ = FingoDataManager.shared
    }
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .preferredColorScheme(.dark)
        }
    }
}

// Správce dat (FingoDataManager) pro načítání/ukládání jediné JSON databáze (POŽADAVEK uživatele)
@Observable
class FingoDataManager {
    static let shared = FingoDataManager()
    
    var database = FingoDatabase()
    var selectedFileURL: URL?
    var selectedFolderURL: URL?
    
    var showSyncToast = false
    var syncToastMessage = ""
    private var isFirstLoad = true
    private var syncToastTask: Task<Void, Never>? = nil
    
    private let fileBookmarkKey = "FingoDatabaseFileBookmark"
    private let folderBookmarkKey = "FingoDatabaseFolderBookmark"
    private let filenameKey = "FingoDatabaseFilename"
    
    init() {
        resolveAndLoad()
        
        // Listen to application foreground transitions to auto-refresh data from iCloud
        NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { [weak self] _ in
            print("Fingo: App returned to foreground, auto-refreshing database...")
            self?.reloadDatabase()
        }
    }
    
    func showToast(message: String) {
        syncToastTask?.cancel()
        syncToastTask = Task {
            await MainActor.run {
                self.syncToastMessage = message
                withAnimation(.spring()) {
                    self.showSyncToast = true
                }
            }
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.spring()) {
                    self.showSyncToast = false
                }
            }
        }
    }
    
    func category(for id: String) -> FingoCategory? {
        database.categories.first { $0.id == id }
    }
    
    func saveDatabase() {
        guard let url = selectedFileURL else {
            print("Chyba při ukládání: selectedFileURL je nil")
            return
        }
        
        let folderStarted = selectedFolderURL?.startAccessingSecurityScopedResource() ?? false
        let started = url.startAccessingSecurityScopedResource()
        
        var writeSucceeded = false
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        encoder.dateEncodingStrategy = .formatted(formatter)
        
        do {
            let data = try encoder.encode(database)
            
            // 1. Zkusíme koordinovaný zápis
            let coordinator = NSFileCoordinator()
            var error: NSError?
            
            coordinator.coordinate(writingItemAt: url, options: [], error: &error) { writeURL in
                let fileStarted = writeURL.startAccessingSecurityScopedResource()
                defer {
                    if fileStarted { writeURL.stopAccessingSecurityScopedResource() }
                }
                
                do {
                    // Zápis neatomicky do koordinované URL
                    try data.write(to: writeURL, options: [])
                    writeSucceeded = true
                    print("Fingo databáze uložena koordinačně do: \(writeURL.path)")
                } catch {
                    print("Chyba zápisu v koordinačním bloku: \(error.localizedDescription)")
                }
            }
            
            if let error = error {
                print("Chyba koordinátora zápisu: \(error.localizedDescription)")
            }
            
            // 2. Pokud se koordinační zápis nepodařil (nebo se block vůbec nespustil),
            // zkusíme přímý zápis (máme přístup přes security scope složky)
            if !writeSucceeded {
                try data.write(to: url, options: [])
                writeSucceeded = true
                print("Fingo databáze uložena napřímo (fallback): \(url.path)")
            }
            
        } catch {
            print("Kritická chyba při ukládání databáze: \(error.localizedDescription)")
        }
        
        if started {
            url.stopAccessingSecurityScopedResource()
        }
        if folderStarted {
            selectedFolderURL?.stopAccessingSecurityScopedResource()
        }
    }
    
    func loadDatabase(from url: URL) {
        let fileManager = FileManager.default
        
        let folderStarted = selectedFolderURL?.startAccessingSecurityScopedResource() ?? false
        let started = url.startAccessingSecurityScopedResource()
        
        // iCloud synchronizace a stažení souboru před čtením (vyhnutí se načtení staré nebo nekompletní cache)
        // Zde se pokusíme stáhnout soubor, pokud je v iCloud (nyní s povoleným přístupem)
        let isUbiquitous = fileManager.isUbiquitousItem(at: url) || url.path.contains("Mobile Documents") || url.path.contains("CloudDocs")
        if isUbiquitous {
            print("Fingo iCloud: Ověřování stavu souboru \(url.lastPathComponent)...")
            try? fileManager.startDownloadingUbiquitousItem(at: url)
            
            var isCurrent = false
            let startTime = Date()
            while !isCurrent && Date().timeIntervalSince(startTime) < 2.0 {
                if let values = try? url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey]),
                   values.ubiquitousItemDownloadingStatus == .current {
                    isCurrent = true
                    print("Fingo iCloud: Soubor \(url.lastPathComponent) stažen a připraven k načtení.")
                    break
                }
                Thread.sleep(forTimeInterval: 0.1)
            }
        }
        
        var readSucceeded = false
        var loadedDB: FingoDatabase?
        
        let decoder = JSONDecoder()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        decoder.dateDecodingStrategy = .custom { decoder -> Date in
            let container = try decoder.singleValueContainer()
            if let dateStr = try? container.decode(String.self) {
                if let date = formatter.date(from: dateStr) {
                    return date
                }
            }
            return Date()
        }
        
        // 1. Zkusíme koordinované čtení
        let coordinator = NSFileCoordinator()
        var error: NSError?
        
        coordinator.coordinate(readingItemAt: url, options: [], error: &error) { readURL in
            let fileStarted = readURL.startAccessingSecurityScopedResource()
            defer {
                if fileStarted { readURL.stopAccessingSecurityScopedResource() }
            }
            
            do {
                let data = try Data(contentsOf: readURL)
                loadedDB = try decoder.decode(FingoDatabase.self, from: data)
                readSucceeded = true
                print("Fingo databáze načtena koordinačně: \(url.lastPathComponent)")
            } catch {
                print("Chyba čtení v koordinačním bloku: \(error.localizedDescription)")
            }
        }
        
        if let error = error {
            print("Chyba koordinátora čtení: \(error.localizedDescription)")
        }
        
        // 2. Pokud koordinované čtení selhalo, zkusíme načíst napřímo
        if !readSucceeded {
            do {
                let data = try Data(contentsOf: url)
                loadedDB = try decoder.decode(FingoDatabase.self, from: data)
                readSucceeded = true
                print("Fingo databáze načtena napřímo (fallback): \(url.lastPathComponent)")
            } catch {
                print("Kritická chyba čtení databáze: \(error.localizedDescription)")
            }
        }
        
        if readSucceeded, let db = loadedDB {
            // Zajistíme, aby se zachovaly všechny případně chybějící defaultní kategorie
            var updatedCategories = db.categories
            for defaultCat in FingoCategory.defaultCategories {
                if !updatedCategories.contains(where: { $0.id == defaultCat.id }) {
                    updatedCategories.append(defaultCat)
                }
            }
            
            // Oprava ikon kategorií (migrace na platné a vyplněné SF Symbols)
            for i in 0..<updatedCategories.count {
                let icon = updatedCategories[i].icon
                if icon == "landmark" {
                    updatedCategories[i].icon = "building.columns.fill"
                } else if icon == "cart" {
                    updatedCategories[i].icon = "cart.fill"
                } else if icon == "house" {
                    updatedCategories[i].icon = "house.fill"
                } else if icon == "car" {
                    updatedCategories[i].icon = "car.fill"
                } else if icon == "gamecontroller" {
                    updatedCategories[i].icon = "gamecontroller.fill"
                } else if icon == "dollarsign" {
                    updatedCategories[i].icon = "dollarsign.circle.fill"
                } else if icon == "ellipsis" {
                    updatedCategories[i].icon = "ellipsis.circle.fill"
                } else if icon.isEmpty {
                    updatedCategories[i].icon = "tag.fill"
                }
            }
            
            var finalDB = db
            finalDB.categories = updatedCategories
            
            // Porovnání změn v transakcích (pouze pokud to není první načtení při spuštění)
            if !self.isFirstLoad {
                let oldTxIds = Set(self.database.transactions.map { $0.id })
                let newTxIds = Set(finalDB.transactions.map { $0.id })
                
                let added = newTxIds.subtracting(oldTxIds).count
                let deleted = oldTxIds.subtracting(newTxIds).count
                
                if added > 0 || deleted > 0 {
                    var parts: [String] = []
                    if added > 0 {
                        if added == 1 {
                            parts.append("přidána 1 transakce")
                        } else if added >= 2 && added <= 4 {
                            parts.append("přidány \(added) transakce")
                        } else {
                            parts.append("přidáno \(added) transakcí")
                        }
                    }
                    if deleted > 0 {
                        if deleted == 1 {
                            parts.append("smazána 1 transakce")
                        } else if deleted >= 2 && deleted <= 4 {
                            parts.append("smazány \(deleted) transakce")
                        } else {
                            parts.append("smazáno \(deleted) transakcí")
                        }
                    }
                    let message = parts.joined(separator: ", ")
                    let formattedMessage = message.prefix(1).uppercased() + message.dropFirst()
                    self.showToast(message: formattedMessage)
                } else {
                    self.showToast(message: "Synchronizace dokončena (beze změn)")
                }
            } else {
                self.isFirstLoad = false
            }
            
            self.database = finalDB
            self.selectedFileURL = url
            processRecurringPayments() // Zpracování trvalých plateb na iOS
            saveDatabase() // Uložíme zmigrované ikony a případné zpracované platby zpět
        }
        
        if started {
            url.stopAccessingSecurityScopedResource()
        }
        if folderStarted {
            selectedFolderURL?.stopAccessingSecurityScopedResource()
        }
        
        updateBackupCount()
    }
    
    func processRecurringPayments() {
        let today = Date()
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: today)
        
        var wasModified = false
        var recurringToKeep: [FingoRecurring] = []
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        for var rec in database.recurring {
            var nextDueDate = calendar.startOfDay(for: rec.nextDueDate)
            var keepRecurring = true
            
            while nextDueDate <= todayStart {
                // Kontrola data ukončení
                if let endDate = rec.endDate {
                    let endDateStart = calendar.startOfDay(for: endDate)
                    if nextDueDate > endDateStart {
                        keepRecurring = false
                        break
                    }
                }
                
                let dateStr = formatter.string(from: nextDueDate)
                
                // Kontrola, zda transakce pro tuto platbu v daný den již existuje (ochrana proti duplicitám při konfliktech)
                let descriptionMarker = "Auto-platba: \(rec.name)"
                let alreadyProcessed = database.transactions.contains { trans in
                    let sameDate = formatter.string(from: trans.date) == dateStr
                    let sameDesc = trans.notes == descriptionMarker
                    let sameAmount = abs(trans.amount - rec.amount) < 0.01
                    return sameDate && sameDesc && sameAmount
                }
                
                if !alreadyProcessed {
                    let newTransaction = FingoTransaction(
                        type: rec.type,
                        amount: rec.amount,
                        date: nextDueDate,
                        notes: descriptionMarker,
                        categoryId: rec.categoryId
                    )
                    database.transactions.append(newTransaction)
                    print("Zpracována trvalá platba v iOS: \(rec.name) pro datum: \(dateStr)")
                }
                
                // Posun data
                if rec.frequency == "weekly" {
                    if let next = calendar.date(byAdding: .day, value: 7, to: nextDueDate) {
                        nextDueDate = next
                    }
                } else if rec.frequency == "monthly" {
                    if let next = calendar.date(byAdding: .month, value: 1, to: nextDueDate) {
                        nextDueDate = next
                    }
                } else if rec.frequency == "yearly" {
                    if let next = calendar.date(byAdding: .year, value: 1, to: nextDueDate) {
                        nextDueDate = next
                    }
                }
                
                rec.nextDueDate = nextDueDate
                wasModified = true
                
                // Kontrola data ukončení po posunu
                if let endDate = rec.endDate {
                    let endDateStart = calendar.startOfDay(for: endDate)
                    if nextDueDate > endDateStart {
                        keepRecurring = false
                        break
                    }
                }
            }
            
            if keepRecurring {
                recurringToKeep.append(rec)
            } else {
                wasModified = true
            }
        }
        
        if wasModified {
            database.recurring = recurringToKeep
        }
    }
    
    func reloadDatabase(completion: (() -> Void)? = nil) {
        resolveAndLoad()
        completion?()
    }
    
    func connectToFolder(url: URL) {
        saveFolderBookmark(for: url)
        UserDefaults.standard.removeObject(forKey: fileBookmarkKey)
        UserDefaults.standard.synchronize()
        resolveAndLoad()
    }
    
    func disconnect() {
        UserDefaults.standard.removeObject(forKey: fileBookmarkKey)
        UserDefaults.standard.removeObject(forKey: folderBookmarkKey)
        UserDefaults.standard.synchronize()
        selectedFileURL = nil
        selectedFolderURL = nil
        resolveAndLoad()
    }
    
    var isCloudSynchronized: Bool {
        UserDefaults.standard.data(forKey: folderBookmarkKey) != nil || UserDefaults.standard.data(forKey: fileBookmarkKey) != nil
    }
    
    func createBackup(completion: @escaping (Bool, Date?) -> Void) {
        guard let url = selectedFileURL else {
            completion(false, nil)
            return
        }
        
        let folderStarted = selectedFolderURL?.startAccessingSecurityScopedResource() ?? false
        let started = url.startAccessingSecurityScopedResource()
        
        let fileManager = FileManager.default
        let backupFolderURL: URL
        if let folder = selectedFolderURL {
            backupFolderURL = folder
        } else {
            backupFolderURL = url.deletingLastPathComponent()
        }
        let fileName = url.deletingPathExtension().lastPathComponent
        
        do {
            if !fileManager.fileExists(atPath: backupFolderURL.path) {
                try fileManager.createDirectory(at: backupFolderURL, withIntermediateDirectories: true, attributes: nil)
            }
        } catch {
            print("Nepodařilo se vytvořit složku záloh: \(error)")
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let dateString = dateFormatter.string(from: Date())
        
        let backupFileName = "\(fileName)_\(dateString).json"
        let backupURL = backupFolderURL.appendingPathComponent(backupFileName)
        
        let coordinator = NSFileCoordinator()
        var coordinateError: NSError?
        
        var success = false
        var backupDate: Date? = nil
        
        coordinator.coordinate(readingItemAt: url, options: [], error: &coordinateError) { readURL in
            let readStarted = readURL.startAccessingSecurityScopedResource()
            defer { if readStarted { readURL.stopAccessingSecurityScopedResource() } }
            
            var writeCoordinateError: NSError?
            coordinator.coordinate(writingItemAt: backupURL, options: [], error: &writeCoordinateError) { writeURL in
                let writeStarted = writeURL.startAccessingSecurityScopedResource()
                defer { if writeStarted { writeURL.stopAccessingSecurityScopedResource() } }
                
                do {
                    if fileManager.fileExists(atPath: writeURL.path) {
                        try fileManager.removeItem(at: writeURL)
                    }
                    try fileManager.copyItem(at: readURL, to: writeURL)
                    success = true
                    backupDate = Date()
                    UserDefaults.standard.set(backupDate?.timeIntervalSince1970, forKey: "lastBackupDate")
                } catch {
                    print("Chyba při zálohování v koordinačním bloku: \(error.localizedDescription)")
                }
            }
        }
        
        // Pokud koordinační kopírování selhalo, zkusíme přímou kopii
        if !success {
            do {
                if fileManager.fileExists(atPath: backupURL.path) {
                    try fileManager.removeItem(at: backupURL)
                }
                try fileManager.copyItem(at: url, to: backupURL)
                success = true
                backupDate = Date()
                UserDefaults.standard.set(backupDate?.timeIntervalSince1970, forKey: "lastBackupDate")
                print("Záloha vytvořena napřímo (fallback): \(backupURL.path)")
            } catch {
                print("Chyba při přímém zálohování (fallback): \(error.localizedDescription)")
            }
        }
        
        if success {
            do {
                let allFiles = try fileManager.contentsOfDirectory(at: backupFolderURL, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
                var backupFiles = allFiles.filter { $0.lastPathComponent.hasPrefix(fileName + "_") && $0.pathExtension == "json" }
                
                if backupFiles.count > 10 {
                    let sortedBackups = backupFiles.sorted { $0.lastPathComponent < $1.lastPathComponent }
                    let backupsToDelete = sortedBackups.dropLast(10)
                    for backup in backupsToDelete {
                        try? fileManager.removeItem(at: backup)
                        backupFiles.removeAll { $0 == backup }
                        print("Smazána stará záloha: \(backup.lastPathComponent)")
                    }
                }
                UserDefaults.standard.set(backupFiles.count, forKey: "backupCount")
            } catch {
                print("Chyba při promazávání starých záloh: \(error.localizedDescription)")
                UserDefaults.standard.set(0, forKey: "backupCount")
            }
        }
        
        if started {
            url.stopAccessingSecurityScopedResource()
        }
        if folderStarted {
            selectedFolderURL?.stopAccessingSecurityScopedResource()
        }
        
        DispatchQueue.main.async {
            completion(success, backupDate)
        }
    }
    
    func updateBackupCount() {
        guard let url = selectedFileURL ?? URL(string: "file://" + URL.documentsDirectory.path + "/fingo_local.json") else {
            UserDefaults.standard.set(0, forKey: "backupCount")
            return
        }
        
        let folderStarted = selectedFolderURL?.startAccessingSecurityScopedResource() ?? false
        let backupFolderURL: URL
        if let folder = selectedFolderURL {
            backupFolderURL = folder
        } else {
            backupFolderURL = url.deletingLastPathComponent()
        }
        let fileName = url.deletingPathExtension().lastPathComponent
        do {
            let allFiles = try FileManager.default.contentsOfDirectory(at: backupFolderURL, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            let backupFiles = allFiles.filter { $0.lastPathComponent.hasPrefix(fileName + "_") && $0.pathExtension == "json" }
            UserDefaults.standard.set(backupFiles.count, forKey: "backupCount")
        } catch {
            UserDefaults.standard.set(0, forKey: "backupCount")
        }
        if folderStarted {
            selectedFolderURL?.stopAccessingSecurityScopedResource()
        }
    }
    
    private func saveFolderBookmark(for url: URL) {
        do {
            let started = url.startAccessingSecurityScopedResource()
            defer {
                if started { url.stopAccessingSecurityScopedResource() }
            }
            let bookmarkData = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
            UserDefaults.standard.set(bookmarkData, forKey: folderBookmarkKey)
            UserDefaults.standard.synchronize()
            print("Uložena bezpečnostní záložka pro složku: \(url.path)")
        } catch {
            print("Chyba při ukládání bezpečnostní záložky složky: \(error)")
        }
    }
    
    private func resolveFolderBookmark() -> URL? {
        guard let bookmarkData = UserDefaults.standard.data(forKey: folderBookmarkKey) else { return nil }
        var isStale = false
        do {
            let url = try URL(resolvingBookmarkData: bookmarkData, options: [], relativeTo: nil, bookmarkDataIsStale: &isStale)
            if isStale { saveFolderBookmark(for: url) }
            _ = url.startAccessingSecurityScopedResource()
            return url
        } catch {
            print("Chyba při startu přístupu k bezpečnostní záložce složky.")
        }
        return nil
    }
    
    private func resolveFileBookmark() -> URL? {
        guard let bookmarkData = UserDefaults.standard.data(forKey: fileBookmarkKey) else { return nil }
        var isStale = false
        do {
            let url = try URL(resolvingBookmarkData: bookmarkData, options: [], relativeTo: nil, bookmarkDataIsStale: &isStale)
            if isStale {
                let startedUrl = url.startAccessingSecurityScopedResource()
                let newBookmarkData = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
                if let data = newBookmarkData {
                    UserDefaults.standard.set(data, forKey: fileBookmarkKey)
                    UserDefaults.standard.synchronize()
                }
                if startedUrl { url.stopAccessingSecurityScopedResource() }
            }
            _ = url.startAccessingSecurityScopedResource()
            return url
        } catch { }
        return nil
    }
    
    private func resolveAndLoad() {
        if let folderURL = resolveFolderBookmark() {
            self.selectedFolderURL = folderURL
            if let files = try? FileManager.default.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) {
                // Pomocné funkce pro ošetření iCloud .icloud zástupných souborů
                func cleanName(for url: URL) -> String {
                    var name = url.lastPathComponent
                    if url.pathExtension == "icloud" {
                        if name.hasPrefix(".") {
                            name.removeFirst()
                        }
                        if name.hasSuffix(".icloud") {
                            name = String(name.dropLast(7))
                        }
                    }
                    return name
                }
                
                let jsonFiles = files.filter { 
                    ($0.pathExtension == "json" || ($0.pathExtension == "icloud" && $0.lastPathComponent.contains(".json."))) 
                    && !$0.pathComponents.contains("zaloha") 
                }
                
                var matchedURL: URL? = nil
                if let savedName = UserDefaults.standard.string(forKey: filenameKey) {
                    matchedURL = jsonFiles.first { cleanName(for: $0) == savedName }
                }
                
                if matchedURL == nil, let firstFile = jsonFiles.first {
                    matchedURL = firstFile
                    UserDefaults.standard.set(cleanName(for: firstFile), forKey: filenameKey)
                }
                
                if let match = matchedURL {
                    let resolvedURL: URL
                    if match.pathExtension == "icloud" {
                        let dir = match.deletingLastPathComponent()
                        let name = cleanName(for: match)
                        resolvedURL = dir.appendingPathComponent(name)
                    } else {
                        resolvedURL = match
                    }
                    
                    self.selectedFileURL = resolvedURL
                    loadDatabase(from: resolvedURL)
                } else {
                    disconnect()
                }
            }
        } else if let fileURL = resolveFileBookmark() {
            // Legacy fallback
            self.selectedFileURL = fileURL
            loadDatabase(from: fileURL)
        } else {
            // Výchozí sandbox lokální úložiště jako fallback
            let localURL = URL.documentsDirectory.appendingPathComponent("fingo_local.json")
            if !FileManager.default.fileExists(atPath: localURL.path) {
                let defaultDB = FingoDatabase(
                    transactions: [],
                    recurring: [],
                    categories: FingoCategory.defaultCategories,
                    loans: [],
                    budgets: [],
                    savingsGoals: []
                )
                self.database = defaultDB
                self.selectedFileURL = localURL
                saveDatabase()
            } else {
                loadDatabase(from: localURL)
                self.selectedFileURL = localURL
            }
        }
        updateBackupCount()
    }
}

struct MainTabView: View {
    @State private var selectedTab = 1
    private var dataManager: FingoDataManager { FingoDataManager.shared }
    
    var body: some View {
        ZStack(alignment: .top) {
            TabView(selection: $selectedTab) {
                DashboardView()
                    .tabItem {
                        Label("Přehled", systemImage: "chart.pie.fill")
                    }
                    .tag(0)
                
                TransactionsView()
                    .tabItem {
                        Label("Transakce", systemImage: "list.bullet")
                    }
                    .tag(1)
                
                PlansView()
                    .tabItem {
                        Label("Úvěry & Plány", systemImage: "building.columns.fill")
                    }
                    .tag(2)
                
                SimulatorView()
                    .tabItem {
                        Label("Simulátor", systemImage: "flame.fill")
                    }
                    .tag(3)
                
                CategoriesView()
                    .tabItem {
                        Label("Nastavení", systemImage: "gearshape.fill")
                    }
                    .tag(4)
            }
            .tint(Color(red: 99/255, green: 102/255, blue: 241/255))
            
            // Plovoucí synchronizační lišta
            if dataManager.showSyncToast {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise.icloud.fill")
                        .foregroundColor(Color(red: 99/255, green: 102/255, blue: 241/255))
                        .font(.system(size: 16, weight: .semibold))
                    Text(dataManager.syncToastMessage)
                        .foregroundColor(.white)
                        .font(.system(size: 14, weight: .medium))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(Color(red: 18/255, green: 18/255, blue: 22/255))
                        .overlay(
                            Capsule()
                                .stroke(Color(red: 99/255, green: 102/255, blue: 241/255).opacity(0.3), lineWidth: 1)
                        )
                )
                .shadow(color: Color.black.opacity(0.5), radius: 8, x: 0, y: 4)
                .padding(.top, 12)
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(999)
            }
        }
    }
}
