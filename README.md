<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="assets/logo/forkumentosLight.png">
    <source media="(prefers-color-scheme: light)" srcset="assets/logo/forkumentosDark.png">
    <img src="assets/logo/forkumentosDark.png" width="180" alt="Forkumentos Logo">
  </picture>
</p>

<h1 align="center">
  Forkumentos
</h1>

<p align="center">
  <em>Generate hundreds of personalized documents in seconds.</em>
</p>

<p align="center">

  <img src="https://img.shields.io/badge/Flutter-Desktop-02569B?style=for-the-badge&logo=flutter&logoColor=white">

  <img src="https://img.shields.io/badge/Platform-Windows-0078D6?style=for-the-badge&logo=windows&logoColor=white">

  <img src="https://img.shields.io/badge/Version-1.0-5B8DEF?style=for-the-badge">

  <img src="https://img.shields.io/badge/License-MIT-success?style=for-the-badge">

</p>

---

> **Forkumentos** is a desktop application that automates document generation from DOCX or PDF templates using CSV or Excel data sources. Map once, preview instantly and export hundreds of personalized documents in just a few clicks.

---

**Version 1.0.0**

Forkumentos is a Windows desktop application for mapping spreadsheet fields onto DOCX or PDF document templates, previewing filled results per data row, and exporting batches of documents.

Projects are portable `.fork` archives that embed the template, datasource, and mappings so you can reopen the same work on another machine.

---

## Main features

- Portable `.fork` projects with embedded template and datasource
- Visual field mapping with undo/redo
- Live preview against any datasource row
- Batch export to DOCX, PDF, or both, with optional ZIP packaging
- Drag-and-drop import and multi-window project handling on Windows

---

## Screenshots

> Place screenshots under `docs/screenshots/` and update the paths below when available.

| Screen | Preview |
|--------|---------|
| Landing | ![Landing Page](docs/screenshots/landing.png) |
| Workbench | ![Workbench](docs/screenshots/workbench.png) |
| Mapping / Review | ![Review](docs/screenshots/review.png) |
| Export | ![Export](docs/screenshots/export.png) |
| Settings | ![Settings](docs/screenshots/settings.png) |

---

## Features

### Project management

- Create, open, save, and save-as projects
- Recent projects list (with prune of missing files and “show in Explorer”)
- Confirm before closing when there are unsaved changes
- Multi-window: with a project already open, **New / Open / Recent** start another process so the current project is not replaced
- Double-click a `.fork` file in Explorer to launch Forkumentos and open that project (per-user file association registered on Windows startup)

### Embedded `.fork` projects

- ZIP-based project format (`.fork`) containing:
  - project metadata
  - mappings
  - embedded template file
  - embedded datasource file
- Opening a project restores embedded resources into a local cache and can enter the workbench when both template and datasource are present

### Templates

- Import **DOCX** or **PDF** templates
- Replace the active template from the ribbon or by drag-and-drop
- Document viewer with zoom, fit, page navigation, and mapping highlights
- PDF text is loaded through Syncfusion; multi-column bands are reconstructed as tables when geometry allows (heuristic)

### Datasources

- Import **CSV** or **XLSX**
- Header detection, row preview, and empty-column detection
- XLSX uses the first sheet that has non-empty headers
- Replace the active datasource from the ribbon or by drag-and-drop

### Mapping

- Assign spreadsheet columns to selectable text ranges in the template
- Multiple occurrences per field
- Field status (pending / assigned / incomplete)
- Validation for overlaps and invalid assignments before export
- Undo / redo (`Ctrl+Z` / `Ctrl+Y`)

### Review mode

- Dedicated review workflow in the workbench
- Inspector of mapped fields alongside the document
- Toggle between mapping review rendering and preview rendering

### Preview

- Builds a filled document from the current template, mappings, and selected datasource row
- Navigate rows and **Refresh Preview** to regenerate the visible document (same pipeline as Preview Mode)

### Export engine

- Export **DOCX**, **PDF**, or **both** (DOCX export is disabled when the template itself is a PDF)
- Row ranges: current row, all rows, or a custom range
- Progress dialog with cancel support
- Optional ZIP of generated files
- Soft validation gate for inconsistent mappings before export starts

### Filename builder

- Compose export names from literal text blocks and datasource fields
- Automatic `_` separators between adjacent blocks
- Drag-and-drop reorder of blocks with live filename preview

### Drag & drop

- Drop DOCX/PDF templates, CSV/XLSX datasources, or `.fork` projects onto the window
- Overlay feedback during drag; files are classified by extension

### Themes & branding

- Light, dark, and system theme
- Theme-aware logos and Windows application icon
- Splash screen and About dialog (version, license, author, website)

### Settings

