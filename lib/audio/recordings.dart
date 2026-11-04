import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Recordings live in `assets/audio/`, one file per hadith: `01.mp3` to
/// `42.mp3`. None is bundled until the reciter gives written permission
/// (see `assets/audio/README.md` and CLAUDE.md, "Audio").
const recordingsDir = 'assets/audio/';

String recordingAsset(int number) =>
    '$recordingsDir${number.toString().padLeft(2, '0')}.mp3';

final _recordingName = RegExp(r'^assets/audio/(\d{2})\.mp3$');

/// The hadith numbers that have a bundled recording, from the asset list.
Set<int> recordedNumbers(Iterable<String> assets) => {
  for (final asset in assets)
    if (_recordingName.firstMatch(asset) case final m?) int.parse(m[1]!),
};

/// Which ahadith can be listened to; overridden in tests.
final recordedNumbersProvider = FutureProvider<Set<int>>((ref) async {
  final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
  return recordedNumbers(manifest.listAssets());
});
