<!-- FUENTE ÚNICA. Edita solo este archivo y ejecuta `python .agents/scripts/sync.py`:
     copia idéntica en .claude/CLAUDE.md (Claude Code). Antigravity lee este mismo archivo. -->
# Forkumentos — guía para agentes de IA

Verificado contra el código a 2026-10-14 (v1.8.0). Si algo choca con `docs/PROJECT_SPEC.md`,
**manda el código**: esa especificación es histórica (v1.0, aún habla de PDF).

## 1. Qué es

App de escritorio **Windows** (Flutter/Dart) de combinación de correspondencia sobre DOCX.
Entrada: plantilla **DOCX** + fuente de datos **XLSX/CSV**. El usuario mapea texto de la plantilla
a columnas y la app genera **un DOCX por fila**. El proyecto se guarda como `.fork`.

- **Solo DOCX de entrada y de salida.** El PDF (exportar *y* usar PDF como plantilla) se eliminó
  por decisión del producto. No lo restaures sin que el usuario lo pida.
- Idioma de UI, comentarios de dominio y commits: **español**. Identificadores: inglés.
- Empaquetado: Inno Setup (`installer/Forkumentos.iss`) → `ForkumentosSetup_v{version}.exe`,
  publicado en GitHub Releases de `Juanes3333/forkumentos`.

## 2. Comandos y reglas de código

```powershell
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # tras tocar modelos freezed/json
flutter analyze                                            # very_good_analysis
flutter test
dart format <archivos modificados>
flutter run -d windows
dart run tool/batch_fork.dart "<carpeta con pares X.docx + X.xlsx>" ["<salida>"]
```

- Resuelve **todos** los avisos de `very_good_analysis`; formatea con `dart format`.
- Sin placeholders (UI de mentira, estado hardcodeado) y sin comentarios `TODO`.
- Commits: Conventional Commits en español, atómicos, compilando y con tests en verde. Una release
  = un commit (`feat: … y release X.Y.Z`). No hagas commit si no te lo piden.
- Filosofía: YAGNI, reutiliza antes de crear, sin paquetes para lo que resuelve la stdlib, sin
  abstracciones con un solo uso. Una tarea termina al compilar, analizar limpio y pasar tests; si
  descubres infraestructura faltante, repórtala en vez de construirla.
- Antes de eliminar un campo de un modelo: `grep -rn '\.campo\b' lib test`. El alcance real casi
  siempre supera el que describe la tarea.

`tool/batch_fork.dart` crea `.fork` con auto-mapeo desde pares `nombre.docx` + `nombre.xlsx`.
Reimplementa la búsqueda sin Flutter: **si cambias `mappings.json` o `findExactTextOccurrences`,
revísalo**.

## 3. Arquitectura

Capas: `app` → `routing` → `features` → `shared` → `core`. Feature-First. Estado con Riverpod;
`go_router` solo para el shell. La composición entre features ocurre en `lib/routing/`
(`datasource_replacement.dart`, `export_launcher.dart`, …).

```
lib/app/            bootstrap, app.dart, splash
lib/core/           commands (Cancellable/Undoable), launch (nueva ventana), logging, storage,
                    theme (AppColors/AppTypography), window, windows/fork_file_association.dart,
                    workspace/workspace_paths.dart
lib/routing/        AppPhase {landing, wizard, workbench}, app_shell, app_drop_target,
                    datasource_replacement.dart, workbench/** (ribbon, workspace, inspector,
                    status bar, export_launcher, mapping_actions)
lib/features/       datasource · template · document_viewer · mapping · export · preview ·
                    project · settings   (cada una: data/ domain/ presentation/)
lib/shared/         models (Document, DocumentTextPath), data/docx_document_repository.dart,
                    providers (activeProject, documentContent, settings), widgets
test/               unit/ widget/ support/fakes.dart   (integration/ vacío)
```

**Acoplamiento real (no lo agraves):** `export`, `datasource`, `template`, `project` y `settings`
no importan otras features (`export` recibe `ExportPlaceholder` ya traducido por `routing`).
Excepciones existentes: `mapping/presentation` usa providers de `template`, `datasource` y la
pantalla de `document_viewer`; `preview` usa `datasource`, `mapping` y `template`; y
`shared/providers` importa `project` y `settings`. `core` no importa nada de las demás capas.
Una clase usada por dos o más features va a `shared/`; si nada encaja sin violar capas, pregunta.

