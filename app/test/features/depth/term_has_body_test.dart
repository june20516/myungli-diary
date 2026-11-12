import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/gen/model/evidence.dart';
import 'package:myungli_diary/core/api/gen/model/evidence_access.dart';
import 'package:myungli_diary/core/api/gen/model/evidence_preview.dart';
import 'package:myungli_diary/core/api/gen/model/rendered_text.dart';
import 'package:myungli_diary/core/api/gen/model/segment.dart';
import 'package:myungli_diary/features/depth/application/depth_sheets.dart';
import 'package:myungli_diary/features/depth/application/evidence_unlock_controller.dart';
import 'package:myungli_diary/features/depth/application/explain_content.dart';
import 'package:myungli_diary/features/depth/application/personal_reading_key.dart';
import 'package:myungli_diary/features/depth/application/term_origin.dart';
import 'package:myungli_diary/features/glossary/application/glossary_providers.dart';
import 'package:myungli_diary/features/glossary/model/glossary_names.dart';

RenderedText _text(String text) =>
    RenderedText(segments: [Segment(text: text)]);

final _reason = Provider<RenderedText?>((_) => _text('오늘 그런 이유'));
final _noReason = Provider<RenderedText?>((_) => null);

/// 오늘 그런 이유만 정하는 출처. 나머지는 쓰지 않습니다.
final class _ReasonSubject implements EvidenceSubject {
  const new({required this.hasReason});

  final bool hasReason;

  @override
  ProviderListenable<RenderedText?> todayReasonOf(String slotId) =>
      hasReason ? _reason : _noReason;

  @override
  ProviderListenable<AsyncValue<EvidenceAccess>> get access =>
      throw UnimplementedError();

  @override
  ProviderListenable<AsyncValue<List<Evidence>>> evidenceOf(String slotId) =>
      throw UnimplementedError();

  @override
  ProviderListenable<List<EvidencePreview>> previewOf(String slotId) =>
      throw UnimplementedError();

  @override
  ProviderListenable<AsyncValue<RenderedText?>> personalOf(
    PersonalReadingKey key,
  ) => throw UnimplementedError();

  @override
  ProviderListenable<SentenceEvidence>? sentenceEvidenceOf(String slotId) =>
      null;

  @override
  Future<void> reload(Ref ref) async {}
}

Future<ProviderContainer> _container(GlossaryNames names) async {
  final container = ProviderContainer(
    overrides: [glossaryProvider.overrideWith((ref) async => names)],
  );
  addTearDown(container.dispose);
  await container.read(glossaryProvider.future);
  return container;
}

const _names = GlossaryNames({
  'ten_god': {'bigyeop': '비견'},
});

ExplainTerm _term({required bool hasReason}) => ExplainTerm(
  'ten_god.bigyeop',
  origin: TermOrigin(
    slotId: 'today.fortune.head',
    subject: _ReasonSubject(hasReason: hasReason),
  ),
);

void main() {
  test('뜻이 있으면 본문이 있습니다', () async {
    final container = await _container(
      GlossaryNames(
        _names.values,
        meanings: {'ten_god.bigyeop': _text('나와 같은 기운')},
      ),
    );
    expect(termHasBodyIn(container.read, _term(hasReason: false)), isTrue);
  });

  test('뜻이 없어도 오늘 그런 이유가 있으면 본문이 있습니다', () async {
    final container = await _container(_names);
    expect(termHasBodyIn(container.read, _term(hasReason: true)), isTrue);
  });

  test('뜻도 오늘 그런 이유도 없으면 본문이 없습니다', () async {
    final container = await _container(_names);
    expect(termHasBodyIn(container.read, _term(hasReason: false)), isFalse);
  });

  test('출처가 없으면 갈 곳이 없어 늘 풀이 시트입니다', () async {
    final container = await _container(_names);
    expect(
      termHasBodyIn(container.read, const ExplainTerm('ten_god.bigyeop')),
      isTrue,
    );
  });

  test('사전을 아직 받지 못했으면 풀이 시트입니다(받는 동안 skeleton)', () {
    final container = ProviderContainer(
      overrides: [
        glossaryProvider.overrideWith(
          (ref) => Future<GlossaryNames>.delayed(const Duration(days: 1)),
        ),
      ],
    );
    addTearDown(container.dispose);
    expect(termHasBodyIn(container.read, _term(hasReason: false)), isTrue);
  });
}
