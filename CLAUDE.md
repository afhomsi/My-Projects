# CLAUDE.md — الأربعون النووية (Arba'een)

A Flutter app for iOS and Android (also runs in Chrome for testing) to read,
listen to, understand and memorize Imam an-Nawawi's Forty Hadith (42 ahadith).
It is the sister app of "حفظ — Hifz" (github.com/afhomsi/Quran) and reuses its
stack, layout and lessons. Offline-first. Free, no ads.

Later (not now): al-Lu'lu' wal-Marjan (muttafaq 'alayh), then Bukhari and
Muslim with search and browsing.

## Working with the owner

- The owner, Ahmad, writes in Arabic. Reply to him in Arabic, in simple
  conversational sentences. When an English word (a tool, file, command or
  product name) appears in Arabic text, put it on its own line.
- Code, comments, commit messages, README and this file are in English.
- Ask before anything that cannot be undone or that leaves the repo
  (store release, signing keys, contacting reciters or publishers).

## Rules that come before code

These come from the mistakes of the Quran app. Follow them in this order.

1. **Rights first.** Do not add any text, sharh, audio or font to the app
   until its source and licence are written down (see "Content and rights").
   "Free to listen on the web" is not a licence. If the rights are unclear,
   leave the content out and say so.
2. **Fixed, small feature list.** Ship the first version with only the
   features under "Scope of v1". Memorization by voice (tasmee') comes first.
   New ideas go to the roadmap, not into the current milestone.
3. **Offline from day one.** All text, sharh and audio needed by v1 is bundled
   in the app. No feature may need the internet to work.
4. **Small app, own signing key, auto download page from day one.** Release
   builds are signed with the owner's key (never the debug key) and CI
   publishes the APK to a download page, as in the Quran repo.
5. **Test tasmee' early on long and fast ahadith** (for example hadith 2,
   Jibril, and hadith 24, "Ya 'ibadi"), not only on short ones.

## Scope of v1

- One page per hadith: the matn with full tashkeel, then a short sharh, then
  "more" with longer shuruh for whoever wants to go deeper.
- Listen to a hadith with repetition (count chosen by the user: 1, 3, 10, 20,
  50, or endless).
- Tasmee' by voice with hidden words, reusing the recitation code of the Quran
  app (`lib/recitation/`: matcher, Arabic normalizer, harakat, offline speech).
- Memorization plan (for example one hadith every two days), smart review
  (spaced repetition) and a short test.
- Share a hadith as text or as a clean image, always with its number, narrator
  and source (for example "رواه البخاري ومسلم").
- Night mode, text size, personal notes, bookmarks, resume where you left off.
- A "Sources and rights" screen that names every text, sharh, recording and
  font, with its licence.

Ideas from users of other apps, kept for later: audio sharh, English and Urdu
translation of the sharh, a "book pages" view.

## Content and rights

The matn of the 42 ahadith (the words of the Prophet ﷺ and an-Nawawi's book)
is old and free of rights. Rights sit on modern tahqeeq, tashkeel and
numbering of a given edition. So:

- **Matn:** typed by us from an old printed edition and checked by hand.
  Keep it in `assets/hadith/arbaeen.json`. Record the edition used in the README.
- **Short sharh:** either our own fresh wording of meanings well known among
  the classical commentators (in `tool/sharh/`, see
  `assets/hadith/SOURCE-sharh.txt`; shown as a draft until a qualified person
  reviews it), or quoted from classical authors whose text is free
  (an-Nawawi's own sharh, Ibn Daqiq al-'Eid, Ibn Rajab's Jami' al-'Ulum
  wal-Hikam), taken from an old edition, not a modern muhaqqaq one.
- **Needs written permission before use:** Ibn 'Uthaymeen's sharh (rights
  believed to be with the Ibn 'Uthaymeen Charitable Foundation, not yet
  verified), 'Abd al-Karim al-Khudayr (alive), and any modern edition.
- **Do not use:** the audio or text of the "الأربعون النووية مع الشرح" app by
  Mohamed Reda (it names no reciter and no rights); `AhmedBaset/hadith-json`
  and `Jaguar16/open-hadith-data` (copied from sunnah.com, which forbids bulk
  copying); the data of `fawazahmed0/hadith-api` (no clear licence for the
  data itself).
- **Usable for Bukhari and Muslim later:** `mhashim6/Open-Hadith-Data`
  (ODbL 1.0: credit the source and publish any change to the data under the
  same licence) and `ibnmukthar/thehadithproject` (data CC BY 4.0).

### Audio

No recording of the Forty with an explicit open licence was found
(archive.org, Alukah, IslamHouse, Islamway). In order of preference:

1. Our own recording: a skilled reader records the 42 ahadith one file per
   hadith (about 45 minutes) and gives written permission.
2. Written permission from Dr. Yusuf al-'Aqil or Hamad ad-Duraihim (or their
   publisher); we then cut the file per hadith ourselves.
3. Device text-to-speech as a stopgap only (weak on tashkeel). Tried in
   PR #6 and removed: the owner did not like it.

Current plan (2026-11-04): the owner is asking for written permission to use
the recitation in the "الأربعون النووية مع الشرح" app (com.reda.nawawiforty).
That app is under "Do not use" until the permission names the reciter and is
saved as `assets/audio/LICENSE-<reciter>.txt`; only then add the files.

Until one of these exists, the audio code is built and tested with a fake
player, and no recording is bundled.

Every licence file goes next to its content
(for example `assets/hadith/LICENSE-<source>.txt`).

## Development

Same toolchain as the Quran app: Flutter 3.47.7 (stable), Dart ^3.13.

```sh
flutter pub get
dart format lib test        # CI fails on unformatted code
flutter analyze
flutter test
flutter run                 # or: flutter run -d chrome
```

Run format, analyze and test before every commit. CI
(`.github/workflows/ci.yml`) runs the same three steps and builds split APKs
(arm and arm64) with the run number as build number.

### Code layout (mirror the Quran app)

- `lib/data/`: hadith models and the repository that loads bundled data
- `lib/features/`: one folder per screen or feature (hadith, sharh, audio,
  recitation, review, plan, share, notes, settings, sources)
- `lib/recitation/`: tasmee' engine (ported from the Quran app)
- `lib/audio/`: player and repetition
- `lib/l10n/`: app strings through `S.of(context)`; Arabic first
- `lib/theme/`: light and night themes
- `assets/hadith/`: matn and sharh JSON, with licence files
- `assets/fonts/`: fonts, each with its licence file
- `tool/`: scripts that build or check bundled data
- `test/`: unit and widget tests; fakes for the player and the speech listener

State with `flutter_riverpod`, settings with `shared_preferences`, audio with
`just_audio`, sharing with `share_plus`, reminders with
`flutter_local_notifications`, as in the Quran app.

### Data format

Each hadith in `assets/hadith/arbaeen.json` has: `number` (1–42), `title`,
`matn` (with tashkeel), `narrator`, `source` (takhreej as written by
an-Nawawi), and `shuruh` (a list of `{ author, text, source }`). Keep the
matn exactly as checked; never "fix" tashkeel by guessing. A test checks that
there are 42 ahadith, numbered 1 to 42, each with a non-empty matn and source.

## Conventions

- Arabic text is right-to-left; test layouts in Arabic first.
- When you reuse code from the Quran app, copy it with its tests and adapt it;
  do not add the Quran repo as a dependency.
- Small pull requests, one feature each, with tests.
- Never commit signing keys, keystores or passwords; they live in CI secrets.
