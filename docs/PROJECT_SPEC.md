# Forkumentos

> **Project Specification**
>
> Version: 1.0 (Draft)
>
> Status: Active Development
>
> License: MIT
>
> Platform: Windows Desktop
>
> Framework: Flutter
>
> Language: English (Documentation)
>
> Application Language (V1): Spanish
>
> Offline-first: Yes

---

# 1. Vision

## 1.1 Purpose

Forkumentos is an open-source desktop application designed to transform a single document template into hundreds or even thousands of personalized documents through an intuitive visual workflow.

Unlike traditional mail merge solutions, Forkumentos does not require users to understand placeholders, merge fields, scripting, or Microsoft Word's correspondence tools.

The application guides the user through every step of the process, making document automation accessible to anyone regardless of their technical knowledge.

Forkumentos focuses on one objective:

> Allow users to automate documents without having to learn document automation.

---

## 1.2 Product Identity

The name **Forkumentos** originates from the metaphor of a fork.

A fork begins as a single handle and branches into multiple prongs.

Likewise, Forkumentos starts with a single document template and generates multiple personalized documents.

This metaphor defines the identity of the project and should guide future design decisions.

Whenever a new feature is proposed, the following question should be asked:

> Does this feature help users generate many documents from one template?

If the answer is no, the feature probably does not belong in Forkumentos.

---

# 2. Product Philosophy

Forkumentos is not trying to compete with Microsoft Word.

It is not intended to become another document editor.

Instead, it specializes in a single workflow and aims to perform it exceptionally well.

The application follows five fundamental principles.

## Simplicity

The interface should remain understandable for users with no technical experience.

Every action should be guided.

Every workflow should have a logical order.

No feature should require reading documentation before use.

---

## Predictability

The application should never surprise the user.

Actions should always produce the expected result.

Automatic decisions should be minimized.

Whenever an assumption would be required, the application should ask the user instead.

---

## Visual Configuration

Users should configure document automation by interacting directly with the document.

No placeholder syntax.

No merge codes.

No scripting.

No formulas.

The document itself becomes the configuration interface.

---

## Performance

Performance is considered a feature.

The application must remain responsive regardless of project size.

Generating one thousand documents should never freeze the interface.

Background processing is mandatory.

---

## User Control

Forkumentos assists the user.

It never replaces their judgement.

Warnings are encouraged.

Restrictions are minimized.

If the user intentionally decides to perform an action that is technically valid, the application should allow it.

---

# 3. Product Goals

The primary objective of Forkumentos is to allow any user to convert an existing DOCX template into a reusable automation project.

To achieve this, the application must provide:

- A guided workflow.
- Instant visual feedback.
- Reliable document generation.
- Professional document fidelity.
- Offline operation.
- High performance.
- Minimal learning curve.

Success is measured not by the number of available features, but by how easily a first-time user can complete their first project.

---

# 4. Non-Goals

The following features are intentionally excluded from Version 1.

These exclusions are not limitations of the technology, but conscious product decisions.

Forkumentos will NOT become:

- A document editor.
- A replacement for Microsoft Word.
- A cloud service.
- A collaborative platform.
- A CRM.
- A database manager.
- A spreadsheet editor.

Version 1 will also exclude:

- OCR.
- Plugin support.
- Image replacement.
- QR code generation.
- Digital signatures.
- Password protected PDFs.
- Watermarks.
- Scheduled exports.
- Online synchronization.
- Multi-user collaboration.

These features may be evaluated for future versions but must not influence Version 1 architecture.

---

# 5. Target Audience

Forkumentos is designed primarily for users who repeatedly generate documents based on structured information.

Typical users include:

- Administrative assistants.
- Human resources departments.
- Educational institutions.
- Law firms.
- Accounting offices.
- Property managers.
- Healthcare administrators.
- Government offices.
- Small businesses.
- Freelancers.

The expected technical level of the average user is low.

Therefore, every feature should prioritize discoverability over flexibility.

Whenever two implementations are technically equivalent, the simpler user experience should always be preferred.

---

# 6. Core Principles

The following principles are considered immutable throughout the project.

## 6.1 Offline First

