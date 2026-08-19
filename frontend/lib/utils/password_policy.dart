/// Password rules shared by every screen that lets a user choose a password.
///
/// This mirrors `Password()` in `backend/pkg/validation/validation.go`. The
/// backend is the enforcing side — this copy exists so the user sees which
/// requirement is unmet while typing, instead of after a round trip. Keep the
/// two in sync; if they drift, the backend wins and the user gets an error the
/// form did not predict.
class PasswordPolicy {
  const PasswordPolicy._();

  /// Minimum length, matching `MinPasswordLength` on the backend.
  static const int minLength = 8;

  // Unicode-aware to match Go's `unicode.IsUpper` / `unicode.IsDigit`, which
  // are not ASCII-only. An ASCII `[A-Z]` here would reject a password the
  // server accepts, which is the more confusing of the two failure modes.
  static final RegExp _upper = RegExp(r'\p{Lu}', unicode: true);
  static final RegExp _digit = RegExp(r'\p{Nd}', unicode: true);

  // Anything that is neither a letter, a decimal digit, nor whitespace.
  // Whitespace is excluded deliberately, matching the backend: a space is
  // usually a typo and must not silently satisfy the requirement.
  static final RegExp _special = RegExp(r'[^\p{L}\p{Nd}\s]', unicode: true);

  static bool hasMinLength(String password) => password.length >= minLength;

  static bool hasUppercase(String password) => _upper.hasMatch(password);

  static bool hasDigit(String password) => _digit.hasMatch(password);

  static bool hasSpecial(String password) => _special.hasMatch(password);

  /// Whether [password] satisfies every requirement.
  static bool isSatisfied(String password) =>
      hasMinLength(password) &&
      hasUppercase(password) &&
      hasDigit(password) &&
      hasSpecial(password);

  /// The requirements [password] does not yet meet, in display order.
  static List<PasswordRequirement> unmet(String password) => [
        for (final r in PasswordRequirement.values)
          if (!r.isMetBy(password)) r,
      ];
}

/// A single password requirement, used both for validation and for the
/// checklist the signup form renders.
enum PasswordRequirement {
  length,
  uppercase,
  digit,
  special;

  bool isMetBy(String password) => switch (this) {
        PasswordRequirement.length => PasswordPolicy.hasMinLength(password),
        PasswordRequirement.uppercase => PasswordPolicy.hasUppercase(password),
        PasswordRequirement.digit => PasswordPolicy.hasDigit(password),
        PasswordRequirement.special => PasswordPolicy.hasSpecial(password),
      };
}
