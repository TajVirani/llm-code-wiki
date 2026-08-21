#!/usr/bin/env python3
"""Collect mechanical facts about a change set into JSON.

Usage:
    python3 collect_change_data.py --repo /path/to/repo [--base REF] [--head REF] [--out FILE]

If --base is omitted, uses the merge-base of HEAD with the first of
origin/main, origin/master, main, master, develop that exists.
Writes JSON to --out (default: stdout).
"""

import argparse
import fnmatch
import json
import subprocess
import sys
from collections import defaultdict

# ---------------------------------------------------------------- categories

LOCKFILES = {
    "package-lock.json", "yarn.lock", "pnpm-lock.yaml", "bun.lockb", "bun.lock",
    "Cargo.lock", "poetry.lock", "Pipfile.lock", "composer.lock", "Gemfile.lock",
    "go.sum", "uv.lock", "packages.lock.json", "gradle.lockfile", "flake.lock",
}

GENERATED_PATTERNS = [
    "*.min.js", "*.min.css", "*.map", "*.pb.go", "*_pb2.py", "*_pb2_grpc.py",
    "*.generated.*", "*.g.dart", "*.snap", "*.pyc",
]
GENERATED_DIR_HINTS = ["/dist/", "/build/", "/out/", "/__generated__/", "/generated/", "/.next/", "/coverage/"]

VENDORED_DIR_HINTS = ["/vendor/", "/node_modules/", "/third_party/", "/thirdparty/", "/deps/"]

TEST_HINTS_DIR = ["/test/", "/tests/", "/__tests__/", "/spec/", "/e2e/", "/testdata/", "/fixtures/"]
TEST_HINTS_FILE = ["*_test.go", "*_test.py", "test_*.py", "*.test.*", "*.spec.*", "*Test.java", "*Tests.cs", "*_spec.rb"]

DOC_EXTS = {".md", ".rst", ".adoc", ".txt", ".mmd", ".mermaid", ".puml", ".plantuml"}
ASSET_EXTS = {".png", ".jpg", ".jpeg", ".gif", ".svg", ".ico", ".webp", ".woff", ".woff2", ".ttf", ".otf", ".eot", ".mp4", ".mp3", ".pdf"}
CONFIG_EXTS = {".yml", ".yaml", ".toml", ".ini", ".cfg", ".conf", ".env", ".properties", ".tf", ".tfvars"}
CONFIG_NAMES = {"Dockerfile", "docker-compose.yml", "docker-compose.yaml", "Makefile", "Justfile", ".gitignore", ".dockerignore", ".editorconfig"}
WORKFLOW_HINTS = ["/.github/workflows/", "/.gitlab/", ".gitlab-ci", "/.circleci/", "/jenkins", "/.buildkite/"]


def categorize(path: str) -> str:
    p = "/" + path.replace("\\", "/")
    name = path.rsplit("/", 1)[-1]
    dot = name.rfind(".")
    ext = name[dot:].lower() if dot != -1 else ""

    if name in LOCKFILES:
        return "lockfile"
    if any(h in p for h in VENDORED_DIR_HINTS):
        return "vendored"
    if any(h in p for h in GENERATED_DIR_HINTS) or any(fnmatch.fnmatch(name, g) for g in GENERATED_PATTERNS):
        return "generated"
    if any(h in p for h in WORKFLOW_HINTS):
        return "ci-workflow"
    if any(h in p for h in TEST_HINTS_DIR) or any(fnmatch.fnmatch(name, t) for t in TEST_HINTS_FILE):
        return "tests"
    if ext in DOC_EXTS or p.startswith("/docs/") or "/docs/" in p:
        return "docs"
    if ext in ASSET_EXTS:
        return "assets"
    if name in CONFIG_NAMES or ext in CONFIG_EXTS or (ext == ".json" and "/" not in path):
        return "config"
    return "source"


NOISE_CATEGORIES = {"lockfile", "generated", "vendored"}

# ------------------------------------------------------------------- git ops


def git(repo, *args):
    r = subprocess.run(["git", "-C", repo, *args], capture_output=True, text=True)
    if r.returncode != 0:
        raise RuntimeError(f"git {' '.join(args)} failed: {r.stderr.strip()}")
    return r.stdout


def ref_exists(repo, ref):
    return subprocess.run(
        ["git", "-C", repo, "rev-parse", "--verify", "--quiet", ref + "^{commit}"],
        capture_output=True,
    ).returncode == 0


def detect_base(repo, head):
    for cand in ("origin/main", "origin/master", "main", "master", "develop"):
        if ref_exists(repo, cand):
            try:
                return git(repo, "merge-base", cand, head).strip(), cand
            except RuntimeError:
                continue
    raise RuntimeError(
        "Could not auto-detect a base branch (tried origin/main, origin/master, "
        "main, master, develop). Pass --base explicitly."
    )