Directorios de runtime en la raíz (`Cache/ Exports/ Logs/ Projects/ Workspace/`) son datos de
usuario generados al correr en desarrollo (`Documentos/Forkumentos/` es esta misma carpeta): están
en `.gitignore` y **no se borran**. En producción los resuelve `WorkspacePaths`.

## 4. Invariantes críticos (léelos antes de tocar parser, exportador o mapeo)

### 4.1 Ingesta y exportador deben ser espejos exactos
Los mapeos guardan `(DocumentTextPath, startOffset, endOffset)` calculados sobre el texto plano de
`lib/shared/data/docx_document_repository.dart`. El exportador (`lib/features/export/data/
docx_zip_exporter.dart`) **re-deriva la misma estructura del XML crudo** y aplica los offsets.
Cualquier divergencia desalinea reemplazos **sin error en runtime** (texto mezclado tipo `El
contrMigueltMartinezn Pérez`, o placeholders sin reemplazar). Ya pasó 3 veces.

Deben coincidir exactamente:
1. **Qué aporta caracteres**: `w:tab` → `'\t'`, `w:br` no-página → `'\n'`; contenido de
   `w:drawing`/`w:pict`/`mc:Fallback` excluido. En el exportador tab/br son nodos "gap" no
   editables: cuentan para offsets pero nunca se escriben.
2. **Control de cambios**: se **conserva** `w:ins`, se **descarta** `w:del`.
3. **Señales de salto de página** (solo vista, nunca la clave): `w:br type="page"`,
   `w:lastRenderedPageBreak`, `w:pageBreakBefore` (marca el bloque *anterior*, idempotente) y
   `w:sectPr` intermedio (último chunk; `nextPage` rompe, `continuous`/`nextColumn` no).
   `pageBreakBefore`/`sectPr` solo a nivel body, nunca en celdas ni header/footer.
4. **Dentro de una celda de tabla se ignoran TODAS las señales de salto** (`_isInsideTable`, mismo
   nombre en ambos archivos). Un `DocumentTableBlock` es atómico. Única excepción, solo vista y
   solo en el parser (`_tableOpensNewPage`): un `lastRenderedPageBreak` antes de cualquier texto
   del primer párrafo de la primera celda de una tabla **raíz** significa "Word la abrió en página
   nueva" y corta antes de la tabla (no crea bloques ni cuenta para `hasRenderedPageBreaks`).

Ambos archivos llevan comentarios "Espejo de …". **Consérvalos y cambia los dos lados a la vez.**

### 4.2 La clave de ruta NO tiene `pageIndex`
`DocumentTextPath = (steps, region)`. `RootDocumentBlockStep.blockIndex` es el índice **absoluto**
del bloque raíz en orden de documento (cuenta `<w:p>`/`<w:tbl>`, nunca se reinicia por página).
Celdas: `DocumentTableCellBlockStep(rowIndex, cellIndex, blockIndex)`. Regiones: `body|header|
footer`. La paginación (`Document.pages`, heurística, `resolvePageNumber`) es **solo vista**.
Consecuencia aceptada: `.fork` viejos cargan, pero sus asignaciones sobre plantillas con
paginación heurística quedan "inválidas" y hay que re-mapear.

### 4.3 Paginación de la vista (no afecta al export)
- Con ≥1 `lastRenderedPageBreak` **fuera de tablas** se usan solo esos y la heurística se apaga
  (`hasRenderedPageBreaks`). Si no, estimador por caracteres/líneas (`_naturalLineHeightRatio =
  1.17`, `_charWidthRatio = 0.44`, medidos sobre fuentes reales).
- Se podan páginas visualmente vacías al final de `_extractPages` (la página 0 nunca).
- El **exportador elimina todos** los `lastRenderedPageBreak` que escribe: Word no re-maquetó y
  quedarían obsoletos (convertían 11 páginas en 20 fantasma).
- `MappingAwareParagraph._visualScale = 0.95` solo escala el `fontSize` **visual**; nunca toca
  `DocumentRun.fontSizePoints`. Cambiarlo rompe a propósito su test de calibración.
