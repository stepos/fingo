# 🃏 Poker Clock

Tmavá „casino" webová appka pro plánování a řízení živých pokerových turnajů.
Čisté HTML/CSS/JS, **funguje offline**, bez instalace – stačí otevřít `index.html` v prohlížeči.

## Funkce
- ⏱️ **Hlavní timer** – velký odpočet levelu, aktuální i příští blindy, celkový čas, ovládání play/pauza/další/předchozí/reset
- ⚙️ **Editor struktury** – tabulka levelů (SB/BB/ante/délka), presety Turbo / Standard / Deepstack
- 🤖 **Doporučovač** – po zadání počtu hráčů navrhne odpočet (délku a počet levelů) i sadu žetonů
- 🔀 **Zapínatelné funkce** – přestávky, rebuy, add-on, žetony/chip-race, prize pool
- 🎰 **Žetony** – nominály a barvy, výpočet potřebného počtu žetonů
- 💰 **Prize pool** – výpočet bance a rozdělení výher podle počtu hráčů
- 🔊 **Zvuková signalizace** při změně levelu (Web Audio, lze vypnout)
- 🌐 **Přepínač CZ / EN**
- 💾 Turnaje se ukládají do prohlížeče (localStorage)

## Spuštění
Otevři `index.html` v prohlížeči. Pro zobrazení na TV/projektoru přepni do fullscreenu (F11).

## Soubory
- `index.html` – struktura a obrazovky
- `style.css` – tmavý casino motiv
- `app.js` – logika timeru, editor, doporučovač, i18n
- `PLAN.md` – původní návrh struktury
