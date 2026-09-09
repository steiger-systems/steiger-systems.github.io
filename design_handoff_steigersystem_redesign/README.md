# Handoff: steigersystem.ch — Design-Überarbeitung «Blueprint»

## Überblick
Neues visuelles Design für die Website von Steiger-Systems (Renato Steiger: SPS-Programmierung, Schaltpläne, Verdrahtung, Inbetriebnahme, Eigenentwicklung TempWatch). Ziel: Besucher sollen die Leistungen schnell erfassen und eine Anfrage stellen. Stil «Blueprint»: Nachtblau statt Schwarz, weiche blaue Lichtflecken, feines Raster, Masslinien mit Zahlen und gestrichelte Pill-Konturen als Trenn-Details, grosse leichte Typografie, ein kühler Blau-Akzent. Kein Foto nötig — Struktur und Zeichnung tragen. Referenz-Design ist **Variante 10a** in `Steiger System Themes.dc.html` (Abschnitt «Turn 10»). 9a ist die Vorstufe (gleiche Seitenstruktur, schwarzer Grund, ohne Zeichnungselemente).

## Zu den Design-Dateien
Die HTML-Dateien in diesem Paket sind **Design-Referenzen** (Prototypen), kein Produktionscode. Aufgabe: Das Design 7a in der bestehenden Codebasis von steigersystem.ch nachbauen — mit deren Framework, Komponenten und Build-Setup. Falls die Seite noch kein Framework hat: statisches HTML/CSS (oder Astro) genügt vollkommen; keine schwere Abhängigkeit nötig.

Die anderen Varianten in der Datei (Turns 2–9) sind Explorationen bzw. Vorstufen und dienen nur als Kontext.

## Fidelity
**High-fidelity.** Farben, Typografie, Abstände, Linien und Layout aus 7a sind final und sollen 1:1 umgesetzt werden. Ausnahmen: Kennzahlen, Systeme, Projekte, Lebenslauf und TempWatch-Specs sind Platzhalterwerte (siehe «Offene Inhalte»).

## Design-Tokens

### Farben
- `--bg` `#0c1017` — Seitenhintergrund (Nachtblau-Schwarz)
- `--text` `#e6e7e9` — Primärtext; Hero-Titel `#f2f5fa`
- `--text-2` `#a3a7ad` — Sekundärtext, Fliesstext
- `--text-3` `#7d8289` — Mono-Labels, Meta (im Hero heller: `#c8d3e3`)
- `--draw` `#dbe6f5` — Zeichnungslinien (SVG-Strokes, Masslinien, Kreise)
- `--line` `rgba(170,200,235,.22)` — Hairlines und Raster (bläulich, nicht weiss)
- `--line-strong` `rgba(170,200,235,.38)` — gestrichelte Konturen, Hilfslinien
- `--border-btn` `rgba(170,200,235,.5)` — Outline-Buttons
- Lichtflecken (nur im Hero): `radial-gradient(420px 300px at 62% 0%, rgba(70,120,210,.55), transparent 70%)` und `radial-gradient(360px 260px at 8% 92%, rgba(60,100,180,.35), transparent 70%)`
- `--accent` `#6fb1c9` — einziger Akzent, gezielt eingesetzt: Abschnittsnummern (`0X` vor dem «/»), Index-Nummern, «STEP 0x», Kategorie-Labels im Systeme-Raster, Kreuzmarken, Jahreszahlen der Projekte, Kopflinien (`border-top` 1px) von Ablauf/Projekte/Über-mich, kurze Ticks (24×1px) über den Kennzahlen, 96×2px-Linie oben im Hero, dritte Hero-Zeile, Brand-Quadrat 8px in Nav, aktives «DE», Pfeile. Nie als grosse Fläche ausser Primär-Buttons.
- Button primär: Fläche `#6fb1c9`, Text `#0b0c0e`; hover `#8ac4d8`. Outline-Buttons unverändert.

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
- Raster im Hero: 44×44px Linien in `--line`, links auf 35 % Deckkraft abgeblendet, rechts voll: `mask-image: linear-gradient(to right, rgba(0,0,0,.35) 0 45%, #000 70%)`.
- Raster in der TempWatch-Zeichnungszelle: 32×32px in `--line`.

