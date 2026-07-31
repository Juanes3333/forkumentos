# Changelog

## 1.1.0

### Added
- Extracción de estilos tipográficos desde DOCX: `colorHex`, `fontSizePoints`, `spacingBeforePoints` y `spacingAfterPoints`.
- Renderizado WYSIWYG en el visor: color, tamaño de fuente y espaciado de párrafo del documento original.
- Export PDF con los mismos estilos tipográficos y espaciado.
- Header/footer en la exportación PDF y selección opcional de páginas.

### Fixed
- Doble paginación en PDF (`pw.MultiPage` por página del documento) que generaba hojas casi en blanco y un conteo inflado de páginas.

## 1.0.0

### Added
- Asociación de archivos `.fork` en Windows (HKCU): al primer arranque, `.fork` se vincula al ejecutable actual.
- Abrir un proyecto haciendo doble clic en un archivo `.fork` desde el Explorador de Windows.
- Multi-ventana: con un proyecto ya abierto, Nuevo / Abrir / Recientes lanzan otra instancia del proceso en lugar de reemplazar el proyecto actual.

### Known limitations
- El intervalo de autoguardado se guarda en Ajustes, pero el motor de autoguardado aún no está activo (indicado en la UI de configuración).
- La reconstrucción de tablas en plantillas PDF (preview) es heurística y puede diferir del layout original en documentos complejos.
