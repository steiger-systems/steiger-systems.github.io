# Hunt

Versteckspiel in echt für Freundesrunden: Runner verstecken sich, Hunter jagen sie,
die App verrät die Runner in regelmässigen Pings. Bauplan: [PLAN.md](PLAN.md).

```
hunt/
├── supabase/
│   ├── config.toml          Supabase-CLI (anonyme Anmeldung an)
│   ├── migrations/          Schema, RLS, Lobby, Spiellogik, pg_cron
│   └── sql-tests/           Datenbank-Tests (laufen lokal gegen Postgres)
├── scripts/test_db.sh       wendet alle Migrationen an und testet
└── app/                     Flutter-App (Android + iOS)
```

## Stand

| Phase | Inhalt | Stand |
| --- | --- | --- |
| 1 Setup | Schema + RLS als Migrationen, Flutter-Grundgerüst | fertig, DB getestet |
| 2 Lobby | Spiel erstellen, Code joinen, Teams, Einstellungen, Presence | fertig |
| 3 Karte + Standort | Live-Karte eigenes Team, Hintergrund-Standort | fertig, auf Geräten zu testen |
| 4 Spiellogik | Vorsprung, Pings, Rundenende serverseitig (pg_cron) | fertig, DB getestet |
| 5 Zone + Tags | schrumpfende Zone, 30-s-Regel, Tag mit Bestätigung, Host entscheidet | fertig, DB getestet |
| 6 Push (FCM) | | offen (Tabelle `push_tokens` + RPC sind schon da) |
| 7 Chat + Statistik | Team-Chat, Statistik am Ende | fertig |
| 8 Funk (LiveKit) | | offen |

Die Datenbank-Logik ist mit 89 Tests abgedeckt. Die Flutter-App ist geschrieben, aber
**noch nie kompiliert**: Bei der Entwicklung gab es kein Flutter-SDK. Beim ersten
`flutter analyze` können also noch kleine Fehler auftauchen.

### Entscheidungen zu den offenen Punkten aus dem Plan

- **Zuschauer-Modus:** Einstellung pro Spiel. Standard: Getaggte sehen alle Positionen.
  Aus: Getaggte sehen nur das, was die Hunter sehen. Zuschauer können den Team-Chat
  lesen, aber nicht schreiben.
- **Tags:** Runner bestätigt oder lehnt ab. Abgelehnte Tags und Tags ohne Antwort
  nach 30 s entscheidet der Host.
- **Push-Tokens** liegen in einer eigenen Tabelle, damit andere Spieler sie nie lesen können.

## Regeln, die der Server durchsetzt

- Clients dürfen nur **lesen**, und das nur, was RLS erlaubt. Alles andere läuft über RPCs.
- Hunter sehen Runner **nie** live aus `locations`, nur über `pings`. Ausnahme: ein Runner
  ist länger als 30 s ausserhalb der Zone.
- Runner sehen Hunter nie (ausser nach Spielende).
- Vorsprung, Pings, Zone und Rundenende laufen über `private.game_tick()` (pg_cron, alle 5 s).
- Spiele samt Standortdaten werden nach 7 Tagen gelöscht (pg_cron, täglich).

## Backend einrichten (Supabase)

1. Projekt auf [supabase.com](https://supabase.com) anlegen (Free Tier, Region Zürich/Frankfurt).
2. **Authentication → Sign In / Providers → Anonymous sign-ins** einschalten.
3. **Database → Extensions → pg_cron** aktivieren.
4. Migrationen einspielen:
   ```bash
   cd hunt
   supabase login
   supabase link --project-ref <project-ref>
   supabase db push
   ```
5. Unter **Project Settings → API** die Project URL und den `anon`-Key notieren.

Datenbank-Tests lokal (braucht nur ein Postgres mit Superuser, kein Supabase):

```bash
PGUSER=postgres hunt/scripts/test_db.sh
```

## App einrichten

Einmalig die Plattform-Ordner erzeugen (sie sind nicht im Repo):

```bash
cd hunt/app
flutter create --org ch.steigersystems --project-name hunt --platforms android,ios .
rm -f test/widget_test.dart   # Beispieltest von flutter create, passt nicht zur App
flutter pub get
```

### Android: `android/app/src/main/AndroidManifest.xml`

Innerhalb von `<manifest>`, vor `<application>`:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION"/>
<uses-permission android:name="android.permission.WAKE_LOCK"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
```

Der Standort läuft über einen Foreground Service (Benachrichtigung „Hunt läuft“), so
funktioniert er auch bei gesperrtem Handy.

### iOS: `ios/Runner/Info.plist`

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Hunt teilt deinen Standort während eines Spiels mit deinem Team.</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>Damit das Spiel auch bei gesperrtem iPhone weiterläuft, braucht Hunt den Standort „Immer“.</string>
<key>UIBackgroundModes</key>
<array>
  <string>location</string>
</array>
```

### Starten

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<anon-key>
```

Tests und Analyse:

```bash
flutter analyze
flutter test
```

## Testen mit 2 Handys

1. Handy A: Name eingeben, **Spiel erstellen**. Code notieren.
2. Handy B: Name + Code, **Beitreten**. Beide sehen sich in der Lobby (grüner Punkt = App offen).
3. A (Host): B per Tippen zum Runner machen, **Zone auf Karte setzen**, in den Einstellungen
   zum Testen kurze Zeiten wählen (Vorsprung 0–1 Min., Ping 1 Min.).
4. **Spiel starten**. Prüfen: B sieht A nie. A sieht B nur als Ping (mit Alter), ausser B
   steht länger als 30 s ausserhalb der Zone.
5. A tippt **Getaggt!** → B bestätigt → Spiel endet, Statistik erscheint.

## Pakete

Nur die aus dem Plan: `supabase_flutter`, `flutter_riverpod`, `go_router`, `flutter_map`
(+ `latlong2`, das flutter_map voraussetzt), `geolocator`, `flutter_localizations`/`intl`.
UI-Texte (Deutsch) stehen in `app/lib/l10n/app_de.arb`.