The application must work entirely without an internet connection.

No online services shall be required during normal operation.

---

## 6.2 Local Ownership

Users own their projects.

Projects are stored locally.

Templates remain local.

Databases remain local.

Generated documents remain local.

Forkumentos never uploads user information.

---

## 6.3 One Project = One Workflow

Each project represents exactly one automation process.

One template.

One data source.

One mapping configuration.

Attempting to support multiple templates within the same project would introduce unnecessary complexity and is therefore outside the scope of Version 1.

---

## 6.4 Read-Only Documents

Forkumentos never edits document content.

Documents are displayed in read-only mode.

Users may:

- Select text.
- Assign fields.
- Remove assignments.
- Review assignments.

Users may not:

- Edit text.
- Change fonts.
- Modify images.
- Edit tables.
- Insert paragraphs.

Document editing belongs to external applications such as Microsoft Word.

Forkumentos focuses exclusively on document automation.

---

# 7. Functional Overview

Forkumentos is composed of six primary modules.

Each module is independent but designed to work as part of a single guided workflow.

The application shall not expose all functionality at once.

Instead, it should progressively guide the user through the document automation process.

The modules are:

1. Project Management
2. Template Management
3. Data Source Management
4. Field Mapping
5. Review & Preview
6. Export

Every project follows this sequence.

The application should always encourage users to complete the current step before moving to the next one.

---

# 8. Project Management

## 8.1 Definition

A project represents a complete document automation workflow.

A project stores every resource required to reproduce the automation process without depending on external files.

Projects should therefore be portable.

A user should be able to send a project file to another person who has Forkumentos installed and continue working immediately.

---

## 8.2 Project Contents

Every project contains:

- Template document.
- Data source.
- Field mappings.
- Export settings.
- User preferences related to the project.
- Cached preview information.
- Metadata.

The original template and spreadsheet shall be embedded inside the project.

Deleting the original files must not affect the project.

---

## 8.3 Project Lifecycle

Projects may exist in one of the following states.

### Empty

No template.

No data source.

Only project metadata exists.

---

### Draft

Template and/or data source loaded.

Mappings incomplete.

Export unavailable.

---

### Ready

All required mappings completed.

Project ready for export.

---

### Exporting

Documents are currently being generated.

Certain actions become temporarily unavailable.

The interface must remain responsive.

---

## 8.4 Creating a Project

Creating a project shall always start with an empty project.

The application does not automatically ask for files immediately.

Instead, users arrive at an empty workspace where the next required actions are clearly indicated.

---

## 8.5 Opening Projects

Recently opened projects should appear on the home screen.

Each project card should contain:

- Project name.
- Last modified date.
- Embedded thumbnail generated from the first page.
- Current project status.

Example:

Ready

Draft

Missing Data Source

Missing Template

---

## 8.6 Saving

Projects should be automatically saved.

The application shall perform silent autosaves after significant changes.

Examples include:

- Loading a template.
- Loading a spreadsheet.
- Creating a mapping.
- Removing a mapping.
- Updating project settings.

Users may also manually save using:

Ctrl + S

or

File → Save.

---

## 8.7 Save As

The application shall support:

Save

Save As

Duplicate Project

Duplicating creates an entirely independent project.

---

## 8.8 Project Compatibility

If a user replaces the spreadsheet with another one:

The application compares column headers.

Three scenarios exist.

### Scenario A

Every header matches.

All mappings remain valid.

---

### Scenario B

Some headers match.

Matching mappings remain.

Missing headers become pending.

New headers require assignment.

The application presents a comparison summary before applying the changes.

Example:

Headers detected: 15

Matching: 13

Missing: 2

New: 4

---

### Scenario C

No meaningful match exists.

The user receives a warning.

Existing mappings are discarded only after confirmation.

---

## 8.9 Project File

Version 1 introduces a dedicated project format.

The internal implementation is intentionally abstracted from users.

Users interact only with project files.

Internal storage format may evolve in future versions without affecting the user experience.

---

# 9. Template Management

## 9.1 Supported Formats

Version 1 supports:

DOCX

Additional formats may be added later.

