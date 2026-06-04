# Fingo iOS – Nativní Xcode SwiftUI projekt s iCloud synchronizací

Tato složka obsahuje kompletní zdrojové kódy pro nativní iOS verzi aplikace **Fingo** napsanou v jazyce Swift s využitím SwiftUI a SwiftData. Aplikace automaticky ukládá a synchronizuje veškerá data (transakce, úvěry, cíle) přes Váš osobní **iCloud (CloudKit)**.

## 🚀 Jak spustit projekt v Xcode

Postupujte podle těchto jednoduchých kroků k sestavení aplikace na svém iPhonu:

### 1. Vytvoření projektu v Xcode
1. Otevřete **Xcode** na svém Macu.
2. Zvolte **File > New > Project...** (nebo stiskněte `Cmd+Shift+N`).
3. Vyberte platformu **iOS** a šablonu **App**, klikněte na *Next*.
4. Vyplňte parametry projektu:
   - **Product Name:** `Fingo`
   - **Organization Identifier:** např. `cz.stepos`
   - **Interface:** *SwiftUI*
   - **Language:** *Swift*
   - **Storage:** *SwiftData* (nebo *None* – databázi inicializujeme sami)
5. Klikněte na *Next* a uložte projekt do svého Macu.

### 2. Zkopírování zdrojových souborů
Nahraďte nebo přidejte soubory z této složky (`FingoiOS/`) do struktury Vašeho Xcode projektu:
- **`Models.swift`**: Datové entity pro SwiftData.
- **`FingoApp.swift`**: Hlavní vstupní bod aplikace (nahraďte jím výchozí vygenerovaný `<NázevProjektu>App.swift` soubor).
- **`DashboardView.swift`**: Hlavní přehled a grafy.
- **`TransactionsView.swift`**: Historie plateb a filtry.
- **`LoansView.swift`**: Evidence úvěrů a splátkový kalendář.
- **`SimulatorView.swift`**: Renta (FIRE), složené úročení a **Konsolidační kalkulačka**.
- **`CategoriesView.swift`**: Správa vlastních kategorií, barev a ikon.

*Tip: Můžete soubory jednoduše přetáhnout do navigátoru Xcode (ujistěte se, že máte zaškrtnuto "Copy items if needed").*

---

## ☁️ Nastavení iCloud & CloudKit synchronizace

Pro bezchybnou a automatickou synchronizaci dat na pozadí mezi Vaším Macem a iPhonem musíte zapnout iCloud capabilities:

1. V Xcode klikněte na **modrou ikonu projektu** nahoře v levém sloupci (Project Navigator).
2. Přejděte na záložku **Signing & Capabilities**.
3. Klikněte na tlačítko **`+ Capability`** vlevo nahoře.
4. Najděte a dvakrát klikněte na **iCloud**.
5. V sekci iCloud:
   - Zaškrtněte políčko **CloudKit**.
   - Pod ním klikněte na tlačítko `+` a vytvořte nový kontejner (Xcode navrhne např. `iCloud.cz.stepos.Fingo` – nechte jej vybraný).
6. Znovu klikněte na **`+ Capability`**, vyhledejte **Background Modes** a přidejte je.
7. V sekci Background Modes zaškrtněte políčko **Remote notifications** (tím se zajistí, že se data na pozadí stáhnou hned, jakmile se změní na jiném zařízení).

Nyní je vše připraveno! Připojte svůj iPhone k Macu, v Xcode vyberte svůj telefon jako cílové zařízení a stiskněte **Run** (`Cmd+R`). Aplikace se nainstaluje do telefonu a začne se automaticky synchronizovat přes Váš iCloud.
