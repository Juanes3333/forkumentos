# Implementation Roadmap: Forkumentos (Version 1.0)

This document outlines the technical roadmap for the initial release of Forkumentos. The development process is divided into sequential, independently completable sprints. Cursor will implement exactly one sprint at a time to minimize architectural rework and ensure strict adherence to project guidelines.

---

## Sprint 1: Core Infrastructure & Application Shell

**Objective**
Establish the foundational architecture, logging, local storage, routing, and the basic application visual shell.

**Included Features**
- `core/logging/` service implementation.
- `core/storage/` key-value service interface and implementation.
- `core/theme/` definitions (colors, typography per DESIGN_SYSTEM.md).
- `app/bootstrap.dart` initialization sequence.
- `routing/` setup using `go_router` with a basic shell route.

**Excluded Features**
- Project lifecycle management.
- Any feature-specific business logic.

**Dependencies**
- None.

**Acceptance Criteria**
- The application launches on Windows to a styled, empty shell.
- Bootstrapping logs are output cleanly to the console.
- Window management (minimum size, positioning) is enforced on startup.

**Expected Commits**
- `feat: implement core logging and storage services`
- `feat: configure application theme and window constraints`
- `feat: establish application bootstrap and routing shell`

**Expected Deliverables**
A compiling, empty Flutter desktop app with a robust initialization pipeline and theming.

---

## Sprint 2: Project Lifecycle Management

**Objective**
Implement the core domain concept of a "Project", enabling the user to create, load, save, and close projects.

**Included Features**
- `features/project/domain/` models and repository interfaces.
- `features/project/data/` repository implementation (local JSON persistence).
- `shared/providers/` for the `activeProjectProvider`.
- Basic project creation, saving, and loading UI (e.g., initial welcome screen and top toolbar).

**Excluded Features**
- Autosave mechanics.
- Complex project configurations (settings).

**Dependencies**
- Sprint 1 (Storage and Routing).

**Acceptance Criteria**
- A user can create a new project.
- A user can save a project to disk.
- A user can load a project from disk, restoring the application state.
- Closing a project fully clears the `activeProjectProvider`.

**Expected Commits**
- `feat: implement project domain models and persistence`
- `feat: implement active project state management`
- `feat: add project creation and loading UI`

**Expected Deliverables**
The application can persist and restore an empty project state to and from the file system.

---

## Sprint 3: Datasource & Template Ingestion

**Objective**
Enable the application to read and parse input data (Datasource) and target schemas (Templates).

**Included Features**
- `features/datasource/` models, parsing logic (e.g., CSV reading), and providers.
- `features/template/` models, parsing logic, and providers.
- Background isolate processing for parsing large files.
- UI panels for importing and displaying the raw datasource headers and template fields.

**Excluded Features**
- Mapping logic between the datasource and the template.

**Dependencies**
- Sprint 2 (Project state, to store references to imported files).

**Acceptance Criteria**
- A user can import a CSV file and view its columns.
- A user can import a Template file and view its target fields.
- Parsing a large CSV (10,000 rows) does not freeze the UI.
- Invalid files produce clear, inline error messages.

**Expected Commits**
- `feat: implement background parsing for datasources`
- `feat: implement template schema extraction`
- `feat: add import UI panels for datasources and templates`

**Expected Deliverables**
Two populated UI panels displaying the "Source" columns and "Target" fields.

---

## Sprint 4: Core Mapping Engine

**Objective**
Implement the central business logic connecting datasource columns to template fields.

**Included Features**
- `features/mapping/domain/` mapping definitions and conflict models.
- State notifiers to manage the collection of mappings.
- Logic to detect mapping conflicts (e.g., duplicate targets, unmapped required fields).
- Basic UI for creating, editing, and deleting mappings (visual grid or list).

**Excluded Features**
- Live data preview of the mapping results.
- Complex data transformations.

**Dependencies**
- Sprint 3 (Datasource and Template schemas must be available in memory).

**Acceptance Criteria**
- A user can link a source column to a target field.
- A user can remove a mapping.
- Conflicts are accurately detected and surfaced in the state.
- Mappings are successfully serialized and saved alongside the active project.

**Expected Commits**
- `feat: implement mapping domain models and conflict detection`
- `feat: implement mapping state management`
- `feat: add visual mapping configuration UI`

**Expected Deliverables**
A functional mapping workbench where users can configure and save their mapping logic.

---

## Sprint 5: Preview Engine & Transformations

**Objective**
Provide a non-blocking, live preview of the mapping applied to the datasource, along with basic data transformations.

**Included Features**
- `features/mapping/presentation/preview/` UI components.
- Data transformation models (e.g., uppercase, trim, date formatting).
- Isolate-based computation of the preview data subset (e.g., first 50 rows).
- Staleness indicators for the preview panel.

**Excluded Features**
- Full dataset processing (only a preview subset is processed).

**Dependencies**
- Sprint 4 (Mapping definitions are required to compute the preview).

**Acceptance Criteria**
- The UI displays a live preview of the mapped data.
- Changing a mapping instantly updates the preview state to "stale" and triggers a background recomputation.
- Transformations can be applied to a mapping and their effect is visible in the preview.

**Expected Commits**
- `feat: implement data transformation models`
- `feat: implement background preview computation`
- `feat: add live preview panel to workbench UI`

**Expected Deliverables**
A reactive preview panel that gives users immediate visual feedback on their mapping configurations.

---

## Sprint 6: Export Pipeline

**Objective**
Generate the final output documents using the configured mappings and the complete datasource.

**Included Features**
- `core/commands/` implementation for export operations.
- `features/export/` progress tracking UI, validation gates, and file writing logic.
- Cancellation tokens to abort long-running exports.

**Excluded Features**
- Multiple complex export formats (start with a single format, e.g., JSON or CSV output).

**Dependencies**
- Sprint 5 (Transformations and mapping engine must be complete).

**Acceptance Criteria**
- A user can initiate an export of the entire dataset.
- The UI displays deterministic progress (percentage/rows).
- The user can cancel the export mid-way, resulting in proper file cleanup.
- The final output exactly matches the configuration defined in the mapping engine.

**Expected Commits**
- `feat: implement export command pattern and background processing`
- `feat: add export progress UI and validation gates`
- `feat: handle export cancellation and cleanup`

**Expected Deliverables**
A reliable, cancellable export pipeline capable of handling large datasets.

---

## Sprint 7: Release Candidate Polish

**Objective**
Resolve bugs, enhance the UI based on DESIGN_SYSTEM.md, and finalize the application for release.

**Included Features**
- Application settings (`features/settings/`).
- Keyboard shortcuts implementation across all panels.
- Comprehensive error handling review.
- Final UI polish (spacing, typography, animations).

**Excluded Features**
- Any new product features.

**Dependencies**
- All previous sprints must be complete and functionally sound.

**Acceptance Criteria**
- All primary actions have functional keyboard shortcuts.
- No raw exceptions are thrown to the console during normal usage.
- The application fully complies with all Cursor Rules and architectural boundaries.
- The end-to-end workflow functions flawlessly.

**Expected Commits**
- `feat: implement global application settings`
- `feat: add keyboard shortcuts for workbench navigation`
- `fix: resolve edge cases in error handling and UI layout`

**Expected Deliverables**
Forkumentos Version 1.0 Release Candidate.
