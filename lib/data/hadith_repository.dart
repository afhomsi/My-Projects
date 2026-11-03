import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'hadith.dart';

const arbaeenAsset = 'assets/hadith/arbaeen.json';

/// Loads the bundled book. Works offline: everything is in the app assets.
class HadithRepository {
  HadithRepository({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;

  Future<Book> loadBook() async {
    final raw = await _bundle.loadString(arbaeenAsset);
    return Book.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }
}

final hadithRepositoryProvider = Provider<HadithRepository>(
  (ref) => HadithRepository(),
);

final bookProvider = FutureProvider<Book>(
  (ref) => ref.watch(hadithRepositoryProvider).loadBook(),
);