### Zeichnungsvokabular (wiederverwendbar)
- **Masslinie**: 1px Linie in `--draw`, an beiden Enden 12px Endstriche quer, Zahl in Plex Mono 10–11px mittig darüber (z. B. «40», «10», «80», «120», «72»). Als SVG mit `fill:none; stroke:#dbe6f5; stroke-width:1`.
- **Gestrichelte Pill-Kontur**: `border: 1px dashed var(--line-strong); border-radius: 999px`, an einer Seite offen (`border-left: none` bzw. `border-right: none`) und an die Seitenkante angedockt. Grössen im Hero: 150×36px links (top 176px), 400×40px rechts (top 34px); als Abschnitts-Detail 260×26px rechts oben am Systeme-Abschnitt.
- **Gestrichelte Hilfslinie**: horizontal 520px breit bei top 112px im Hero; vertikal von oben 280px bei right 150px.
- **Fadenkreuz**: Kreis r=16 in `--draw`, darüber vier Hilfslinien (2 diagonal, 1 vertikal, 1 horizontal) in `--line-strong`, Zahl «10» links daneben.
- **Pill mit Cursor-Skizze**: Rechteck 130×40 rx=20 in `--draw` mit Masslinie «40» oben und «10» links.
- **Tabellen-Skizze**: Winkel-Linie (horizontal 280px, dann vertikal) mit drei Kreisen r=4 in Reihe, Masslinie «80» darüber.
- Alle Zeichnungselemente sind Dekoration: `aria-hidden="true"`, `pointer-events: none`, nie über Text.

## Strukturprinzipien (statt Fotos)
- Jeder Abschnitt beginnt mit einem Mono-Label `0X / NAME` links; rechts optional ein Meta-Label (z. B. `STAND 2026`, `AUSWAHL · 2021–2026`).
- Inhalte sitzen in Hairline-Rastern: Spalten via `border-right`, Zeilen via `border-bottom`, Kopfzeile via `border-top: var(--line-strong)`.
- Kreuzmarken «+» (Plex Mono 11px, `--text-3`, 9×9px, absolut positioniert −5px) an den vier Ecken des Systeme-Rasters.
- Tabellen als Grid, nicht als `<table>`-Optik: `align-items: baseline`, Mono für Zahlen/Codes, Sans für Titel.
- Genau **ein Foto** (TempWatch). Alles andere bleibt Text + Linie.

## Seitenaufbau (Homepage 9a, von oben nach unten)

### 0. Navigation
- Höhe 64px, `border-bottom: var(--line)`, sticky optional.
- Links: Brand «STEIGER-SYSTEMS», dann Links «Leistungen · Ablauf · TempWatch · Über mich» (gap 28px).
- Rechts: Sprachumschalter `DE/EN` in Plex Mono 11.5px (aktiv `--text`, inaktiv `--text-2`), Outline-Button «Anfrage senden» (`border: 1px solid var(--border-btn)`, padding 10px 18px).
- Hover Links: Farbe → `--text`. Hover Outline-Button: Border → `rgba(255,255,255,.7)`.

