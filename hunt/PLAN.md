# Hunt – Bauplan für Claude Code

Stand: 5. November 2026

Eigenes Versteckspiel in echt nach dem Vorbild von SCRAM (com.scram.app): Runner verstecken sich, Hunter jagen sie, die App verrät die Runner in regelmässigen Pings. Arbeitstitel **Hunt**, für Android und iOS, nur für Freundesrunden. Eigener Code, eigene Texte, eigenes Design.

## 1. Ziel & Entscheidungen

| Thema | Entscheidung |
| --- | --- |
| Zweck | Privat für Freunde, kein Store, kein Bezahlmodell |
| Name | Arbeitstitel „Hunt“ |
| Plattformen | Android + iOS mit einer Codebasis (Flutter) |
| Backend | Supabase |
| MVP | Pings, Zone (schrumpfend), Tags, Team-Funk, Team-Chat, Statistik |

## 2. Spielablauf

1. **Lobby:** Host erstellt Spiel → 6-stelliger Code → Freunde joinen mit Code und Namen (kein Account nötig).
2. **Setup:** Host verteilt Teams (Hunter/Runner), setzt Rundenlänge, Vorsprung, Ping-Intervall und Zone auf der Karte.
3. **Vorsprung:** Runner verstecken sich, Hunter sehen nichts (Countdown).
4. **Runde:** Jedes Team sieht die eigenen Leute live. Hunter bekommen alle X Minuten einen Ping mit der Position jedes Runners und dem Alter des Pings. Runner sehen Hunter nie.
5. **Zone:** Schrumpft nach Zeitplan. Wer sie verlässt, ist nach 30 s live für Hunter sichtbar, bis er zurück ist.
6. **Tag:** Hunter berührt Runner in echt → tippt „Getaggt“ → Runner bestätigt → Runner ist raus (wird Zuschauer).
7. **Ende:** Alle Runner getaggt (Hunter gewinnen) oder Zeit abgelaufen (verbleibende Runner gewinnen) → Statistik.

## 3. Features

| # | Feature | Phase | Notizen |
| --- | --- | --- | --- |
| 1 | Lobby mit Code, Teams, Host-Einstellungen | MVP | kein Login, anonyme Supabase-Auth |
| 2 | Live-Karte eigenes Team | MVP | |
| 3 | Pings für Hunter | MVP | serverseitig, Host kann abschalten |
| 4 | Tags mit Bestätigung | MVP | |
| 5 | Schrumpfende Zone | MVP | optional pro Spiel |
| 6 | Push-Benachrichtigungen (auch gesperrt, Vibration) | MVP | Ping, Zone, Tag, Spielende |
| 7 | Team-Chat (Text) | MVP | |
| 8 | Team-Funk (Push-to-Talk) | MVP, als letzte Phase | technisch am aufwändigsten |
| 9 | Spielstatistik | MVP | Gewinner, Überlebenszeit, Distanz, Tags |
| 10 | Tutorial | später | |

## 4. Tech-Stack

- **App:** Flutter (Dart), State Management mit Riverpod, Navigation mit go_router
- **Backend:** Supabase – anonyme Auth, Postgres, Realtime (Broadcast + Presence), Edge Functions, Row Level Security, pg_cron für Pings und Zone
- **Karte:** flutter_map mit OpenStreetMap-Kacheln (gratis, kein Google-API-Key)
- **Standort:** geolocator; Android mit Foreground Service, iOS mit „Immer“-Berechtigung und Background Mode „Location“
- **Push:** Firebase Cloud Messaging (Android + iOS über APNs), ausgelöst von einer Supabase Edge Function
- **Funk:** LiveKit (Cloud-Gratisstufe), ein Audio-Raum pro Team, Token über Edge Function

## 5. Datenmodell (Entwurf)

