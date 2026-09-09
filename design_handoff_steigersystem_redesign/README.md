# Handoff: steigersystem.ch — Design-Überarbeitung «Enterprise-Dunkel»

## Überblick
Neues visuelles Design für die Website von Steiger-Systems (Renato Steiger: SPS-Programmierung, Schaltpläne, Verdrahtung, Inbetriebnahme, Eigenentwicklung TempWatch). Ziel: Besucher sollen die Leistungen schnell erfassen und eine Anfrage stellen. Stil: dunkel, monochrom, technisch-präzise, mit einem einzigen kühlen Blau-Akzent. Referenz-Design ist **Variante 7a** in `Steiger System Themes.dc.html` (Abschnitt «Turn 7»). Variante 8a (rein monochrom) ist eine Alternative ohne Akzent — **7a ist die gewählte Richtung.**

## Zu den Design-Dateien
Die HTML-Dateien in diesem Paket sind **Design-Referenzen** (Prototypen), kein Produktionscode. Aufgabe: Das Design 7a in der bestehenden Codebasis von steigersystem.ch nachbauen — mit deren Framework, Komponenten und Build-Setup. Falls die Seite noch kein Framework hat: statisches HTML/CSS (oder Astro) genügt vollkommen; keine schwere Abhängigkeit nötig.

Die anderen Varianten in der Datei (Turns 2–6, 8) sind verworfene Explorationen und dienen nur als Kontext.

## Fidelity
**High-fidelity.** Farben, Typografie, Abstände, Linien und Layout aus 7a sind final und sollen 1:1 umgesetzt werden. Ausnahmen: Fotos (Platzhalter), Kennzahlen und TempWatch-Specs (Platzhalterwerte, siehe «Offene Inhalte»).

## Design-Tokens

### Farben
- `--bg` `#0b0c0e` — Seitenhintergrund
- `--bg-photo` `#111417` / `#15181c` — Bildflächen-Fallback
- `--text` `#e6e7e9` — Primärtext
- `--text-2` `#a3a7ad` — Sekundärtext, Fliesstext
- `--text-3` `#7d8289` — Mono-Labels, Meta
- `--line` `rgba(255,255,255,.12)` — Hairlines (alle Trennlinien)
- `--line-strong` `rgba(255,255,255,.2)` — Ablauf-Kopflinie
- `--border-btn` `rgba(255,255,255,.35)` — Outline-Buttons
- `--accent` `#6fb1c9` — einziger Akzent: Index-Nummern, «STEP 0x», eine Kennzahl. Sparsam, nie als Fläche.
- Button primär: Fläche `#e6e7e9`, Text `#0b0c0e`

### Typografie (Google Fonts)
- `IBM Plex Sans` 300 / 400 / 500 / 600
- `IBM Plex Mono` 400 / 500
- H1: Plex Sans 300, `clamp(48px, 5.2vw, 72px)`, line-height 1.02, letter-spacing −0.035em; letzte Zeile in `--text-3`
- H2: Plex Sans 300, 40px, lh 1.1, ls −0.03em
- H3 (Kontakt): wie H2
- H4 (Ablauf-Schritte): Plex Sans 500, 17px, lh 1.3
- Leistungstitel (Index): Plex Sans 500, 17px
- Lead-Absatz: Plex Sans 400, 17px, lh 1.6, `--text-2`, max-width 56ch
- Fliesstext: Plex Sans 400, 14–15px, lh 1.6–1.65, `--text-2`
- Kennzahlen: Plex Sans 300, 34px, ls −0.03em
- Zitat: Plex Sans 300, 34px, lh 1.3, ls −0.02em, max-width 30ch
- Mono-Label (Abschnittsnummern, Meta): Plex Mono 400, 11.5px, ls 0.04em, Grossbuchstaben, `--text-3`. Format `0X / ABSCHNITT`
- Nav-Brand: Plex Sans 600, 14px, ls 0.14em, «STEIGER-SYSTEMS»
- Nav-Links: Plex Sans 400, 13px, `--text-2`
- Buttons: Plex Sans 500, 13–13.5px, ls 0.02em

### Abstände & Geometrie
- Container: max-width 1120px, seitliches Padding 40px (Desktop). Auf Mobil 20px.
- Section-Padding vertikal: 64px (Standard), Hero 96px oben / 80px unten
- **Keine Border-Radius** irgendwo (0px). Keine Schatten. Keine Verläufe ausser dem Hero-Raster-Fade.
- Hairline `1px solid var(--line)` als einziges Trennmittel; Spalten durch `border-right`, Reihen durch `border-bottom`.
- Grid im Hero: 80×80px Linien `rgba(255,255,255,.035)`, mit `mask-image: linear-gradient(to bottom, rgba(0,0,0,.9), transparent 90%)` ausblenden.

