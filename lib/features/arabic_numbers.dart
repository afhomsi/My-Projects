const _digits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];

/// Writes [n] with Arabic-Indic digits, as in printed books: 24 -> ٢٤.
String arabicNumber(int n) =>
    n.toString().split('').map((d) => _digits[int.parse(d)]).join();