- `_applyContextualSpacing` no debe suprimir en bordes (`index > 0 && …`, `index < len - 1 && …`).

### 4.4 Reemplazo de texto en el exportador
Por párrafo: texto plano = unión de runs; mapa carácter→nodo `<w:t>`; reemplazos de atrás hacia
adelante; el texto nuevo hereda el **estilo del run donde empieza** la zona reemplazada y el resto
de runs conserva texto/formato (no volcar todo al primer `<w:t>`).
- Un reemplazo que cruza varios **grupos editables** separados por tab/`w:br` escribe en el primero,
  vacía los siguientes y **elimina los gaps intermedios** del XML.
- Tipos: `DocxTextReplacement` (en sitio), `DocxListReplacement` (campo de lista: rango por
  `w:numId`, una línea por párrafo clonando el primero), `DocxRangeReplacement` (rango entre
  párrafos hermanos del nivel raíz o de una misma celda; otros rangos se marcan
  inválidos). Listas y rangos se aplican **al final**, en orden inverso de
  `blockIndex`.
- `ExportPlaceholder` (`features/export/domain`) es el tipo agnóstico al mapeo; `routing` lo
  construye desde `FieldAssignment`. `paragraphSpan` sigue en `ExportPlaceholder`/
  `DocxListReplacement` pero `FieldAssignment` ya no lo tiene (lo reemplazó `endPath`): código
  heredado, candidato a limpieza.

### 4.5 Texto y offsets en el mapeo
- `confirmAssignment`/`replaceAssignment` hacen `trim()` **y ajustan** start/end; invariante
  `selectedText.length == endOffset - startOffset` (lo comprueba `_stillMatchesDocument`).
- `findExactTextOccurrences` busca sobre el texto de todos los bloques unido por `\n` (admite
  coincidencias entre párrafos), **sin distinguir mayúsculas y normalizando comillas** (carácter a
  carácter: los offsets siguen válidos). Si el match va entre comillas, el rango las incluye. No
  normaliza acentos.
- "Coincidencias adicionales" filtra ocurrencias que solapan asignaciones existentes
  (`occStart < existingEnd && occEnd > existingStart`); respeta los checkboxes y "Omitir"/cerrar
  no asigna nada.
- Auto-mapeo (`auto_mapping.dart`, `applyAutoMapping`): usa la **primera fila de datos**, un solo
  paso de undo, omite solapes sin lanzar error.
- Rango entre párrafos: `FieldAssignment.endPath` + `endOffset` (aplica en `endPath`), se cierra
  con "Definir fin de rango" (`beginRangeClose`/`completeRangeClose`). JSON: `endPath` y
  `endOffsetSecondary`. `isListField` se ofrece por diálogo si el párrafo tiene `numberingId`.

### 4.6 Fuente de datos
- XLSX (`xlsx_datasource_repository.dart`, `xlsx_sheet_parser.dart`): las filas con solo formato
  **no cuentan** (`isEmptyRow`); encabezados vacíos finales se recortan, los intermedios se llaman
  `Columna N`. Fechas/moneda/miles/% salen legibles (es-CO). El paquete `excel` 4.0.6 **lanza** con
  `numFmtId < 164` en `styles.xml`: se sanea antes de decodificar y se reintenta.
- Un fallo de importación muestra **diálogo modal** (`datasource_import_error_dialog.dart`).
- Refresco: `Project.datasourceExternalPath` (en `project.json`; null en proyectos viejos).
  `ActiveDatasourceNotifier.refreshDatasource()` → `DatasourceRefreshStatus {unchanged, updated,
  notFound, error}`; el botón solo está activo si el archivo existe.
- **Cambio de encabezados** (`mapping/domain/header_mismatch.dart` + `routing/datasource_
  replacement.dart`): al reemplazar *o refrescar* se compara contra el `fieldHeader` de las
  asignaciones y, en columnas sin asignaciones, contra los encabezados activos. Diálogo: aceptar y
  actualizar (`updateFieldHeaders`), usar sin actualizar (quedan inválidas) o cancelar.
  `MappingReviewSidebar` marca las columnas desfasadas.

### 4.7 Exportación y `.fork`
- `ExportJob`: `destinationFolder, filenamePattern, rangeMode (single|batch|custom), rowIndexes,
  createZip, templateBaseName, customRangeText, filenameMode (automatic|manual), manualFilenames`.
