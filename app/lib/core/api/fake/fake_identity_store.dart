import 'package:myungli_diary/core/api/fake/fake_problem.dart';

/// 대역 서버의 로그인 수단 연결 목록입니다(결정 A84).
///
/// 처음 목록은 시나리오 `listIdentities` 파일의 `items`입니다. 규칙:
/// * `google` 붙이기는 409 `auth.identity_in_use`(다른 계정에 연결된 인증 계정), 나머지는
///   붙습니다. 이미 붙어 있으면 바꾸지 않습니다.
/// * 떼기는 마지막이면 409 `auth.last_identity`, 없는 제공자면 404 `auth.identity_not_found`.
/// * 합치기 인증은 이 계정에 이미 연결된 제공자면 422 `merge.same_account`, `apple`은
///   422 `merge.no_account`, 그 밖은 통과입니다.
final class FakeIdentityStore {
  /// `seed`는 처음 `Identity` JSON 목록(붙인 순서), `nowUtc`는 붙인 시각입니다.
  new({required List<Map<String, Object?>> seed, required this._nowUtc})
    : _items = [for (final item in seed) Map<String, Object?>.from(item)];

  final DateTime Function() _nowUtc;
  final List<Map<String, Object?>> _items;

  /// `IdentityList` JSON.
  Map<String, Object?> list() => {
    'items': [for (final item in _items) Map<String, Object?>.of(item)],
  };

  /// [provider]를 붙이고 `(새로 붙였는지, 붙인 뒤 목록)`을 돌려줍니다.
  (bool, Map<String, Object?>) link(String provider) {
    if (_has(provider)) {
      return (false, list());
    }
    if (provider == 'google') {
      throw const FakeProblem(
        409,
        'auth.identity_in_use',
        'Identity in use',
        '그 인증 계정은 다른 계정에 연결돼 있습니다.',
      );
    }
    _items.add({
      'provider': provider,
      'linkedAt': _nowUtc().toUtc().toIso8601String().replaceFirst(
        RegExp(r'\.\d+Z$'),
        'Z',
      ),
    });
    return (true, list());
  }

  /// [provider] 연결을 지웁니다.
  void unlink(String provider) {
    if (!_has(provider)) {
      throw const FakeProblem(
        404,
        'auth.identity_not_found',
        'Identity not found',
        '이 계정에 그 로그인 수단이 없습니다.',
      );
    }
    if (_items.length == 1) {
      throw const FakeProblem(
        409,
        'auth.last_identity',
        'Last identity',
        '마지막 로그인 수단은 뗄 수 없습니다.',
      );
    }
    _items.removeWhere((item) => item['provider'] == provider);
  }

  /// 합치기 인증이 통과하지 못하는 경우의 오류를 던집니다. 통과면 아무것도 하지 않습니다.
  void checkMergeable(String provider) {
    if (_has(provider)) {
      throw const FakeProblem(
        422,
        'merge.same_account',
        'Same account',
        '이미 이 계정에 연결된 로그인 수단입니다.',
      );
    }
    if (provider == 'apple') {
      throw const FakeProblem(
        422,
        'merge.no_account',
        'No account',
        '그 인증 계정에 연결된 계정이 없습니다.',
      );
    }
  }

  bool _has(String provider) =>
      _items.any((item) => item['provider'] == provider);
}
