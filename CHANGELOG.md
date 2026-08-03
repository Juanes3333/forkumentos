# Changelog

## 1.2.0

### Added
- Formato legible de celdas XLSX en importación y preview (fechas `YYYY-MM-DD` y doubles sin notación científica).
- Auto-mapeo de campos y dropzones ampliadas compartidas entre wizard y overlay de arrastre.
- Token de contraste `onAccent` y warning light-mode accesible en el design system.

### Changed
- Exportación **solo DOCX**: se eliminó export/import PDF, el selector de formato y las deps `pdf` / `syncfusion_flutter_pdf`.
- `DocumentTextPath` ya no usa `pageIndex`; `rootBlock.blockIndex` es un índice absoluto en orden de documento (ingestion y export alineados).
- UI: cards de recursos, tema y superficies de drop rediseñadas.

### Fixed
- Desync de offsets al confirmar/reemplazar mapeos con whitespace (leading/trailing trim ajusta `startOffset`/`endOffset`).
- Desync de paginación heurística entre viewer y export DOCX.

### Breaking
- Mapeos guardados en `.fork` viejos contra plantillas paginadas heurísticamente pueden marcarse inválidos y requerir re-mapeo (sin corrupción silenciosa).
- Plantillas PDF ya no se importan ni exportan.

## 1.1.0

### Added
- Extracción de estilos tipográficos desde DOCX: `colorHex`, `fontSizePoints`, `spacingBeforePoints` y `spacingAfterPoints`.
- Renderizado WYSIWYG en el visor: color, tamaño de fuente y espaciado de párrafo del documento original.

### Fixed
- Mejoras de fidelidad tipográfica en preview/export DOCX.

## 1.0.0

### Added
- Asociación de archivos `.fork` en Windows (HKCU): al primer arranque, `.fork` se vincula al ejecutable actual.
- Abrir un proyecto haciendo doble clic en un archivo `.fork` desde el Explorador de Windows.
- Multi-ventana: con un proyecto ya abierto, Nuevo / Abrir / Recientes lanzan otra instancia del proceso en lugar de reemplazar el proyecto actual.

### Known limitations
- El intervalo de autoguardado se guarda en Ajustes, pero el motor de autoguardado aún no está activo (indicado en la UI de configuración).
