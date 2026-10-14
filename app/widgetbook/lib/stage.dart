import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:myungli_diary/design/theme/app_theme.dart';

/// 선택된 밝기와 로케일에 맞는 토큰 테마를 입혀 [child]를 보여 줍니다.
///
/// 테마 add-on은 밝기만 정하고, 글꼴 묶음은 언어(일본어 여부)에 따라 달라서
/// 현재 로케일로 `buildTheme`을 다시 부릅니다.
class Stage extends StatelessWidget {
  /// 무대를 만듭니다.
  const new({required this.child, super.key});

  /// 보여 줄 위젯.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final locale = Localizations.localeOf(context);
    final theme = buildTheme(brightness: brightness, locale: locale);
    return DefaultAssetBundle(
      bundle: _AppPackageAssetBundle(DefaultAssetBundle.of(context)),
      child: Theme(
        data: theme,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Align(alignment: Alignment.topLeft, child: child),
        ),
      ),
    );
  }
}

/// 앱의 `assets/…` 키를 의존 패키지 키(`packages/myungli_diary/assets/…`)로 바꿔 읽습니다.
///
/// 앱 코드는 자기 자산을 `assets/brand/…`로 부르지만, Widgetbook에서는 앱이 의존 패키지라
/// 번들 키에 패키지 접두사가 붙습니다. 글꼴과 달리 자산은 다시 선언하지 않습니다.
class _AppPackageAssetBundle extends CachingAssetBundle {
  new(this._parent);

  final AssetBundle _parent;

  static const String _prefix = 'packages/myungli_diary/';

  @override
  Future<ByteData> load(String key) =>
      _parent.load(key.startsWith('assets/') ? '$_prefix$key' : key);
}
