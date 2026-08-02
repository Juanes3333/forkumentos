"""Reconstruye el grafo de conocimiento de Forkumentos en `graphify-out/`.

Uso:
    python tool/graphify_rebuild.py

Requiere el intérprete que tiene instalado `graphify` (ver `graphify-out/.graphify_python`,
que escribe la skill `/graphify`). Desde PowerShell:

    & (Get-Content graphify-out\\.graphify_python) tool\\graphify_rebuild.py

Qué hace, en orden: detecta el corpus (respetando `.graphifyignore`), extrae la
estructura del código con AST, recupera la extracción semántica de documentos desde
la caché, **normaliza los ids** (paso 4, ver abajo), construye y clusteriza el grafo,
etiqueta las comunidades, y escribe `graph.json`, `GRAPH_REPORT.md` y `graph.html`.

La extracción semántica de documentos NO se hace aquí: la produce un LLM vía la skill
`/graphify`. Este script solo la lee de la caché. Si algún documento cambió, el script
se detiene y te dice qué archivos hay que volver a extraer con `/graphify .`.

---

## Paso 4: la normalización (antes `graphify-out/_step_normalize.py`)

Es el paso no obvio y el motivo por el que existe este script. Sin él el grafo se
construye igual, pero sale roto de dos formas silenciosas:

1. **Ids con ruta absoluta.** Los archivos generados `.freezed.dart` referencian su
   fuente por ruta absoluta, así que el extractor AST acuña ids que llevan dentro el
   directorio home de la máquina (`c_users_<usuario>_documents_forkumentos_...`). No son
   portables entre clones y 9 de ellos duplican un nodo que ya existe en forma relativa.

2. **La documentación queda desconectada del código.** Este es el grave. El extractor
   AST genera ids con forma `{ruta}_{ext}_{ruta}_{símbolo}`, pero la especificación de
   extracción que siguen los subagentes documenta `{ruta}_{símbolo}`. Resultado: *todas*
   las aristas documento -> código apuntan a nodos inexistentes y se descartan al
   construir, sin aviso. `PROJECT_SPEC.md` y `ARCHITECTURE.md` acaban flotando sin
   conexión con los modelos de dominio que describen.

3. **Nodos gemelos.** La otra cara de (2). Cuando el extractor semántico no solo
   referencia la entidad sino que la *declara* como nodo, el extremo de la arista deja de
   estar colgante y el relinkeo nunca se dispara: el grafo acaba con dos `FieldAssignment`,
   el real del AST y el gemelo que nació del `.md`, y las aristas se reparten entre ambos.
   Es peor que (2) porque no se nota: el nodo existe, la arista existe, y aun así el
   documento no está hablando del código.

La normalización construye un índice del id que la especificación *dice* que tendría cada
nodo AST (`{ruta_sin_extensión}_{símbolo}`, derivado de su `source_file` y su etiqueta)
hacia el id que el AST acuñó de verdad, y resuelve contra él tanto los nodos semánticos
como los extremos de arista. Ese índice es el puente fiable; el sufijo por sí solo no
basta, porque el AST también emite ids sueltos como `mappingstate` que no terminan en la
ruta. Se conserva el match por sufijo como respaldo, restringido a ids con forma de ruta
del repositorio (`lib_`, `test_`): un token suelto como `string` NO se resuelve, haría
match con `none_string`, que es el tipo anulable `String?`, un nodo distinto.

Esto seguirá haciendo falta mientras la especificación de extracción de graphify y su
extractor AST no coincidan. Si una versión futura los alinea, el paso 4 pasará a ser
un no-op (informará 0 relinkeos) y podrá borrarse.
"""

from __future__ import annotations

import json
import multiprocessing
import re
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "graphify-out"

# Prefijo que el extractor AST filtra desde los `part of` de los .freezed.dart.
ABS_PREFIX = re.sub(r"[^a-z0-9]+", "_", str(ROOT).lower()).strip("_") + "_"

# Solo ids con forma de ruta del repo pueden resolverse por sufijo (ver docstring).
REPO_SHAPED = ("lib_", "test_")
BARE_TOKEN = re.compile(r"^[a-z0-9]+$")

ACRONYM = {
    "docx": "DOCX", "pdf": "PDF", "csv": "CSV", "xlsx": "XLSX", "zip": "ZIP",
    "ui": "UI", "app": "App", "json": "JSON", "win32": "Win32",
    "cmakelists": "CMakeLists", "svg": "SVG",
}
DOC_SUFFIXES = (".md", ".yaml", ".yml", ".txt", ".pdf", ".png", ".svg")