## Seitenaufbau (Homepage, von oben nach unten)

### 0. Navigation
- Höhe 64px, `border-bottom: var(--line)`, sticky optional.
- Links: Brand «STEIGER-SYSTEMS», dann Links «Leistungen · Ablauf · TempWatch · Über mich» (gap 28px).
- Rechts: Sprachumschalter `DE/EN` in Plex Mono 11.5px (aktiv `--text`, inaktiv `--text-2`), Outline-Button «Anfrage senden» (`border: 1px solid var(--border-btn)`, padding 10px 18px).
- Hover Links: Farbe → `--text`. Hover Outline-Button: Border → `rgba(255,255,255,.7)`.

### 1. Hero (`01 / STEUERUNGSTECHNIK — SCHWEIZ`)
- Padding 96px 40px 80px, Hairline unten, Raster-Hintergrund wie oben.
- Inhalt max-width 820px, linksbündig.
- Mono-Label, dann H1 (margin-top 34px):  
  «Steuerungen, die im / Betrieb funktionieren. / **Nicht nur im Plan.**» (dritte Zeile in `--text-3`)
- Lead (margin-top 34px): «SPS-Programmierung, Schaltpläne, Verdrahtung, Inbetriebnahme — und eigene Elektronik, wenn der Katalog nichts Passendes hergibt. Ein Ansprechpartner, vom Konzept bis zum Anlauf.»
- Buttons (margin-top 40px, gap 14px): Primär «Leistungen ansehen» (padding 14px 24px), Outline «Projekt besprechen».

### 2. Kennzahlenband
- 4 gleich breite Spalten, Hairlines oben/unten/zwischen den Spalten, Padding 28px 32px (erste Spalte links 40px).
- Zahl 34px/300, darunter Mono-Label (margin-top 12px):  
  `15+ / JAHRE AUTOMATION`, `120 / ANLAGEN IN BETRIEB`, `1 / ANSPRECHPARTNER`, `≤ 1 Tag / BIS ZUR RÜCKMELDUNG` (letzte Zahl in `--accent`).

### 3. Leistungen (`02 / LEISTUNGEN`)
- Zweispaltig: links 0.9fr (Padding 64px 40px, Hairline rechts), rechts 1.1fr.
- Links: Mono-Label, H2 «Vier Bereiche, / eine Verantwortung.», Absatz (max 38ch): «Programm, Plan, Schrank und Anlauf aus einer Hand — damit an der Schnittstelle nichts verloren geht.»
- Rechts: 4 Zeilen als Index-Tabelle, jede `grid-template-columns: 64px 1fr 1.3fr`, gap 24px, padding 28px 40px, Hairline zwischen Zeilen, `align-items: baseline`.  
  Spalte 1 Mono-Nummer in `--accent`, Spalte 2 Titel 17px/500, Spalte 3 Text 14px `--text-2`:
  1. SPS-Programmierung — Neuanlagen und Umbauten — strukturiert, dokumentiert, lesbar für den nächsten Techniker.
  2. Schaltpläne & Planung — Elektroplanung mit Materialliste und Revision. Plan und Schrank stimmen überein.
  3. Aufbau & Verdrahtung — Schaltschränke sauber gebaut, beschriftet und geprüft, bevor sie die Werkstatt verlassen.
  4. Inbetriebnahme — Vor Ort testen, messen, nachjustieren, bis es im Alltag läuft. Übergabe mit Einweisung.
- Hover Zeile: Hintergrund `rgba(255,255,255,.03)`; ganze Zeile verlinkt auf Leistungs-Unterseite/Anker.

### 4. Bildband
- Volle Breite, Höhe 420px, Hairline unten. Foto (Schaltschrank, verdrahtet), dunkel, `object-fit: cover`, ggf. Overlay `rgba(0,0,0,.35)`.
- Unten links (40px / 32px) Mono-Bildunterschrift.

### 5. Ablauf (`03 / ABLAUF`)
- Padding 64px 40px, Hairline unten. Mono-Label, dann 4 Spalten (gap 32px, margin-top 40px) mit gemeinsamer `border-top: var(--line-strong)`, Padding-top 24px.
- Pro Spalte: `STEP 01` (Mono, `--accent`), H4, Text:
  - Gespräch — Anruf oder Besuch, Schema anschauen, Ziel klären.
  - Konzept & Offerte — Lösungsvorschlag mit Aufwand, Material und Termin.
  - Umsetzung — Programm, Plan und Schrank entstehen in der Werkstatt.
  - Anlauf & Support — Inbetriebnahme, Einweisung — und erreichbar, wenn später etwas ist.