PDF templates are intentionally excluded from Version 1.

---

## 9.2 Loading Templates

Templates may be loaded through:

File picker.

Drag & Drop.

Recent files.

Replacing an existing template.

---

## 9.3 Document Integrity

Forkumentos must preserve every visual element contained within the template.

Including:

- Fonts.
- Paragraph formatting.
- Tables.
- Images.
- Headers.
- Footers.
- Page numbering.
- Lists.
- Alignment.
- Margins.
- Page breaks.
- Sections.

The generated documents should visually match the original template.

---

## 9.4 Ignored Content

Forkumentos ignores:

Word comments.

Tracked changes.

Mail Merge fields.

Hidden editing metadata.

These elements should never appear inside the application.

---

## 9.5 Read Only Mode

The document viewer is strictly read-only.

Editing capabilities are intentionally unavailable.

Users cannot:

Delete text.

Insert text.

Modify formatting.

Resize images.

Move objects.

Edit tables.

This limitation is a fundamental design principle.

---

## Technical Constraints

Version 1 intentionally avoids introducing internal placeholder syntaxes.

Document mappings are stored externally as project metadata.

The imported DOCX remains unchanged throughout the entire workflow.

Generated documents are created by applying the mapping metadata during export.

The original template is never modified.

---

# 10. Data Source Management

## 10.1 Supported Formats

CSV

XLSX

---

## 10.2 Data Detection

After importing a spreadsheet, Forkumentos automatically detects:

Column headers.

Total records.

Preview row.

Empty columns.

Duplicate headers.

Potential formatting issues.

---

## 10.3 Preview

The interface always displays:

Column names.

First data row.

This preview exists solely to help users understand what each field represents.

A permanent notice should clarify:

"This preview represents only the first record. All rows will be used during export."

---

## 10.4 Header Validation

Every column header must be unique.

Duplicate headers are not allowed.

The application shall request the user to correct duplicates before continuing.

---

## 10.5 Empty Columns

Completely empty columns may be ignored automatically.

The application should ask for confirmation before excluding them.

---

## 10.6 Large Files

There is no artificial row limit.

The application must remain responsive regardless of spreadsheet size.

Large datasets should be processed lazily whenever possible.

---

## 10.7 Missing Values

Empty cells are considered valid.

When exported:

The corresponding placeholder becomes empty.

No error should be generated.

---

## 10.8 Data Editing

Forkumentos never edits spreadsheet data.

Users wishing to modify information must do so using their preferred spreadsheet application.

Forkumentos acts only as a consumer of structured data.

---

# 11. Workspace

The main workspace consists of four synchronized areas.

1. Top Preview Panel

Displays spreadsheet headers and the preview row.

Assigned fields receive persistent colors.

Hovering any field highlights every corresponding assignment.

---

2. Document Viewer

Displays the document.

Supports:

Scrolling.

Zoom.

Text selection.

Searching.

Navigation.

No editing.

---

3. Sidebar

Displays every detected field.

Each entry contains:

Field name.

Assignment count.

Color.

Current status.

Possible statuses:

Pending.

Assigned.

Incomplete.

---

4. Status Bar

Displays:

Current page.

Zoom level.

Project state.

Export readiness.

Autosave status.

Background tasks.

The status bar should remain subtle and non-intrusive.

# 12. Field Mapping

## 12.1 Purpose

The Field Mapping system is the core feature of Forkumentos.

Its purpose is to visually connect structured data from a spreadsheet with text contained inside a document template.

Unlike traditional mail merge solutions, users never create placeholders manually.

Instead, they simply select existing text within the document.

The document itself becomes the mapping interface.

This approach dramatically reduces the learning curve while maintaining full control over the generated output.

---

## 12.2 Mapping Workflow

After both a valid template and data source have been loaded, the application enters Mapping Mode.

The user is guided through each spreadsheet column one by one.

The workflow always follows the original order of the spreadsheet headers.

The application never changes this order.

---

The mapping sequence is:

1. Load template.

2. Load spreadsheet.

3. Detect headers.

4. Display preview row.

5. Select first unmapped field.

6. Wait for user selection.

7. Confirm assignment.