def spec_path() -> str:
    """Prompt de extracción; identifica las entradas de la caché semántica."""
    import os

    if env := os.environ.get("GRAPHIFY_SPEC"):
        return env
    return str(Path.home() / ".claude/skills/graphify/references/extraction-spec.md")


def step_detect() -> dict:
    from graphify.detect import detect

    result = detect(ROOT)
    (OUT / ".graphify_detect.json").write_text(
        json.dumps(result, ensure_ascii=False), encoding="utf-8"
    )
    counts = {k: len(v) for k, v in result["files"].items() if v}
    print(f"[1/8] corpus: {result['total_files']} archivos, ~{result['total_words']:,} palabras {counts}")
    for s in result.get("skipped_sensitive", []):
        print(f"      omitido: {s}")
    return result


def step_ast(detect_result: dict) -> dict:
    from graphify.extract import collect_files, extract

    code_files: list[Path] = []
    for f in detect_result.get("files", {}).get("code", []):
        p = Path(f)
        code_files.extend(collect_files(p) if p.is_dir() else [p])

    result = (
        extract(code_files, cache_root=ROOT)
        if code_files
        else {"nodes": [], "edges": [], "input_tokens": 0, "output_tokens": 0}
    )
    (OUT / ".graphify_ast.json").write_text(
        json.dumps(result, indent=2, ensure_ascii=False), encoding="utf-8"
    )
    print(f"[2/8] AST: {len(result['nodes'])} nodos, {len(result['edges'])} aristas")
    return result


def ingest_chunks(uncached: list[str]) -> bool:
    """Guarda en caché los `.graphify_chunk_*.json` que dejaron los subagentes.

    Cierra el bucle de la extracción semántica: el script lista los archivos que le
    faltan, un LLM los extrae a chunks, y la siguiente corrida los absorbe.
    """
    from graphify.cache import save_semantic_cache

    chunks = sorted(OUT.glob(".graphify_chunk_*.json"))
    if not chunks:
        return False

    nodes, edges, hyperedges = [], [], []
    for c in chunks:
        d = json.loads(c.read_text(encoding="utf-8"))
        nodes += d.get("nodes", [])
        edges += d.get("edges", [])
        hyperedges += d.get("hyperedges", [])
    saved = save_semantic_cache(
        nodes, edges, hyperedges,
        root=str(ROOT), allowed_source_files=uncached, prompt_file=spec_path(),
    )
    for c in chunks:
        c.unlink()
    print(f"      chunks ingeridos: {len(chunks)} archivo(s) de chunk, {saved} fuente(s) cacheada(s)")
    return True


def step_semantic(detect_result: dict) -> dict:
    """Lee la extracción semántica de la caché. No invoca ningún LLM."""
    from graphify.cache import check_semantic_cache

    files = [
        f
        for cat in ("document", "paper", "image")
        for f in detect_result["files"].get(cat, [])
    ]
    check = lambda: check_semantic_cache(  # noqa: E731
        files, root=str(ROOT), prompt_file=spec_path()
    )
    nodes, edges, hyperedges, uncached = check()
    if uncached and ingest_chunks(uncached):
        nodes, edges, hyperedges, uncached = check()
    if uncached:
        print(f"[3/8] ERROR: {len(uncached)} archivo(s) sin extracción semántica en caché:")
        for f in uncached:
            print(f"        {f}")
        print("      Extráelos con `/graphify .` (o con subagentes que escriban")
        print("      graphify-out/.graphify_chunk_NN.json) y vuelve a ejecutar este script.")
        raise SystemExit(1)

    result = {
        "nodes": nodes, "edges": edges, "hyperedges": hyperedges,
        "input_tokens": 0, "output_tokens": 0,
    }
    print(f"[3/8] semántica (caché): {len(nodes)} nodos, {len(edges)} aristas, {len(files)} archivos")
    return result


def norm_token(s: str) -> str:
    return re.sub(r"[^a-z0-9]+", "_", s.lower()).strip("_")