| Tabelle | Wichtige Felder |
| --- | --- |
| games | id, code, host_id, status (lobby/headstart/running/ended), settings (JSON), started_at, ends_at |
| players | id, game_id, name, team (hunter/runner), status (active/tagged/spectator), push_token |
| locations | player_id, game_id, lat, lng, accuracy, updated_at (nur letzte Position) |
| location_track | player_id, lat, lng, ts (für Distanz-Statistik) |
| pings | id, game_id, runner_id, lat, lng, captured_at |
| tags | id, game_id, hunter_id, runner_id, status (pending/confirmed/rejected), ts |
| zone_state | game_id, center_lat, center_lng, radius_m, next_shrink_at |
| messages | id, game_id, team, player_id, text, ts |

## 6. Spiellogik & Fairness

- **Server entscheidet, nicht die App:** Pings, Zone, Rundenende laufen über pg_cron/Edge Functions. So kann niemand mogeln, indem er die App manipuliert.
- **RLS ist Pflicht:** Hunter dürfen Runner-Positionen nur über die Tabelle `pings` lesen, nie live aus `locations`. Ausnahme: Runner ausserhalb der Zone seit über 30 s.
- **Standort-Updates:** alle 5–10 s während der Runde, sonst aus. Akku im Blick behalten.
- **Zone:** Mittelpunkt + Radius, schrumpft linear in Stufen. Aus-der-Zone-Prüfung serverseitig.
- **Tag:** Hunter meldet, Runner bestätigt innert 30 s; ohne Antwort entscheidet der Host.
- **Datenschutz:** Spiele und Standortdaten nach 7 Tagen automatisch löschen (pg_cron).

**Standardwerte:** Runde 30 Min., Vorsprung 5 Min., Ping alle 3 Min., Zone 1 km Radius, schrumpft alle 5 Min. um 15 %.

## 7. Screens

- Start: Spiel erstellen / Code eingeben
- Lobby: Spielerliste, Teams, Host-Einstellungen, Zone auf Karte setzen
- Spiel: Karte (eigenes Team live, Pings mit Alter, Zone), Timer, Tag-Button, Funk-Taste, Chat
- Zuschauer: Karte mit allen Positionen (für Getaggte)
- Ende: Gewinner, Statistik, Replay der Wege (später)

**Design:** Dark Theme, klare Farben für Teams (Hunter rot, Runner blau), grosse Buttons für Bedienung beim Rennen.

## 8. Umsetzungsphasen für Claude Code

1. **Setup:** Flutter-Projekt, Supabase-Projekt, Schema + RLS als SQL-Migrationen
2. **Lobby:** Spiel erstellen, Code joinen, Teams, Einstellungen (Realtime Presence)
3. **Karte + Standort:** eigene Position, Team live, Hintergrund-Standort auf Android und iOS
4. **Spiellogik:** Vorsprung, Pings, Rundenende serverseitig
5. **Zone + Tags**
6. **Push-Benachrichtigungen** (FCM)
7. **Team-Chat + Statistik**
8. **Team-Funk** mit LiveKit

Regeln für Claude Code:

- Nach jeder Phase lauffähig, mit 2 Handys testen, Git-Commit
- Datenbankänderungen nur als Migrationen, RLS-Policies mit Tests
- Code/Kommentare Englisch, UI-Texte Deutsch (Flutter-Lokalisierung)
- Keine neuen Pakete ohne Rückfrage

## 9. Offene Punkte

- [ ] **iOS-Build:** braucht einen Mac (oder Cloud-Build wie Codemagic) und für TestFlight einen Apple-Developer-Account (99 USD/Jahr). Ohne das können iPhone-Freunde die App nicht installieren.
- [ ] Standardwerte oben passen?
- [ ] Funk wirklich im MVP oder erst nach dem ersten Testspiel?
- [ ] Zuschauer-Modus für Getaggte: alle Positionen sehen oder nur Hunter-Sicht?

## 10. Kosten

| Posten | Kosten |
| --- | --- |
| Supabase | gratis (Free Tier) |
| Firebase (nur Push) | gratis |
| LiveKit Cloud | gratis bis zum Freikontingent |
| OpenStreetMap-Kacheln | gratis bei kleiner Nutzung |
| Apple Developer | 99 USD/Jahr (nur für iOS) |
