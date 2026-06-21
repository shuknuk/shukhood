#!/usr/bin/env python3
"""Shukhood skills MCP server — exposes skills as MCP resources (stdio)."""

import os
import re
import subprocess
import sys
from collections import defaultdict
from pathlib import Path

from fastmcp import FastMCP

# ---------------------------------------------------------------------------
# Skills directory resolution
# ---------------------------------------------------------------------------
_REPO_ROOT = Path(__file__).parent.parent.parent
_VENDORED = _REPO_ROOT / "skills"


def _resolve_skills_dir() -> Path:
    env = os.environ.get("SHUKHOOD_SKILLS_DIR", "")
    if env:
        p = Path(env)
        if p.is_dir():
            return p
    return _VENDORED


SKILLS_DIR = _resolve_skills_dir()

# ---------------------------------------------------------------------------
# Collapse threshold
# Any category dir with more sub-skills than this gets a generated index
# resource instead of flooding list_resources() with every sub-skill.
# ---------------------------------------------------------------------------
CATEGORY_THRESHOLD = 10

_SKIP = {"__pycache__", "node_modules", ".git", "bin", "scripts"}

# ---------------------------------------------------------------------------
# Category map — every top-level skill dir assigned to one umbrella category.
# Sub-skills inherit from their parent dir's category.
# ---------------------------------------------------------------------------
_CATEGORY_MAP: dict[str, str] = {
    # GStack — Browser & QA
    "gstack":                    "GStack — Browser & QA",
    "gstack-browse":             "GStack — Browser & QA",
    "gstack-qa":                 "GStack — Browser & QA",
    "gstack-qa-only":            "GStack — Browser & QA",
    "gstack-canary":             "GStack — Browser & QA",
    "gstack-benchmark":          "GStack — Browser & QA",
    "gstack-scrape":             "GStack — Browser & QA",
    "gstack-skillify":           "GStack — Browser & QA",
    "gstack-open-gstack-browser":"GStack — Browser & QA",
    "gstack-setup-browser-cookies": "GStack — Browser & QA",
    "browser-automation":        "GStack — Browser & QA",
    "dogfood":                   "GStack — Browser & QA",
    # GStack — iOS
    "gstack-ios-qa":             "GStack — iOS",
    "gstack-ios-fix":            "GStack — iOS",
    "gstack-ios-design-review":  "GStack — iOS",
    "gstack-ios-clean":          "GStack — iOS",
    "gstack-ios-sync":           "GStack — iOS",
    "ios":                       "GStack — iOS",
    "mobile-development":        "GStack — iOS",
    # GStack — Code & Engineering
    "gstack-spec":               "GStack — Code & Engineering",
    "gstack-ship":               "GStack — Code & Engineering",
    "gstack-review":             "GStack — Code & Engineering",
    "gstack-investigate":        "GStack — Code & Engineering",
    "gstack-health":             "GStack — Code & Engineering",
    "gstack-land-and-deploy":    "GStack — Code & Engineering",
    "gstack-landing-report":     "GStack — Code & Engineering",
    "gstack-upgrade":            "GStack — Code & Engineering",
    "gstack-benchmark-models":   "GStack — Code & Engineering",
    "gstack-autoplan":           "GStack — Code & Engineering",
    "gstack-careful":            "GStack — Code & Engineering",
    "gstack-guard":              "GStack — Code & Engineering",
    "gstack-freeze":             "GStack — Code & Engineering",
    "gstack-unfreeze":           "GStack — Code & Engineering",
    "gstack-plan-eng-review":    "GStack — Code & Engineering",
    "gstack-setup-deploy":       "GStack — Code & Engineering",
    "software-development":      "GStack — Code & Engineering",
    "devops":                    "GStack — Code & Engineering",
    # GStack — Design & Docs
    "gstack-design-html":        "GStack — Design & Docs",
    "gstack-design-review":      "GStack — Design & Docs",
    "gstack-design-shotgun":     "GStack — Design & Docs",
    "gstack-design-consultation":"GStack — Design & Docs",
    "gstack-plan-design-review": "GStack — Design & Docs",
    "gstack-plan-ceo-review":    "GStack — Design & Docs",
    "gstack-plan-devex-review":  "GStack — Design & Docs",
    "gstack-devex-review":       "GStack — Design & Docs",
    "gstack-document-generate":  "GStack — Design & Docs",
    "gstack-document-release":   "GStack — Design & Docs",
    "gstack-make-pdf":           "GStack — Design & Docs",
    "gstack-retro":              "GStack — Design & Docs",
    "gstack-plan-tune":          "GStack — Design & Docs",
    "gstack-office-hours":       "GStack — Design & Docs",
    "gstack-cso":                "GStack — Design & Docs",
    # GStack — Context & Agents
    "gstack-context-save":       "GStack — Context & Agents",
    "gstack-context-restore":    "GStack — Context & Agents",
    "gstack-pair-agent":         "GStack — Context & Agents",
    "gstack-setup-gbrain":       "GStack — Context & Agents",
    "gstack-sync-gbrain":        "GStack — Context & Agents",
    "gstack-claude":             "GStack — Context & Agents",
    "gstack-learn":              "GStack — Context & Agents",
    "autonomous-ai-agents":      "GStack — Context & Agents",
    "claude-fable-5":            "GStack — Context & Agents",
    # Design
    "gsap-core":                 "Design",
    "gsap-frameworks":           "Design",
    "gsap-performance":          "Design",
    "gsap-plugins":              "Design",
    "gsap-react":                "Design",
    "gsap-scrolltrigger":        "Design",
    "gsap-timeline":             "Design",
    "gsap-utils":                "Design",
    "diagramming":               "Design",
    "awesome-design-skills":     "Design",
    "design-skills":             "Design",
    "creative":                  "Design",
    # Document & Office
    "docs":                      "Document & Office",
    "productivity":              "Document & Office",
    "note-taking":               "Document & Office",
    # Science & Research
    "scientific-skills":         "Science & Research",
    "medical-research":          "Science & Research",
    "research":                  "Science & Research",
    "data-science":              "Science & Research",
    "mlops":                     "Science & Research",
    # Media & Creative
    "media":                     "Media & Creative",
    "gifs":                      "Media & Creative",
    "voicebox":                  "Media & Creative",
    "gaming":                    "Media & Creative",
    # Developer Tooling
    "mcp":                       "Developer Tooling",
    "github":                    "Developer Tooling",
    "domain":                    "Developer Tooling",
    "security":                  "Developer Tooling",
    "inference-sh":              "Developer Tooling",
    "apple":                     "Developer Tooling",
    "skill-building":            "Developer Tooling",
    "master-skill-index":        "Developer Tooling",
    # Communication & Social
    "email":                     "Communication & Social",
    "social-media":              "Communication & Social",
    "yuanbao":                   "Communication & Social",
    "smart-home":                "Communication & Social",
    # Anthropic / Claude Ecosystem
    "anthropic-cookbooks":       "Anthropic / Claude Ecosystem",
    "awesome-claude-skills-index":"Anthropic / Claude Ecosystem",
    "writing-content":           "Anthropic / Claude Ecosystem",
    # Superpowers
    "superpowers":               "Superpowers",
    # Red Teaming
    "red-teaming":               "Red Teaming",
}