### 1. Hero (Blueprint)
- Höhe 640px (Desktop), `position: relative; overflow: hidden`, Hairline unten. Ebenen von hinten nach vorn: Grund → Lichtflecken → Raster (rechts stark, links schwach) → gestrichelte Konturen/Hilfslinien → Zeichnungs-SVG (400×300px, rechts 40px, top 300px) → Navigation → Text → Meta-Zeile.
- **Navigation** liegt im Hero (Höhe 72px, kein eigener Hintergrund, keine Hairline): links Marke = Ring 22px (`border: 2px solid #e6ecf5; border-radius: 50% 50% 50% 4px`) + «STEIGER-SYSTEMS» (Plex Sans 500, 13px, ls 0.16em); Mitte Links in Plex Mono 11.5px Grossbuchstaben ls 0.06em `#c8d3e3`: Leistungen · Systeme · Projekte · TempWatch · Über mich; rechts `DE/EN` (aktiv in `--accent`) und Outline-Button «Anfrage» (Mono, `border: 1px solid rgba(170,200,235,.6)`, padding 10px 18px).
- **Kicker** (left 40px, top 250px): Plex Mono 15px Grossbuchstaben `#e6ecf5` «Steuerungstechnik · Elektronik» gefolgt von «↘» in `--accent`.
- **H1** (margin-top 22px, max-width 720px): Plex Sans 300, `clamp(56px, 6vw, 82px)`, lh 1.04, ls −0.035em, `#f2f5fa`: «Steuerungen, die im / Betrieb funktionieren.»
- **Meta-Zeile** unten (bottom 40px, 3 Spalten, Plex Mono 11.5px Grossbuchstaben lh 1.5 `#c8d3e3`): Spalte 1 «▾» in `--accent` + «Seit 2019 / Inhaber» + «Renato Steiger / Schweiz · CH / DACH» in `#e6ecf5`; Spalte 2 «Steiger-Systems / — SPS · Plan · Schrank · Anlauf»; Spalte 3 rechtsbündig Primär-Button «Leistungen ansehen» (`--accent` Fläche, Text `#0c1017`, Plex Sans 500 12.5px, padding 12px 20px).
- Lead-Absatz entfällt im Hero; die Leistungs-Kurzbeschreibung steht im Abschnitt 02.

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

### 4. Systeme & Werkzeuge (`03 / SYSTEME & WERKZEUGE` — rechts `STAND 2026`)
- Padding 64px 40px, Hairline unten. H2 «Womit ich arbeite.»
- Raster 4 Spalten × 2 Zeilen, `border-top` + `border-left` am Raster, jede Zelle `border-right` + `border-bottom`, Padding 26px 24px 28px. Kreuzmarken an den 4 Ecken.
- Zelle: Mono-Kategorie (11px, `--text-3`), Titel 16px/500, Detail 13px `--text-2`. Inhalte (Platzhalter, mit Kunde prüfen): SPS · Siemens TIA Portal · S7-1200/1500, WinCC | SPS · Codesys · IEC 61131-3 | PLANUNG · EPLAN Electric P8 | HMI · Bedienpanels | FELDBUS · Profinet · Modbus | ANTRIEBE · Frequenzumrichter | ELEKTRONIK · Eigene Hardware · KiCad, C/C++ | NORMEN · Sicherheit · EN 60204-1, ISO 13849.
- Abstand unter dem Raster 64px.

### 5. Ablauf (`04 / ABLAUF`)
- Padding 64px 40px, Hairline unten. Mono-Label, dann 4 Spalten (gap 32px, margin-top 40px) mit gemeinsamer `border-top: var(--line-strong)`, Padding-top 24px.
- Pro Spalte: `STEP 01` (Mono, `--accent`), H4, Text:
  - Gespräch — Anruf oder Besuch, Schema anschauen, Ziel klären.
  - Konzept & Offerte — Lösungsvorschlag mit Aufwand, Material und Termin.
  - Umsetzung — Programm, Plan und Schrank entstehen in der Werkstatt.
  - Anlauf & Support — Inbetriebnahme, Einweisung — und erreichbar, wenn später etwas ist.
- Unter jedem Schritt eine Mono-Metazeile (margin-top 18px): DAUER · 1 H / DAUER · 2–5 TAGE / DAUER · NACH UMFANG / VOR ORT.

