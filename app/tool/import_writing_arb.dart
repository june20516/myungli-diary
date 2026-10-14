// writing이 만든 ui 원고 ARB(../docs/identity/writing/generated/arb/)를 app ARB에 합칩니다(#128).
// 원고가 바뀌면 다시 돌린 뒤 `flutter gen-l10n`을 실행합니다.
// 실행: dart run tool/import_writing_arb.dart

import 'dart:convert';
import 'dart:io';

const _writingArbDir = '../docs/identity/writing/generated/arb';
const _appArbDir = 'lib/core/l10n/arb';
const _templateLocale = 'ko';
const List<String> _locales = [_templateLocale, 'en', 'ja'];

/// `@`로 시작하지 않는 키가 메시지입니다. writing의 전역 속성(`@@x-generated` 등)은
/// 메시지가 아니라 가져오지 않습니다. app ARB에는 app에만 있는 키도 있어 파일 전체가
/// writing 생성물이 아니기 때문입니다. `@@locale`은 app 파일 것을 둡니다.
bool _isMessageKey(String key) => !key.startsWith('@');

/// 한 언어의 app ARB에 writing ARB를 합친 결과를 돌려줍니다.
///
/// * writing 기준 언어 파일([writingTemplate])의 메시지 키마다 값을 [writing]의
///   번역으로 바꿉니다. 번역이 없으면 기준 언어 문구를 씁니다.
/// * 기준 언어([isTemplate])면 `@키` 메타데이터도 writing 것으로 바꿉니다. writing에
///   메타데이터가 없으면 app 것을 둡니다(없으면 만들지 않음).
/// * 번역 언어 파일에서는 메시지의 `@키` 메타데이터를 모두 지웁니다. gen-l10n은 기준 언어
///   메타데이터만 읽으므로 writing 관례대로 기준 언어에만 둡니다(app에만 있는 키 포함).
/// * app에 이미 있는 키는 제자리에서 바꾸고, 없는 키는 writing 순서대로 끝에 더합니다.
/// * app에만 있는 키의 값과 `@@locale`은 그대로 둡니다.
///
/// 결과를 다시 넣어도 같은 결과가 나옵니다(멱등).
Map<String, Object?> mergeWritingArb({
  required Map<String, Object?> app,
  required Map<String, Object?> writing,
  required Map<String, Object?> writingTemplate,
  required bool isTemplate,
}) {
  // app 순서를 그대로 이어받는다. 이미 있는 키를 다시 넣으면 Map은 제자리를 지킨다.
  final merged = Map<String, Object?>.of(app);
  if (!isTemplate) {
    merged.removeWhere((key, _) => _isMessageMetaKey(key));
  }
  for (final key in writingTemplate.keys.where(_isMessageKey)) {
    merged[key] = writing[key] ?? writingTemplate[key];
    final meta = writingTemplate['@$key'];
    if (isTemplate && meta != null) {
      merged['@$key'] = meta;
    }
  }
  return merged;
}

/// 메시지의 메타데이터 키(`@키`)입니다. 전역 속성(`@@…`)은 아닙니다.
bool _isMessageMetaKey(String key) =>
    key.startsWith('@') && !key.startsWith('@@');

/// app ARB 파일 형식(두 칸 들여쓰기, 끝 줄바꿈)으로 씁니다.
String encodeArb(Map<String, Object?> arb) =>
    '${const JsonEncoder.withIndent('  ').convert(arb)}\n';

Map<String, Object?> _readArb(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>;

void main() {
  final writingTemplate = _readArb('$_writingArbDir/app_$_templateLocale.arb');
  for (final locale in _locales) {
    final appPath = '$_appArbDir/app_$locale.arb';
    final merged = mergeWritingArb(
      app: _readArb(appPath),
      writing: _readArb('$_writingArbDir/app_$locale.arb'),
      writingTemplate: writingTemplate,
      isTemplate: locale == _templateLocale,
    );
    File(appPath).writeAsStringSync(encodeArb(merged));
  }
}