# Display order for categories in the rendered index
_CATEGORY_ORDER = [
    "GStack — Browser & QA",
    "GStack — iOS",
    "GStack — Code & Engineering",
    "GStack — Design & Docs",
    "GStack — Context & Agents",
    "Design",
    "Document & Office",
    "Science & Research",
    "Media & Creative",
    "Developer Tooling",
    "Communication & Social",
    "Anthropic / Claude Ecosystem",
    "Superpowers",
    "Red Teaming",
]


# ---------------------------------------------------------------------------
# Skill discovery
# ---------------------------------------------------------------------------
_ROOT_DOC_NAMES = ("SKILL.md", "SOUL.md")


def _find_skills(root: Path) -> dict[str, Path]:
    """Return {skill_name: primary_doc_path} scanning up to 3 levels deep.

    Level 1: skills/<entry>/SKILL.md  → flat skill keyed as <entry>
    Level 2: skills/<entry>/<sub>/SKILL.md  → category skill keyed as <entry>/<sub>
    Level 3: skills/<entry>/<sub>/<subsub>/SKILL.md  → collapsed under <entry>/<subsub>
             (used by superpowers/ which splits skills into community/core/lab sub-dirs)
    """
    skills: dict[str, Path] = {}
    for entry in sorted(root.iterdir()):
        if entry.name.startswith(".") or entry.name in _SKIP or not entry.is_dir():
            continue

        root_doc = next((entry / n for n in _ROOT_DOC_NAMES if (entry / n).exists()), None)
        if root_doc is not None and root_doc.stat().st_size > 0:
            skills[entry.name] = root_doc
            continue

        found_sub = False
        for sub in sorted(entry.iterdir()):
            if sub.name.startswith(".") or sub.name in _SKIP or not sub.is_dir():
                continue
            if (sub / "SKILL.md").exists():
                skills[f"{entry.name}/{sub.name}"] = sub / "SKILL.md"
                found_sub = True
            else:
                # Level 3: category sub-dirs that themselves contain skill dirs
                for subsub in sorted(sub.iterdir()):
                    if subsub.name.startswith(".") or subsub.name in _SKIP or not subsub.is_dir():
                        continue
                    if (subsub / "SKILL.md").exists():
                        skills[f"{entry.name}/{subsub.name}"] = subsub / "SKILL.md"
                        found_sub = True

        if not found_sub:
            for candidate in ("AGENTS.md", "README.md"):
                if (entry / candidate).exists():
                    skills[entry.name] = entry / candidate
                    break

    return skills