8. Detect identical occurrences.

9. Optionally assign additional occurrences.

10. Continue with the next field.

This process repeats until every field has been processed.

---

## 12.3 Mapping Mode Layout

While Mapping Mode is active, the interface contains four synchronized areas.

Top Preview Panel

Shows:

- Spreadsheet headers
- Preview values
- Current field
- Progress indicator

Document Viewer

Displays the template.

Allows:

- Selection
- Search
- Zoom
- Scroll

Does NOT allow editing.

Sidebar

Displays every spreadsheet field.

Each field displays:

- Color
- Status
- Assignment count

Floating Confirmation Menu

Appears immediately after selecting text.

---

## 12.4 Current Field

Only one field is considered active at any given moment.

The active field should be clearly highlighted throughout the interface.

The following areas must indicate the active field:

- Preview panel
- Sidebar
- Status indicator

The document itself should not display any special indicator until an assignment has been confirmed.

---

## 12.5 Selecting Text

Users may select any visible text.

Valid selections include:

- Single words
- Multiple words
- Partial sentences
- Entire paragraphs
- Multiple lines
- Text inside table cells

Selections are not limited by formatting.

A selection may span multiple paragraphs if technically possible.

---

The following cannot be selected:

- Images
- Shapes
- Tables as objects
- Headers of the application
- Sidebar content

Text inside tables remains selectable.

---

## 12.6 Confirmation

Immediately after a valid selection, a floating contextual menu appears near the selection.

The menu asks:

"This text represents the field:

<Field Name>

Is this correct?"

Buttons:

Yes

No

The menu disappears automatically when another selection begins.

Only confirming "Yes" completes the mapping.

---

## 12.7 Successful Assignment

After confirmation:

The selected text becomes linked to the current spreadsheet field.

The application immediately:

Assigns a persistent color.

Updates the preview panel.

Updates the sidebar.

Marks the field as assigned.

Stores the mapping.

Triggers autosave.

---

## 12.8 Multiple Occurrences

After every successful assignment, Forkumentos searches the document for additional exact matches.

Only exact matches are considered.

Examples

Selected

"Juan"

Matches

"Juan"

Does not match

"Juan Carlos"

Does not match

"Juan."

(with punctuation differences)

Future versions may introduce fuzzy matching.

Version 1 intentionally avoids it.

---

If additional matches are found, the application asks:

"Additional identical text was found.

Would you like to assign more occurrences?"

The user may:

Assign all.

Assign selected occurrences.

Skip.

---

The application presents every occurrence together with:

Page number.

Short surrounding context.

Selection checkbox.

Example

Page 1

"...Dear Juan..."

☑

Page 5

"...Employee Juan..."

☑

Page 9

"...Signed by Juan..."

☐

---

## 12.9 Colors

Every spreadsheet field receives exactly one persistent color.

That color remains constant for the lifetime of the project.

Colors are assigned sequentially from a predefined palette.

The palette must never be randomized.

The same field always uses the same color.

The color appears simultaneously in:

Spreadsheet preview.

Sidebar.

Document.

Search results.

Review Mode.

---

### 12.9.1 Mapping Visualization

Mapped text must preserve its original appearance.

Forkumentos should never modify:

- Text color.
- Font family.
- Font size.
- Bold.
- Italic.
- Underline.
- Paragraph formatting.

Instead, mappings are represented using a subtle visual indicator.

Preferred visualization:

- Rounded underline.
- Soft highlight with low opacity.
- Small colored marker.

The indicator must remain clearly visible without interfering with document readability.

The visualization should feel like an overlay rather than a modification of the original document.

This overlay exists only inside Forkumentos.

Generated documents never include mapping indicators.

---

## 12.10 Hover Behavior

Hovering any mapped occurrence highlights every assignment belonging to the same field.

Hovering the spreadsheet field highlights every mapped occurrence.

Hovering the sidebar entry highlights every mapped occurrence.

This interaction should feel immediate.

No noticeable delay should exist.

---

## 12.11 Existing Assignments

If the user selects text that has already been assigned:

A contextual dialog appears.

"This text already belongs to:

<Field Name>

