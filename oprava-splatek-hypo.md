# Oprava splátek hypoték a úvěrů — zadání pro AI (iOS / Swift verze Fingo)

Tento dokument popisuje změny, které už byly provedeny ve **webové verzi Fingo**
(`index.html`), a slouží jako zadání pro AI, aby stejné chování naimplementovala
v **nativní iOS (Swift / SwiftUI) verzi** projektu.

## Kontext
Nejdřív si prosím prostuduj projekt a zjisti:
- datový model úvěru (ekvivalent: name, type, totalAmount, remainingAmount,
  monthlyPayment, interestRate, **den zaúčtování / booking day**, endDate,
  category, notes),
- jak a kde se ukládá stav (Core Data / SwiftData / JSON / UserDefaults),
- jestli už existuje mechanismus **opakovaných/trvalých plateb** (recurring).
  Pokud ano, novou logiku úvěrů naimplementuj **stejným způsobem a na stejném
  místě** (stejné konvence, stejný spouštěč při startu appky).

## Problém, který opravujeme
Měsíční splátka úvěru se na dashboardu označovala jako „zaplaceno", jakmile
uplynul den zaúčtování, ale **reálně nevznikla žádná transakce** a nesnížil se
zůstatek. Uživateli pak přebývaly peníze na kontě.

---

## Změna A — Automatické účtování měsíční splátky

Přidej funkci (např. `processLoanPayments()`), která se spustí **při startu
appky**, ideálně hned vedle zpracování trvalých plateb. Pro každý úvěr:

1. `monthly = monthlyPayment`; pokud `<= 0`, přeskoč.
2. `bookingDay` = den v měsíci (1–31) z pole „den zaúčtování".
3. Zjisti `endDate` (konec splácení).
4. **Bez zpětného doúčtování:** pokud úvěr nemá uložené `nextPaymentDate`,
   nastav ho na **nejbližší budoucí (nebo dnešní) výskyt** dne `bookingDay`.
   (Tj. tento měsíc na `bookingDay`; pokud už tento měsíc uplynul, příští
   měsíc.) Tím se u existujících úvěrů NEvygenerují žádné staré transakce.
5. Cyklus, dokud `nextPaymentDate <= dnes`:
   - když `nextPaymentDate > endDate` → konec (úvěr doběhl),
   - když `remainingAmount <= 0` → konec (doplaceno),
   - vytvoř **výdajovou transakci**: částka `monthly`, datum `nextPaymentDate`,
     kategorie = kategorie úvěru (fallback „Úvěrové produkty"), popis
     `"Splátka úvěru: {name}"`,
   - **deduplikace:** transakci nepřidávej, pokud už existuje transakce se
     stejným datem + popisem + částkou (ochrana proti duplicitám při
     synchronizaci/opakovaném startu),
   - sniž `remainingAmount` o `monthly` (clamp na min. 0),
   - posuň `nextPaymentDate` o 1 měsíc s **oříznutím na délku měsíce**
     (viz helper níže) a ulož.
6. Na konci stav persistuj.

### Helper: přičtení měsíců s oříznutím dne
Den se kotví na `bookingDay`, ale ořízne se na poslední den měsíce:
31. 1. + 1 měsíc = 28./29. 2., a další měsíc se zase vrátí na 31.
(Swift: použij `Calendar`; spočítej cílový měsíc, vezmi `min(bookingDay,
početDníVMěsíci)`.)

### Poznámka k jistině
Pro zjednodušení se jistina snižuje o **celou měsíční splátku** (úrok se neřeší)
— stejně jako to dělá webová verze. Drž stejné chování kvůli konzistenci.

---

## Změna B — „Mimořádná splátka" místo „Zapsat splátku"

Původní ruční tlačítko „Zapsat splátku" se mění na **„Mimořádná splátka"**:

- **Tlačítko na kartě úvěru:** text → „Mimořádná splátka".
- **Formulář/sheet:** titulek „Zapsat mimořádnou splátku", podtitulek
  „Mimořádná splátka navíc k automatické měsíční splátce ({formátovaná měsíční
  splátka})". **Jediné částkové pole**: „Kolik jste zaplatili navíc (Kč)"
  (odstraň původní dvě pole „zaúčtovaná splátka" + „snížení jistiny").
  Ponech pole datum + popis (default popisu `"Mimořádná splátka: {name}"`).
- **Po potvrzení:** vytvoř výdajovou transakci na zadanou částku a o **celou
  tuto částku** sniž `remainingAmount` (clamp na 0). Toast:
  „Mimořádná splátka zaúčtována. Jistina snížena o {částka}."
- Validace: částka musí být > 0.

---

## Lokalizace
Doplň překlady (CS/EN/DE) pro nové texty — drž styl stávajících klíčů:

| CS | EN | DE |
|----|----|----|
| Mimořádná splátka | Extra payment | Sondertilgung |
| Zapsat mimořádnou splátku | Record extra payment | Sondertilgung erfassen |
| Mimořádná splátka navíc k automatické měsíční splátce | Extra payment on top of the automatic monthly installment | Sondertilgung zusätzlich zur automatischen Monatsrate |
| Kolik jste zaplatili navíc (Kč) | How much you paid extra | Wie viel Sie zusätzlich gezahlt haben |

---

## Test / akceptační kritéria
1. Existující úvěr se po updatu **nedoúčtuje zpětně** (žádné staré transakce).
2. V den zaúčtování (a při startu appky daný den či později) vznikne **právě
   jedna** výdajová transakce a sníží se zůstatek; opakovaný start ji
   nezduplikuje.
3. Po konci splácení nebo po doplacení jistiny se další splátky negenerují.
4. Krátké měsíce: den 31 se v únoru ořízne a další měsíc se vrátí na 31.
5. „Mimořádná splátka" vytvoří výdaj a o stejnou částku sníží jistinu.

---

## Reference: implementace ve webové verzi
V `index.html` jsou klíčové části:
- `processLoanPayments()` — automatické měsíční splátky (spouští se při startu
  vedle `processRecurringPayments()`),
- `openLoanPaymentModal()` + `handleLoanPaymentSubmit()` — mimořádná splátka,
- `addMonthsClamped()` — posun o měsíc s oříznutím dne,
- modal `#modal-loan-payment` — formulář mimořádné splátky.
