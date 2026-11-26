@AGENTS.md

## GitHub Releases

To request a release, add or update `.github/releases/v<VERSION>.md` on `main`.
Use the version from `pubspec.yaml` without the build number. The release workflow
builds Android, Windows, and both iOS targets before creating a new tag at the
built commit. The workflow also supports manual dispatch.
