/// 계약의 operation 하나: HTTP method, 경로 템플릿, operationId.
///
/// 대역 서버가 요청을 operationId로 가르는 데 씁니다. 표는 계약에서 생성합니다.
class ApiRoute {
  /// operation 하나를 만듭니다.
  const new(this.method, this.pathTemplate, this.operationId);

  /// 대문자 HTTP method. 예: `GET`.
  final String method;

  /// 경로 템플릿. 예: `/v1/daily/{date}`.
  final String pathTemplate;

  /// 계약의 operationId. 생성 클라이언트의 메서드 이름과 같습니다.
  final String operationId;

  /// [path]가 이 템플릿과 맞으면 path 매개변수를, 아니면 null을 돌려줍니다.
  Map<String, String>? pathParametersOf(String path) {
    final templateSegments = pathTemplate.split('/');
    final pathSegments = _segmentsOf(path);
    if (templateSegments.length != pathSegments.length) {
      return null;
    }
    final parameters = <String, String>{};
    for (var i = 0; i < templateSegments.length; i++) {
      final template = templateSegments[i];
      final segment = pathSegments[i];
      if (_isParameter(template)) {
        if (segment.isEmpty) {
          return null;
        }
        parameters[template.substring(1, template.length - 1)] = segment;
      } else if (template != segment) {
        return null;
      }
    }
    return parameters;
  }

  /// 경로 템플릿의 매개변수 개수.
  int get parameterCount => pathTemplate.split('/').where(_isParameter).length;
}

bool _isParameter(String segment) =>
    segment.startsWith('{') && segment.endsWith('}');

/// query와 끝 슬래시를 뺀 경로를 `/`로 나눕니다(맨 앞 빈 조각 포함).
List<String> _segmentsOf(String path) {
  var clean = path.split('?').first;
  if (clean.length > 1 && clean.endsWith('/')) {
    clean = clean.substring(0, clean.length - 1);
  }
  return clean.split('/');
}
