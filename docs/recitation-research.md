# Open-source reading and tasmee' apps: what they do (2026-11-17)

A survey of open-source projects on GitHub that read and check a recitation
of hadith or Quran, to decide what to improve in this app. Only ideas were
taken; no code, text, model or audio was copied.

| Project | Licence | Speech recognition | Matching | Memorization flow |
|---|---|---|---|---|
| yazinsai/tilawa | MIT | On-device ONNX model trained on the Quran (phonemes), ~66 MB download | Streaming tracker restricted to the declared passage; a mistake is "confirmed" once the next word starts | — |
| ibrahimokdadov/quranm (on Tilawa) | MIT | Same as Tilawa | Same | Read a unit twice with the text, then hide it, recall each unit, then recite the connected passage; more help after repeated failure; spaced review dates |
| Recite-Quran/Natlu (`recite_quran` package) | see repo | On-device sherpa-onnx Zipformer, INT8, trained on the Quran | Acoustic + text alignment | Tajweed revision, study circles |
| Al-Edrisy/samme3 | proprietary | On-device engine | Forced alignment | — |
| SaminYeaserKhan/NEki | MIT | Whisper over the Groq API (cloud), device recognizer offline | Greedy streaming cursor with lookahead; stops on a wrong word for a retry | — |
| yayaiu6/Real-Time-Quran-recitation-tracker | MIT | Whisper over the Groq API (cloud) | Fuzzy Levenshtein matching (Tarteel's published approach), sequence/skip detection | — |
| foyzulkarim/hifz-tester | MIT | Quran-tuned Whisper on a server | Deterministic word alignment after recording; auto-detects the range | Record, then review |
| AbdirahmanNomad/IqraAI | MIT | Tarteel whisper-base-ar-quran (Python) | Verse match; green/red/yellow words | — |
| mahmoodhamdi/nawawi_40_hadith_app | MIT (code) | none | none | Reader with audio by a named sheikh; links to sunnah.com |

## What this means for this app

- **Recognition.** The best offline engines (Tilawa, Natlu) use models
  trained on the Quran only and add tens of MB; a hadith is not Quran, so
  they would not recognize it well, and their model licences would need
  checking. Cloud Whisper breaks the offline rule. The platform recognizer
  on the device (what we use, with opt-in online) stays the right choice
  for v1. A general Arabic on-device model (sherpa-onnx, Apache-2.0) is a
  roadmap idea if the platform recognizer proves weak.
- **Matching.** Our aligner (word-level edit distance with going back,
  split/joined words, held-back mistakes until the recognizer settles,
  harakat check) already does what the others do, and more than the greedy
  cursors (NEki) or plain fuzzy matching. No change.
- **Memorization flow.** Here the others are ahead: Quranm's step-by-step
  memorize mode drives learning by voice. This PR adds it (see
  `lib/features/guided/`).
- **Hadith reader apps.** The one open Nawawi app links to sunnah.com and
  bundles a sheikh's audio without a stated licence: nothing to reuse under
  our rights rules.