### 5b. Projekte (`05 / PROJEKTE` — rechts `AUSWAHL · 2021–2026`)
- Padding 64px 40px, Hairline unten. Tabelle als Grid `72px 1.4fr 1fr 1fr 120px`, gap 24px.
- Kopfzeile Mono 11px `--text-3`, `border-top: var(--line-strong)`: JAHR · ANLAGE · BRANCHE · LEISTUNG · STEUERUNG (rechtsbündig).
- Zeilen Padding 22px 0, Hairline unten: Jahr Mono 12.5px `--text-3`, Anlage 16px/500, Branche + Leistung 14px `--text-2`, Steuerung Mono 12.5px rechtsbündig (TempWatch-Zeile in `--accent`).
- Platzhalter-Zeilen: 2026 Abfüllanlage Umbau · Lebensmittel · SPS, HMI, Inbetriebnahme · S7-1500 | 2025 Lüftungs-/Kälteanlage · Gebäudetechnik · Schaltplan, Schrank, SPS · Codesys | 2024 Prüfstand Sondermaschine · Maschinenbau · Komplett inkl. Sicherheit · S7-1200 | 2023 Temperaturüberwachung Lager · Logistik · Eigene Elektronik · TempWatch.
- Darunter Link «Alle Projekte →» (12.5px `--text-2`).

### 6. TempWatch (`06 / EIGENENTWICKLUNG`)
- Grid `1fr 400px`, Hairline unten. Links Text (Padding 64px 40px, Hairline rechts). Rechts: **Masszeichnung statt Foto** — Zelle mit 32px-Raster, mittig ein SVG 300×220: Gehäuse-Rechteck 180×110 rx=10, Display-Rechteck 90×44 in `--accent`, Drehknopf-Kreis r=9, zwei LEDs r=4, drei Klemmen-Striche unten, Masslinien «120» oben und «72» rechts, gestrichelte Hilfslinie links. Unten links Mono-Label «ZEICHNUNG / TEMPWATCH · MASSE IN MM». Fusszeile: Hairline oben, Padding 20px 24px, Mono: REV. 3 (in `--accent`) / SEIT 2023 IM EINSATZ.
- Spec-Tabelle 2×3 statt 2×2; zusätzlich SCHNITTSTELLE Modbus / Web · VERSORGUNG 24 V DC.
- H2 «TempWatch», Absatz (max 44ch): «Temperaturen messen, protokollieren, melden — bevor etwas kippt. Entstanden aus einem Kundenproblem, für das es kein Katalogprodukt gab. Platine, Firmware und Gehäuse aus einer Hand.»
- Spec-Tabelle: 2×2, Mono 12.5px, Hairlines; Label `--text-3`, Wert `--text-2`. Platzhalter: MESSBEREICH −40…+125 °C · PROTOKOLL lokal + Alarm · KANÄLE bis 8 · HERKUNFT Schweiz.
- Buttons: Primär «TempWatch ansehen», Outline «Datenblatt (PDF)».

### 7. Über mich (`07 / ÜBER MICH`)
- Grid 1fr / 1fr, Hairline unten. Links (Padding 64px 40px, Hairline rechts): H2 «Renato Steiger.», Absatz (max 44ch): «Steiger-Systems, das bin ich. Ich programmiere SPS-Steuerungen, zeichne Schaltpläne, verdrahte und nehme Anlagen in Betrieb. Daneben entwickle ich eigene Elektronik. Mir ist wichtig, dass eine Lösung im Alltag funktioniert und nicht nur auf dem Papier.»
- Rechts (Padding 64px 40px): Fakten-Liste, `border-top: var(--line-strong)`, Zeilen Padding 16px 0 mit Hairline, `justify-content: space-between`: Mono-Label links (`--text-3`), Wert rechts (13px `--text`, max-width 60%). Platzhalter: AUSBILDUNG · SEIT · SCHWERPUNKT · SPRACHEN · STANDORT — Werte vom Kunden.