def documented_id(node: dict) -> str | None:
    """El id que la especificación de extracción dice que tendría este nodo AST.

    La especificación documenta `{ruta_sin_extensión}_{símbolo}`. Reproducirlo sobre cada
    nodo AST da un índice del id que un extractor semántico *va* a acuñar hacia el id que
    el AST acuñó de verdad, que es el único puente fiable entre ambos (el sufijo no basta:
    el AST emite ids sueltos como `mappingstate` que no terminan en la ruta).
    """
    src = (node.get("source_file") or "").replace("\\", "/")
    label = str(node.get("label") or "")
    if not src or src == "?" or not label:
        return None
    stem = src.rsplit(".", 1)[0] if "." in src.rsplit("/", 1)[-1] else src
    return f"{norm_token(stem)}_{norm_token(label)}"


def step_normalize(ast: dict, sem: dict) -> dict:
    """Fusiona AST + semántica y repara los ids. Ver la sección 'Paso 4' del docstring."""

    def strip_abs(v: str) -> str:
        return v[len(ABS_PREFIX):] if v.startswith(ABS_PREFIX) else v

    # Nodos AST primero: quitar el prefijo absoluto destapa duplicados que hay que fusionar
    # antes de que nada más se resuelva contra ellos.
    nodes, ids = [], set()
    for n in ast["nodes"]:
        n["id"] = strip_abs(n["id"])
        if n["id"] not in ids:
            ids.add(n["id"])
            nodes.append(n)
    merged_abs = len(ast["nodes"]) - len(nodes)

    canon: dict[str, str] = {}
    for n in nodes:
        if (did := documented_id(n)) and did not in ids:
            canon.setdefault(did, n["id"])

    def resolve(v: str) -> str | None:
        if hit := canon.get(v):
            return hit
        if not v.startswith(REPO_SHAPED):
            return None
        cands = [i for i in ids if i.endswith("_" + v)]
        if not cands:
            return None
        # Prefiere la fuente escrita a mano sobre su gemelo generado .freezed.dart.
        pool = [c for c in cands if "_freezed_dart_" not in c] or cands
        return min(pool, key=len)

    # Un nodo semántico que nombra una entidad que el AST ya tiene es un gemelo, no un nodo
    # nuevo: se fusiona. Si se dejara pasar, el extremo dejaría de estar colgante y el
    # relinkeo de aristas de abajo nunca se dispararía (ver punto 3 del docstring).
    resolved: dict[str, str] = {}
    for n in sem["nodes"]:
        n["id"] = strip_abs(n["id"])
        if n["id"] in ids:
            continue
        if hit := resolve(n["id"]):
            resolved[n["id"]] = hit
            continue
        ids.add(n["id"])
        nodes.append(n)
    merged_ghost = len(resolved)

    edges = ast["edges"] + sem["edges"]
    hyperedges = list(sem.get("hyperedges", []))
    for e in edges:
        e["source"], e["target"] = strip_abs(e["source"]), strip_abs(e["target"])
    for h in hyperedges:
        h["nodes"] = [strip_abs(x) for x in h.get("nodes", [])]

    unresolved: Counter[str] = Counter()
    for e in edges:
        for side in ("source", "target"):
            v = e[side]
            if v in ids:
                continue
            if v not in resolved:
                hit = resolve(v)
                if not hit:
                    unresolved[v] += 1
                    continue
                resolved[v] = hit
            e[side] = resolved[v]
    for h in hyperedges:
        h["nodes"] = [resolved.get(x, x) for x in h["nodes"]]

    # Un objetivo interno del repo sin match en el AST es un símbolo alucinado. Un token
    # suelto (`string`, `dwmapi`) es una referencia real a stdlib o a un header del
    # sistema: se deja como está, no se inventa un nodo para él.
    def phantom(v: str) -> bool:
        return v not in ids and not BARE_TOKEN.match(v)

    before = len(edges)
    edges = [e for e in edges if not (phantom(e["source"]) or phantom(e["target"]))]

    # Guardia del punto 3: un gemelo superviviente no da error en ninguna parte, solo
    # reparte las aristas entre dos nodos que son la misma entidad.
    code_labels = {
        norm_token(str(n.get("label", "")))
        for n in nodes
        if not (n.get("source_file") or "").replace("\\", "/").endswith(DOC_SUFFIXES)
    }
    twins = [
        n["label"]
        for n in nodes
        if (n.get("source_file") or "").replace("\\", "/").endswith(DOC_SUFFIXES)
        and norm_token(str(n.get("label", ""))) in code_labels
    ]

    merged = {
        "nodes": nodes, "edges": edges, "hyperedges": hyperedges,
        "input_tokens": sem.get("input_tokens", 0),
        "output_tokens": sem.get("output_tokens", 0),
    }
    (OUT / ".graphify_extract.json").write_text(
        json.dumps(merged, indent=2, ensure_ascii=False), encoding="utf-8"
    )
    print(
        f"[4/8] normalizado: {len(nodes)} nodos, {len(edges)} aristas "
        f"({merged_abs} duplicados por ruta absoluta fusionados, "
        f"{merged_ghost} nodos gemelos doc->código fusionados, "
        f"{len(resolved) - merged_ghost} extremos de arista relinkeados, "
        f"{before - len(edges)} aristas fantasma eliminadas)"
    )
    for k, v in sorted(resolved.items()):
        print(f"        {k} -> {v}")
    if twins:
        print(f"        AVISO: {len(twins)} gemelo(s) sin fusionar: {', '.join(sorted(twins))}")
    if unresolved:
        ext = sum(c for k, c in unresolved.items() if BARE_TOKEN.match(k))
        print(f"        {ext} aristas a referencias externas (stdlib / headers) sin resolver")
    return merged