Would you like to change the assignment?"

Options:

Replace

Cancel

Replacing immediately removes the previous assignment.

Undo remains available.

---

## 12.12 Removing Assignments

Assignments may be removed from:

Sidebar.

Context menu.

Review Mode.

Removing an assignment immediately:

Restores the original document appearance.

Removes highlighting.

Updates the sidebar.

Marks the field as incomplete if necessary.

Triggers autosave.

---

## 12.13 Undo & Redo

The mapping system supports:

Undo

Redo

Supported actions include:

Assignment creation.

Assignment deletion.

Assignment replacement.

Automatic assignment.

Multiple assignment operations.

Keyboard shortcuts:

Ctrl + Z

Ctrl + Y

Undo history is cleared only when the project is closed.

---

## 12.14 Search

The document viewer includes an integrated search bar.

The search system supports:

Plain text.

Case insensitive search.

Next result.

Previous result.

Search results should scroll automatically into view.

Search is independent from the mapping system.

However, mapped fields remain highlighted while searching.

---

## 12.15 Navigation

Users may navigate assignments through multiple methods.

Sidebar.

Search.

Manual scrolling.

When navigating through sidebar entries:

Selecting an occurrence immediately scrolls to the correct page.

The destination assignment receives a temporary visual emphasis.

The application never changes zoom during navigation.

---

## 12.16 Automatic Scrolling

Whenever the application needs to reveal a mapping:

Scrolling should animate smoothly.

The destination should appear approximately centered inside the viewport whenever possible.

Instant jumps should be avoided except when performance requires them.

---

## 12.17 Autosave

Every confirmed mapping operation triggers an automatic background save.

Autosave must never interrupt user interaction.

No modal dialogs should appear.

---

## 12.18 Mapping Completion

When every spreadsheet field has been assigned at least once:

Mapping Mode automatically finishes.

The application transitions into Review Mode.

The transition should feel natural.

No loading screen is required.

Only the interface adapts to the new mode.

---

## 12.19 Document View Modes

Forkumentos provides multiple viewing modes to improve navigation across documents of different sizes.

The available modes are:

- Fit Width
- Fit Page
- 50%
- 75%
- 100%
- 125%
- 150%
- 200%

Users may also zoom using:

- Ctrl + Mouse Wheel

Changing the zoom level must never affect:

- Current mappings
- Current selection
- Search results
- Scroll position (except when mathematically unavoidable)

Whenever possible, the viewport should preserve the same reading position after changing the zoom.

The selected view mode belongs to the project state and should be restored when reopening the project.

---

## 12.20 Document Navigation

The document viewer shall provide smooth navigation for both small and large documents.

Navigation methods include:

- Mouse wheel
- Scroll bar
- Search results
- Sidebar assignments
- Page navigation (future versions)

Whenever the application navigates automatically to a mapping or search result, scrolling should be animated smoothly.

Instant jumps should only occur when required for performance reasons.

---

# 13. Multi-Window Behavior

Forkumentos does not use document tabs.

Each project is opened in its own independent native window.

Opening a project never replaces the currently opened project.

Instead, a completely new application window is created.

Each window owns its own:

- Project
- Undo history
- Autosave state
- Export queue
- Preview cache
- Navigation state
- Search state

Closing one project must never affect any other open project.

This behavior intentionally follows professional desktop applications such as Microsoft Word and Microsoft Excel.

Users may therefore compare two projects side by side using the operating system's window management features.

---

## 13.1 New Project

Selecting:

File → New Project

creates a completely new application window.

The new project begins in the Empty state.

No template or spreadsheet is loaded automatically.

---

## 13.2 Open Project

Selecting:

File → Open Project

opens the selected project in a new window.

The currently opened project remains unchanged.

---

## 13.3 Recent Projects

The Home screen displays recently opened projects.

Each card contains:

- Project thumbnail
- Project name
- Last modified date
- Current status

Opening a recent project also creates a new independent window.

---

## 13.4 Window Independence

Every project window behaves independently.

Examples:

Exporting in one window must never freeze another.

Autosaving one project must never trigger saves in another.

Undo history belongs only to the active project.