def _extract_metadata(skill_md: Path) -> tuple[str, list[str]]:
    """Return (description, tags) from a SKILL.md file.

    Reads frontmatter first; falls back to first substantial body paragraph
    for skills without a description field.
    """
    description = ""
    tags: list[str] = []
    try:
        text = skill_md.read_text(encoding="utf-8", errors="replace")
        body_start = 0

        if text.startswith("---"):
            end = text.find("\n---", 3)
            if end != -1:
                fm_text = text[3:end]
                body_start = end + 4

                # Extract description — handles both inline and block scalar (|)
                in_desc_block = False
                desc_lines: list[str] = []
                for line in fm_text.splitlines():
                    if in_desc_block:
                        if line.startswith("  ") or line.startswith("\t"):
                            desc_lines.append(line.strip())
                        else:
                            in_desc_block = False
                    m = re.match(r"^description:\s*\|\s*$", line.strip())
                    if m:
                        in_desc_block = True
                        continue
                    m = re.match(r'^description:\s*["\']?(.+?)["\']?\s*$', line.strip())
                    if m and not in_desc_block:
                        desc_lines = [m.group(1).strip()]

                if desc_lines:
                    raw = " ".join(desc_lines)
                    # Strip trailing parenthetical like " (gstack)" from autogenerated docs
                    raw = re.sub(r"\s*\([^)]{1,20}\)\s*$", "", raw)
                    description = raw.split(". ")[0].strip()[:140]

                # Extract tags
                for line in fm_text.splitlines():
                    m = re.match(r"^tags:\s*\[(.+)\]", line.strip())
                    if m:
                        tags = [t.strip().strip("\"'") for t in m.group(1).split(",")]
                    m = re.match(r"^tags:\s*$", line.strip())
                    if m:
                        # Block-style tags on following lines
                        pass  # simple inline format is sufficient

        # Fallback: first substantial non-heading body line
        if not description:
            for line in text[body_start:].splitlines():
                line = line.strip()
                if (
                    line
                    and not line.startswith("#")
                    and not line.startswith("---")
                    and not line.startswith("<!--")
                    and len(line) > 20
                ):
                    description = line[:140]
                    break

    except Exception:
        pass

    return description, tags


# ---------------------------------------------------------------------------
# Build skill map and split into flat vs. collapsed categories
# ---------------------------------------------------------------------------
_SKILL_DOCS: dict[str, Path] = _find_skills(SKILLS_DIR)

# Separate top-level skills from category/sub-skill pairs
_top_level: dict[str, Path] = {}
_by_category: dict[str, dict[str, Path]] = defaultdict(dict)

for _name, _path in _SKILL_DOCS.items():
    if "/" in _name:
        _cat, _sub = _name.split("/", 1)
        _by_category[_cat][_sub] = _path
    else:
        _top_level[_name] = _path

# Categories exceeding the threshold get a generated index + template URIs
_collapsed: set[str] = {
    cat for cat, subs in _by_category.items() if len(subs) > CATEGORY_THRESHOLD
}
_flat_cats: set[str] = set(_by_category) - _collapsed


