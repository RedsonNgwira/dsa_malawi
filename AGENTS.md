# AGENTS.md — DSA Malawi

## 🎯 Project Identity

- **What:** Flutter app for Direct Sales Agents in Malawi — scan documents, calculate loans, send emails.
- **Who:** Built for DSAs working with banks in Malawi (and other African markets).
- **Stack:** Flutter 3.x, Dart 3.x, Provider (state), get_it (DI), sqflite (local DB), camera, pdf, flutter_email_sender.
- **Platform target:** Android (APK builds via GitHub Actions).
- **Download page:** `https://redsonngwira.github.io/dsa_malawi/`

## 📁 Architecture — Feature-First Clean Architecture

Every file goes in one of these layers. No exceptions.

```
lib/
├── core/                    # App-wide essentials
│   ├── constants/           # AppConstants
│   ├── theme/               # AppTheme (light, dark)
│   ├── utils/               # FormatUtils
│   ├── widgets/             # Reusable shared widgets
│   └── di/                  # service_locator.dart (get_it setup)
├── data/                    # Persistence layer
│   ├── database/            # DatabaseHelper (SQLite init/migrate)
│   └── repositories/        # CRUD repos (Loans, Exports, Settings, etc.)
├── providers/               # Global ChangeNotifier providers
│   └── app_state.dart
├── services/                # Business logic
│   ├── tools/               # Image processing tools (crop, filter, etc.)
│   ├── image_processor.dart # Orchestrator
│   ├── export_service.dart  # PDF/DOCX export
│   ├── database_service.dart # Thin facade over repositories
│   ├── cloud_backup_service.dart
│   ├── connectivity_service.dart
│   ├── gps_service.dart
│   └── ocr_service.dart
├── features/                # Feature modules
│   ├── scanner/             # Camera, edge detection, image processing
│   │   ├── providers/       # ScannerController
│   │   ├── screens/         # ScanPageDto, CropToolScreen
│   │   └── widgets/         # CameraView, CornerPainter
│   ├── email/               # Email composer
│   │   └── widgets/         # EmailToolbar, PlaceholderFields, TemplatePicker
│   ├── loan_calc/           # Loan calculator
│   │   ├── services/        # LoanCalcService (pure logic)
│   │   └── widgets/         # LoanResultCard, AmortizationTable
│   ├── documents/           # Document list
│   │   └── widgets/         # DocumentCard, DocumentActionSheet
│   └── cloud_backup/        # Cloud backup screen
│       └── screens/
└── screens/                 # Top-level screens (thin UI shells)
    ├── scanner_screen.dart
    ├── loan_calc_screen.dart
    ├── documents_screen.dart
    ├── about_screen.dart
    ├── email_composer_screen.dart
    └── file_viewer_screen.dart
```

### Strict Rules

**Rule 1 — No file exceeds 200 lines.**
If a file hits 200 lines, split it. Extract widgets into `features/*/widgets/`, extract logic into `services/` or providers.

**Rule 2 — Feature-first, not type-first.**
A scanner widget goes in `features/scanner/widgets/`, not `lib/widgets/`. Shared widgets go in `core/widgets/`.

**Rule 3 — Screens are thin.**
A screen file should only compose widgets and call controllers. All business logic lives in `providers/`, `services/`, or `repositories/`.

**Rule 4 — One-way dependency chain.**
`core/` → `data/` → `services/` → `providers/` → `features/` → `screens/`
A file may never import from a layer above it. Screens may never import other screens directly.

## 💉 Dependency Injection

All services are registered in `lib/core/di/service_locator.dart` via `get_it`.

```dart
// Registering
sl.registerLazySingleton<ExportService>(() => ExportService());
sl.registerFactory<ScannerController>(() => ScannerController(
  exportService: sl<ExportService>(),
));

// Using
final svc = sl<ExportService>();
```

**Rules:**
- Services are singletons (`registerLazySingleton`).
- Controllers are factories (`registerFactory`).
- Never call `new ExportService()` or `ExportService()` in a screen/controller — always use `sl<>()` or constructor injection.
- `main.dart` gets all providers from `sl<>()`:
  ```dart
  ChangeNotifierProvider(create: (_) => sl<ConnectivityService>()),
  ChangeNotifierProvider(create: (_) => sl<CloudBackupService>()),
  ChangeNotifierProvider(create: (_) => sl<ScannerController>()),
  ```

## 🗄️ State Management

- **Provider** (ChangeNotifier) for global state: `AppState` handles settings, saved loans, export history, templates, contacts.
- **ScannerController** extends ChangeNotifier and is provided at the app level.
- **Local widget state** uses `setState` or `StatefulWidget` — fine for UI-only state.
- Never put business logic in a screen's `build` method.

## 🖼️ Image Processing

All image processing goes through `lib/services/image_processor.dart` which delegates to `services/tools/*`:

| Tool | File | Purpose |
|------|------|---------|
| CropTool | `tools/crop_tool.dart` | Auto-crop by edge detection |
| EnhanceTool | `tools/enhance_tool.dart` | Whiten, auto-level, contrast |
| FilterTool | `tools/filter_tool.dart` | Sauvola threshold, grayscale, sepia, etc. |
| PerspectiveTool | `tools/perspective_tool.dart` | Deskew, perspective correction |
| ShadowTool | `tools/shadow_tool.dart` | Remove shadows |
| NoiseTool | `tools/noise_tool.dart` | Denoise |
| ColorTool | `tools/color_tool.dart` | White balance, color correction |

