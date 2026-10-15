"""Sincroniza la configuración de IA: .agents/ (fuente) -> .claude/ (copia para Claude Code).

Uso:
    python .agents/scripts/sync.py           # copia y valida
    python .agents/scripts/sync.py --check   # solo verifica (sale con 1 si hay diferencias)

Correspondencia (copias byte a byte):
    .agents/AGENTS.md        -> .claude/CLAUDE.md
    .agents/rules/*.md       -> .claude/rules/
    .agents/skills/<n>/**    -> .claude/skills/<n>/**
    .agents/agents/*.md      -> .claude/agents/

También valida el frontmatter que exigen las dos herramientas:
    agents  : name (= nombre del archivo) y description
    skills  : name (= nombre de la carpeta) y description
    rules   : trigger in {always_on, model_decision, glob, manual}; globs si trigger=glob;
              description si trigger=model_decision
    AGENTS.md: sin frontmatter y menos de 24 000 bytes (Antigravity trunca por encima)

ponytail: parseo manual del frontmatter (claves planas) en vez de pyyaml; si algún día es YAML
anidado, cambia a pyyaml.
"""

from __future__ import annotations

import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent.parent
SRC = ROOT / ".agents"
DST = ROOT / ".claude"
LIMIT = 24_000
TRIGGERS = {"always_on", "model_decision", "glob", "manual"}


def frontmatter(text: str) -> dict[str, str] | None:
    text = text.replace("\r\n", "\n")
    if not text.startswith("---\n"):
        return None
    end = text.find("\n---\n", 4)
    if end == -1:
        return None
    meta: dict[str, str] = {}
    for line in text[4:end].splitlines():
        if ":" in line and not line.startswith((" ", "-")):
            key, _, value = line.partition(":")
            meta[key.strip()] = value.strip()
    return meta


def validate() -> list[str]:
    errors: list[str] = []

    agents_md = SRC / "AGENTS.md"
    if not agents_md.is_file():
        errors.append("falta .agents/AGENTS.md")
    else:
        raw = agents_md.read_bytes()
        if raw.startswith(b"---"):
            errors.append("AGENTS.md no debe llevar frontmatter")
        if len(raw) >= LIMIT:
            errors.append(f"AGENTS.md pesa {len(raw)} bytes (límite {LIMIT})")

    for path in sorted((SRC / "agents").glob("*.md")):
        meta = frontmatter(path.read_text(encoding="utf-8"))
        if meta is None:
            errors.append(f"{path.name}: sin frontmatter")
            continue
        if meta.get("name") != path.stem:
            errors.append(f"{path.name}: name={meta.get('name')!r} debe ser {path.stem!r}")
        if not meta.get("description"):
            errors.append(f"{path.name}: falta description")
        for forbidden in ("tools", "skills"):
            if forbidden in meta:
                errors.append(f"{path.name}: '{forbidden}' no es portable entre herramientas")

    for skill in sorted(p for p in (SRC / "skills").iterdir() if p.is_dir()):
        file = skill / "SKILL.md"
        if not file.is_file():
            errors.append(f"skills/{skill.name}: falta SKILL.md")
            continue
        meta = frontmatter(file.read_text(encoding="utf-8")) or {}
        if meta.get("name") != skill.name:
            errors.append(f"skills/{skill.name}: name={meta.get('name')!r} debe ser {skill.name!r}")
        if not meta.get("description"):
            errors.append(f"skills/{skill.name}: falta description")

    for path in sorted((SRC / "rules").glob("*.md")):
        meta = frontmatter(path.read_text(encoding="utf-8"))
        if meta is None:
            errors.append(f"rules/{path.name}: sin frontmatter (Antigravity la descarta)")
            continue
        trigger = meta.get("trigger")
        if trigger not in TRIGGERS:
            errors.append(f"rules/{path.name}: trigger={trigger!r} no válido")
        if trigger == "glob" and not (meta.get("globs") or meta.get("glob")):
            errors.append(f"rules/{path.name}: trigger=glob requiere globs")
        if trigger == "model_decision" and not meta.get("description"):
            errors.append(f"rules/{path.name}: model_decision requiere description")
        if path.stat().st_size >= LIMIT:
            errors.append(f"rules/{path.name}: supera {LIMIT} bytes")
    return errors


def plan() -> dict[pathlib.Path, pathlib.Path]:
    """destino -> origen"""
    pairs: dict[pathlib.Path, pathlib.Path] = {DST / "CLAUDE.md": SRC / "AGENTS.md"}
    for sub in ("agents", "rules"):
        for f in (SRC / sub).glob("*.md"):
            pairs[DST / sub / f.name] = f
    for f in (SRC / "skills").rglob("*"):
        if f.is_file():
            pairs[DST / "skills" / f.relative_to(SRC / "skills")] = f
    return pairs


def stale(pairs: dict[pathlib.Path, pathlib.Path]) -> list[pathlib.Path]:
    """Archivos en .claude/{agents,rules,skills} que ya no existen en la fuente."""
    out = []
    for sub in ("agents", "rules", "skills"):
        base = DST / sub
        if base.is_dir():
            out += [f for f in base.rglob("*") if f.is_file() and f not in pairs]
    return out


def main() -> int:
    check = "--check" in sys.argv[1:]
    errors = validate()
    pairs = plan()
    diffs = [d for d, s in pairs.items() if not d.is_file() or d.read_bytes() != s.read_bytes()]
    extra = stale(pairs)

    if check:
        for d in diffs:
            print(f"DESINCRONIZADO: {d.relative_to(ROOT)}")
        for f in extra:
            print(f"SOBRA: {f.relative_to(ROOT)}")
    else:
        for d in diffs:
            d.parent.mkdir(parents=True, exist_ok=True)
            d.write_bytes(pairs[d].read_bytes())
            print(f"copiado  {d.relative_to(ROOT)}")
        for f in extra:
            f.unlink()
            print(f"borrado  {f.relative_to(ROOT)}")
        diffs, extra = [], []

    for e in errors:
        print(f"ERROR: {e}")
    ok = not (errors or diffs or extra)
    print("OK" if ok else "FALLA")
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
