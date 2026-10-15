---
name: docx-parity-check
description: Lista de comprobación para verificar que el parser DOCX y el exportador de Forkumentos siguen siendo espejo exacto tras tocar el recorrido de XML, el texto plano, los saltos de página, las tablas o el control de cambios. Úsala antes de dar por bueno cualquier cambio en esas zonas.
---

# Paridad ingesta ↔ exportador

Archivos espejo:
- Ingesta: `lib/shared/data/docx_document_repository.dart`
- Exportador: `lib/features/export/data/docx_zip_exporter.dart`
- Catálogo (usa el texto de la ingesta): `lib/features/mapping/domain/document_text_catalog.dart`

## Comprueba cada punto en AMBOS lados
1. **Caracteres**: `w:t` aporta su texto; `w:tab` → `\t`; `w:br` que no es de página → `\n`;
   `w:drawing`, `w:pict` y `mc:Fallback` no aportan. (`_runContentElements`,
   `_isOutsideParagraphFlow`.)
2. **Control de cambios**: runs bajo `w:del` se descartan; los de `w:ins` se conservan.
3. **Clave de ruta**: `blockIndex` = conteo absoluto de `<w:p>`/`<w:tbl>` del cuerpo (y de los
   trozos en que se parte un párrafo), sin reiniciar por página; celdas =
   `(rowIndex, cellIndex, blockIndex)`.
4. **Saltos de página** que parten bloques: `w:br type="page"`, `w:lastRenderedPageBreak`,
   `w:pageBreakBefore` (marca el bloque anterior, idempotente), `w:sectPr` intermedio (solo
   `nextPage`); los dos últimos solo a nivel body. **Dentro de `w:tc` se ignoran todos**
   (`_isInsideTable`).
5. **Exportación**: elimina todo `lastRenderedPageBreak` que escribe; tab/`w:br` son nodos "gap"
   que cuentan para offsets pero no se escriben; un reemplazo que cruza grupos vacía los
   siguientes y borra los gaps intermedios.
6. Los comentarios "Espejo de …" siguen presentes y apuntan al lado correcto.

## Prueba mínima obligatoria
Un test que construya la plantilla en memoria, la pase por la ingesta y por el exportador y
compruebe que el texto reemplazado cae donde el catálogo dijo. Incluye al menos: runs
fragmentados, tabs entre palabras mapeadas, `w:ins`/`w:del`, una tabla con salto interno y una
lista con `numId`.

## Veredicto
Paridad intacta / En riesgo / Rota, citando archivo:línea de cada lado.
