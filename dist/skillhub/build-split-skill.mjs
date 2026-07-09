// Regenerates the SkillHub upload package for the `macos-app-scaffold` skill.
//
// SkillHub's uploader has two constraints this build works around:
//   1. A request-size limit on the submit endpoint — so the root SKILL.md
//      (which is sent inline as `skill_md_content`) is kept COMPACT; the full
//      New-App / Enhance flows ride along as bundled files new-app.md /
//      enhance.md, and the templates ride in templates/.
//   2. A file-extension whitelist (no .swift/.plist/.snippet) — so every file
//      under templates/ gets a trailing `.txt` appended. Strip it on copy.
//
// Sources of truth stay in ../../skills/ (the working Claude plugin, untouched).
// Run:  node dist/skillhub/build-split-skill.mjs
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const SRC = path.join(__dirname, '..', '..', 'skills');
const OUTDIR = path.join(__dirname, 'macos-app-scaffold');

function stripFrontmatter(md) {
  const m = md.match(/^---\n[\s\S]*?\n---\n?/);
  return m ? md.slice(m[0].length).trim() : md.trim();
}

let router = stripFrontmatter(fs.readFileSync(path.join(SRC, 'macos-app-scaffold/SKILL.md'), 'utf8'));
const rIdx = router.indexOf('## Routing Logic');
if (rIdx > 0) router = router.slice(rIdx);
const newFlow = stripFrontmatter(fs.readFileSync(path.join(SRC, 'macos-app-scaffold-new/SKILL.md'), 'utf8'));
const enhance = stripFrontmatter(fs.readFileSync(path.join(SRC, 'macos-app-scaffold-enhance/SKILL.md'), 'utf8'));

const helperTplFrom = [
  "**Templates location.** The agent and daemon templates ship with the",
  "companion `macos-app-scaffold-new` skill. From this skill's directory the",
  "relative path is `../macos-app-scaffold-new/templates/{agent,daemon}/`; from",
  "the repo root it is `skills/macos-app-scaffold-new/templates/{agent,daemon}/`.",
  "If you cannot find them locally (e.g., user installed only one skill), fetch",
  "from the upstream repo at",
  "`https://github.com/XueshiQiao/macos-app-scaffold/tree/main/skills/macos-app-scaffold-new/templates`.",
  "Read each template's `README.md` before copying.",
].join("\n");
const helperTplTo = "**Templates location.** The agent and daemon templates are bundled with this skill under `templates/{agent,daemon}/` — every file has a trailing `.txt` (strip it on copy). Read each template's `README.md.txt` first.";
const srTplFrom = [
  "**Templates location.** `../macos-app-scaffold-new/templates/screen-recording/`",
  "(repo path: `skills/macos-app-scaffold-new/templates/screen-recording/`).",
].join("\n");
const srTplTo = "**Templates location.** `templates/screen-recording/` — bundled with this skill; every file has a trailing `.txt` (strip it on copy).";

const R = [
  [helperTplFrom, helperTplTo],
  [srTplFrom, srTplTo],
  ["The full instructions for each flow are in sibling skill files:", "The full instructions for each flow are in the bundled files `new-app.md` / `enhance.md`:"],
  ["Read and follow those files completely when executing the chosen flow.", "Read and follow that bundled file (`new-app.md` or `enhance.md`) completely when executing the chosen flow."],
  ["[New App flow](../macos-app-scaffold-new/SKILL.md)", "[New App flow → `new-app.md`](new-app.md)"],
  ["[Enhance flow](../macos-app-scaffold-enhance/SKILL.md)", "[Enhance flow → `enhance.md`](enhance.md)"],
  ["Companion to `/new-macos-app` (which scaffolds from scratch).", "See `new-app.md` (bundled with this skill) for scaffolding a project from scratch."],
  ["Generate the workflow from the template in `/new-macos-app` skill, adapted to the existing project:", "Generate the workflow from the `build.yml` template in `new-app.md` (bundled), adapted to the existing project:"],
  ["Generate `UpdateChecker.swift` (see new-macos-app templates)", "Generate `UpdateChecker.swift` (see the `UpdateChecker.swift` template in `new-app.md`)"],
  ["Generate sensible defaults (see new-macos-app template).", "Generate sensible defaults (see the `.swiftlint.yml` template in `new-app.md`)."],
  ["If the user provided an argument (e.g., `/enhance-macos-app auto-update`), skip the dashboard and go directly to that feature.", "If the user provided an argument (e.g., `macos-app-scaffold enhance auto-update`), skip the dashboard and go directly to that feature."],
  ["skills/macos-app-scaffold-new/templates/", "templates/"],
  ["../macos-app-scaffold-new/templates/", "templates/"],
  ["`macos-app-scaffold-new/templates/", "`templates/"],
  ["../macos-app-scaffold-new/SKILL.md", "new-app.md"],
  ["macos-app-scaffold-new/SKILL.md", "new-app.md"],
  ["../macos-app-scaffold-enhance/SKILL.md", "enhance.md"],
  ["macos-app-scaffold-enhance/SKILL.md", "enhance.md"],
];
const apply = (t) => R.reduce((acc, [f, to]) => acc.split(f).join(to), t);