- `FilenamePattern`: `FilenameTextBlock`, `FilenameFieldBlock`, `FilenameTemplateBlock` (nombre del
  DOCX sin extensión; es el patrón por defecto). Separador `_`; manual por posición en
  `rowIndexes`; blanco → cae al patrón; se deduplican colisiones.
- La exportación se bloquea (`isExportReady`) con solapes, asignaciones inválidas o ids duplicados.
- `.fork` = ZIP con `manifest.json`, `project.json` (id, name, timestamps,
  `datasourceExternalPath`), `mappings.json`, `template/`, `datasource/`. Todo campo nuevo del JSON
  necesita default para leer proyectos viejos. Abrir un `.fork` con proyecto activo ofrece *Abrir
  aquí / Nueva ventana / Cancelar*; el post-load vive en un listener de `App` (no uses un `ref`
  desmontado).

## 5. UI

- Autoridad visual: `docs/DESIGN_SYSTEM.md`. Tokens en `lib/core/theme/` (`AppColors` como
  `ThemeExtension`). Modo **Operate** (herramienta de escritorio), Material 3, sin CSS/HTML.
- Contraste ya resuelto: `AppColors.warning` claro = `0xFF8A5D00`; texto/íconos sobre relleno de
  acento usan **`AppColors.onAccent`** (no `foregroundPrimary`). "Auto-mapear" y "Exportar" son
  `FilledButton` reales.
- Atajos del visor: Ctrl+rueda = zoom, Ctrl+Z / Ctrl+Mayús+Z = deshacer/rehacer; al elegir una
  coincidencia se resalta la palabra exacta además de hacer scroll.
- Ajustes: 5 pestañas (General, Apariencia, Comportamiento, Exportación, Acerca de).
- El cuadro «Asignar campo» (`workbench_selection_tooltip.dart`) se coloca con un
  `CustomSingleChildLayout` que mide su **tamaño real** (hoy ~300 px de alto) y lo pone arriba, abajo o
  al lado del texto sin tapar la selección; no vuelvas a una altura supuesta. La selección en el
  documento funciona también sin Excel (el cuadro ofrece «Crear campo nuevo»); solo la Vista previa
  la desactiva.

## 6. Versionado y release

Una versión nueva toca **todos** estos sitios (ya se desincronizaron una vez):
1. `pubspec.yaml` (`version: X.Y.Z+N`)
2. `lib/shared/widgets/about_forkumentos_dialog.dart` → `forkumentosVersion` (lo usa el update check)
3. `installer/Forkumentos.iss` → `MyAppVersion` y `OutputBaseFilename`
4. `CHANGELOG.md` y `README.md`

Auto-actualización: `UpdateChecker.check` consulta `releases/latest` de GitHub (`dart:io`, sin
paquetes), compara semver y busca un asset `.exe`. "Actualizar ahora" descarga a
`Directory.systemTemp`, lanza el instalador con `/SILENT` desacoplado y cierra la app. Por eso el
`.iss` **no** lleva `skipifsilent` en `[Run]` y sí `CloseApplications=yes`. El release de GitHub debe
adjuntar `ForkumentosSetup_vX.Y.Z.exe`. Procedimiento completo: skill `release`.

## 7. Configuración de IA en este repo (Claude Code y Antigravity)

```
.agents/                 FUENTE ÚNICA, la lee Antigravity (y se versiona)
  AGENTS.md              este archivo
  rules/*.md             reglas por glob (frontmatter: trigger, globs; Claude usa paths)
  skills/<n>/SKILL.md    procedimientos reutilizables (name, description)
  agents/<n>.md          subagentes (name, description)
  scripts/               sync.py y graphify_rebuild.py
.claude/                 COPIA GENERADA para Claude Code (CLAUDE.md, rules/, skills/, agents/)
```

- Edita **solo** `.agents/`; luego `python .agents/scripts/sync.py` (o `--check` para verificar).
- Los frontmatter usan únicamente campos comunes (`name`, `description`) para ser
  válidos en ambas herramientas; sin `tools:` ni `skills:` (cada herramienta nombra distinto).