Search history belongs only to the active project.

Zoom level belongs only to the active project.

Each project window should be treated internally as an isolated workspace.

# 14. Review Mode

## 14.1 Purpose

Review Mode allows users to inspect, validate and modify mappings after the guided mapping process has been completed.

Unlike Mapping Mode, Review Mode is not sequential.

Users may freely navigate throughout the document and modify any mapping at any time.

This mode is intended to reduce friction when working with large contracts, legal documents or templates where the same information appears multiple times.

---

## 14.2 Entering Review Mode

Review Mode is entered automatically once every required spreadsheet field has been assigned at least once.

Users may also enter Review Mode manually through:

View → Review Mode

Toolbar button

Keyboard shortcut (future version)

---

## 14.3 Interface Changes

When Review Mode becomes active:

• The mapping assistant disappears.

• The current field indicator disappears.

• The document gains additional horizontal space.

• The sidebar remains visible.

• Mapping colors remain visible.

• Search remains available.

• Zoom remains available.

The transition between Mapping Mode and Review Mode should be animated using a subtle fade.

---

## 14.4 Sidebar

The sidebar becomes the primary navigation element.

Fields always appear in the same order as the spreadsheet.

The order never changes.

Each field displays:

• Assigned color

• Field name

• Assignment count

• Status

Possible states:

Pending

Assigned

Incomplete

---

## 14.5 Expanding Fields

Each sidebar item may be expanded.

Example:

Employee Name (4)

▼

Page 1

"...Dear John..."

Page 3

"...John Smith..."

Page 7

"...Employee John..."

Page 12

"...Signature..."

Each occurrence represents one assignment.

---

## 14.6 Navigation

Selecting an occurrence immediately scrolls the document to the mapped text.

The mapped text briefly receives a subtle emphasis animation.

The animation should never modify the document contents.

---

## 14.7 Adding Assignments

Users may manually add additional mappings.

Workflow:

1.

Select the desired field.

2.

The application enters Add Assignment Mode.

3.

The cursor changes.

4.

The status bar displays:

"Select additional text for <Field Name>"

5.

The next confirmed selection becomes part of that field.

Review Mode remains active.

---

## 14.8 Removing Assignments

Assignments may be removed individually.

Removing one assignment does not affect other assignments belonging to the same field.

If the final assignment is removed:

The field becomes Pending.

Export readiness updates immediately.

---

## 14.9 Editing Assignments

Existing assignments may be reassigned.

Workflow:

Select mapped text.

↓

Context menu.

↓

Assign to another field.

↓

Confirmation.

↓

Autosave.

---

# 15. Preview System

## 15.1 Purpose

Preview allows users to verify the generated output before exporting documents.

Preview should be instantaneous.

The application never generates temporary files for preview.

Instead, preview should be rendered directly from the template and current spreadsheet record.

---

## 15.2 Preview Record

By default, the first spreadsheet row is displayed.

Users may navigate between records using:

Previous

Next

Record selector

Changing the preview record immediately updates every mapped field inside the document.

---

## 15.3 Preview Performance

Preview should update without visible delay.

Only mapped regions should be recalculated whenever possible.

The application should avoid fully rebuilding the document after every record change.

---

## 15.4 Missing Values

If the selected record contains empty values:

Mapped regions become empty.

No placeholder text should appear.

No warning should be displayed.

This behavior reflects the final exported result.

---

# 16. Export System

## 16.1 Purpose

The Export System transforms one template and one structured dataset into a collection of personalized documents.

The export process must prioritize:

Correctness

Performance

Reliability

Responsiveness

---

## 16.2 Supported Formats

Version 1 supports:

DOCX

PDF

DOCX + PDF simultaneously

---

## 16.3 Export Dialog

Before exporting, users choose:

Output format

Destination folder

File naming pattern

Records to export

Overwrite behavior

The application remembers previous export preferences.

---

## 16.4 Output Naming

Generated filenames support spreadsheet variables.

Example:

Employment Contract - {{EmployeeName}}

↓

Employment Contract - John Smith.docx

Duplicate filenames are resolved automatically.

Example:

John Smith

↓

