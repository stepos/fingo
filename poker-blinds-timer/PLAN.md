# 🃏 BlindUp – Poker Tournament Planner & Timer

> Návrh struktury aplikace. Zatím **pouze plán** – programování začne až po schválení.

## Návrh jména

Vybral jsem pracovní název **BlindUp** (= "zvedání blindů" + "buď připraven").
Alternativy, kdyby se nelíbil:

| Název | Vibe |
|-------|------|
| **BlindUp** ⭐ | krátké, výstižné, o zvedání blindů |
| **ChipClock** | čip + hodiny/odpočet |
| **PokerPit** | herna / "the pit" |
| **BlindTimer** | popisné, jasné |
| **AllInClock** | hravé |

Složka projektu: `poker-blinds-timer/`

---

## K čemu appka slouží

Plánování a řízení živého pokerového turnaje:
- **Odpočet času** aktuálního levelu (blind level countdown)
- **Automatické zvedání blindů** (small / big blind + ante) podle struktury
- **Rebuy / Add-on okno** – kdy je rebuy povolený, vizuální upozornění na konec
- **Přestávky (breaks)** mezi levely
- **Žetony (chips)** – nominály, počáteční stack, hodnota, chip-race
- **Plánování struktury turnaje** předem (vytvoření a uložení šablon)

---

## Obrazovky (Views)

### 1. 🏠 Domů / Setup
- Seznam uložených turnajových šablon
- Tlačítko „Nový turnaj" a „Spustit turnaj"
- Rychlé presety (Turbo / Standard / Deepstack)

### 2. ⚙️ Editor struktury turnaje
Tady se plánuje vše předem:
- Tabulka levelů: `# | Small | Big | Ante | Délka (min)`
- Vkládání přestávek mezi levely (např. „po levelu 4 → pauza 15 min")
- Nastavení rebuy: do kterého levelu, cena, kolik žetonů
- Nastavení add-onu
- Generátor struktury (zadám počet hráčů, délku turnaje, startovní stack → vygeneruje levely)

### 3. ⏱️ Hlavní TIMER (běžící turnaj)
Velký, čitelný na dálku (TV/projektor):
- Obří odpočet aktuálního levelu
- Aktuální blindy (SB / BB / ante) – velké
- Příští blindy (náhled „next")
- Indikátor REBUY OPEN / CLOSED
- Číslo levelu + celkový čas turnaje
- Ovládání: ▶️ Play / ⏸ Pauza / ⏭ Další level / ⏮ Předchozí
- Zvuková signalizace při změně levelu / konci rebuy
- Stav: počet hráčů, průměrný stack, total chips, prize pool

### 4. 🎰 Žetony & Chip-race
- Definice nominálů žetonů a barev
- Výpočet startovního stacku
- Chip-race kalkulačka (odebrání nejnižších nominálů)

### 5. 💰 Hráči & Prize pool (volitelně, fáze 2)
- Počet hráčů, buy-in, rebuy count → výpočet prize poolu
- Rozdělení výher (payout struktura)

---

## Datový model (návrh)

```js
Tournament = {
  id, name, createdAt,
  startingStack: 10000,
  buyIn: 1000,
  levels: [
    { type: "level", sb: 25, bb: 50, ante: 0, durationMin: 20 },
    { type: "break", durationMin: 15, label: "Přestávka" },
    ...
  ],
  rebuy:  { enabled: true, untilLevel: 6, price: 1000, chips: 10000 },
  addon:  { enabled: true, atBreak: 1, price: 1000, chips: 15000 },
  chips:  [ { value: 25, color: "green" }, { value: 100, color: "black" } ],
  players: { registered: 0, rebuys: 0, addons: 0 }
}

// Běhový stav timeru
RunState = {
  currentIndex: 0,      // index v levels[]
  remainingSec: 1200,
  isRunning: false,
  elapsedTotalSec: 0
}
```

Ukládání: **localStorage** (offline-first, žádný server).

---

## Technický stack (návrh)

- **Čisté HTML + CSS + JS** (single-page, žádný build krok) – stejně jako stávající app v repu
- Soubor `index.html` v této složce, případně rozdělené `style.css` a `app.js`
- Bez závislostí (vanilla JS), aby šlo otevřít přímo v prohlížeči i offline
- Responzivní – ovládání na mobilu/tabletu, zobrazení na velké obrazovce
- (Volitelně později) PWA – přidání na plochu, fullscreen, zvuky

---

## Navrhovaná struktura souborů

```
poker-blinds-timer/
├── PLAN.md          ← tento návrh
├── index.html       ← appka
├── style.css        ← styly (případně inline)
├── app.js           ← logika timeru + plánování
└── assets/          ← zvuky, ikony
    └── beep.mp3
```

---

## Fáze vývoje (návrh postupu)

1. **Fáze 1 – MVP timer:** editor struktury + běžící timer s odpočtem a zvedáním blindů + uložení do localStorage
2. **Fáze 2 – Rebuy/break/zvuky:** rebuy okno, přestávky, zvuková signalizace
3. **Fáze 3 – Žetony & chip-race:** kalkulačky
4. **Fáze 4 – Hráči & prize pool:** payouty, statistiky

---

## ❓ K odsouhlasení

1. **Jméno** – bereme **BlindUp**, nebo jiné z tabulky?
2. **Rozsah MVP** – stačí pro start Fáze 1 (editor + timer), nebo chceš rovnou víc?
3. **Jazyk UI** – česky, anglicky, nebo přepínač CZ/EN?
4. **Vzhled** – tmavý „casino" styl (zelená/zlatá), nebo čistý minimalistický?

Až tohle potvrdíš, pustím se do HTML appky. 🚀