### 8. Kontakt (`08 / KONTAKT`)
- Padding 72px 40px, Grid `1fr auto`, gap 48px, Hairline unten.
- H3 «Erzähl mir von deiner Anlage.», Absatz «Ein Anruf, ein Schema oder ein paar Fotos genügen. Rückmeldung innerhalb eines Arbeitstages.»
- Rechts gestapelt (min-width 240px, gap 12px): Primär «Anfrage senden», Outline Mono «+41 79 000 00 00» (tel:-Link).

### 9. Footer
- 3 Spalten mit Hairlines dazwischen, Padding 24px, Mono 11.5px lh 1.7 `--text-3`: «STEIGER-SYSTEMS / RENATO STEIGER» · «MAIL@STEIGERSYSTEM.CH / +41 79 000 00 00» · rechtsbündig «IMPRESSUM · DATENSCHUTZ / © 2026».

## Interaktion & Verhalten
- Sprache: DE Standard, EN als zweite Sprache (Inhalt übersetzen; Struktur identisch). Umschalter in der Nav.
- Alle Buttons: Transition 150ms ease auf Farbe/Border. Primär hover: Fläche `#ffffff`. Fokus: `outline: 2px solid #6fb1c9; outline-offset: 2px`.
- Keine Scroll-Animationen, keine Parallax-Effekte. Ruhe ist Teil des Designs.
- Anker-Navigation zu den Abschnitten (Leistungen, Ablauf, TempWatch, Über mich → Zitat/Über-mich-Block).

## Responsive
- ≤ 1024px: Leistungen, TempWatch, Über mich untereinander (1 Spalte), Hairline rechts entfällt; Hero-Status-Panel unter den Hero-Text als 2×2; Systeme-Raster 2 Spalten; Projekte-Tabelle: Branche/Steuerung ausblenden oder als Mono-Zeile unter dem Titel.
- Hero ≤ 1024px: Zeichnungs-SVG ausblenden, Raster bleibt, H1 min 44px, Meta-Zeile 1 Spalte, Höhe auto (Padding 120px 20px 40px).
- ≤ 768px: Kennzahlen 2×2; Ablauf 2 Spalten; Nav-Links in Menü (Burger, gleiches Hairline-Vokabular); H1 min 40px; Section-Padding 48px 20px; Zitat-Grid 1 Spalte.
- Bildband auf Mobil 260px hoch.

## Offene Inhalte (vom Kunden zu liefern)
- Keine Fotos nötig. Optional später: ein echtes TempWatch-Foto kann die Zeichnung ersetzen (dann dunkel, kontrastarm, mit gleichem Mono-Label).
- Die Masszeichnung des TempWatch ist symbolisch — mit echten Gehäusemassen ersetzen.
- Systeme/Werkzeuge, Projekte und Über-mich-Fakten: alle Werte sind Platzhalter, mit Renato Steiger verifizieren.
- Echte Kennzahlen (Jahre, Anlagen, Reaktionszeit).
- Echte TempWatch-Spezifikationen.
- Telefonnummer, E-Mail, Impressum/Datenschutz-Links.
- Englische Übersetzung der Texte.

## Assets
- Fonts: IBM Plex Sans, IBM Plex Mono über Google Fonts (oder self-hosted, empfohlen wegen Datenschutz in CH).
- Keine Icons im Design. Falls nötig: Lucide, stroke 1.5, monochrom.
- Zeichnungselemente als Inline-SVG (siehe «Zeichnungsvokabular»), keine Bitmaps.

## Dateien
- `Steiger System Themes.dc.html` — alle Varianten; **Turn 10 / Option 10a** ist die Referenz (9a = Vorstufe ohne Zeichnung).
- `uploads/` — Stimmungsreferenz des Kunden (Fremdmarke; **nicht** Logo, Name oder Layout übernehmen — nur die Bildsprache Raster/Masslinien/Lichtflecken). Öffnet direkt im Browser (benötigt `support.js` und den Ordner `_ds/` im gleichen Verzeichnis).
- `support.js`, `_ds/` — Laufzeit- und Stylesheet-Dateien für die Vorschau; nicht übernehmen.
