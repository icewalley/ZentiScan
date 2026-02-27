
# Zenti iOS Sjekkliste-app

iOS-app for vedlikeholdssjekklister med Apple Intelligence og objektdeteksjon.

## Funksjoner

### 🔍 Smart Scan (Apple Intelligence)
- **Live objektdeteksjon** med Vision framework
- **Automatisk utstyrsidentifisering** basert på kamerastrøm
- **TFM-kode parsing** (=360.01-PU001 format)
- **NS3457 Part 8 mapping** til norske standardkoder

### 📷 Kode Scan
- QR-kode og strekkode scanning
- Tekstgjenkjenning for utstyrsmerker
- VisionKit DataScanner integrasjon

### 📋 Sjekkliste-generering
- Dynamisk generering basert på NS3457-kode
- AI-anbefalinger fra Andrea
- Kritikalitetsbasert sortering
- Estimert tidsbruk

### ✅ Registrering
- Status per sjekkpunkt (OK/AVVIK/IKKE VURDERT)
- Måleverdier med enheter
- Foto-dokumentasjon
- Avviksoppfølging

## Prosjektstruktur

```
ios-sources/
├── ProprixiOSApp.swift          # Hovedapp med NavigationStack
├── Models/
│   ├── Models.swift             # Basis datamodeller
│   └── EquipmentModels.swift    # Utstyrs- og deteksjonsmodeller
├── Services/
│   ├── APIManager.swift         # Backend-kommunikasjon
│   └── ObjectDetectionService.swift  # Vision & Core ML
└── Views/
    ├── ScannerView.swift        # Basis kode-scanning
    ├── SmartScannerView.swift   # AI-drevet objektdeteksjon
    ├── EquipmentDetailView.swift # Utstyrsdetaljer
    ├── ChecklistView.swift      # Sjekkliste-utfylling
    └── GeneratedChecklistView.swift # Generert sjekkliste
```

## Oppsett i Xcode

### 1. Opprett nytt prosjekt
```
File → New → Project → iOS App
- Product Name: ZentiChecklist
- Interface: SwiftUI
- Language: Swift
- Minimum Deployments: iOS 17.0
```

### 2. Importer filer
Dra alle mapper (`Models`, `Services`, `Views`) og `ProprixiOSApp.swift` inn i Xcode.

### 3. Info.plist-tillatelser
Legg til følgende i Info.plist:

| Nøkkel | Verdi |
|--------|-------|
| `NSCameraUsageDescription` | Kamera brukes til å identifisere utstyr |
| `NSSpeechRecognitionUsageDescription` | Talegjenkjenning for hands-free registrering |
| `NSMicrophoneUsageDescription` | Mikrofon for stemmekommandoer |

### 4. Backend-konfigurasjon
Oppdater `APIManager.swift` med riktig backend-URL:

```swift
// For Simulator
private let baseURL = "http://localhost:3000/api"

// For fysisk enhet (bruk Mac's IP)
private let baseURL = "http://192.168.1.X:3000/api"
```

## Backend API Endpoints

Appen bruker følgende API-endepunkter:

| Endpoint | Metode | Beskrivelse |
|----------|--------|-------------|
| `/api/ios/detect` | POST | Bildeanalyse for utstyrsdeteksjon |
| `/api/ios/generate-checklist` | POST | Generer sjekkliste for NS3457-kode |
| `/api/ios/submit-checklist` | POST | Send inn sjekklistresultater |
| `/api/lookup` | GET | Slå opp sjekkpunkter for kode |

## NS3457 Kodeoversikt

| Kode | Navn | Kategori |
|------|------|----------|
| PU | Pumpe | Rør/Sanitær |
| VF | Vifte | Ventilasjon |
| VL | Ventil | Rør/Sanitær |
| MO | Motor | Elektro |
| SE | Sensor | Styring |
| SL | Brannslukker | Brann |
| RA | Radiator | Oppvarming |
| KL | Kjølemaskin | Kjøling |

## Krav

- **iOS 17.0+** (grunfunksjonalitet)
- **iOS 18.0+** (full Apple Intelligence)
- **Xcode 15+**
- **Swift 5.9+**

## Utvikling

### Kjøre på Simulator
1. Start backend: `cd apps/web && pnpm dev`
2. Åpne prosjektet i Xcode
3. Velg iPhone 15 Pro Simulator
4. Trykk Run (⌘R)

### Kjøre på fysisk enhet
1. Koble til iPhone via USB
2. Oppdater `baseURL` i `APIManager.swift`
3. Velg enheten som target
4. Trykk Run (⌘R)

## Testing

```bash
# Backend API-tester
cd apps/web && pnpm test

# Check API endpoints
curl http://localhost:3000/api/ios/detect
curl http://localhost:3000/api/ios/generate-checklist
```

## Lisens

Proprietær - Zenti AS
