# Changelog

## 1.8.0

### Added
- Diálogo al reemplazar datasource (ribbon o drop) si los encabezados no coinciden con los mapeos: aceptar y actualizar nombres, usar sin actualizar, o cancelar.
- Detección de `HeaderMismatch` y `updateFieldHeaders` en el provider de mapeo.

### Changed
- Texto de actualización disponible en Ajustes: `Disponible: x.y.z`.

## 1.7.0

### Added
- Verificación de actualizaciones desde GitHub Releases (Ajustes → comprobar versión, notas y descarga del installer).

### Fixed
- Export DOCX: reemplazos que cruzan tabs/`w:br` vacían la cola en grupos posteriores y eliminan los gaps intermedios del XML (ya no dejan restos del texto mapeado).
- Constante `forkumentosVersion` alineada con `pubspec` / installer (About y update check).

## 1.6.0

### Added
- Nombrado **manual por fila** en la exportación DOCX (prellenado desde el patrón automático).
- Formato de celdas XLSX con moneda/miles/% (convención es-CO) y diálogo modal al fallar la importación.
- Diálogo Abrir aquí / nueva ventana / Cancelar al abrir otro `.fork` con proyecto activo.

### Fixed
- Export DOCX conserva negrita/estilo por run al reemplazar texto (ya no fusiona todo en el primer `<w:t>`).
- Abrir `.fork` ya no se queda sin efecto: post-load en listener de App + argv real para nueva ventana.
- Filas fantasma vacías en XLSX; comillas tipográficas en automapeo; `numFmtId` < 164 sanitizado al decodificar.

## 1.5.0

### Added
- **Refrescar datos**: relee el datasource desde `datasourceExternalPath` (archivo original en disco), sin destruir el estado si el archivo no cambió o no existe.
- Persistencia de `datasourceExternalPath` en `project.json` del `.fork` (compatible con proyectos viejos: ausente → null).
- Acciones de refresco en ribbon y card de datasource; feedback de delta de filas / no encontrado / error.

## 1.4.0

### Added
- Rangos multi-párrafo con `endPath`/`endOffset`: cerrar el extremo final con una segunda selección en el documento.
- Export DOCX con `endBlockIndex` para reemplazar prosa que cruza párrafos de forma estructural.
- Modo UI `beginRangeClose` / `completeRangeClose` para completar campos de rango cruzado.

### Changed
- Sustituye `paragraphSpan` (conteo fijo de párrafos) por rutas de inicio/fin explícitas (`FieldAssignment.endPath`, `TextOccurrence.endPath`).
- Validación y highlights adaptados a rangos cross-paragraph; catálogo de texto busca ocurrencias multi-párrafo.

### Fixed
- `assignmentStillMatchesDocument` ya no usa `endOffset` del párrafo de inicio cuando el rango termina en otro bloque (evita `RangeError`).

## 1.3.0

### Added
- Bloque de nombre de plantilla en el constructor de nombres de export (`FilenameTemplateBlock`); el patrón por defecto usa el basename del DOCX.
- Restauración de plantilla/datasource embebidos al abrir un `.fork` (paths iniciales en providers activos).

### Fixed
- Mapeos inválidos cuando el datasource reordena o renombra columnas (`fieldIndex` vs `fieldHeader`).
- Sugerencias de ocurrencias múltiples: se excluyen rangos que ya solapan otra asignación.
- Padding negativo de spacing/indent/header-footer distance (clamp a ≥ 0) que podía romper el layout del viewer.

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