- Antigravity trunca archivos de reglas de más de 24 000 bytes: mantén este archivo por debajo.
- Los workflows de Antigravity dejan de funcionar el 2026-10-19: usa skills.
- Las skills de usuario `impeccable`, `ponytail` y `graphify` son opcionales; si tu herramienta no
  las tiene, aplica lo escrito en las reglas.

**Subagentes** (cruzar de dominio: documenta el contrato y detente):
`ingestion-specialist` (parsers, `.fork`) · `mapping-specialist` (lógica pura de mapeo) ·
`export-specialist` (pipeline DOCX, nombres) · `desktop-ui-specialist` (widgets, Riverpod, Win32) ·
`docx-parity-auditor` (parser y exportador siguen siendo espejo) · `test-engineer` ·
`release-manager` · `ci-engineer` (GitHub Actions) · `security-reviewer` (updater, ZIP, instalador) ·
`perf-profiler` · `ux-copy-reviewer` (textos en español) · `docs-curator` · `reviewer` ·
`architect` · `graph-orchestrator`.
Tienden a **commitear solos**: si quieres un único commit revisado, dilo en el prompt. Cuando un
cambio cruza dominios, primero el contrato compartido (modelo + mapeo + preview) y luego los
especialistas en paralelo.

**Grafo (graphify):** `graphify-out/GRAPH_REPORT.md` primero. Regenera con
`python .agents/scripts/graphify_rebuild.py` (nunca `/graphify .` a secas: grafo roto en silencio);
si cambiaron `.md`/`.yaml`/imágenes pide antes la extracción semántica. Skill `rebuild-graph`.

## 8. Estado conocido y deuda

- Línea base 2026-10-24: `flutter test` = **581 en verde**. `flutter analyze` = 6 avisos `info`
  (línea >80 en `document_viewer_screen.dart:750`; `use_raw_strings` y
  `missing_whitespace_between_adjacent_strings` en tests de export/catálogo): pendientes de limpiar.
- Hallazgos abiertos de la ultrareview sobre el diff sin commitear (updater y encabezados):
  - **Actualizar ahora**: `isDirty` se comprueba una vez antes de descargar; si el usuario cierra
    Ajustes y edita, `launchAndExit` hace `exit(0)` sin recomprobar ni mirar `mounted`. Tampoco
    protege el trabajo sin guardar de **otras instancias** (no hay single-instance; Inno con
    `/SILENT` + `CloseApplications=yes` las cierra).
  - `UpdateChecker.check` toma el **primer** `.exe`; debería exigir `ForkumentosSetup_v<ver>.exe`.
    `downloadInstaller` no tiene timeouts, no limpia su directorio temporal y su estado vive en el
    State del widget (reabrir Ajustes permite una segunda descarga).
  - `refreshDatasourceConfirmingHeaders` solo aplica "Aceptar y actualizar" si el estado es
    `updated`; con archivo sin cambios y encabezados ya desfasados el diálogo reaparece siempre,
    parsea el archivo dos veces y pregunta aun con cero asignaciones.
  - `DatasourceResourceCard` (asistente) refresca/reemplaza **sin** `*ConfirmingHeaders`.
- Tablas más altas que una página no se parten (atómicas); listas solo a nivel raíz; rangos solo entre párrafos de un mismo contenedor (raíz o celda).
- `Isolate.run`/`compute` solo desde funciones **de nivel superior** que reciben datos simples: una
  función anónima dentro de un método captura `this` (y con él la ventana) y falla con «object is
  unsendable» (`DocxExportCommand` lo sufrió: fallaban todos los lotes de exportación).
- Los dibujos flotantes (`wp:anchor`) se pintan **en línea** con el texto, no en su posición real.
  Solo se descartan los que seguro caen fuera de la hoja (`_isAnchoredOffPage`: Word no los dibuja).
- `docs/PROJECT_SPEC.md` es histórico (menciona PDF).

## 9. Mapa de documentación

| Archivo | Para qué |
|---|---|
| `README.md`, `CHANGELOG.md` | producto y versiones (español) |
| `docs/DESIGN_SYSTEM.md` | autoridad visual vigente |
| `docs/PROJECT_SPEC.md` | especificación original v1.0 (histórica) |
| `graphify-out/GRAPH_REPORT.md` | comunidades y god nodes del código (generado) |