def prettify(stem: str) -> str:
    return " ".join(
        ACRONYM.get(w, w.capitalize()) for w in re.split(r"[_\-.]+", stem) if w
    )


# Símbolos que existen en casi todos los archivos: nombran el lenguaje, no el clúster.
GENERIC_LABELS = {"main", "build", "createState", "initState", "setUp", "tearDown"}


def is_concept_label(label: object) -> bool:
    """True si la etiqueta nombra una entidad, no una ruta, import o símbolo trivial."""
    if not isinstance(label, str) or len(label) < 3:
        return False
    if label in GENERIC_LABELS:
        return False
    if label.startswith(("package:", "dart:", ".", "@", "_")):
        return False
    if "/" in label or "\\" in label or label.endswith((".dart", ".yaml", ".md", ".txt")):
        return False
    return True


def label_for(members: list[str], nodes: dict, degree: Counter) -> str:
    """Nombre de comunidad, derivado del contenido para que sobreviva a reconstrucciones.

    Louvain sobre un grafo a nivel de símbolo agrupa los símbolos por el archivo que
    los declara, así que la mayoría de comunidades SON un archivo y su nombre honesto
    es ese archivo. Las que la capa semántica produjo sí cruzan archivos: esas se
    nombran con su concepto de mayor grado. Los ids de comunidad cambian en cada
    reconstrucción, por eso no se codifican a mano.
    """
    files = Counter()
    for m in members:
        sf = (nodes.get(m) or {}).get("source_file")
        if sf and sf != "?":
            files[sf.replace("\\", "/")] += 1
    if not files:
        top_node = max(members, key=lambda m: degree[m], default=None)
        return prettify(str((nodes.get(top_node) or {}).get("label") or "misc"))[:40]

    top, top_count = files.most_common(1)[0]
    conceptual = top_count / sum(files.values()) < 0.5 or top.endswith(DOC_SUFFIXES)
    if conceptual:
        # El nodo de mayor grado suele ser el archivo o un import; ninguno nombra un
        # concepto. Se busca la entidad con nombre de mayor grado, priorizando las que
        # vienen de documentos (que es lo que esta rama existe para nombrar), y si no
        # hay ninguna se cae al nombre derivado del archivo en lugar de una ruta.
        named = [m for m in members if is_concept_label((nodes.get(m) or {}).get("label"))]
        from_docs = [
            m
            for m in named
            if (nodes[m].get("source_file") or "").replace("\\", "/").endswith(DOC_SUFFIXES)
        ]
        if pool := (from_docs or named):
            return str(nodes[max(pool, key=lambda m: degree[m])]["label"])[:48]

    p = Path(top)
    pretty = prettify(p.name.split(".")[0])
    parts = p.parts
    if parts[0] == "test":
        return f"Test: {pretty}"
    if parts[0] == "windows":
        return f"Windows Runner: {pretty}"
    if parts[0] == "lib" and len(parts) > 2 and parts[1] == "features":
        return f"{prettify(parts[2])}: {pretty}"
    if parts[0] == "lib" and len(parts) > 1:
        return f"{prettify(parts[1])}: {pretty}"
    return pretty


