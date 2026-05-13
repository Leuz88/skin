# Skin Analyzer Pro — Documentazione Completa

## Indice

1. [Cos'è questo progetto](#1-cosè-questo-progetto)
2. [Come funziona il software originale](#2-come-funziona-il-software-originale)
3. [Architettura del dispositivo hardware](#3-architettura-del-dispositivo-hardware)
4. [Come funziona il programma Flutter](#4-come-funziona-il-programma-flutter)
5. [Struttura dei file](#5-struttura-dei-file)
6. [Cosa rimane da fare per farlo funzionare](#6-cosa-rimane-da-fare-per-farlo-funzionare)
7. [Troubleshooting](#7-troubleshooting)

---

## 1. Cos'è questo progetto

**Skin Analyzer Pro** è una app Flutter per Windows Desktop che si collega all'analizzatore cutaneo fisico *Skin Observed System* (distribuito da varie marche in Cina/Asia) e visualizza i risultati dell'analisi della pelle in modo professionale, con:

- Grafici circolari animati per ognuno degli 8 parametri
- Radar chart a 8 assi
- Gestione pazienti (anagrafica, storico scansioni)
- Export PDF del referto (formato A4)
- Interfaccia medica pulita in Material 3

Il progetto è un **reverse engineering + reimplementazione** del software originale `Skin_Plus.exe` — software Windows Forms scritto in C# che veniva fornito col dispositivo.

---

## 2. Come funziona il software originale

### 2.1 Stack tecnologico del software originale

Il software originale (`C:\Program Files (x86)\Skin Observed System\Skin_Plus.exe`) è un'applicazione **.NET Framework 4.0** (Windows Forms, 32-bit) che usa le seguenti DLL:

| DLL | Ruolo |
|---|---|
| `Skin_Plus.exe` | Frontend Windows Forms C# |
| `SkinDetector.dll` | Motore di analisi — contiene gli 8 algoritmi detector |
| `Geb.Image.dll` | Libreria di computer vision per elaborazione immagini |
| `DataBase.mdb` | Database MS Access (Jet OLEDB 4.0) per pazienti e risultati |

### 2.2 Come avviene la connessione al dispositivo

Il dispositivo si identifica sul bus USB con:
- **VendorID: `0x0555`**
- **ProductID: `0x0160`**

Identificato tramite diagnostica HID (il vecchio `0x0AC8` / `0x5678` trovato nel binario non corrisponde all'hardware reale).

Il dispositivo è **fisicamente una webcam USB** con un tasto/sensore touch integrato. Viene enumerato dal sistema operativo come **dispositivo HID** (Human Interface Device), esattamente come un mouse o tastiera, quindi non richiede driver particolari.

### 2.3 Come avviene l'analisi della pelle

**L'analisi è basata su immagini, NON su segnali elettrici raw.**

Questo è il punto più importante da capire: il dispositivo non misura direttamente i parametri cutanei con sensori. Funziona così:

```
Dispositivo fisico
      │
      ├─ Webcam USB ──────→ Cattura frame video della pelle
      │                     (illuminate da LED del dispositivo)
      │
      └─ HID Interface ──→ Segnale "tasto premuto" per avviare scan
```

La DLL `SkinDetector.dll` riceve l'immagine dalla webcam e la elabora tramite `Geb.Image.dll`. Per ogni parametro esiste una classe `*Detector` con un metodo `Detect(image)` che restituisce un punteggio **da 0.0 a 9.9**.

### 2.4 I parametri analizzati e cosa misurano

| # | Parametro | Cosa misura visivamente |
|---|---|---|
| 1 | **Umidità** | Riflettanza superficiale — pelle secca appare diversamente |
| 2 | **Olio/Sebo** | Zone brillanti/lucide nell'immagine |
| 3 | **Texture** | Irregolarità della superficie cutanea |
| 4 | **Fibra Collagene** | Analisi cromatica dello strato dermico visibile |
| 5 | **Rughe** | Rilevamento bordi/solchi nell'immagine |
| 6 | **Pigmentazione** | Macchie, discromie, variazioni di colore |
| 7 | **Sensibilità** | Rossori, eritemi, variazioni vascolari |
| 8 | **Pori** | Dimensione e densità dei pori nella texture |

### 2.5 Il database originale

File: `C:\Program Files (x86)\Skin Observed System\DataBase\DataBase.mdb`  
Password Jet OLEDB: **`33560`**  
Driver richiesto: **Jet OLEDB 4.0 (32-bit)** — solo accessibile da process a 32-bit.

Tabelle principali:

| Tabella | Contenuto |
|---|---|
| `Examer` | Anagrafica pazienti (nome, età, sesso) |
| `MeasData` | Misurazioni grezze |
| `Result` | Risultati analisi con 8 score |
| `SetValue` | Configurazione soglie |
| `ResultMark` | Range di giudizio (Eccellente/Buono/Medio/Scarso/Critico) |

Le foto della pelle vengono salvate in:  
`C:\Program Files (x86)\Skin Observed System\DataBase\Picture\<ID_paziente>\`

### 2.6 Il funzionamento passo-passo del software originale

```
1. Avvio app → connessione al dispositivo USB (VID 0AC8, PID 5678)
2. Operatore seleziona paziente nel database
3. Operatore preme il tasto touch sull'analizzatore (o UI)
4. Il firmware del dispositivo invia segnale HID al PC
5. Skin_Plus.exe riceve il segnale e avvia acquisizione video
6. La webcam cattura 1 o più frame della zona cutanea
7. I frame vengono passati a SkinDetector.dll
8. Ogni Detector elabora l'immagine e produce uno score 0.0-9.9
9. I risultati vengono salvati nel database MDB
10. L'interfaccia mostra grafici e suggerimenti
```

---

## 3. Architettura del dispositivo hardware

```
┌─────────────────────────────────────────┐
│        ANALIZZATORE CUTANEO             │
│                                         │
│  ┌─────────┐    ┌─────────────────────┐ │
│  │  LED    │    │  Sensore / Webcam   │ │
│  │ bianchi │    │  CMOS (Z-Star)      │ │
│  │ + UV    │    │  VID:0AC8 PID:5678  │ │
│  └────┬────┘    └──────────┬──────────┘ │
│       │ illumina           │ acquisisce  │
│       └─────────→ PELLE ←─┘            │
│                                         │
│  ┌─────────────────────────────────────┐│
│  │  Tasto Touch / Trigger              ││
│  │  → segnale HID sul bus USB          ││
│  └─────────────────────────────────────┘│
└────────────────────┬────────────────────┘
                     │ USB 2.0
                     ▼
              PC Windows
         (driver HID standard,
          nessun driver extra)
```

Il dispositivo si connette tramite **un solo cavo USB** che trasporta:
- Il flusso video (UVC — USB Video Class)
- Il segnale HID del tasto

---

## 4. Come funziona il programma Flutter

### 4.1 Architettura generale

```
lib/
├── main.dart              → Entry point, MultiProvider setup
├── app.dart               → MaterialApp + tema
├── theme/app_theme.dart   → Colori, font Inter, ThemeData
│
├── models/
│   ├── scan_result.dart   → SkinParam enum, SkinResult, range giudizi
│   └── patient.dart       → Patient model
│
├── providers/             → State management (Provider pattern)
│   ├── device_provider.dart   → Gestisce connessione USB + polling
│   ├── scan_provider.dart     → Storico scansioni, paziente selezionato
│   └── patient_provider.dart  → CRUD pazienti
│
├── services/
│   ├── hid_service.dart   → Comunicazione USB HID via FFI + win32
│   └── report_service.dart → Generazione PDF (libreria pdf/printing)
│
├── screens/
│   ├── home_screen.dart      → NavigationRail principale
│   ├── scan_screen.dart      → Schermata scansione
│   ├── report_screen.dart    → Visualizzazione risultati + export
│   └── patients_screen.dart  → Gestione anagrafica pazienti
│
└── widgets/
    ├── skin_gauge.dart        → Gauge circolare animato (CustomPainter)
    ├── radar_chart.dart       → Radar chart a 8 assi (CustomPainter)
    ├── scan_animation.dart    → Animazione durante acquisizione
    ├── device_status_badge.dart → Indicatore connessione dispositivo
    └── parameter_card.dart    → Card singolo parametro
```

### 4.2 Flusso di una scansione nell'app Flutter

```
Utente preme "Avvia Scansione"
         │
         ▼
DeviceProvider.triggerScan()
         │
         ├─ [SIMULATION MODE = true]
         │   └─ dopo 3 secondi genera 8 score casuali (1.5–8.5)
         │
         └─ [SIMULATION MODE = false — da implementare]
             └─ HidService.instance.readReport()
                 │ legge 65 byte HID
                 └─ HidService.parseScores() → 8 double
                     │
                     ▼
         onScanComplete(List<double> scores)
                     │
                     ▼
         ScanProvider._onScanData()
             │ crea SkinResult con score + resultNos
             │ inserisce in cima alla lista storico
             └─ notifyListeners()
                     │
                     ▼
         HomeScreen naviga automaticamente → ReportScreen
             │ mostra gauge, radar chart, suggerimenti
             └─ tasto "Esporta PDF" → ReportService.generateAndPrint()
```

### 4.3 Come funziona la connessione USB nell'app

Il file `lib/services/hid_service.dart` usa **Win32 FFI** (Foreign Function Interface) per comunicare direttamente con Windows senza driver aggiuntivi:

```
hid_service.dart
    │
    ├─ hid.dll         → HidD_GetHidGuid(), HidD_GetAttributes()
    │                    (caricata direttamente con DynamicLibrary.open)
    │
    └─ setupapi.dll    → SetupDiGetClassDevs(), SetupDiEnumDeviceInterfaces()
       (tramite win32 package)
```

**Algoritmo di ricerca dispositivo:**
1. `HidD_GetHidGuid` → ottieni GUID della classe HID
2. `SetupDiGetClassDevs` → lista tutti i dispositivi HID connessi
3. Per ognuno: `SetupDiGetDeviceInterfaceDetail` → path del device
4. `CreateFile` temporaneo → `HidD_GetAttributes` → legge VID/PID
5. Se VID=`0x0AC8` e PID=`0x5678` → apre con `FILE_FLAG_OVERLAPPED`
6. `ReadFile` asincrona + `WaitForSingleObject` con timeout 3 secondi

### 4.4 Modalità attuale: SIMULAZIONE

Attualmente `_simulationMode = true` in `device_provider.dart`.

In questa modalità:
- Il dispositivo appare **sempre connesso** (senza hardware reale)
- La scansione genera **8 score casuali** dopo 3 secondi
- Tutte le funzionalità UI sono testabili senza l'analizzatore fisico

---

## 5. Struttura dei file

```
C:\SkinAnalyzer\
├── lib/                   → Codice sorgente Dart
├── windows/               → Codice platform Windows (C++, CMake)
│   └── runner/            → Entry point Win32 nativo
├── assets/                → Risorse (immagini, font — attualmente vuote)
├── test/                  → Test (placeholder)
├── pubspec.yaml           → Dipendenze Flutter
├── analysis_options.yaml  → Regole linter
├── setup.ps1              → Script PowerShell per setup ambiente
└── PROGETTO.md            → Questo file
```

### Dipendenze principali (pubspec.yaml)

| Pacchetto | Versione | Uso |
|---|---|---|
| `win32` | ^5.5.1 | Win32 API (HID, SetupDI, File I/O) |
| `ffi` | ^2.1.3 | FFI Dart ↔ C/C++ |
| `provider` | ^6.1.2 | State management |
| `fl_chart` | ^0.69.0 | Grafici (non usato direttamente, CustomPainter) |
| `pdf` | ^3.11.1 | Generazione PDF |
| `printing` | ^5.13.1 | Stampa/anteprima PDF |
| `google_fonts` | ^6.2.1 | Font Inter |
| `intl` | ^0.19.0 | Formattazione date |
| `path_provider` | ^2.1.4 | Directory documenti (salvataggio PDF) |
| `uuid` | ^4.4.2 | ID univoci per pazienti/scansioni |
| `shared_preferences` | ^2.3.2 | Persistenza impostazioni |

---

## 6. Cosa rimane da fare per farlo funzionare

### PASSO 1 — Installare Visual Studio C++ Workload *(BLOCCANTE)*

Flutter Windows compila il runner nativo con MSVC. VS 2022 è installato ma **manca il workload "Desktop development with C++"**.

**Soluzione A — tramite VS Installer (raccomandato):**
1. Apri **Visual Studio Installer** dal menu Start
2. Clicca **Modifica** su "Visual Studio Community 2022"
3. Seleziona **"Sviluppo di applicazioni desktop con C++"**
4. Assicurati che siano selezionati:
   - MSVC v143 (o superiore)
   - Windows 10 SDK (10.0.19041.0 o superiore)
5. Clicca **Modifica** e aspetta il download (~3-5 GB)

**Soluzione B — da PowerShell (Amministratore):**
```powershell
& "C:\Program Files (x86)\Microsoft Visual Studio\Installer\vs_installer.exe" modify `
  --installPath "C:\Program Files\Microsoft Visual Studio\2022\Community" `
  --add Microsoft.VisualStudio.Workload.NativeDesktop `
  --includeRecommended --quiet --norestart
```

**Verifica:**
```powershell
flutter doctor
# Deve mostrare: [✓] Visual Studio - develop Windows apps (Visual Studio Community 2022 17.x)
```

---

### PASSO 2 — Prima compilazione e test in simulazione

Dopo aver installato il workload C++:

```powershell
cd C:\SkinAnalyzer
flutter pub get
flutter run -d windows
```

L'app si avvierà in **simulation mode** — il dispositivo appare connesso e le scansioni generano dati casuali. Testa che tutto funzioni:
- [ ] Navigazione tra le tre sezioni (Scansione / Pazienti / Referti)
- [ ] Aggiunta di un paziente
- [ ] Esecuzione di una scansione (tasto "Avvia Scansione")
- [ ] Visualizzazione gauge e radar chart
- [ ] Export PDF

---

### PASSO 3 — Connettere il dispositivo fisico e calibrare i byte HID

Questo è il passo **più critico** per il funzionamento reale.

#### 3a. Abilitare la modalità reale

In `lib/providers/device_provider.dart`, riga ~22:
```dart
// PRIMA (simulation):
bool _simulationMode = true;

// DOPO (reale):
bool _simulationMode = false;
```

Poi decommentare il blocco `_checkDevice()` reale (~riga 62) che usa `HidService`.

#### 3b. Capire cosa mandano i byte HID

**Il problema:** Non sappiamo esattamente il formato dei dati HID che il dispositivo manda.

Ci sono due scenari possibili:

**Scenario A — Il dispositivo manda SOLO il segnale del tasto (più probabile)**
Il dispositivo è una webcam. La maggior parte dei frame dati passa attraverso il protocollo video (UVC), NON HID. Il report HID contiene solo il segnale del pulsante touch (1 byte = 0x01 quando premuto).

In questo caso `parseScores()` non è il posto giusto — gli score devono venire dall'analisi del frame video della webcam, non dai byte HID.

**Scenario B — Il dispositivo manda i punteggi preprocessati via HID**
Alcuni dispositivi di questo tipo hanno un microcontrollore interno che elabora il segnale e invia direttamente i valori numerici.

#### 3c. Come scoprire qual è il caso reale (USB Sniffing)

**Installa Wireshark + USBPcap:**
1. Scarica [USBPcap](https://desowin.org/usbpcap/) e installalo
2. Apri Wireshark → seleziona interfaccia `USBPcap1` (o simile)
3. Avvia il software **originale** `Skin_Plus.exe`
4. Esegui una scansione reale
5. Filtra in Wireshark: `usb.idVendor == 0x0ac8`
6. Cattura i pacchetti durante e dopo la scansione

**Cosa cercare nei pacchetti:**
- Se vedi pacchetti HID con payload di 8+ byte con valori 0-255 → **Scenario B** → aggiorna `parseScores()`
- Se i pacchetti HID hanno solo 1-2 byte → **Scenario A** → serve accesso webcam

#### 3d. Se serve la webcam (Scenario A)

Aggiungere al progetto:
```yaml
# pubspec.yaml
dependencies:
  camera_windows: ^0.2.1+6
  # oppure usare direttamente MediaFoundation via FFI
```

Il flusso diventa:
```
Tasto HID premuto → apri stream webcam → cattura frame →
analisi immagine → 8 score
```

---

### PASSO 4 — Integrare il database originale (opzionale)

Il database MS Access originale contiene i pazienti già inseriti.  
Per importarli nell'app Flutter, creare uno script di migrazione:

```powershell
# Connessione al DB originale (PowerShell 32-bit)
$conn = New-Object System.Data.OleDb.OleDbConnection
$conn.ConnectionString = "Provider=Microsoft.Jet.OLEDB.4.0;Data Source='C:\Program Files (x86)\Skin Observed System\DataBase\DataBase.mdb';Jet OLEDB:Database Password=33560"
```

Esportare i pazienti da `Examer` e i risultati da `Result` in JSON, poi importarli nell'app tramite `PatientProvider.addPatient()`.

---

### PASSO 5 — Build release

Quando tutto funziona:
```powershell
cd C:\SkinAnalyzer
flutter build windows --release
```

L'eseguibile finale si trova in:
```
build\windows\x64\runner\Release\skin_analyzer.exe
```

Per distribuirlo, copia tutta la cartella `Release\` (include le DLL necessarie).

---

## 7. Troubleshooting

### `flutter build windows` fallisce con "CMake not found"
→ Installare il workload VS C++ (vedi Passo 1)

### L'app parte ma il dispositivo non viene trovato
```dart
// Aggiungi log temporaneo in hid_service.dart findAndOpen():
debugPrint('Device path: $devicePath');
debugPrint('VID: ${attributes.ref.VendorID.toRadixString(16)}');
```
→ Verifica che VID/PID corrispondano

### `HidD_GetAttributes` restituisce 0 (false)
→ Prova ad aprire il device con accesso `GENERIC_READ` invece di `0` nella chiamata temporanea

### Il dispositivo viene trovato ma `readReport` va in timeout
→ Il device non sta mandando dati HID spontaneamente. Conferma che il tasto fisico viene premuto, oppure invia un report di output per richiedere dati.

### PDF non si genera
→ Assicurati che `path_provider` abbia permessi di scrittura. Su Windows, i documenti vanno in `%USERPROFILE%\Documents\`.

---

## Riepilogo stato attuale

| Componente | Stato |
|---|---|
| UI completa (gauge, radar, pazienti, PDF) | ✅ Funzionante |
| Simulation mode | ✅ Funzionante |
| Compilazione Windows | ⛔ Bloccata (manca VS C++ workload) |
| Connessione HID reale | ⚠️ Implementata ma da testare con hardware |
| Byte mapping HID | ⚠️ Provvisorio — da calibrare o sostituire con webcam |
| Import dati da DB originale | ⬜ Non implementato |

**Priorità assoluta: installare il workload VS C++ e fare `flutter run -d windows`.**
