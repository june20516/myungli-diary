import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:myungli_diary/app/router/app_router.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/field_problems.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/error_messages.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/action/primary_button.dart';
import 'package:myungli_diary/design/components/feedback/toast.dart';
import 'package:myungli_diary/design/components/frame/app_bar.dart';
import 'package:myungli_diary/design/components/input/text_field.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';
import 'package:myungli_diary/features/contact/application/contact_controller.dart';

/// 문의 메일함 주소(E14, D102 ④). 공개 값이고 화면에 글자로 보입니다.
const String supportEmailAddress = 'support@myungli-diary.app';

/// IA `contact`이 직접 처리하는 상태.
///
/// * `error`: 보내기 실패. toast로 알리고 입력은 그대로 둡니다. 메일 주소가 틀리면 그 칸에
///   오류를 보입니다. 보내기를 못 쓸 때를 위해 주소 안내(`contact.address.note`)는 늘 보입니다.
const Set<String> contactHandledStates = {'error'};

/// 문의하기 출구: 보낸 뒤 설정으로 돌아갑니다.
const Set<String> contactExits = {ScreenIds.settings};

/// 문의하기(IA `contact`, D102).
///
/// 사용자는 문의 내용과 답장 받을 메일 주소만 씁니다. 계정 id(토큰), 앱 버전, 기기 정보는 app이
/// 붙이고(`contact.attached.notice`로 알림) 사용자가 고칠 수 없습니다. 보내면 toast를 띄우고
/// 화면을 닫습니다(스택 바닥이면 설정으로 갑니다).
class ContactScreen extends ConsumerWidget {
  /// contact 화면을 만듭니다.
  const new({super.key});

  /// 보내기 버튼을 찾는 테스트용 키.
  static const Key sendKey = ValueKey('contact.send');

  /// 메일 주소 오류 줄을 찾는 테스트용 키.
  static const Key emailErrorKey = ValueKey('contact.email.error');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sending = ref.watch(contactControllerProvider);
    // 보내는 중에는 뒤로 가기를 막습니다. 결과를 기다리는 동안 화면이 사라지면 알릴 곳이 없습니다.
    return PopScope(
      canPop: !sending,
      child: Semantics(
        identifier: ScreenIds.contact,
        child: Scaffold(
          key: const ValueKey(ScreenIds.contact),
          body: SafeArea(
            child: Column(
              children: [
                MyungliAppBar.inner(
                  title: AppLocalizations.of(context).contactBarTitle,
                  titleIdentifier: SlotIds.contactBarTitle,
                  showBack: MyungliAppBar.canGoBack(context),
                ),
                const Expanded(child: _ContactForm()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ContactForm extends ConsumerStatefulWidget {
  const new();

  @override
  ConsumerState<_ContactForm> createState() => _ContactFormState();
}

class _ContactFormState extends ConsumerState<_ContactForm> {
  final TextEditingController _message = TextEditingController();
  final TextEditingController _email = TextEditingController();

  /// 메일 주소가 틀렸다고 알린 상태. 주소를 고치면 지웁니다.
  bool _emailError = false;

  @override
  void dispose() {
    _message.dispose();
    _email.dispose();
    super.dispose();
  }

  bool get _sendable =>
      isInquiryMessage(_message.text) && _email.text.trim().isNotEmpty;

  Future<void> _send() async {
    if (!_sendable) return;
    if (!isInquiryEmail(_email.text)) {
      setState(() => _emailError = true);
      return;
    }
    final l10n = AppLocalizations.of(context);
    try {
      final sent = await ref
          .read(contactControllerProvider.notifier)
          .send(message: _message.text, email: _email.text);
      if (!sent || !mounted) return;
      showMyungliToast(
        context,
        l10n.contactSentToast,
        identifier: SlotIds.contactSentToast,
      );
      _close();
    } on AppError catch (error) {
      if (!mounted) return;
      if (fieldProblemAt(error, '/replyEmail') != null) {
        setState(() => _emailError = true);
        return;
      }
      showMyungliToast(context, _failureMessage(l10n, error));
    }
  }

  /// 보내기 실패 문구. 연결 오류와 요청 한도는 공통 문구, 그 밖(메일 발송 불가 503 포함)은 문의
  /// 전용 문구이고 주소 안내로 이어집니다.
  String _failureMessage(AppLocalizations l10n, AppError error) =>
      switch (error) {
        OfflineError() || TimeoutError() => errorMessage(l10n, error),
        ProblemError(code: 'rate_limited') => errorMessage(l10n, error),
        _ => l10n.contactSendFailed,
      };

  /// 화면을 닫습니다. 스택 바닥(딥링크, 복원)이면 설정으로 갑니다.
  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(pathOf(ScreenIds.settings));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = context.tokens;
    final colors = tokens.colors;
    final sending = ref.watch(contactControllerProvider);
    final labelStyle = tokens.typography.labelMd.copyWith(
      color: colors.textSecondary,
    );
    final noteStyle = tokens.typography.captionMd.copyWith(
      color: colors.textSecondary,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              Space.s20,
              Space.s8,
              Space.s20,
              Space.s24,
            ),
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    identifier: SlotIds.contactIntroBody,
                    child: Text(
                      l10n.contactIntroBody,
                      style: tokens.typography.bodyUi.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: Space.s24),
                  Text(l10n.contactMessageFieldLabel, style: labelStyle),
                  const SizedBox(height: Space.s8),
                  MyungliTextField(
                    key: const ValueKey(SlotIds.contactMessageField),
                    identifier: SlotIds.contactMessageField,
                    label: l10n.contactMessageFieldLabel,
                    hint: l10n.contactMessageFieldHint,
                    controller: _message,
                    maxLength: inquiryMessageMaxLength,
                    maxLines: MyungliTextField.maxLinesLimit,
                    enabled: !sending,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: Space.s24),
                  Text(l10n.contactEmailFieldLabel, style: labelStyle),
                  const SizedBox(height: Space.s8),
                  MyungliTextField(
                    key: const ValueKey(SlotIds.contactEmailField),
                    identifier: SlotIds.contactEmailField,
                    label: l10n.contactEmailFieldLabel,
                    hint: l10n.contactEmailFieldHint,
                    controller: _email,
                    maxLength: inquiryEmailMaxLength,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    error: _emailError,
                    enabled: !sending,
                    onChanged: (_) => setState(() => _emailError = false),
                    onSubmitted: (_) => FocusScope.of(context).unfocus(),
                  ),
                  if (_emailError) ...[
                    const SizedBox(height: Space.s8),
                    Text(
                      l10n.contactEmailInvalid,
                      key: ContactScreen.emailErrorKey,
                      style: tokens.typography.captionMd.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                  const SizedBox(height: Space.s24),
                  Semantics(
                    identifier: SlotIds.contactAttachedNotice,
                    child: Text(l10n.contactAttachedNotice, style: noteStyle),
                  ),
                  const SizedBox(height: Space.s12),
                  // 보내기를 못 쓸 때 주소를 옮겨 적을 수 있게 고를 수 있는 글자입니다.
                  Semantics(
                    identifier: SlotIds.contactAddressNote,
                    child: SelectableText(
                      l10n.contactAddressNote(supportEmailAddress),
                      style: noteStyle,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.s20,
            Space.s8,
            Space.s20,
            Space.s16,
          ),
          child: ToastAnchor(
            child: PrimaryButton(
              key: ContactScreen.sendKey,
              label: l10n.contactSendCta,
              identifier: SlotIds.contactSendCta,
              loading: sending,
              onPressed: _sendable ? () => unawaited(_send()) : null,
            ),
          ),
        ),
      ],
    );
  }
}