John Smith (2)

↓

John Smith (3)

---

## 16.5 Export Range

Users may export:

Entire dataset

Range of rows

Specific row numbers

Examples:

1-100

15,18,24,91

Rows are always interpreted using spreadsheet order.

---

## 16.6 Progress Window

During export the application displays:

Progress bar

Current document

Total documents

Estimated remaining time

Documents per second

Current operation

Example:

Generating PDF...

125 / 500

01:34 remaining

18 documents/s

---

## 16.7 Background Processing

Export always runs in background.

The main interface remains usable.

The user may continue inspecting the project while export is running.

---

## 16.8 Cancellation

Users may cancel export.

Cancellation finishes the document currently being generated.

No new document begins.

The ZIP remains valid.

Already generated documents remain available.

---

## 16.9 ZIP Generation

Generated documents should never accumulate in memory.

Instead:

Generate document

↓

Add to ZIP

↓

Release memory

↓

Continue

This minimizes RAM usage regardless of project size.

---

## 16.10 Export Validation

Export is enabled only when every required field has at least one assignment.

If incomplete mappings exist:

The application displays a confirmation dialog.

Users may still continue.

Unmapped regions preserve their original template text.

---

## 16.11 Export Completion

After completion the application displays:

Documents generated

Elapsed time

Errors

Warnings

Open destination folder

Close

---

# 17. Settings

Version 1 intentionally keeps configuration minimal.

Settings include:

Default export folder

Remember last folder

Autosave

Language (Spanish)

Application information

License information

GitHub repository

Settings are global and independent from projects.

---

# 18. Search

Search is available throughout the application.

Features:

Plain text search

Case insensitive

Next

Previous

Occurrence counter

Automatic scrolling

Search never modifies mappings.

Mappings remain visible while searching.

---

# 19. User Interface

Forkumentos follows a desktop-first design philosophy.

The interface should feel closer to Microsoft Office than to a web application.

Layout:

Top Menu Bar

Toolbar

Spreadsheet Preview

Main Workspace

Sidebar

Status Bar

All panels are resizable.

Panel sizes persist between sessions.

---

## 19.1 Visual Language

Primary colors:

White

Black

Soft blue accent

Field mappings use an independent color palette.

The interface itself should remain visually calm.

---

## 19.2 Component Style

Large spacing

Rounded corners

Minimal shadows

No gradients

No glassmorphism

No neumorphism

Subtle transitions only

Consistency is prioritized over visual novelty.

---

# 20. Application Menu

Forkumentos follows the interaction model of professional desktop applications.

The application provides a native menu bar.

Every menu action is implemented as an independent command.

Toolbar buttons, keyboard shortcuts and menu entries invoke the same command internally.

No business logic should exist inside UI components.

---

## 20.1 File

New Project

Open Project

Open Recent

Save

Save As

Duplicate Project

Project Settings

Export

Exit

---

## 20.2 Edit

Undo

Redo

Find

Preferences

---

## 20.3 View

Fit Width

Fit Page

Zoom

Review Mode

Reset Layout

---

## 20.4 Project

Replace Template

Replace Spreadsheet

Refresh Preview

Validate Project

---

## 20.5 Help

Documentation

GitHub Repository

Report Issue

About Forkumentos

---

# 21. Keyboard Shortcuts

Forkumentos supports standard Windows shortcuts whenever possible.

Supported shortcuts:

Ctrl + N

Create Project

Ctrl + O

Open Project

Ctrl + S

Save Project

Ctrl + Z

Undo

Ctrl + Y

Redo

Ctrl + F

Search

Ctrl + Mouse Wheel

Zoom

Delete

Remove selected assignment

Esc

Close floating dialogs

Cancel current selection

Future versions may introduce additional shortcuts.

---

# 22. Drag & Drop

The application supports drag & drop.

Supported files:

Project files

DOCX

CSV

XLSX

Dropping a file onto the main window performs the appropriate action automatically.

Example:

Project

↓

Open Project

Spreadsheet

↓

Replace Spreadsheet

DOCX

↓

Replace Template

Unsupported files display a friendly error message.

---

# 23. Validation Rules