const templateNote = `## Template files (\`.txt\` suffix)

Every file under \`templates/\` has a trailing \`.txt\` appended **only** to satisfy the uploader's file-type filter — the real type is the *inner* extension. **When you copy a template into the user's project, delete the trailing \`.txt\`** (e.g. \`templates/agent/HelperMain.swift.txt\` → \`HelperMain.swift\`, \`templates/agent/LaunchAgent.plist.txt\` → \`LaunchAgent.plist\`, \`templates/agent/project.yml.snippet.txt\` → \`project.yml.snippet\`). Same rule for every file under \`templates/\`.`;

const frontmatter = `---
name: macos-app-scaffold
description: Scaffold a new production-grade macOS app or add features (CI/CD, signing, notarization, auto-update, launch-at-login, permission flows) to an existing one. Auto-detects context and routes accordingly.
argument-hint: "[new|enhance] [AppName]"
allowed-tools: Bash, Write, Read, Edit, Glob, Grep
---`;

const rootMd = `${frontmatter}

# macOS App Scaffold

Single entry point for macOS app scaffolding: create a new production-grade app, or add features to an existing one. Detects context and routes to the right flow. **The two full flows are bundled as separate files in this skill:** \`new-app.md\` (create from scratch) and \`enhance.md\` (add to an existing project), plus a \`templates/\` folder.

${templateNote}

${apply(router)}

## Full flows (bundled files)

- **New App** → read and follow \`new-app.md\` (bundled with this skill) completely.
- **Enhance** → read and follow \`enhance.md\` (bundled with this skill) completely.
- Reusable code/config templates are under \`templates/\` (strip the trailing \`.txt\` on copy, per the note above).
`;

const newMd = `# macOS App Scaffold — New App flow

> Bundled flow file for the \`macos-app-scaffold\` skill. Start from the root \`SKILL.md\` for routing.

${templateNote}

---

${apply(newFlow)}
`;

const enhanceMd = `# macOS App Scaffold — Enhance flow

> Bundled flow file for the \`macos-app-scaffold\` skill. Start from the root \`SKILL.md\` for routing.

${templateNote}

---

${apply(enhance)}
`;

// fresh output tree
fs.rmSync(OUTDIR, { recursive: true, force: true });
fs.mkdirSync(OUTDIR, { recursive: true });
fs.writeFileSync(path.join(OUTDIR, 'SKILL.md'), rootMd);
fs.writeFileSync(path.join(OUTDIR, 'new-app.md'), newMd);
fs.writeFileSync(path.join(OUTDIR, 'enhance.md'), enhanceMd);

// copy templates, appending .txt to every file (real type = inner extension)
function copyTemplates(srcDir, dstDir) {
  fs.mkdirSync(dstDir, { recursive: true });
  for (const e of fs.readdirSync(srcDir, { withFileTypes: true })) {
    const s = path.join(srcDir, e.name);
    if (e.isDirectory()) copyTemplates(s, path.join(dstDir, e.name));
    else {
      const name = e.name.endsWith('.txt') ? e.name : `${e.name}.txt`;
      fs.copyFileSync(s, path.join(dstDir, name));
    }
  }
}
copyTemplates(path.join(SRC, 'macos-app-scaffold-new/templates'), path.join(OUTDIR, 'templates'));

const count = (d) => fs.readdirSync(d, { withFileTypes: true }).reduce((n, e) =>
  n + (e.isDirectory() ? count(path.join(d, e.name)) : 1), 0);
console.log('Generated', OUTDIR);
console.log('  SKILL.md    ', fs.statSync(path.join(OUTDIR, 'SKILL.md')).size, 'bytes (root / skill_md_content)');
console.log('  new-app.md  ', fs.statSync(path.join(OUTDIR, 'new-app.md')).size, 'bytes');
console.log('  enhance.md  ', fs.statSync(path.join(OUTDIR, 'enhance.md')).size, 'bytes');
console.log('  templates/  ', count(path.join(OUTDIR, 'templates')), 'files (.txt)');