# ---------------------------------------------------------------------------
# Master skills index — built once at startup, cached in memory
# ---------------------------------------------------------------------------
def _lookup_category(skill_name: str) -> str:
    """Return umbrella category for a skill, inheriting from parent if nested."""
    top = skill_name.split("/")[0]
    return _CATEGORY_MAP.get(top, "Uncategorized")


def _build_index() -> list[dict]:
    """Build a flat list of index entries for every registered resource.

    Each entry: {name, uri, category, description, tags}
    Grouped by category only for rendering — storage is a flat list.
    """
    entries: list[dict] = []

    # Top-level flat skills
    for name, path in sorted(_top_level.items()):
        desc, tags = _extract_metadata(path)
        entries.append({
            "name": name,
            "uri": f"skill://{name}",
            "category": _lookup_category(name),
            "description": desc,
            "tags": tags,
        })

    # Flat-category sub-skills (listed individually in list_resources)
    for cat in sorted(_flat_cats):
        for sub, path in sorted(_by_category[cat].items()):
            name = f"{cat}/{sub}"
            desc, tags = _extract_metadata(path)
            entries.append({
                "name": name,
                "uri": f"skill://{name}",
                "category": _lookup_category(name),
                "description": desc,
                "tags": tags,
            })

    # Collapsed category indexes (single entry per large category)
    for cat in sorted(_collapsed):
        path = next(iter(_by_category[cat].values()))  # sample for metadata
        desc, tags = _extract_metadata(path)
        count = len(_by_category[cat])
        entries.append({
            "name": cat,
            "uri": f"skill://{cat}",
            "category": _lookup_category(cat),
            "description": f"{count} sub-skills — {desc}" if desc else f"{count} sub-skills",
            "tags": tags,
            "sub_count": count,
        })

    return entries


_APPLY_HEADER    = "> [$HUKHOOD] You are reading a skill from the Shukhood MCP server. Mark your response with [$HUKHOOD].\n\n"
_DISCOVER_HEADER = "> [$HUKHOOD - discovery] You are browsing the Shukhood MCP skill library.\n\n"


def _render_master_index(entries: list[dict]) -> str:
    """Render the index as category-grouped text optimized for model scanning."""
    # Group by category
    by_cat: dict[str, list[dict]] = defaultdict(list)
    for e in entries:
        by_cat[e["category"]].append(e)

    total = len(entries)
    lines = [
        f"[$HUKHOOD - discovery]",
        f"# Shukhood Master Skills Index",
        f"# {total} entries across {len(by_cat)} categories — {SKILLS_DIR}",
        f"# Usage: read skill://index for this list · read skill://<uri> for full skill doc",
        "",
    ]

    seen_cats = set()
    ordered = list(_CATEGORY_ORDER) + sorted(c for c in by_cat if c not in _CATEGORY_ORDER)

    for cat in ordered:
        if cat not in by_cat or cat in seen_cats:
            continue
        seen_cats.add(cat)
        cat_entries = sorted(by_cat[cat], key=lambda e: e["name"])
        lines.append(f"## {cat}  ({len(cat_entries)})")
        for e in cat_entries:
            tags_str = "  #" + " #".join(e["tags"]) if e["tags"] else ""
            desc = e["description"] or "(no description)"
            # Truncate desc so lines stay readable
            if len(desc) > 110:
                desc = desc[:107] + "..."
            lines.append(f"  {e['uri']:<50}  {desc}{tags_str}")
        lines.append("")

    return "\n".join(lines)


# Build index once at startup
_SKILL_INDEX: list[dict] = _build_index()
_MASTER_INDEX_TEXT: str = _render_master_index(_SKILL_INDEX)

# ---------------------------------------------------------------------------
# MCP server
# ---------------------------------------------------------------------------
mcp = FastMCP(
    "shukhood-skills",
    instructions=(
        "Provides read access to all Shukhood skills. "
        "Start with 'skill://master-skills-index' to see every available skill "
        "with descriptions, tags, and categories. "
        "Large category dirs expose a category index at 'skill://<category>' "
        "listing sub-skills; read individual sub-skills via 'skill://<category>/<subname>'."
    ),
)


# ── skill://master-skills-index ─────────────────────────────────────────────

@mcp.resource("skill://master-skills-index")
def skill_master_index() -> str:
    """Master skills index: all skills with descriptions, tags, and categories."""
    return _MASTER_INDEX_TEXT


# ── skill://index — alias to master-skills-index ────────────────────────────

