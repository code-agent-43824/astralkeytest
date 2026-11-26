@AGENTS.md

## iOS toolchain

The iOS workflows use the `xcode-27` runner and the stable version pinned in
`.xcode-version`. For local Flutter iOS builds, select that installation in Xcode
or set `DEVELOPER_DIR` to its `Contents/Developer` directory. CI verifies the SDK
used to link both bundles and runs the native Keychain and display-region tests
on iPhone Duo.

## GitHub Releases

To request a release, add or update `.github/releases/v<VERSION>.md` on `main`.
Use the version from `pubspec.yaml` without the build number. The release workflow
builds Android, Windows, and both iOS targets before creating a new tag at the
built commit. The workflow also supports manual dispatch.
