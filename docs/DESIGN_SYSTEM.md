# Design System: Forkumentos

## 1. Design Philosophy
Forkumentos is a professional desktop workbench. The design philosophy centers on information density, efficiency, and clarity. It avoids consumer-oriented minimalism in favor of structured, data-rich interfaces that empower power users. The UI must feel like a precision instrument: quiet, reliable, and out of the way of the data.

## 2. Desktop-First Principles
The interface is optimized for mouse and keyboard ergonomics. 
- Large screens are utilized to display parallel information panels. 
- Mobile patterns like swipe-to-dismiss, bottom sheets, and full-screen overlay menus are strictly avoided.
- Hover states and rich tooltips are expected and required for all interactive elements.

## 3. Nielsen Heuristics Integration
- **Visibility of system status:** The application never "hangs" silently. Operations longer than 200ms show deterministic progress.
- **Error prevention:** Destructive actions (e.g., file overwrites, project closures with unsaved data) require explicit confirmation.
- **User control and freedom:** Background processes, such as large exports, are always cancellable.
- **Consistency and standards:** Interaction patterns, button placements, and terminology remain identical across all panels.
- **Help users recognize, diagnose, and recover from errors:** Errors are presented inline, in plain language, explaining exactly how to fix the issue.

## 4. Color Palette
Colors encode meaning; they are not merely decorative.
- **Backgrounds:** Neutral, low-contrast grays or dark themes to reduce eye strain during long sessions.
- **Surfaces:** Slightly elevated panel backgrounds for visual grouping.
- **Primary Accent:** Used sparingly to draw attention to the primary call to action, active selections, or keyboard focus rings.
- **Semantic Colors:**
  - *Success (Green):* Successful mappings, completed exports.
  - *Warning (Amber):* Mapping conflicts, missing optional fields, stale previews.
  - *Error (Red):* Invalid data, failed exports, missing required fields.

## 5. Typography
Typography is functional, highly legible at small sizes, and hierarchical.
- **Display Typeface:** Used only for high-level branding, empty state headers, or major section titles.
- **Interface Typeface:** A highly legible sans-serif optimized for dense data grids and small labels.
- **Monospace Typeface:** Used exclusively for raw data previews, file paths, and transformation expressions.
- **Scale & Weight:** Hierarchy relies heavily on weight differences (e.g., Medium vs. Regular) and subtle color contrast rather than extreme size differences.

## 6. Spacing
Spacing uses a strict, tight grid to maintain information density.
- **Dense Spacing:** Used within data rows, tables, and tightly coupled controls.
- **Structural Spacing:** Used between major panels and distinct sections to provide visual breathing room without wasting screen real estate.

## 7. Corner Radius
Corner radii are sharp and deliberate, reflecting a professional tool.
- Small controls (buttons, inputs, checkboxes): Minimal radius (e.g., 2px–4px).
- Large panels and dialogs: Slight radius (e.g., 4px–8px).
- Pill-shaped or fully rounded corners are avoided.

## 8. Elevation
Elevation relies on subtle borders rather than heavy shadows.
- Panels are separated by hairline borders (1px) to keep the interface flat and clean.
- Floating elements (dialogs, tooltips, dropdown menus) use a distinct, crisp shadow to break out of the flat hierarchy and indicate z-index superiority.

## 9. Icons
Icons are sharp, geometric, and unfilled by default. 
- They are used to supplement text, never to replace primary labels unless the icon is universally understood (e.g., Settings gear, Close 'X').
- Icons align perfectly with the baseline of adjacent text.

## 10. Components

### Buttons
- **Primary:** Solid background, used for the single most important action on a screen (e.g., "Export Data").
- **Secondary:** Outlined or subtle background, used for alternative actions.
- **Tertiary:** Text-only, used for minor, inline, or repetitive actions.
- All buttons include immediate visual hover states and display keyboard shortcuts in tooltips.

### Panels
- The workbench is divided into resizable panels allowing users to customize their workspace.
- Panels can be collapsed to maximize the central working area (e.g., the mapping grid).
- Scrollbars are always visible on hover or scroll to indicate overflow.

### Dialogs
- Used exclusively for decisions requiring immediate user input or confirmation of destructive actions.
- Dialogs trap keyboard focus and dim the background, preventing interaction with the main window until resolved.

### Sidebar
- A thin, collapsible vertical strip on the left edge.
- Provides global navigation between major application states (e.g., Project Setup, Mapping, Review, Export).

### Toolbar
- Located horizontally above the main working area.
- Houses context-specific actions for the active panel (e.g., "Add Transformation", "Clear Mapping").

### Status Bar
- A thin horizontal strip at the bottom of the window.
- Displays global system status, the active project name, and background task indicators.

### Loading Indicators & Progress Bars
- **Deterministic Progress Bars:** Used for all operations with a known duration or size (e.g., exporting rows). Must show percentage or item counts.
- **Indeterminate Indicators:** Used briefly while initializing tasks. They must always be accompanied by descriptive text.
- Full-screen blocking loaders are strictly prohibited.

### Search
- Search is instant, non-destructive, and non-blocking.
- Matching terms are highlighted within the data grid.
- Supports keyboard navigation to jump between matches.

## 11. Mapping Visualization
- Mappings are represented visually as a clear relationship between a source column and a target field.
- The interface uses parallel alignment or visual connectors to demonstrate this relationship.
- Invalid mappings or type mismatches display inline semantic warning/error icons.
- Complex data transformations are previewed inline as an expandable or hoverable expression.

## 12. Animations & Motion
Motion is entirely functional and never decorative.
- **State Changes:** Hover, focus, and active states transition instantaneously or very quickly (<100ms) to feel snappy and responsive.
- **Panel Resizing:** Smooth, 1:1 tracking with the mouse cursor.
- **Progressive Disclosure:** Expanding panels or revealing menus use a subtle, fast slide/fade to prevent jarring layout jumps.
- Animations must never delay user input or force the user to wait.

## 13. Accessibility
- **Keyboard Navigation:** Every interactive element must be reachable via the `Tab` key. Focus rings must be highly visible and distinct from hover states.
- **Shortcuts:** Power-user actions possess dedicated shortcuts (e.g., `Ctrl+E` for Export, `Ctrl+S` for Save).
- **Contrast:** Text and essential icons must meet standard WCAG contrast ratios against their backgrounds.
- **Color Independence:** Semantic states (Error, Success) are conveyed through both color and iconography, ensuring usability for color-blind users.
