---
description: Paridad obligatoria entre el parser DOCX y el exportador al editar ingesta, exportación o mapeo
trigger: glob
globs: "lib/shared/data/docx_document_repository.dart, lib/features/export/**/*.dart, lib/features/mapping/domain/*.dart, lib/shared/models/document_text_path*.dart"
paths:
  - "lib/shared/data/docx_document_repository.dart"
  - "lib/features/export/**/*.dart"
  - "lib/features/mapping/domain/*.dart"
  - "lib/shared/models/document_text_path*.dart"
---

# Paridad parser ↔ exportador (el bug más caro del proyecto)

`docx_document_repository.dart` (ingesta) y `docx_zip_exporter.dart` (exportador) reconstruyen **de
forma independiente** el mismo texto plano y el mismo `blockIndex`. Si divergen, los reemplazos
caen en otro párrafo o se pierden **sin error**.

- Cambia el recorrido de XML, qué nodos aportan caracteres, `w:ins`/`w:del`, tabs/saltos, señales de
  salto de página o el conteo de bloques → **cambia los dos archivos en el mismo cambio** y deja
  los comentarios "Espejo de …".
- `DocumentTextPath` no lleva `pageIndex`; `blockIndex` es absoluto en orden de documento.
- El exportador elimina todos los `lastRenderedPageBreak` que escribe.
- Mapeo: `trim()` de una selección ajusta start/end; el texto buscado normaliza mayúsculas y
  comillas **sin cambiar longitudes**.
- Añade/actualiza una prueba que pase la misma plantilla por ambos lados.

Antes de dar el cambio por bueno, aplica la skill `docx-parity-check` o delega en el subagente
`docx-parity-auditor`. Contexto completo: `.agents/AGENTS.md` §4.
