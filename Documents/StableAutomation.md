# Automatic custom stable releases

The **Sync Stable Release** GitHub Actions workflow on `main` checks M2Team/NanaZip
once daily at **08:17 UTC**. It also supports **Run workflow** for an immediate check.

Only the official latest non-draft, non-prerelease version with a numeric four-part
tag and its stable `NanaZip_<version>.msixbundle` asset is accepted. Preview-only
releases are never built by this automation.

The first automatic update starts from `custom-7.0.1843.0`. Subsequent updates use
`custom-stable`. The exact official release tag is merged, preserving fork changes
in conflicting hunks and keeping the fork's `.github` directory. The version and
build date are pinned to the release; the package remains `BrunoFaria.NanaZip`,
published by Bruno Faria, with the customized toolbar and stable branding.

The workflow builds x64 and ARM64, signs the bundle using the existing self-signed
certificate process, and packages the installation helpers. It uploads the installer
ZIP and `SHA256SUMS.txt` to a draft before publishing `v<version>-bf1` as stable.
The private signing key is not included in the installer.

An existing complete release is skipped, as is a manual build of that version still
in progress. Build failures are retried on the next daily run. Unresolved merge
conflicts or failed validation stop publication and appear in the Actions log.
Published releases are not overwritten; interrupted draft uploads can be retried.

The workflow uses the repository's `GITHUB_TOKEN`; no personal token or external
scheduler is required. The build is a dependent job in the same workflow, so it
does not depend on a bot push triggering another workflow.

Validation: run `python .github/scripts/test_sync_stable.py` and
`actionlint .github/workflows/SyncStableRelease.yml`.
