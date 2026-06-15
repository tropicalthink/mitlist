/// Plan 037 — shared, pure string-similarity helpers used across the ensemble
/// (candidate generation, feature extraction). No deps, fully unit-testable.
library;

/// Lowercase, trim, collapse internal whitespace. The single normalisation the
/// resolver and the alias table agree on.
String normaliseText(String s) =>
    s.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');

/// Levenshtein edit distance.
int editDistance(String s, String t) {
  final m = s.length, n = t.length;
  if (m == 0) return n;
  if (n == 0) return m;
  var prev = List<int>.generate(n + 1, (j) => j);
  var curr = List<int>.filled(n + 1, 0);
  for (var i = 1; i <= m; i++) {
    curr[0] = i;
    for (var j = 1; j <= n; j++) {
      final cost = s.codeUnitAt(i - 1) == t.codeUnitAt(j - 1) ? 0 : 1;
      final del = prev[j] + 1;
      final ins = curr[j - 1] + 1;
      final sub = prev[j - 1] + cost;
      curr[j] = del < ins ? (del < sub ? del : sub) : (ins < sub ? ins : sub);
    }
    final tmp = prev;
    prev = curr;
    curr = tmp;
  }
  return prev[n];
}

/// Similarity in [0, 1]: `1 - editDistance / max(len)`. 1.0 == identical.
double stringSimilarity(String a, String b) {
  if (a == b) return 1.0;
  if (a.isEmpty || b.isEmpty) return 0.0;
  final maxLen = a.length > b.length ? a.length : b.length;
  return 1.0 - editDistance(a, b) / maxLen;
}