@mcp.resource("skill://index")
def skill_index() -> str:
    """Alias for skill://master-skills-index."""
    return _MASTER_INDEX_TEXT


# ── Top-level skill resources (static, in list_resources) ───────────────────

def _register_static(name: str, path: Path) -> None:
    safe = f"skill_{name.replace('/', '__').replace('-', '_').replace('.', '_')}"

    @mcp.resource(f"skill://{name}", name=name, description=f"Skill: {name}")
    def _read() -> str:
        return _APPLY_HEADER + path.read_text(encoding="utf-8", errors="replace")

    _read.__name__ = safe


for _name, _path in sorted(_top_level.items()):
    _register_static(_name, _path)


# ── Flat-category sub-skills (static, in list_resources) ────────────────────

for _cat in sorted(_flat_cats):
    for _sub, _path in sorted(_by_category[_cat].items()):
        _register_static(f"{_cat}/{_sub}", _path)


# ── Collapsed-category indexes (static, in list_resources) ──────────────────

def _make_category_index(category: str, subs: dict[str, Path]) -> None:
    count = len(subs)

    @mcp.resource(
        f"skill://{category}",
        name=category,
        description=f"Category index: {category} ({count} sub-skills)",
    )
    def _cat_index() -> str:
        lines = [f"# {category} — {count} sub-skills\n"]
        lines.append(
            f"Read individual sub-skills via skill://{category}/<subname>\n"
        )
        for sub in sorted(subs):
            desc, _ = _extract_metadata(subs[sub])
            suffix = f" — {desc}" if desc else ""
            lines.append(f"- {sub}{suffix}")
        return _DISCOVER_HEADER + "\n".join(lines)

    _cat_index.__name__ = f"skill_cat_{category.replace('-', '_')}"


for _cat in sorted(_collapsed):
    _make_category_index(_cat, _by_category[_cat])


# ── Resource template for collapsed-category sub-skills ─────────────────────
# Not in list_resources(); discoverable via the category index.

@mcp.resource("skill://{category}/{subname}")
def get_sub_skill(category: str, subname: str) -> str:
    """Read a sub-skill from any category directory."""
    key = f"{category}/{subname}"
    if key not in _SKILL_DOCS:
        raise ValueError(
            f"Sub-skill '{key}' not found. "
            f"Read skill://{category} for the list of available sub-skills."
        )
    return _APPLY_HEADER + _SKILL_DOCS[key].read_text(encoding="utf-8", errors="replace")


# ---------------------------------------------------------------------------
# Tools — callable MCP functions (additive; skills remain readable as resources)
# ---------------------------------------------------------------------------

_VENV_PYTHON = Path(__file__).parent / ".venv" / "bin" / "python"
_PYTHON = str(_VENV_PYTHON) if _VENV_PYTHON.exists() else sys.executable

_IOS_SCRIPTS = SKILLS_DIR / "ios" / "ios-simulator-skill" / "scripts"


def _run_script(script: Path, args: list[str], timeout: int = 60) -> str:
    """Run a Python script as a subprocess; return stdout or a formatted error."""
    if not script.exists():
        return f"Error: script not found at {script}"
    try:
        result = subprocess.run(
            [_PYTHON, str(script)] + args,
            capture_output=True,
            text=True,
            timeout=timeout,
        )
    except subprocess.TimeoutExpired:
        return f"Error: script timed out after {timeout}s"
    if result.returncode != 0:
        err = result.stderr.strip()
        out = result.stdout.strip()
        return f"Error (exit {result.returncode}): {err or out or 'command failed'}"
    return result.stdout.strip() or "(no output)"


# ── PDF extraction ───────────────────────────────────────────────────────────

@mcp.tool()
def extract_pdf(
    path: str,
    mode: str = "text",
    pages: str | None = None,
) -> str:
    """Extract content from a PDF file.

    path:  absolute path to the PDF file.
    mode:  'text' (default) — plain text per page;
           'markdown' — layout-aware markdown via pymupdf4llm;
           'tables'   — table contents in markdown format;
           'metadata' — JSON with page count, title, author, etc.
    pages: optional 0-indexed page range, e.g. '0-4' or '2'.
    """
    script = SKILLS_DIR / "productivity" / "ocr-and-documents" / "scripts" / "extract_pymupdf.py"
    _MODE_FLAGS = {"markdown": "--markdown", "tables": "--tables", "metadata": "--metadata"}
    if mode not in {*_MODE_FLAGS, "text"}:
        return f"Error: unknown mode '{mode}'. Valid modes: text, markdown, tables, metadata"
    args = [path]
    if mode in _MODE_FLAGS:
        args.append(_MODE_FLAGS[mode])
    if pages:
        args += ["--pages", pages]
    return _run_script(script, args, timeout=60)


