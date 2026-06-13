# 🃏 Poker Clock – Poker Tournament Planner & Timer

> Návrh struktury aplikace. **Schválená rozhodnutí níže**, kódování začne po finálním odsouhlasení tohoto plánu.

## ✅ Odsouhlasená rozhodnutí

| Téma | Volba |
|------|-------|
| **Jméno** | **Poker Clock** |
| **Rozsah** | Funkce **zapínatelné přepínačem** (uživatel si v nastavení turnaje zvolí, co chce použít) |
| **Jazyk UI** | **Přepínač CZ / EN** |
| **Vzhled** | **Tmavý „casino"** – tmavé pozadí, zelené plátno, zlaté akcenty |

Složka projektu: `poker-clock/`

---

## K čemu appka slouží

Plánování a řízení živého pokerového turnaje:
- **Odpočet času** aktuálního levelu (blind level countdown)
- **Automatické zvedání blindů** (small / big blind + ante) podle struktury
- **Rebuy / Add-on okno** – kdy je rebuy povolený, vizuální upozornění na konec
- **Přestávky (breaks)** mezi levely
- **Žetony (chips)** – nominály, počáteční stack, hodnota, chip-race
- **Plánování struktury turnaje** předem (vytvoření a uložení šablon)

Každá z volitelných funkcí (rebuy, add-on, přestávky, žetony, prize pool) má **přepínač zap/vyp** – jednoduchý turnaj může běžet jen s blindy a časem, složitější zapne vše.

---

## Obrazovky (Views)

### 1. 🏠 Domů / Setup
- Seznam uložených turnajových šablon
- Tlačítko „Nový turnaj" a „Spustit turnaj"
- Rychlé presety (Turbo / Standard / Deepstack)
- Přepínač jazyka **CZ/EN**

### 2. ⚙️ Editor struktury turnaje
Tady se plánuje vše předem, s přepínači pro volitelné části:
- Tabulka levelů: `# | Small | Big | Ante | Délka (min)`
- **[přepínač] Přestávky** – vkládání pauz mezi levely (např. „po levelu 4 → pauza 15 min")
- **[přepínač] Rebuy** – do kterého levelu, cena, kolik žetonů
- **[přepínač] Add-on** – kdy, cena, žetony
- **[přepínač] Žetony / chip-race**
- **[přepínač] Prize pool**
- Generátor struktury (počet hráčů, délka turnaje, startovní stack → vygeneruje levely)

### 3. ⏱️ Hlavní TIMER (běžící turnaj)
Velký, čitelný na dálku (TV/projektor), tmavý casino styl:
- Obří odpočet aktuálního levelu
- Aktuální blindy (SB / BB / ante) – velké
- Příští blindy (náhled „next")
- Indikátor REBUY OPEN / CLOSED (jen pokud zapnuto)
- Číslo levelu + celkový čas turnaje
- Ovládání: ▶️ Play / ⏸ Pauza / ⏭ Další level / ⏮ Předchozí
- Zvuková signalizace při změně levelu / konci rebuy
- Stav: počet hráčů, průměrný stack, total chips, prize pool (dle zapnutých funkcí)

### 4. 🎰 Žetony & Chip-race *(volitelné)*
- Definice nominálů žetonů a barev
- Výpočet startovního stacku
- Chip-race kalkulačka (odebrání nejnižších nominálů)

### 5. 💰 Hráči & Prize pool *(volitelné)*
- Počet hráčů, buy-in, rebuy count → výpočet prize poolu
- Rozdělení výher (payout struktura)

---

## Datový model (návrh)

```js
Tournament = {
  id, name, createdAt,
  startingStack: 10000,
  buyIn: 1000,
  features: {                 // přepínače funkcí
    breaks: true, rebuy: true, addon: false,
    chips: true, prizePool: false
  },
  levels: [
    { type: "level", sb: 25, bb: 50, ante: 0, durationMin: 20 },
    { type: "break", durationMin: 15, label: "Přestávka" },
    ...
  ],
  rebuy:  { untilLevel: 6, price: 1000, chips: 10000 },
  addon:  { atBreak: 1, price: 1000, chips: 15000 },
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

// Globální nastavení
Settings = { lang: "cs" | "en", sound: true }
```

Ukládání: **localStorage** (offline-first, žádný server).

---

## Technický stack (návrh)

- **Čisté HTML + CSS + JS** (single-page, žádný build krok) – stejně jako stávající app v repu
- Bez závislostí (vanilla JS), aby šlo otevřít přímo v prohlížeči i offline
- Responzivní – ovládání na mobilu/tabletu, zobrazení na velké obrazovce
- Lokalizace CZ/EN přes slovník (`i18n` objekt) a přepínač jazyka
- Tmavý casino motiv (CSS proměnné: zelené plátno, zlatá `#d4af37`, tmavé pozadí)
- (Volitelně později) PWA – přidání na plochu, fullscreen, zvuky

---

## Navrhovaná struktura souborů

```
poker-clock/
├── PLAN.md          ← tento návrh
├── index.html       ← appka
├── style.css        ← styly (tmavý casino motiv)
├── app.js           ← logika timeru + plánování + i18n
└── assets/          ← zvuky, ikony
    └── beep.mp3
```

---

## Fáze vývoje (návrh postupu)

1. **Fáze 1 – MVP timer:** editor struktury + běžící timer s odpočtem a zvedáním blindů + uložení do localStorage + přepínač CZ/EN + tmavý casino styl
2. **Fáze 2 – Rebuy/break/zvuky:** rebuy okno, přestávky, zvuková signalizace (přes přepínače)
3. **Fáze 3 – Žetony & chip-race:** kalkulačky
4. **Fáze 4 – Hráči & prize pool:** payouty, statistiky

> Všechny volitelné funkce budou zapínatelné přepínačem, takže lze přidávat postupně bez zásahu do jednoduchého režimu.

---

## ❓ Zbývá k finálnímu odsouhlasení

Plán je hotový a zapracoval jsem všechna tvá rozhodnutí. Než začnu kódovat, potřebuju jen poslední „go":

- Souhlasíš s tímto plánem a strukturou souborů?
- Začneme **Fází 1** (editor + timer), nebo rovnou i Fází 2 (rebuy + přestávky + zvuky)?

Po tvém potvrzení se pustím do HTML appky. 🚀
