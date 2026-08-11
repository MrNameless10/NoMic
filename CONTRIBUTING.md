# Contributing to PrivateMic

PrivateMic favors small, auditable changes and native macOS APIs. Contributions must preserve the project's privacy promise: no analytics, tracking, telemetry, advertising, audio capture, or unnecessary network behavior.

## Workflow

1. Open an issue for significant behavior or architecture changes.
2. Branch from the latest `main` using `feature/short-name`, `fix/short-name`, `docs/short-name`, or `chore/short-name`.
3. Keep commits focused and write an imperative summary such as `Fix volume restoration after device change`.
4. Add or update tests for testable logic.
5. Open a pull request and complete its privacy and validation checklist.
6. Merge only after CI passes and review conversations are resolved.

`main` must remain release-ready. Releases are created from annotated `vMAJOR.MINOR.PATCH` tags; there is no permanent `develop` branch.

## Local checks

Open `PrivateMic.xcodeproj`, select **My Mac**, and run the test suite with Command-U. The equivalent command-line check is:

```sh
xcodebuild \
  -project PrivateMic.xcodeproj \
  -scheme PrivateMic \
  -configuration Debug \
  -destination "platform=macOS" \
  -derivedDataPath /tmp/PrivateMicDerivedData \
  test \
  CODE_SIGNING_ALLOWED=NO
```

Run `./Scripts/build-release.sh` when changing packaging, signing, entitlements, version metadata, or release behavior.

## Scope and permissions

Explain any new permission in the pull request and README. Changes that introduce audio capture, private APIs, privileged helpers, shell execution during normal app use, or unexplained external communication will not be accepted.

Do not include API keys, signing certificates, provisioning profiles, wallet private keys, user data, or captured audio in commits or issue reports.
