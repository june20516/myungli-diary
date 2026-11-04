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
import 'package:myungli_diary/design/interaction/haptics.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';
import 'package:myungli_diary/features/contact/application/contact_controller.dart';

/// 문의 메일함 주소(E14, D102 ④). 공개 값이고 화면에 글자로 보입니다.
const String supportEmailAddress = 'support@myungli-diary.app';

/// IA `contact`이 직접 처리하는 상태.
///
/// * `error`: 보내기 실패. 화면을 바꾸지 않고 쓴 글을 그대로 둔 채 toast로 알립니다(design
///   V55). 보내기를 못 쓸 때를 위해 주소 안내(`contact.address.note`)는 늘 보입니다.
const Set<String> contactHandledStates = {'error'};

/// 문의하기 출구: 보낸 뒤 설정으로 돌아갑니다.
const Set<String> contactExits = {ScreenIds.settings};

/// 문의 내용 칸이 처음 여는 줄 수(design V55).
const int _messageMinLines = 4;

/// 문의하기(IA `contact`, D102, design V55).
///
/// 사용자는 문의 내용과 답장 받을 메일 주소만 씁니다. 계정 id(토큰), 앱 버전, 기기 정보는 app이
/// 붙이고(`contact.attached.notice`로 알림) 사용자가 고칠 수 없습니다. 보내면 설정으로 돌아가고,
/// 설정 화면이 `contact.sent.toast`를 보입니다([contactSentNoticeProvider]). 뒤로 가기는 확인 창
/// 없이 쓴 글을 버리고, 보내는 중에도 막지 않습니다.
class ContactScreen extends StatelessWidget {
  /// contact 화면을 만듭니다.
  const new({super.key});

  /// 보내기 버튼을 찾는 테스트용 키.
  static const Key sendKey = ValueKey('contact.send');

  @override
  Widget build(BuildContext context) => Semantics(
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
  );
}

class _ContactForm extends ConsumerStatefulWidget {
  const new();

  @override
  ConsumerState<_ContactForm> createState() => _ContactFormState();
}

class _ContactFormState extends ConsumerState<_ContactForm> {
  final TextEditingController _message = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final FocusNode _emailFocus = FocusNode();

  /// 메일 주소가 틀렸다고 알린 상태. 주소를 고치기 시작하면 지웁니다.
  bool _emailError = false;

  @override
  void dispose() {
    _message.dispose();
    _email.dispose();
    _emailFocus.dispose();
    super.dispose();
  }

  /// 내용(앞뒤 공백 제외)과 메일 칸이 둘 다 비어 있지 않으면 누를 수 있습니다.
  bool get _sendable =>
      isInquiryMessage(_message.text) && _email.text.trim().isNotEmpty;

  /// 메일 칸에 오류 줄을 띄우고 초점을 그 칸으로 옮깁니다.
  void _showEmailError() {
    setState(() => _emailError = true);
    _emailFocus.requestFocus();
  }

  Future<void> _send() async {
    if (!_sendable) return;
    if (!isInquiryEmail(_email.text)) {
      _showEmailError();
      return;
    }
    final l10n = AppLocalizations.of(context);
    try {
      final sent = await ref
          .read(contactControllerProvider.notifier)
          .send(message: _message.text, email: _email.text);
      if (!sent || !mounted) return;
      unawaited(Haptics.light());
      ref.read(contactSentNoticeProvider.notifier).show();
      context.go(pathOf(ScreenIds.settings));
    } on AppError catch (error) {
      if (!mounted) return;
      if (fieldProblemAt(error, '/replyEmail') != null) {
        _showEmailError();
        return;
      }
      showMyungliToast(context, _failureMessage(l10n, error));
    }
  }

  /// 보내기 실패 문구. 연결 오류는 공통 문구, 그 밖(너무 자주 보냄 429, 발송 불가 503 포함)은
  /// 문의 전용 문구입니다(design V55).
  String _failureMessage(AppLocalizations l10n, AppError error) =>
      switch (error) {
        OfflineError() || TimeoutError() => errorMessage(l10n, error),
        _ => l10n.contactSendFailed,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = context.tokens;
    final colors = tokens.colors;
    final sending = ref.watch(contactControllerProvider);
    final noteStyle = tokens.typography.captionLg.copyWith(
      color: colors.textSecondary,
    );
    final address = l10n.contactAddressNote(supportEmailAddress);
    final addressAt = address.indexOf(supportEmailAddress);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              Space.s20,
              Space.s12,
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
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: Space.s24),
                  MyungliTextField(
                    key: const ValueKey(SlotIds.contactMessageField),
                    identifier: SlotIds.contactMessageField,
                    label: l10n.contactMessageFieldLabel,
                    showLabel: true,
                    hint: l10n.contactMessageFieldHint,
                    controller: _message,
                    maxLength: inquiryMessageMaxLength,
                    minLines: _messageMinLines,
                    maxLines: MyungliTextField.maxLinesLimit,
                    enabled: !sending,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: Space.s20),
                  MyungliTextField(
                    key: const ValueKey(SlotIds.contactEmailField),
                    identifier: SlotIds.contactEmailField,
                    label: l10n.contactEmailFieldLabel,
                    showLabel: true,
                    hint: l10n.contactEmailFieldHint,
                    controller: _email,
                    focusNode: _emailFocus,
                    maxLength: inquiryEmailMaxLength,
                    email: true,
                    errorText: _emailError ? l10n.contactEmailInvalid : null,
                    enabled: !sending,
                    // 고치기 시작하면 오류 줄과 error 상태가 함께 사라집니다.
                    onChanged: (_) => setState(() => _emailError = false),
                    onSubmitted: (_) => FocusScope.of(context).unfocus(),
                  ),
                  const SizedBox(height: Space.s24),
                  Semantics(
                    identifier: SlotIds.contactAttachedNotice,
                    child: Text(l10n.contactAttachedNotice, style: noteStyle),
                  ),
                  const SizedBox(height: Space.s12),
                  // 주소는 링크가 아닌 글자이고 길게 눌러 복사할 수 있습니다(D102 ④). 주소만
                  // text.primary입니다.
                  Semantics(
                    identifier: SlotIds.contactAddressNote,
                    child: SelectableText.rich(
                      TextSpan(
                        style: noteStyle,
                        children: addressAt < 0
                            ? [TextSpan(text: address)]
                            : [
                                TextSpan(text: address.substring(0, addressAt)),
                                TextSpan(
                                  text: supportEmailAddress,
                                  style: noteStyle.copyWith(
                                    color: colors.textPrimary,
                                  ),
                                ),
                                TextSpan(
                                  text: address.substring(
                                    addressAt + supportEmailAddress.length,
                                  ),
                                ),
                              ],
                      ),
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