# ---------------------------------------------------------------------- main


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--repo", default=".")
    ap.add_argument("--base", default=None, help="Base ref (default: merge-base with main branch)")
    ap.add_argument("--head", default="HEAD")
    ap.add_argument("--out", default=None, help="Output JSON path (default: stdout)")
    ap.add_argument("--top", type=int, default=15, help="How many top-churn files to list")
    a = ap.parse_args()

    head_sha = git(a.repo, "rev-parse", a.head).strip()
    if a.base:
        base_sha = git(a.repo, "merge-base", a.base, a.head).strip()
        base_label = a.base
    else:
        base_sha, base_label = detect_base(a.repo, a.head)

    rng = f"{base_sha}..{head_sha}"
    diff_args = ["-M50%", base_sha, head_sha]

    # name-status: statuses + rename pairs
    status_by_path, old_paths = {}, {}
    for line in git(a.repo, "diff", "--name-status", *diff_args).splitlines():
        parts = line.split("\t")
        code = parts[0]
        if code.startswith("R") and len(parts) == 3:
            status_by_path[parts[2]] = "renamed"
            old_paths[parts[2]] = parts[1]
        elif code.startswith("C") and len(parts) == 3:
            status_by_path[parts[2]] = "copied"
            old_paths[parts[2]] = parts[1]
        else:
            status_by_path[parts[1]] = {"A": "added", "D": "deleted", "M": "modified", "T": "type-changed"}.get(code[0], "modified")

    # numstat: line counts ("-" for binary)
    files = []
    for line in git(a.repo, "diff", "--numstat", *diff_args).splitlines():
        adds_s, dels_s, path = line.split("\t", 2)
        if "=>" in path:  # rename notation a/{old => new}/b
            if "{" in path:
                pre, rest = path.split("{", 1)
                inner, post = rest.split("}", 1)
                new_inner = inner.split(" => ")[1]
                path = (pre + new_inner + post).replace("//", "/")
            else:
                path = path.split(" => ")[1]
        binary = adds_s == "-"
        files.append({
            "path": path,
            "status": status_by_path.get(path, "modified"),
            "old_path": old_paths.get(path),
            "additions": 0 if binary else int(adds_s),
            "deletions": 0 if binary else int(dels_s),
            "binary": binary,
            "category": categorize(path),
        })

    # rollups
    totals = {
        "files_changed": len(files),
        "additions": sum(f["additions"] for f in files),
        "deletions": sum(f["deletions"] for f in files),
    }
    by_category = defaultdict(lambda: {"files": 0, "additions": 0, "deletions": 0})
    by_dir = defaultdict(lambda: {"files": 0, "additions": 0, "deletions": 0})
    by_status = defaultdict(int)
    for f in files:
        c = by_category[f["category"]]
        top = f["path"].split("/", 1)[0] if "/" in f["path"] else "(root)"
        d = by_dir[top]
        for b in (c, d):
            b["files"] += 1
            b["additions"] += f["additions"]
            b["deletions"] += f["deletions"]
        by_status[f["status"]] += 1

    noise_files = sum(1 for f in files if f["category"] in NOISE_CATEGORIES)
    substantive = [f for f in files if f["category"] not in NOISE_CATEGORIES]
    top_churn = sorted(substantive, key=lambda f: f["additions"] + f["deletions"], reverse=True)[: a.top]

    commits = [
        line for line in git(a.repo, "log", "--oneline", "--no-merges", rng).splitlines()
    ]

    result = {
        "repo": a.repo,
        "base": {"label": base_label, "sha": base_sha, "short": base_sha[:8]},
        "head": {"label": a.head, "sha": head_sha, "short": head_sha[:8]},
        "totals": totals,
        "noise": {"files": noise_files, "categories": sorted(NOISE_CATEGORIES)},
        "by_status": dict(by_status),
        "by_category": {k: dict(v) for k, v in sorted(by_category.items())},
        "by_top_dir": {k: dict(v) for k, v in sorted(by_dir.items(), key=lambda kv: -(kv[1]["additions"] + kv[1]["deletions"]))},
        "top_churn_files": [
            {k: f[k] for k in ("path", "status", "additions", "deletions", "category")} for f in top_churn
        ],
        "commit_count": len(commits),
        "commits": commits[:50],
        "files": files,
    }

    out = json.dumps(result, indent=2)
    if a.out:
        with open(a.out, "w") as fh:
            fh.write(out)
        print(f"Wrote {a.out}: {totals['files_changed']} files, +{totals['additions']}/-{totals['deletions']}, "
              f"{noise_files} noise files, {len(commits)} commits", file=sys.stderr)
    else:
        print(out)


if __name__ == "__main__":
    try:
        main()
    except RuntimeError as e:
        print(f"error: {e}", file=sys.stderr)
        sys.exit(1)
