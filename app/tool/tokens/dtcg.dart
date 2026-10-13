// DTCG 2025.10 토큰 JSON을 읽어 참조를 푸는 순수 Dart 모듈입니다.
// `dart run`이 Flutter 엔진 없이 돌아야 하므로 Flutter·dart:ui를 import하지 않습니다.

/// 토큰 입력이 규약을 어겼을 때 던집니다.
class TokenError implements Exception {
  new(this.message);

  final String message;

  @override
  String toString() => 'TokenError: $message';
}

/// design 작업 단위가 `$extensions`에 쓰는 역도메인 키.
const designExtensionKey = 'io.github.june20516.myungli-diary';

/// 참조가 모두 풀린 토큰 하나.
class ResolvedToken {
  const new({
    required this.name,
    required this.type,
    required this.value,
    required this.description,
    required this.extensions,
  });

  /// 점으로 이은 전체 경로. 예: `color.bg.base`.
  final String name;

  /// `$type`. 예: `color`, `dimension`, `typography`.
  final String type;

  /// 참조를 푼 `$value`. JSON 값(Map·List·num·String)입니다.
  final Object? value;

  final String? description;

  /// [designExtensionKey] 아래의 확장 값. 없으면 빈 Map.
  final Map<String, Object?> extensions;
}

final _referencePattern = RegExp(r'^\{([^{}]+)\}$');

/// 테마 하나를 이루는 토큰 파일들(primitive + 색 모드 + 글자 언어)을 합쳐 참조를 풉니다.
///
/// 파일끼리 같은 이름을 정의하면, 참조 대상이 없으면, 참조가 순환하면 [TokenError]입니다.
Map<String, ResolvedToken> resolveTheme(List<Map<String, Object?>> files) {
  final raw = <String, Map<String, Object?>>{};
  for (final file in files) {
    _collect(file, '', raw);
  }

  final resolved = <String, ResolvedToken>{};
  Object? valueOf(String name, List<String> stack) {
    if (stack.contains(name)) {
      throw TokenError('순환 참조: ${[...stack, name].join(' -> ')}');
    }
    final token = raw[name];
    if (token == null) {
      throw TokenError(
        "참조 대상 '$name'이 없습니다 (${stack.isEmpty ? '' : stack.last}).",
      );
    }
    final done = resolved[name];
    if (done != null) {
      return done.value;
    }
    final value = _resolveValue(token[r'$value'], [...stack, name], valueOf);
    final type = token[r'$type'];
    if (type is! String) {
      throw TokenError("'$name'에 \$type이 없습니다.");
    }
    final extensions = token[r'$extensions'];
    resolved[name] = ResolvedToken(
      name: name,
      type: type,
      value: value,
      description: token[r'$description'] as String?,
      extensions: extensions is Map<String, Object?>
          ? (extensions[designExtensionKey] as Map<String, Object?>? ??
                const {})
          : const {},
    );
    return value;
  }

  for (final name in raw.keys) {
    valueOf(name, const []);
  }
  return resolved;
}

void _collect(
  Map<String, Object?> group,
  String prefix,
  Map<String, Map<String, Object?>> out,
) {
  for (final entry in group.entries) {
    if (entry.key.startsWith(r'$')) {
      continue;
    }
    final node = entry.value;
    if (node is! Map<String, Object?>) {
      throw TokenError("'$prefix${entry.key}'이 객체가 아닙니다.");
    }
    final name = '$prefix${entry.key}';
    if (node.containsKey(r'$value')) {
      if (out.containsKey(name)) {
        throw TokenError("토큰 '$name'이 여러 파일에 정의돼 있습니다.");
      }
      out[name] = node;
    } else {
      _collect(node, '$name.', out);
    }
  }
}

Object? _resolveValue(
  Object? value,
  List<String> stack,
  Object? Function(String name, List<String> stack) valueOf,
) {
  if (value is String) {
    final match = _referencePattern.firstMatch(value);
    return match == null ? value : valueOf(match.group(1)!, stack);
  }
  if (value is List<Object?>) {
    return [for (final item in value) _resolveValue(item, stack, valueOf)];
  }
  if (value is Map<String, Object?>) {
    return {
      for (final entry in value.entries)
        entry.key: _resolveValue(entry.value, stack, valueOf),
    };
  }
  return value;
}

/// 색 토큰 값. 기준값은 hex이고, 알파는 hex와 따로 옵니다.
class DtcgColor {
  const new({required this.hex, required this.alpha});

  /// 소문자 `#rrggbb`.
  final String hex;

  /// 0~1. 투명도가 없으면 1.
  final double alpha;

  int get red => int.parse(hex.substring(1, 3), radix: 16);
  int get green => int.parse(hex.substring(3, 5), radix: 16);
  int get blue => int.parse(hex.substring(5, 7), radix: 16);
}

/// 해석된 색 값을 [DtcgColor]로 읽습니다.
DtcgColor parseColor(Object? value) {
  if (value is! Map<String, Object?>) {
    throw TokenError('색 값이 객체가 아닙니다: $value');
  }
  final hex = value['hex'];
  if (hex is! String || !RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(hex)) {
    throw TokenError('색의 hex가 #rrggbb 형식이 아닙니다: $hex');
  }
  final alpha = value['alpha'];
  if (alpha != null && (alpha is! num || alpha < 0 || alpha > 1)) {
    throw TokenError('alpha는 0~1이어야 합니다: $alpha');
  }
  return DtcgColor(
    hex: hex.toLowerCase(),
    alpha: (alpha as num?)?.toDouble() ?? 1,
  );
}

/// `{"value": 16, "unit": "px"}` → 16.
double parseDimension(Object? value) => _parseUnitValue(value, 'px').toDouble();

/// `{"value": 320, "unit": "ms"}` → 320.
int parseDurationMs(Object? value) => _parseUnitValue(value, 'ms').round();

num _parseUnitValue(Object? value, String unit) {
  if (value is! Map<String, Object?> ||
      value['unit'] != unit ||
      value['value'] is! num) {
    throw TokenError("'$unit' 단위 값이 아닙니다: $value");
  }
  return value['value']! as num;
}
