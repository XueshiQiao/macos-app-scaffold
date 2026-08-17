# CI/CD — build, sign, notarize, release

`build.yml` is a complete GitHub Actions workflow: test → universal build →
Developer ID signing → Apple notarization → DMG → GitHub release.

**Copy it. Do not retype it, and do not write your own from memory.** Every
non-obvious line below is there because of a failure that only appears on a real
tagged release — the build goes green, and then the release attempt fails with an
error that points somewhere else.

## Install

```bash
mkdir -p .github/workflows
cp templates/ci/build.yml .github/workflows/build.yml
```

Then replace the placeholders:

| Placeholder | Value |
|---|---|
| `{{AppName}}` | Product name, e.g. `MenuPeek` — also used for the scheme, the `.app` and the `.dmg` |

If the scheme, entitlements path or bundle id differ from the defaults, adjust
the `env:` block and the `ENTITLEMENTS` path in the signing step.

## Required secrets

| Secret | What it is |
|---|---|
| `MAC_CERTS_P12_BASE64` | Developer ID Application cert exported as `.p12`, then base64'd |
| `MAC_CERTS_P12_PASSWORD` | The password set when exporting that `.p12` |
| `APPLE_ID` | Apple ID email used for notarization |
| `APP_SPECIFIC_PASSWORD` | App-specific password from appleid.apple.com |
| `APPLE_TEAM_ID` | 10-character team identifier |
| `SIGNING_IDENTITY` | Optional; defaults to `Developer ID Application` |

There is deliberately no keychain-password secret: the workflow generates one
with `uuidgen` for the throwaway keychain it creates and discards.

`HAS_APPLE_SECRETS` is derived from whether `MAC_CERTS_P12_BASE64` is set. With
none of these configured the workflow still runs and produces an **unsigned**
DMG, so forks and outside pull requests don't fail.

### Auto-update (Sparkle)

This template does **not** generate a Sparkle appcast. If the app embeds Sparkle,
add the appcast steps from the "Auto-Update" section of the skill and the
`SPARKLE_EDDSA_KEY` secret. Anchor the version greps there
(`grep -E '^\s+MARKETING_VERSION: '`): `project.yml` also contains reference
lines such as `CFBundleShortVersionString: $(MARKETING_VERSION)` which carry no
quotes, and an unanchored grep can match one of those first and yield an empty
version — producing an appcast that silently offers nothing.

## Why the workflow is shaped this way

**It builds unsigned, then signs by hand, inside out.** Letting `xcodebuild` sign
an app that embeds Sparkle — or any framework carrying XPC services or a nested
helper `.app` — produces a bundle that signs cleanly and verifies locally, and is
then rejected by Apple's notary service for the nested code. Sparkle 2.x ships
`Autoupdate`, an `Updater.app` and two XPC services inside its framework. Each
nested piece must be signed with `--options runtime` and sealed **before** the
thing containing it is signed, or the outer signature covers a hash that then
changes.

**It parses `status:` out of notarytool's output.** `xcrun notarytool submit
--wait` exits **0 even when Apple rejects the submission**. A workflow that
trusts the exit code sails past a rejection and fails at the next step,
`stapler`, with `Record not found` / `Error 65` — an error that mentions nothing
about notarization and sends you looking in the wrong place entirely. On anything
other than `Accepted`, this workflow prints `notarytool log <id>`, which is where
Apple's actual reason lives.

**It declares `permissions: contents: write`.** The default `GITHUB_TOKEN` is
read-only; creating a release without this fails with `403 Resource not
accessible by integration`.

**`codesign:` is in the `set-key-partition-list` ACL.** The signing step invokes
`codesign` directly rather than through `xcodebuild`, and the partition list is
what decides which tools may use the key. Too narrow a list surfaces as codesign
blocking on a GUI prompt that no runner can answer.

## Verify it, don't assume it

A green run on `main` proves only that the project compiles. **Signing,
notarization and release only execute on a tag.** Cut a real tag, then download
the published artifact and check it:

```bash
spctl -a -vv MyApp.app        # expect: accepted / source=Notarized Developer ID
xcrun stapler validate MyApp.app
lipo -archs MyApp.app/Contents/MacOS/MyApp   # expect: x86_64 arm64
```

If `spctl` says anything other than `accepted`, users will see a Gatekeeper
warning — regardless of what the CI logs said.