Adding a new filter? Add it to `FilterTool.apply()` switch and add to `FilterPreset` enum in `image_processor.dart`.

## 📱 Scanner

The scanner flow:
1. User taps Smart Scan FAB → `SmartScannerService.scanDocument()` (native edge detection)
2. OR taps Camera → `openCamera()` → `capture()` → `ImageProcessor.autoEnhance()` (auto-crop + deskew + whiten + level + sharpen)
3. OR taps Gallery → `pickFromGallery()` → same processing pipeline
4. GPS location captured silently after each capture
5. Pages shown in reorderable grid with filter/delete/recapture actions
6. Export: PDF (full A4, landscape-aware) or DOCX (images embedded)

### Live Edge Detection

- In-app camera uses `CameraController.startImageStream()` 
- Y-plane downsampled to 40×56, Sobel-like gradient edge detection
- Document stable for ~8 frames → auto-capture
- Progress shown via amber ring around shutter button
- Green border overlay when document detected

## 🐘 Database

Local SQLite via sqflite. Migration handled by `DatabaseHelper` (version 2).

Tables:
- `saved_loans` — saved loan calculations
- `export_history` — exported file records
- `app_settings` — key-value settings (rates, theme)
- `email_templates` — email templates with `{placeholders}`
- `saved_contacts` — contact list with email/phone/role

**Rules:**
- All writes go through a Repository class in `data/repositories/`.
- `DatabaseService` is a thin facade — never add new methods to it directly, add to the appropriate repository.
- Default interest rates and fee rates seeded on first launch.

## 📧 Email Composer

- Opens via `EmailComposerScreen` with a `File` attachment
- Supports templates (placeholder substitution: `{client_name}`, `{loan_amount}`, etc.)
- Supports picking contacts from saved list
- Toggle between native email client and system share sheet (fallback)
- Templates and contacts stored in local DB

## 💰 Loan Calculator

Pure calculation logic in `LoanCalcService` — no UI dependency.

- PMT formula: `rate * PV / (1 - (1+rate)^-n)`
- Rates configurable via settings dialog (JSON editor)
- Results include amortization schedule
- Calculations can be saved and loaded
- Platinum vs Standard pricing

## 🎨 UI / Theme

- Design system: 8px grid (xs=4, sm=8, md=16, lg=24, xl=32)
- Inter font (Google Fonts)
- Material 3 — `SegmentedButton`, `NavigationBar`, `FilledButton`
- Impeller GPU renderer enabled (`android:enableImpeller="true"`)
- Dark mode + Light mode + System (persisted in settings)
- Fade transitions between tabs

## ⚙️ CI/CD

GitHub Actions at `.github/workflows/build.yml`:
- Parallel matrix builds: arm64-v8a, armeabi-v7a, x86_64
- Pub dependency caching + Gradle caching
- Separate analyze + test job
- Uses standard Flutter APK naming: `app-arm64-v8a-release.apk`
- GitHub Pages at `docs/index.html` auto-detects device architecture

## ✅ Code Quality

- `flutter analyze` must pass with **0 errors, 0 warnings** before any commit.
- Info-level lint issues should be fixed when practical.
- Every file ≤ 200 lines.
- No `print()` statements in committed code — use proper logging if needed.
- All imports relative, no circular dependencies.

## 📝 Naming Conventions

| What | Convention | Example |
|------|-----------|---------|
| Screens | `*_screen.dart` | `scanner_screen.dart` |
| Controllers | `scanner_controller.dart` | `features/scanner/providers/` |
| Services | `*_service.dart` | `export_service.dart` |
| Tools | `*_tool.dart` | `filter_tool.dart` |
| Repositories | `*_repository.dart` | `loans_repository.dart` |
| Widgets | `camel_case.dart` | `document_card.dart` |
| Models | `camel_case.dart` | `scan_page_model.dart` |
| State | `app_state.dart` | `providers/app_state.dart` |

## 🔧 Common Pitfalls

1. **Don't create services inline.** Use `sl<>()` or constructor injection.
2. **Don't put logic in build methods.** Extract to controller/service.
3. **Don't exceed 200 lines per file.** Split before you hit the limit.
4. **Don't import across screen layers.** A screen never imports another screen.
5. **Don't hardcode rates.** Use the settings dialog to configure.
6. **Don't ignore GPS errors.** GPS can fail silently — log but don't block capture.
7. **Don't use `SingleChildScrollView` in a `ListView`.** Use `slivers` or shrinkWrap.
8. **Don't block the UI thread.** Image processing runs async — show progress indicator.

## 📦 Key Dependencies

```yaml
dependencies:
  provider: ^6.0.0        # State management
  get_it: ^8.0.0           # Dependency injection
  sqflite: ^2.4.0          # Local database
  camera: ^0.11.0          # Camera access
  image: ^4.0.0            # Image processing
  image_picker: ^1.0.0     # Gallery import
  flutter_image_compress: ^2.0.0  # JPEG compression
  pdf: ^3.0.0              # PDF generation
  flutter_email_sender: ^6.0.0    # Native email
  share_plus: ^10.0.0      # Share sheet
  geolocator: ^13.0.0      # GPS
  connectivity_plus: ^6.0.0 # Network status
  path_provider: ^2.0.0    # File paths
  permission_handler: ^11.0.0 # Permissions
  google_mlkit_text_recognition: ^0.13.0  # OCR
  edge_detection_scan: ^1.0.0  # Native edge detection
```

## 📄 License

MIT — free and open source. Made with ❤️ for Malawi.
