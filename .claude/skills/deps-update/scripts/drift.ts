#!/usr/bin/env bun
// Reports dependencies declared in >=2 real workspaces, flagging version drift.
// Debris workspaces (agentic-tests, aircraft-service-* benchmark variants) are excluded.
// Run from repo root: bun .claude/skills/deps-update/scripts/drift.ts [--all]
import { Glob } from "bun";

const DEBRIS = /\/(agentic-tests|aircraft-service-[a-z]+)\//;
const showAll = process.argv.includes("--all");

const manifests: string[] = [];
for await (const path of new Glob("**/package.json").scan({ dot: false })) {
  if (path.includes("node_modules") || DEBRIS.test(`/${path}`)) continue;
  manifests.push(path);
}

const byDep = new Map<string, Map<string, string>>();
for (const path of manifests) {
  const pkg = await Bun.file(path).json();
  const ws = path === "package.json" ? "root" : path.replace(/\/package\.json$/, "");
  for (const section of ["dependencies", "devDependencies", "peerDependencies"] as const) {
    for (const [name, range] of Object.entries(pkg[section] ?? {})) {
      if (String(range).startsWith("workspace:")) continue; // workspace protocol, not a version
      (byDep.get(name) ?? byDep.set(name, new Map()).get(name)!).set(ws, String(range));
    }
  }
}

let drifted = 0;
for (const name of [...byDep.keys()].sort()) {
  const locs = byDep.get(name)!;
  if (locs.size < 2) continue;
  const isDrift = new Set(locs.values()).size > 1;
  if (!isDrift && !showAll) continue;
  if (isDrift) drifted++;
  const flag = isDrift ? " ← DRIFT" : "";
  console.log(`${name}  (${locs.size} ws)${flag}`);
  for (const [ws, range] of locs) console.log(`    ${range}\t${ws}`);
}
console.log(`\n${drifted} drifting dep(s). Catalog candidates: everything above.`);
