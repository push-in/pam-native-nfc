# PAM Native NFC

Read and write NDEF tags from PAM Native with one lifecycle-safe API on Android and iOS.

```bash
pam add nfc
pam doctor
```

```php
$nfc->beginRead(fn (bool $ok, ?string $error) => null);
$nfc->write(NdefRecord::uri('https://pam.dev'), fn (bool $ok, ?string $error) => null);
$nfc->poll(fn (array $events) => handleNfcEvents($events));
```

Only one NFC session may be active at a time. iOS presents the system NFC sheet and requires the NFC capability in the signing profile. Android uses reader mode and requires a foreground Activity. The queue is bounded to 128 events. NDEF payloads are limited to 1 MiB in PHP before reaching native code; the physical tag's capacity is checked at write time.


## What installation does

`pam add nfc` resolves the official compatible package, performs a non-mutating Composer preflight, updates the normal `composer.json` and `composer.lock`, refreshes generated native integration when required, and leaves the project ready for `pam doctor` validation.

Use `pam packages` to inspect availability and `pam remove nfc` to uninstall the capability safely. Direct Composer commands are an advanced interoperability path; PAM is the supported application workflow.

## API guide

| API | Responsibility |
| --- | --- |
| `Nfc` | Begin reading, write NDEF, poll events, and end sessions. |
| `NdefRecord` | Build URI, text, MIME, and external NDEF records. |
| `NfcEvent` / `NfcEventKind` | Consume typed tag and session events. |
| `NfcAvailability` | Inspect platform and hardware support. |

All coded states, kinds, and variants are sequential integer-backed enums. Use enum cases in application code; do not depend on raw wire numbers.

## Production checklist

- End sessions when the owning screen leaves the foreground.
- Validate every record type, length, and payload before use.
- Treat tag data as untrusted external input.
- Run `pam doctor`, `pam test`, and a signed release build on every supported platform.
- Exercise denial, cancellation, backgrounding, process restart, and offline behavior before release.

## Troubleshooting

- **Session will not start:** only one session may be active.
- **iOS cannot scan:** verify NFC entitlement and a compatible signed device.
- **Write fails:** compare the encoded payload with the physical tag capacity.
- **Native integration is stale:** run `pam doctor --fix`, rebuild the native host, and inspect the first reported diagnostic.

## Compatibility and support

This package targets PAM Native `0.6.x`, Android API 26+, and iOS 15+ unless a platform-specific section above states a stricter requirement. Platform SDKs, credentials, entitlements, physical hardware, and store configuration remain application responsibilities.

- [PAM documentation](https://push-in.github.io/pam-docs/introduction/)
- [PAM Native overview](https://push-in.github.io/pam-docs/native/overview/)
- [Plugin and native capability model](https://push-in.github.io/pam-docs/native/plugins/)
- [Report an issue](https://github.com/push-in/pam-native-nfc/issues)

Security vulnerabilities should be reported through the repository security policy or GitHub private vulnerability reporting, not a public issue.