### 6. TempWatch (`04 / EIGENENTWICKLUNG`)
- Zweispaltig 1fr / 1fr, Hairline unten. Links Text (Padding 64px 40px, Hairline rechts), rechts Foto (min-height 420px).
- H2 «TempWatch», Absatz (max 44ch): «Temperaturen messen, protokollieren, melden — bevor etwas kippt. Entstanden aus einem Kundenproblem, für das es kein Katalogprodukt gab. Platine, Firmware und Gehäuse aus einer Hand.»
- Spec-Tabelle: 2×2, Mono 12.5px, Hairlines; Label `--text-3`, Wert `--text-2`. Platzhalter: MESSBEREICH −40…+125 °C · PROTOKOLL lokal + Alarm · KANÄLE bis 8 · HERKUNFT Schweiz.
- Buttons: Primär «TempWatch ansehen», Outline «Datenblatt (PDF)».

### 7. Zitat
- Padding 72px 40px, Hairline unten. Grid `1fr 260px`, gap 64px, `align-items: end`.
- Zitat: «Mir ist wichtig, dass eine Lösung im Alltag funktioniert — nicht nur auf dem Papier.»
- Rechts: Hairline, «Renato Steiger» (14px/500), Mono «INHABER · STEIGER-SYSTEMS».

### 8. Kontakt (`05 / KONTAKT`)
- Padding 72px 40px, Grid `1fr auto`, gap 48px, Hairline unten.
- H3 «Erzähl mir von deiner Anlage.», Absatz «Ein Anruf, ein Schema oder ein paar Fotos genügen. Rückmeldung innerhalb eines Arbeitstages.»
- Rechts gestapelt (min-width 240px, gap 12px): Primär «Anfrage senden», Outline Mono «+41 79 000 00 00» (tel:-Link).

### 9. Footer
- Padding 22px 40px, Mono 11.5px `--text-3`, zwei Seiten: «STEIGER-SYSTEMS · RENATO STEIGER · STEIGERSYSTEM.CH» / «IMPRESSUM · DATENSCHUTZ».

## Interaktion & Verhalten
- Sprache: DE Standard, EN als zweite Sprache (Inhalt übersetzen; Struktur identisch). Umschalter in der Nav.
- Alle Buttons: Transition 150ms ease auf Farbe/Border. Primär hover: Fläche `#ffffff`. Fokus: `outline: 2px solid #6fb1c9; outline-offset: 2px`.
- Keine Scroll-Animationen, keine Parallax-Effekte. Ruhe ist Teil des Designs.
- Anker-Navigation zu den Abschnitten (Leistungen, Ablauf, TempWatch, Über mich → Zitat/Über-mich-Block).

## Responsive
- ≤ 1024px: Leistungen und TempWatch untereinander (1 Spalte), Hairline rechts entfällt, Index-Zeilen `56px 1fr` mit Text darunter.
- ≤ 768px: Kennzahlen 2×2; Ablauf 2 Spalten; Nav-Links in Menü (Burger, gleiches Hairline-Vokabular); H1 min 40px; Section-Padding 48px 20px; Zitat-Grid 1 Spalte.
- Bildband auf Mobil 260px hoch.

## Offene Inhalte (vom Kunden zu liefern)
- Fotos: Inbetriebnahme/Anlage (Hero-Hintergrund optional), Schaltschrank verdrahtet (Bildband), TempWatch-Gerät, Porträt Renato Steiger. Dunkel, kontrastarm, gern leicht entsättigt.
- Echte Kennzahlen (Jahre, Anlagen, Reaktionszeit).
- Echte TempWatch-Spezifikationen.
- Telefonnummer, E-Mail, Impressum/Datenschutz-Links.
- Englische Übersetzung der Texte.

## Assets
- Fonts: IBM Plex Sans, IBM Plex Mono über Google Fonts (oder self-hosted, empfohlen wegen Datenschutz in CH).
- Keine Icons im Design. Falls nötig: Lucide, stroke 1.5, monochrom.

## Dateien
- `Steiger System Themes.dc.html` — alle Varianten; **Turn 7 / Option 7a** ist die Referenz. Öffnet direkt im Browser (benötigt `support.js` und den Ordner `_ds/` im gleichen Verzeichnis).
- `support.js`, `_ds/` — Laufzeit- und Stylesheet-Dateien für die Vorschau; nicht übernehmen.