Persisted application settings (see [Settings](#settings) below). The autosave **interval** is stored for future use; the autosave engine is not active in 1.0.

### Workspace

Default workspace under `Documents/Forkumentos` with folders for projects, exports, cache, and logs. The workspace root is configurable in Settings.

---

## Technology

| Layer | Choice |
|-------|--------|
| UI / platform | Flutter Desktop (Windows) |
| Language | Dart 3.12+ |
| State | Riverpod (`flutter_riverpod`) |
| Navigation | `go_router` |
| Models | `freezed` + `json_serializable` |
| Window | `window_manager` |
| Files | `file_picker`, `path_provider`, `path`, `desktop_drop` |
| CSV / XLSX | `csv`, `excel` |
| DOCX (ZIP/XML) | `archive`, `xml` |
| PDF load | `syncfusion_flutter_pdf` |
| PDF export | `pdf` |
| Logging | `logger` |
| Analysis | `very_good_analysis` |

Architecture is **feature-first** (`lib/features/*`) with shared models/providers and a routing/workbench shell that orchestrates cross-feature flows (for example export). Features do not import each other directly.

---

## Installation

### Requirements

- [Flutter SDK](https://docs.flutter.dev/get-started/install/windows) (stable, **3.44.6** or compatible with `sdk: ^3.12.2`)
- [Visual Studio 2022](https://visualstudio.microsoft.com/) with the **Desktop development with C++** workload
- Git
- Windows 10/11 (x64)

### Clone and run

```bash
git clone https://github.com/Juanes3333/forkumentos.git
cd forkumentos
flutter pub get
flutter run -d windows
```

### Release build

```bash
flutter build windows
```

The executable is produced under `build/windows/x64/runner/Release/`.

On first run, Forkumentos registers the `.fork` extension for the **current** executable (per-user `HKCU`). Double-clicking a `.fork` file opens that project. If you switch between debug and release builds, run the build you want associated so the registration points at the right binary.

---

## Usage

1. **Create a project** from the landing screen (or File → New in another window).
2. **Import a template** (DOCX or PDF) via the wizard, ribbon, or drag-and-drop.
3. **Import a datasource** (CSV or XLSX) the same way.
4. **Start working** to enter the workbench when both resources are ready.
5. **Map fields**: select text in the document and assign datasource columns; use Review Mode to inspect coverage.
6. **Preview**: switch to Preview Mode, change rows, and use Refresh Preview to regenerate the filled document.
7. **Save** the project as a `.fork` file (Save / Save As).
8. **Export**: choose format, destination, row range, filename pattern, and optional ZIP; review the summary when finished.

Closing the window with unsaved changes prompts according to Settings.

---

## Project structure

```
forkumentos/
├── assets/
│   ├── icons/          # Application .ico branding
│   ├── images/
│   └── logo/           # Theme-aware SVG logos
├── docs/               # Spec, architecture, design system, playbooks
├── lib/
│   ├── app/            # Bootstrap, splash, root App
│   ├── core/           # Commands, theme, storage, workspace, Windows/launch helpers
│   ├── features/
│   │   ├── project/    # .fork load/save, welcome, lifecycle
│   │   ├── template/   # DOCX/PDF template import
│   │   ├── datasource/ # CSV/XLSX import
│   │   ├── mapping/    # Assignments, review, undo/redo
│   │   ├── preview/    # Row-based filled document preview
│   │   ├── export/     # DOCX/PDF/ZIP export + filename builder
│   │   ├── document_viewer/
│   │   └── settings/   # Persisted AppSettings UI
│   ├── routing/        # Router, phases, workbench chrome, DnD, export launcher
│   ├── shared/         # Document model, providers, widgets
│   └── main.dart
├── test/               # Unit and widget tests
├── windows/            # Flutter Windows runner, icon, version resources
├── CHANGELOG.md
└── LICENSE
```

---

## Supported formats

### Templates

| Format | Role |
|--------|------|
| `.docx` | Template import, preview, DOCX and PDF export |
| `.pdf` | Template import and preview; export as PDF only |

### Datasources

| Format | Role |
|--------|------|
| `.csv` | Spreadsheet import |
| `.xlsx` | Spreadsheet import (first sheet with headers) |

### Output

| Format | Role |
|--------|------|
| `.docx` | Generated documents (DOCX templates only) |
| `.pdf` | Generated documents |
| `.zip` | Optional archive of generated files |
| `.fork` | Portable project archive |

---

## Settings

Settings are organized in four tabs:

| Tab | Options |
|-----|---------|
| **General** | Workspace root (default `Documents/Forkumentos`), derived Projects / Exports paths |
| **Appearance** | Theme: dark, light, or system |
| **Behavior** | Open most recent project on startup; recent list limit (1–50); confirm before closing; autosave interval (persisted only — engine not active in 1.0) |
| **Export** | Default format (DOCX / PDF / both); default “create ZIP” |

Settings persist in application support storage across sessions.

---

## Roadmap

### Version 1.1

- Autosave engine (interval already configurable)
- Windows installer (MSI/Inno) with stable `.fork` association
- Stronger PDF table reconstruction for complex layouts

### Version 1.2

- Packaged release channel and update notes
- Additional export naming / destination conveniences
- Performance and fidelity polish for large DOCX/PDF/XLSX workloads

---

## License

This project is licensed under the [MIT License](LICENSE).

---

## Credits

Forkumentos is developed by **Juan Restrepo**.

It targets professional desktop document workflows: keep templates and data local, map visually, preview row by row, and export batches without a separate mail-merge stack.

- Repository: [github.com/Juanes3333/forkumentos](https://github.com/Juanes3333/forkumentos)
- Version: **1.0.0**
