import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:myungli_diary/app/entry/entry_providers.dart';
import 'package:myungli_diary/app/router/app_router.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/gen/model/consent_document.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/error_messages.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/action/primary_button.dart';
import 'package:myungli_diary/design/components/feedback/live_announcement.dart';
import 'package:myungli_diary/design/components/frame/app_bar.dart';
import 'package:myungli_diary/design/components/frame/onboarding_page_layout.dart';
import 'package:myungli_diary/design/components/input/check_row.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';
import 'package:myungli_diary/features/auth/application/consent_controller.dart';

/// IA `consent`의 출구 대상. `notify-ask`(미리보기를 거친 새 계정)·`onboard-call`(그 외)은
/// 진입 상태가 바뀌는 이동이라 동의 뒤 진입 갱신으로 라우터 redirect가 보냅니다. `legal`만
/// 화면이 직접 엽니다.
const Set<String> consentExits = {
  ScreenIds.notifyAsk,
  ScreenIds.onboardCall,
  ScreenIds.legal,
};

/// IA `consent`가 직접 처리하는 상태. 동의 저장 실패를 버튼 위 안내로 그립니다.
const Set<String> consentHandledStates = {'error'};

/// 오류 상태 안내를 찾는 테스트용 키.
const Key consentErrorKey = ValueKey('consent.error');

/// 동의 항목 한 줄을 찾는 테스트용 키.
Key consentDocumentKey(ConsentDocumentDocumentEnum document) =>
    ValueKey('consent.document.${document.value}');

/// 동의 줄의 Semantics identifier.
///
/// IA에는 필수 항목 슬롯(`consent.required.label`)이 하나뿐인데 줄은 문서마다 있어,
/// E2E가 줄을 구분할 수 있게 슬롯 id에 문서 값(`terms`·`privacy`)을 붙입니다.
String consentRowIdentifier(ConsentDocumentDocumentEnum document) =>
    '${SlotIds.consentRequiredLabel}.${document.value}';

/// 새 계정의 필수 약관 동의(D50).
///
/// 내 정보의 `requiredConsents` 문서마다 `check-row` card를 그립니다. MVP 약관 동의는
/// 필수만이라 선택 항목은 없습니다(D67, IA v2). 모두 체크해야 동의
/// 버튼이 켜지고, 처리 중에는 다시 받지 않습니다. '보기'는 `legal`을 열며 체크는 그대로입니다.
///
/// 슬롯이 모두 `ui`(ARB 문자열)라 제목은 같은 글자 역할의 [Text]로 그립니다.
class ConsentScreen extends ConsumerStatefulWidget {
  /// consent 화면을 만듭니다.
  const new({super.key});

  @override
  ConsumerState<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends ConsumerState<ConsentScreen> {
  /// 체크한 문서. 버전과 상관없이 문서 종류로 둡니다.
  final Set<ConsentDocumentDocumentEnum> _checked = {};

  bool _busy = false;

  /// 마지막 동의 실패. null이면 안내가 없습니다.
  AppError? _failure;

  Future<void> _agree(List<ConsentDocument> documents) async {
    // 같은 프레임의 두 번째 누름도 막도록 상태를 바로 바꿉니다.
    if (_busy) return;
    setState(() {
      _busy = true;
      _failure = null;
    });
    final failure = await ref
        .read(consentControllerProvider.notifier)
        .agree(documents);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _failure = failure;
      // 버전이 바뀌었으면 새로 받은 문서를 다시 확인하도록 체크를 풉니다.
      if (failure != null && isConsentVersionMismatch(failure)) {
        _checked.clear();
      }
    });
  }

  void _toggle(ConsentDocumentDocumentEnum document, {required bool value}) {
    setState(() {
      if (value) {
        _checked.add(document);
      } else {
        _checked.remove(document);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // 처리 중에 controller가 버려지지 않게 화면이 붙들어 둡니다.
    ref.watch(consentControllerProvider);
    final documents = ref.watch(meProvider)?.requiredConsents ?? const [];
    final l10n = AppLocalizations.of(context);
    final tokens = context.tokens;
    final failure = _failure;
    final failureMessage = failure == null ? null : errorMessage(l10n, failure);
    final allChecked =
        documents.isNotEmpty &&
        documents.every((d) => _checked.contains(d.document));
    return Semantics(
      identifier: ScreenIds.consent,
      child: Scaffold(
        key: const ValueKey(ScreenIds.consent),
        body: SafeArea(
          child: Column(
            children: [
              // 진입 갈래(consentRequired)의 첫 화면이라 돌아갈 곳이 없어 뒤로 버튼을 두지 않습니다.
              const MyungliAppBar.inner(title: '', showBack: false),
              Expanded(
                child: OnboardingPageLayout(
                  body: [
                    Semantics(
                      identifier: SlotIds.consentTitleHead,
                      header: true,
                      child: Text(
                        l10n.consentTitleHead,
                        key: const ValueKey(SlotIds.consentTitleHead),
                        style: tokens.typography.title.copyWith(
                          color: tokens.colors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: Space.s24),
                    for (final (index, document) in documents.indexed) ...[
                      if (index > 0) const SizedBox(height: Space.s12),
                      KeyedSubtree(
                        key: consentDocumentKey(document.document),
                        child: CheckRow(
                          variant: CheckRowVariant.card,
                          label: _requiredLabel(l10n, document.document),
                          checked: _checked.contains(document.document),
                          onChanged: _busy
                              ? null
                              : (value) =>
                                    _toggle(document.document, value: value),
                          viewLabel: l10n.consentView,
                          onView: () =>
                              context.push<void>(pathOf(ScreenIds.legal)),
                          identifier: consentRowIdentifier(document.document),
                        ),
                      ),
                    ],
                  ],
                  actions: [
                    if (failureMessage != null) ...[
                      LiveAnnouncement(
                        key: consentErrorKey,
                        label: failureMessage,
                        role: SemanticsRole.alert,
                        child: Text(
                          failureMessage,
                          style: tokens.typography.bodyUi.copyWith(
                            color: tokens.colors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(height: Space.s16),
                    ],
                    PrimaryButton(
                      label: l10n.consentCtaAgree,
                      identifier: SlotIds.consentCtaAgree,
                      loading: _busy,
                      onPressed: allChecked ? () => _agree(documents) : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 필수 동의 항목 이름(슬롯 `consent.required.label`, 문서마다 원고가 따로 있음).
String _requiredLabel(
  AppLocalizations l10n,
  ConsentDocumentDocumentEnum document,
) => switch (document) {
  ConsentDocumentDocumentEnum.terms => l10n.consentRequiredLabelTerms,
  ConsentDocumentDocumentEnum.privacy => l10n.consentRequiredLabelPrivacy,
};
