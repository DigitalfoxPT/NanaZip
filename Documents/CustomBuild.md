# NanaZip custom build

This branch is based on the stable NanaZip `7.0.1843.0` tag.

The upstream release is version `2609.2`. Stable mode is enabled by default, and
the package version is pinned to `7.0.1843.0` regardless of the build date.

## Alterações desta compilação

- Shows localized text labels to the right of the main toolbar icons.
- Removes the Test, Benchmark, and Sponsor buttons from the main toolbar.
- Shows only the ellipsis icon for the More button.
- Uses `NanaZip` as the visible application name and `Bruno Faria` as the publisher.
- Uses the separate `BrunoFaria.NanaZip` MSIX identity.
- Uses a separate shell extension CLSID and retains the existing execution aliases.
- Produces a self-signed MSIX bundle and installation helpers in GitHub Actions.

The original NanaZip licenses, notices, and attribution are preserved.

## Downloads and installation

- [Custom release 7.0.1843.0](https://github.com/DigitalfoxPT/NanaZip/releases/tag/v7.0.1843.0-bf1)
- [Release notes](../Installer/ReleaseNotes-7.0.1843.0.md)
- [Installation and removal instructions](../Installer/README.txt)

The previous custom release remains available in the GitHub release history.