# ── iOS simulator — list/boot/shutdown ──────────────────────────────────────

@mcp.tool()
def list_simulators(
    device_type: str | None = None,
    suggest: bool = False,
) -> str:
    """List available iOS simulators. Requires Xcode / xcrun on this machine.

    device_type: optional filter, e.g. 'iPhone' or 'iPad'.
    suggest:     if True, return scored recommendations ranked by boot status
                 and iOS version instead of the default summary.
    Returns JSON. Use the cache_id from the summary to retrieve full details.
    """
    args = ["--json"]
    if suggest:
        args.append("--suggest")
    if device_type:
        args += ["--device-type", device_type]
    return _run_script(_IOS_SCRIPTS / "sim_list.py", args)


@mcp.tool()
def boot_simulator(
    udid: str,
    wait_ready: bool = False,
    timeout: int = 120,
) -> str:
    """Boot an iOS simulator by UDID. Requires Xcode / xcrun.

    udid:       simulator UDID (obtain from list_simulators).
    wait_ready: if True, block until the device is fully responsive.
    timeout:    seconds to wait when wait_ready=True (default 120).
    Returns JSON with success status and elapsed time.
    """
    args = ["--udid", udid, "--json"]
    if wait_ready:
        args += ["--wait-ready", "--timeout", str(timeout)]
    return _run_script(_IOS_SCRIPTS / "simctl_boot.py", args, timeout=timeout + 30)


@mcp.tool()
def shutdown_simulator(
    udid: str | None = None,
    shutdown_all: bool = False,
) -> str:
    """Shut down an iOS simulator. Requires Xcode / xcrun.

    udid:         simulator UDID to shut down (obtain from list_simulators).
    shutdown_all: if True, shut down every booted simulator (udid is ignored).
    Exactly one of udid or shutdown_all=True must be provided.
    Returns JSON with success status.
    """
    if not udid and not shutdown_all:
        return "Error: provide udid or set shutdown_all=True"
    args = ["--json"]
    if shutdown_all:
        args.append("--all")
    else:
        args += ["--udid", udid]
    return _run_script(_IOS_SCRIPTS / "simctl_shutdown.py", args, timeout=60)


# ── iOS simulator — app lifecycle ────────────────────────────────────────────

@mcp.tool()
def launch_app(
    bundle_id: str,
    udid: str | None = None,
    launch_args: list[str] | None = None,
) -> str:
    """Launch an iOS app in the simulator. Requires Xcode / xcrun.

    bundle_id:   app bundle identifier, e.g. 'com.apple.mobilesafari'.
    udid:        simulator UDID (auto-detects booted simulator if omitted).
    launch_args: optional arguments forwarded to the app process.
    Returns PID on success.
    """
    args = ["--launch", bundle_id]
    if udid:
        args += ["--udid", udid]
    if launch_args:
        args += ["--args"] + launch_args
    return _run_script(_IOS_SCRIPTS / "app_launcher.py", args)


@mcp.tool()
def terminate_app(
    bundle_id: str,
    udid: str | None = None,
) -> str:
    """Terminate a running iOS app in the simulator. Requires Xcode / xcrun.

    bundle_id: app bundle identifier, e.g. 'com.apple.mobilesafari'.
    udid:      simulator UDID (auto-detects booted simulator if omitted).
    """
    args = ["--terminate", bundle_id]
    if udid:
        args += ["--udid", udid]
    return _run_script(_IOS_SCRIPTS / "app_launcher.py", args)


@mcp.tool()
def list_simulator_apps(
    udid: str | None = None,
) -> str:
    """List apps installed in the booted iOS simulator. Requires Xcode / xcrun.

    udid: simulator UDID (auto-detects booted simulator if omitted).
    Returns a list of installed apps with bundle IDs, names, and versions.
    """
    args = ["--list"]
    if udid:
        args += ["--udid", udid]
    return _run_script(_IOS_SCRIPTS / "app_launcher.py", args)


if __name__ == "__main__":
    mcp.run()
