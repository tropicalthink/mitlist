import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/utils/password_policy.dart';

/// Mirrors `TestPassword` in `backend/pkg/validation/validation_test.go`.
/// The backend is the enforcing side; if these two disagree, the form will
/// either block a password the server accepts or wave through one it rejects.
void main() {
  group('PasswordPolicy.isSatisfied', () {
    test('accepts a password meeting every requirement', () {
      expect(PasswordPolicy.isSatisfied('Passw0rd!'), isTrue);
    });

    test('rejects a password shorter than the minimum', () {
      expect(PasswordPolicy.isSatisfied('Pa0!aaa'), isFalse);
      expect(PasswordPolicy.hasMinLength('Pa0!aaa'), isFalse);
    });

    test('rejects a password with no uppercase letter', () {
      expect(PasswordPolicy.isSatisfied('passw0rd!'), isFalse);
    });

    test('rejects a password with no number', () {
      expect(PasswordPolicy.isSatisfied('Password!'), isFalse);
    });

    test('rejects a password with no special character', () {
      expect(PasswordPolicy.isSatisfied('Passw0rdd'), isFalse);
    });

    test('does not accept whitespace as a special character', () {
      // Matches the backend: a space is usually a typo, and accepting it would
      // let the policy be satisfied in a way the user cannot see.
      expect(PasswordPolicy.hasSpecial('Passw0rd 1'), isFalse);
      expect(PasswordPolicy.isSatisfied('Passw0rd 1'), isFalse);
    });

    test('treats non-ASCII uppercase as uppercase, matching unicode.IsUpper',
        () {
      expect(PasswordPolicy.hasUppercase('Ünicode1!'), isTrue);
      expect(PasswordPolicy.isSatisfied('Ünicode1!'), isTrue);
    });

    test('accepts a symbol as a special character', () {
      expect(PasswordPolicy.isSatisfied('Passw0rd~'), isTrue);
    });

    test('empty password fails every requirement', () {
      expect(PasswordPolicy.unmet(''), PasswordRequirement.values);
    });
  });

  group('PasswordPolicy.unmet', () {
    test('reports only the requirements not yet met', () {
      expect(PasswordPolicy.unmet('password'), [
        PasswordRequirement.uppercase,
        PasswordRequirement.digit,
        PasswordRequirement.special,
      ]);
      expect(PasswordPolicy.unmet('Passw0rd'), [PasswordRequirement.special]);
    });

    test('is empty for a fully valid password', () {
      expect(PasswordPolicy.unmet('Passw0rd!'), isEmpty);
    });
  });
}
