# الأربعون النووية — Arba'een

A Flutter app (Android, iOS, web for testing) to read, listen to, understand
and memorize Imam an-Nawawi's Forty Hadith (42 ahadith). Offline, free, no ads.
Sister app of "حفظ — Hifz". See `CLAUDE.md` for the scope and the rules.

## What works now

- Index (table of contents) of the 42 ahadith with number, title and narrator.
- One page per hadith: matn with full tashkeel, narrator, takhreej, and a
  sharh section (empty until a sharh with clear rights is added).
- Swipe or previous/next buttons between ahadith. Right-to-left, Arabic UI,
  light and night themes (follows the system).

## Content sources

| Content | Source | Licence | File |
| --- | --- | --- | --- |
| Matn and takhreej of the 42 ahadith | Typed by hand; an-Nawawi's text | Public domain | `assets/hadith/SOURCE-arbaeen.txt` |
| Sharh | none yet | — | — |
| Audio | none yet | — | — |
| Fonts | system fonts only | — | — |

**Printed edition used for checking: not yet chosen.** The matn is a draft
until it is checked against an old printed edition (see
`assets/hadith/SOURCE-arbaeen.txt`).

## Development

```sh
flutter pub get
dart format lib test tool
flutter analyze
flutter test
flutter run -d chrome
```

To change the text, edit `tool/matn/*.json`, then run
`dart run tool/build_arbaeen.dart` to rebuild `assets/hadith/arbaeen.json`.
A test fails if the two are out of sync.