Validation exists to prevent inconsistent projects.

The application validates:

Template availability

Spreadsheet availability

Spreadsheet headers

Duplicate headers

Incomplete mappings

Unsupported formats

Corrupted files

Invalid export paths

Missing output permissions

Validation messages must always explain:

What happened.

Why it happened.

How the user can resolve the issue.

Technical jargon should be avoided.

---

# 24. Error Handling

Errors should never expose stack traces or implementation details.

Every error must contain:

Title

Description

Suggested solution

Optional details

Unexpected failures should be logged locally for troubleshooting.

The application should recover whenever possible.

A single failed document must never stop the entire export operation.

---

# 25. Performance Requirements

Performance is a core feature of Forkumentos.

The application should remain responsive regardless of project size.

General principles:

Never block the UI thread.

Use background isolates for heavy processing.

Generate files incrementally.

Avoid unnecessary memory allocations.

Reuse cached resources whenever possible.

Only recompute modified data.

Lazy-load heavy resources.

Virtualize long lists whenever applicable.

The application should remain usable while exporting hundreds or thousands of documents.

---

# 26. Accessibility

The application should follow common desktop accessibility practices.

Requirements:

Readable typography.

High contrast.

Large click targets.

Keyboard navigation.

Visible focus indicators.

Status must never rely exclusively on color.

Animations should remain subtle.

The interface should remain understandable without prior training.

---

# 27. Visual Design

Forkumentos adopts a minimalist visual language.

The interface should communicate professionalism rather than decoration.

Design references include:

Microsoft Office

Linear

Notion

Figma

The application intentionally avoids visual trends that reduce readability.

The design should age well.

---

## Color Palette

Primary

White

Secondary

Black

Accent

Soft Blue

Field mappings use their own independent palette.

The mapping palette must never interfere with the application theme.

---

## Typography

Typography should prioritize readability.

Avoid decorative fonts.

Use consistent spacing.

Maintain strong visual hierarchy.

---

## Icons

Icons should remain simple, recognizable and consistent.

The entire application should rely on a single icon library.

---

## Motion

Animations should communicate state changes.

Never distract the user.

Recommended duration:

150–250 ms.

Preferred animations:

Fade

Opacity

Subtle scaling

Smooth scrolling

---

# 28. Non-Functional Requirements

Forkumentos should be:

Reliable

Predictable

Maintainable

Responsive

Offline-first

Extensible

Professional

The application must prioritize long-term maintainability over short-term implementation speed.

Whenever architectural decisions are required, maintainability should be preferred.

---

# 29. Future Versions

The following features are intentionally postponed.

Image placeholders.

OCR.

PDF templates.

Cloud synchronization.

Plugin system.

Multiple languages.

Dark mode.

Digital signatures.

QR codes.

Watermarks.

Password-protected PDFs.

Batch project execution.

Macro support.

API integrations.

These features must not influence Version 1 architecture.

---

# 30. Acceptance Criteria

Forkumentos Version 1 is considered complete when:

✓ Projects can be created.

✓ Projects can be saved.

✓ Projects can be reopened.

✓ Templates can be imported.

✓ Spreadsheets can be imported.

✓ Fields can be assigned visually.

✓ Multiple occurrences can be assigned.

✓ Review Mode functions correctly.

✓ Search functions correctly.

✓ Preview updates correctly.

✓ DOCX export works.

✓ PDF export works.

✓ ZIP generation is incremental.

✓ Large exports remain responsive.

✓ Autosave functions correctly.

✓ Undo/Redo functions correctly.

✓ Multi-window support works.

✓ Keyboard shortcuts function correctly.

✓ Validation prevents inconsistent projects.

✓ All generated documents preserve formatting.

✓ The application functions completely offline.

---

# 31. Guiding Principle

Every design and development decision should reinforce the original purpose of Forkumentos.

One template.

Many documents.

Simple.

Visual.

Offline.

Professional.

Whenever a future feature introduces unnecessary complexity without significantly improving the primary workflow, that feature should be reconsidered or postponed.

Forkumentos should never become a general-purpose document editor.

Its strength comes from doing one thing exceptionally well.


