#!/usr/bin/env python3
"""Shukhood skills MCP server — exposes Hermes skills as MCP resources (stdio)."""

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
_HERMES = Path.home() / ".hermes" / "skills"


def _resolve_skills_dir() -> Path:
    env = os.environ.get("SHUKHOOD_SKILLS_DIR", "")
    if env:
        p = Path(env)
        if p.is_dir():
            return p
    if _VENDORED.is_dir() and any(p for p in _VENDORED.iterdir() if not p.name.startswith(".")):
        return _VENDORED
    return _HERMES


SKILLS_DIR = _resolve_skills_dir()

# ---------------------------------------------------------------------------
# Collapse threshold
# Any category dir with more sub-skills than this gets a generated index
# resource instead of flooding list_resources() with every sub-skill.
# Tune here; applies uniformly to all categories.
# ---------------------------------------------------------------------------
CATEGORY_THRESHOLD = 10

_SKIP = {"__pycache__", "node_modules", ".git", "bin", "scripts"}


# ---------------------------------------------------------------------------
# Skill discovery
# ---------------------------------------------------------------------------
def _find_skills(root: Path) -> dict[str, Path]:
    """Return {skill_name: primary_doc_path} scanning up to 2 levels deep."""
    skills: dict[str, Path] = {}
    for entry in sorted(root.iterdir()):
        if entry.name.startswith(".") or entry.name in _SKIP or not entry.is_dir():
            continue

        if (entry / "SKILL.md").exists():
            skills[entry.name] = entry / "SKILL.md"
            continue

        found_sub = False
        for sub in sorted(entry.iterdir()):
            if sub.name.startswith(".") or sub.name in _SKIP or not sub.is_dir():
                continue
            if (sub / "SKILL.md").exists():
                skills[f"{entry.name}/{sub.name}"] = sub / "SKILL.md"
                found_sub = True

        if not found_sub:
            for candidate in ("AGENTS.md", "README.md"):
                if (entry / candidate).exists():
                    skills[entry.name] = entry / candidate
                    break

    return skills


def _extract_description(skill_md: Path) -> str:
    """Pull the first-line description from SKILL.md YAML frontmatter."""
    try:
        text = skill_md.read_text(encoding="utf-8", errors="replace")
        if not text.startswith("---"):
            return ""
        end = text.find("\n---", 3)
        if end == -1:
            return ""
        frontmatter = text[3:end]
        for line in frontmatter.splitlines():
            m = re.match(r"^description:\s*(.+)$", line.strip())
            if m:
                val = m.group(1).strip()
                # Strip surrounding quotes (single or double)
                if len(val) >= 2 and val[0] in "\"'" and val[-1] == val[0]:
                    val = val[1:-1]
                # Return first sentence, max 120 chars
                return val.split(". ")[0][:120]
    except Exception:
        pass
    return ""


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
# MCP server
# ---------------------------------------------------------------------------
mcp = FastMCP(
    "shukhood-skills",
    instructions=(
        "Provides read access to all Shukhood skills. "
        "Start with 'skill://index' to see every available skill. "
        "Large category dirs expose a category index at 'skill://<category>' "
        "listing sub-skills; read individual sub-skills via 'skill://<category>/<subname>'."
    ),
)


# ── skill://index ───────────────────────────────────────────────────────────

@mcp.resource("skill://index")
def skill_index() -> str:
    """Master index of all skills and category dirs available in Shukhood."""
    lines = [f"Shukhood skills — served from {SKILLS_DIR}\n"]

    # Top-level skills (one entry each)
    lines.append(f"## Top-level skills ({len(_top_level)})\n")
    for name in sorted(_top_level):
        lines.append(f"- skill://{name}")

    # Flat categories (listed individually)
    flat_sub_count = sum(len(_by_category[c]) for c in _flat_cats)
    if _flat_cats:
        lines.append(f"\n## Flat category sub-skills ({flat_sub_count} across {len(_flat_cats)} categories)\n")
        for cat in sorted(_flat_cats):
            for sub in sorted(_by_category[cat]):
                lines.append(f"- skill://{cat}/{sub}")

    # Collapsed categories (index only)
    if _collapsed:
        lines.append(f"\n## Category indexes ({len(_collapsed)} large categories — read index for sub-skill list)\n")
        for cat in sorted(_collapsed):
            count = len(_by_category[cat])
            lines.append(f"- skill://{cat}  ({count} sub-skills)")

    return "\n".join(lines)


# ── Top-level skill resources (static, in list_resources) ───────────────────

def _register_static(name: str, path: Path) -> None:
    safe = f"skill_{name.replace('/', '__').replace('-', '_').replace('.', '_')}"

    @mcp.resource(f"skill://{name}", name=name, description=f"Skill: {name}")
    def _read() -> str:
        return path.read_text(encoding="utf-8", errors="replace")

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
            desc = _extract_description(subs[sub])
            suffix = f" — {desc}" if desc else ""
            lines.append(f"- {sub}{suffix}")
        return "\n".join(lines)

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
    return _SKILL_DOCS[key].read_text(encoding="utf-8", errors="replace")


# ---------------------------------------------------------------------------
# Tools — callable MCP functions (additive; skills remain readable as resources)
# ---------------------------------------------------------------------------

# Use the venv Python (pymupdf lives there). Falls back to sys.executable if
# the venv hasn't been created yet, though skills.sh ensures it exists before
# starting the server.
_VENV_PYTHON = Path(__file__).parent / ".venv" / "bin" / "python"
_PYTHON = str(_VENV_PYTHON) if _VENV_PYTHON.exists() else sys.executable

# iOS scripts share a common/ module via relative imports — invoke as subprocess
# from the scripts directory so Python adds it to sys.path automatically.
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
