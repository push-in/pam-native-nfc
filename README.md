# PAM Native NFC

Read and write NDEF tags from PAM Native with one lifecycle-safe API on Android and iOS.

```bash
composer require pushinbr/pam-native-nfc
pam mobile prepare
```

```php
$nfc->beginRead(fn (bool $ok, ?string $error) => null);
$nfc->write(NdefRecord::uri('https://pam.dev'), fn (bool $ok, ?string $error) => null);
$nfc->poll(fn (array $events) => handleNfcEvents($events));
```

Only one NFC session may be active at a time. iOS presents the system NFC sheet and requires the NFC capability in the signing profile. Android uses reader mode and requires a foreground Activity. The queue is bounded to 128 events. NDEF payloads are limited to 1 MiB in PHP before reaching native code; the physical tag's capacity is checked at write time.
