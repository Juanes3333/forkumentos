---
name: rebuild-graph
description: Regenera el grafo de conocimiento (graphify-out/) de Forkumentos con el script del repositorio, que normaliza los ids y conecta la documentación con el código. Úsala cuando el grafo esté desactualizado, refleje código ya borrado o tras cambios grandes. Nunca uses /graphify . a secas.
---

# Regenerar el grafo de Forkumentos

**No ejecutes `/graphify .` a secas**: el pipeline crudo produce un grafo roto sin avisar (ids con
ruta absoluta de los `.freezed.dart` y aristas documento → código que apuntan a nodos
inexistentes). Usa el script del repositorio, que hace el pipeline completo con un paso de
normalización.

## Pasos (PowerShell, desde la raíz del repo)

```powershell
$py = (Get-Content graphify-out\.graphify_python -Raw).Trim([char]0xFEFF).Trim()
& $py .agents\scripts\graphify_rebuild.py
& (Join-Path (Split-Path $py) 'graphify.exe') export html
```

El script no usa ningún LLM: lee de caché la extracción semántica de documentos.

## Si se detiene con "N archivo(s) sin extracción semántica en caché"
Cambió algún `.md`, `.yaml` o imagen. Hay que extraerlos y volver a ejecutar el script:
1. Ejecuta la extracción semántica solo de esos archivos con la skill `/graphify` (un subagente
   de extracción basta; el resultado se guarda con `graphify.cache.save_semantic_cache`).
2. Vuelve a ejecutar el script.

## Después
- Revisa `graphify-out/GRAPH_REPORT.md`: ya no debe haber nodos de código eliminado.
- Valida que las comunidades respetan las capas y fronteras de `.agents/AGENTS.md` §3.
- Las exclusiones del corpus viven en `.graphifyignore` (la copia generada `.claude/` y los datos
  de usuario no entran). Añade ahí cualquier exclusión nueva en vez de pasar flags.