def step_build_and_report(extraction: dict, detection: dict) -> None:
    from graphify.analyze import god_nodes, suggest_questions, surprising_connections
    from graphify.build import build_from_json
    from graphify.cluster import cluster, score_all
    from graphify.diagnostics import diagnose_extraction, format_diagnostic_report
    from graphify.export import to_json
    from graphify.report import generate

    G = build_from_json(extraction, root=str(ROOT), directed=False)
    if G.number_of_nodes() == 0:
        print("[5/8] ERROR: el grafo quedó vacío, la extracción no produjo nodos.")
        raise SystemExit(1)

    communities = cluster(G)
    cohesion = score_all(G, communities)
    gods = god_nodes(G)
    surprises = surprising_connections(G, communities)
    print(
        f"[5/8] grafo: {G.number_of_nodes()} nodos, {G.number_of_edges()} aristas, "
        f"{len(communities)} comunidades"
    )

    summary = diagnose_extraction(extraction, directed=False, root=str(ROOT))
    flags = [
        f"{summary[k]} {label}"
        for k, label in (
            ("dangling_endpoint_edges", "aristas colgantes"),
            ("missing_endpoint_edges", "aristas sin extremo"),
            ("self_loop_edges", "auto-referencias"),
        )
        if summary.get(k, 0)
    ]
    print(f"[6/8] salud: {'; '.join(flags) if flags else 'OK'}")
    (OUT / "diagnostics.txt").write_text(
        format_diagnostic_report(summary), encoding="utf-8"
    )

    degree = Counter()
    for u, v in G.edges():
        degree[u] += 1
        degree[v] += 1
    nodes = {n: G.nodes[n] for n in G.nodes}
    labels = {cid: label_for(m, nodes, degree) for cid, m in communities.items()}

    # to_json rechaza escribir un grafo más pequeño que el existente (#479). Al excluir
    # archivos el encogimiento es intencional, así que se retira el anterior primero.
    (OUT / "graph.json").unlink(missing_ok=True)
    if not to_json(G, communities, str(OUT / "graph.json")):
        print("[7/8] ERROR: no se pudo escribir graph.json.")
        raise SystemExit(1)

    tokens = {
        "input": extraction.get("input_tokens", 0),
        "output": extraction.get("output_tokens", 0),
    }
    questions = suggest_questions(G, communities, labels)
    report = generate(
        G, communities, cohesion, labels, gods, surprises,
        detection, tokens, str(ROOT), suggested_questions=questions,
    )
    (OUT / "GRAPH_REPORT.md").write_text(report, encoding="utf-8")
    (OUT / ".graphify_labels.json").write_text(
        json.dumps({str(k): v for k, v in labels.items()}, ensure_ascii=False),
        encoding="utf-8",
    )
    print(f"[7/8] graph.json + GRAPH_REPORT.md escritos ({len(labels)} comunidades etiquetadas)")
    print("      god nodes: " + ", ".join(f"{g['label']} ({g['degree']})" for g in gods[:5]))


def step_manifest(detection: dict, extraction: dict) -> None:
    from graphify.cli import _stamped_manifest_files
    from graphify.detect import save_manifest

    corpus = detection.get("all_files") or detection["files"]
    manifest_files = _stamped_manifest_files(corpus, extraction, ROOT)
    scan = {f for fl in corpus.values() for f in fl}
    save_manifest(manifest_files, root=str(ROOT), scan_corpus=scan)
    print(f"[8/8] manifiesto guardado ({sum(len(v) for v in manifest_files.values())} archivos)")

    for name in (".graphify_detect.json", ".graphify_ast.json", ".graphify_extract.json"):
        (OUT / name).unlink(missing_ok=True)


def main() -> None:
    OUT.mkdir(exist_ok=True)
    if not Path(spec_path()).exists():
        print(f"aviso: no se encontró la especificación de extracción en {spec_path()}")
        print("       (define GRAPHIFY_SPEC si vive en otra ruta; la caché fallará sin ella)")

    detection = step_detect()
    if detection["total_files"] == 0:
        print("No se encontraron archivos soportados.")
        raise SystemExit(1)

    ast = step_ast(detection)
    sem = step_semantic(detection)
    extraction = step_normalize(ast, sem)
    step_build_and_report(extraction, detection)
    step_manifest(detection, extraction)

    print(f"\nListo. Ejecuta `graphify export html` para regenerar {OUT / 'graph.html'}")


if __name__ == "__main__":
    multiprocessing.freeze_support()
    sys.exit(main())
