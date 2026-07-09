# SkillHub upload package — `macos-app-scaffold`

Generated package published to **小红书 SkillHub**. The sources of truth are the three
skills under [`../../skills/`](../../skills/) (the working Claude plugin); this folder is a
**generated, self-contained single-skill build** for SkillHub.

## Live listing
- **Display name:** macOS app 生成脚手架
- **Skill ID (identifier):** `macos-app-scaffold` · platform `skill_id` **7146**
- **Version:** 1.0.1 · **原创** · tags: 编程开发 / 学习成长

## Layout
```
macos-app-scaffold/
├── SKILL.md      compact root — this is what SkillHub sends inline as skill_md_content
├── new-app.md    full "New App" flow (bundled file)
├── enhance.md    full "Enhance" flow (bundled file)
└── templates/    17 reusable code/config templates
```

## Two workarounds baked into this build
1. **Compact root.** The submit endpoint rejects large request bodies (verified: a ~90 KB
   body returns HTTP 405 from the gateway; the limit sits ~65–90 KB). `skill_md_content` is
   the root `SKILL.md` inline, so the root is kept small (~3.5 KB) and the full flows ride
   along as `new-app.md` / `enhance.md` inside the bundle.
2. **`.txt` on every template.** The uploader whitelists file extensions (no `.swift` /
   `.plist` / `.snippet`). Every file under `templates/` therefore has a trailing `.txt`
   appended; the real type is the inner extension. **Strip the trailing `.txt` on copy**
   (`HelperMain.swift.txt` → `HelperMain.swift`).

## Rebuild
```bash
node dist/skillhub/build-split-skill.mjs
```
Regenerates `macos-app-scaffold/` from `../../skills/`. Deterministic.

## Publish / update
- First publish used the `@xhs/skillhub-upload` CLI (`skillhub-upload publish <dir> …`).
- **The CLI can only CREATE a skill, not update one** — re-submitting an existing identifier
  returns `Skill ID 已被占用`. **Updates go through the SkillHub web console** (upload this
  folder / a zip of it as a new version).

> Note: live SkillHub v1.0.1 was built from source at `200582e` (just before PR #4,
> `676cff0`, which anchored the Sparkle version-grep in the enhance flow). Regenerating now
> includes that fix, so this committed package is one small CI-template fix ahead of the
> live v1.0.1; it will sync on the next SkillHub update.
