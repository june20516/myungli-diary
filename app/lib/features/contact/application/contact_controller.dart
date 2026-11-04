import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/gen/model/inquiry_input.dart';
import 'package:myungli_diary/core/platform/device_info.dart';
import 'package:myungli_diary/features/contact/data/inquiry_repository.dart';
import 'package:uuid/uuid.dart';

/// 문의 내용 글자 수 상한(계약 `InquiryInput.message`).
const int inquiryMessageMaxLength = 2000;

/// 답장 받을 메일 주소 글자 수 상한(계약 `InquiryInput.replyEmail`).
const int inquiryEmailMaxLength = 254;

final RegExp _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

/// [value]가 보낼 수 있는 메일 주소 꼴인지(앞뒤 공백은 뺌). 정확한 검사는 server가 합니다.
bool isInquiryEmail(String value) {
  final email = value.trim();
  return email.length <= inquiryEmailMaxLength && _emailPattern.hasMatch(email);
}

/// [value]에 공백이 아닌 글자가 있는지(계약 `message` pattern `\S`).
bool isInquiryMessage(String value) => value.trim().isNotEmpty;

/// 문의 server 요청.
final inquiryRepositoryProvider = Provider<InquiryRepository>(
  (ref) => InquiryRepository(ref.watch(restClientProvider)),
);

/// 문의 보내기(IA `contact`, D102). 상태는 보내는 중인지입니다.
///
/// 같은 문의(내용과 메일이 같음)를 다시 보내면 같은 `Idempotency-Key`를 씁니다. 응답을 받지
/// 못해 다시 보내도 메일이 두 번 가지 않습니다. 내용이나 메일이 바뀌면 새 키입니다.
class ContactController extends Notifier<bool> {
  ({String message, String email, String key})? _lastAttempt;

  @override
  bool build() => false;

  /// [message]와 [email]을 앱과 기기 정보와 함께 보냅니다. 보내는 중에 다시 부르면 아무 일도
  /// 하지 않고 false, 보냈으면 true입니다. 실패는 [AppError]로 던집니다.
  Future<bool> send({required String message, required String email}) async {
    if (state) return false;
    state = true;
    try {
      final info = await ref.read(deviceInfoReaderProvider).read();
      final trimmedEmail = email.trim();
      final attempt = _lastAttempt;
      final key =
          attempt != null &&
              attempt.message == message &&
              attempt.email == trimmedEmail
          ? attempt.key
          : const Uuid().v4();
      _lastAttempt = (message: message, email: trimmedEmail, key: key);
      await ref
          .read(inquiryRepositoryProvider)
          .send(
            InquiryInput(
              message: message,
              replyEmail: trimmedEmail,
              appVersion: info.appVersion,
              os: info.os,
              deviceModel: info.deviceModel,
            ),
            idempotencyKey: key,
          );
      _lastAttempt = null;
      return true;
    } finally {
      if (ref.mounted) state = false;
    }
  }
}

/// 문의 보내기 상태. 화면이 닫히면 버려집니다.
final NotifierProvider<ContactController, bool> contactControllerProvider =
    NotifierProvider.autoDispose<ContactController, bool>(
      ContactController.new,
    );

/// 보낸 뒤 설정 화면이 띄울 toast가 남아 있는지(design V55: 설정으로 돌아간 뒤 그 화면에서
/// `contact.sent.toast`).
///
/// 문의 화면이 보낸 뒤 [show]로 남기고 설정으로 이동하면, 설정 화면이 이 값을 보고 [consume]한
/// 뒤 자기 자리에서 toast를 띄웁니다. 어느 길(설정, 구매 내역)로 들어왔든 같습니다.
class ContactSentNotice extends Notifier<bool> {
  @override
  bool build() => false;

  /// 알림을 남깁니다.
  void show() => state = true;

  /// 남은 알림을 가져가고 지웁니다. 남아 있었으면 true입니다.
  bool consume() {
    final pending = state;
    state = false;
    return pending;
  }
}

/// 보낸 뒤 설정 화면이 띄울 toast.
final NotifierProvider<ContactSentNotice, bool> contactSentNoticeProvider =
    NotifierProvider<ContactSentNotice, bool>(ContactSentNotice.new);
