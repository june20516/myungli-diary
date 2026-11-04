import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/app/router/app_router.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/api/fake/fake_server.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations_ko.dart';
import 'package:myungli_diary/core/platform/device_info.dart';
import 'package:myungli_diary/design/components/action/primary_button.dart';
import 'package:myungli_diary/design/components/input/text_field.dart';
import 'package:myungli_diary/features/contact/presentation/contact_screen.dart';
import 'package:myungli_diary/features/me/presentation/settings_screen.dart';
import 'package:myungli_diary/testing/covers.dart';

import '../../support/app_bar_title.dart';
import '../../support/app_harness.dart';
import '../../support/onboarding_steps.dart';

final _ko = AppLocalizationsKo();

FakeServerInterceptor _fake(ProviderContainer container) =>
    container.read(fakeServerInterceptorProvider)! as FakeServerInterceptor;

/// 회원으로 앱을 띄우고 `contact`를 엽니다. [network]는 대역 서버 앞에 끼웁니다.
Future<ProviderContainer> _openContact(
  WidgetTester tester, {
  Interceptor? network,
}) async {
  final container = await pumpApp(tester, scenario: 'member');
  if (network != null) {
    final interceptors = container.read(dioProvider).interceptors;
    interceptors.insert(interceptors.length - 1, network);
  }
  unawaited(
    container.read(routerProvider).push<void>(pathOf(ScreenIds.contact)),
  );
  await pumpUntilScreen(tester, ScreenIds.contact);
  await settleWithIo(tester);
  return container;
}

Future<void> _fill(
  WidgetTester tester, {
  String message = '결제한 광고 제거권이 보이지 않아요.',
  String email = ' me@example.com ',
}) async {
  await tester.enterText(
    find.descendant(
      of: find.byKey(const ValueKey(SlotIds.contactMessageField)),
      matching: find.byType(EditableText),
    ),
    message,
  );
  await tester.enterText(
    find.descendant(
      of: find.byKey(const ValueKey(SlotIds.contactEmailField)),
      matching: find.byType(EditableText),
    ),
    email,
  );
  await tester.pump();
}

bool _sendEnabled(WidgetTester tester) =>
    tester.widget<PrimaryButton>(find.byKey(ContactScreen.sendKey)).onPressed !=
    null;

/// 떠 있는 toast가 저절로 사라지게 시간을 보냅니다(테스트 끝에 timer가 남지 않게).
Future<void> _dismissToast(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 3));
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _tapSend(WidgetTester tester) async {
  await tester.tap(find.byKey(ContactScreen.sendKey));
  await settleWithIo(tester);
}

/// `createInquiry`의 `Idempotency-Key`를 남기고, 처음 [failures]번은 503으로 끊습니다.
final class _InquiryGate extends Interceptor {
  new({this.failures = 0});

  int failures;
  final keys = <String?>[];

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.path != '/v1/support/inquiries') {
      handler.next(options);
      return;
    }
    keys.add(options.headers['Idempotency-Key'] as String?);
    if (failures == 0) {
      handler.next(options);
      return;
    }
    failures--;
    handler.reject(
      DioException.badResponse(
        statusCode: 503,
        requestOptions: options,
        response: Response<Object?>(
          requestOptions: options,
          statusCode: 503,
          headers: Headers.fromMap({
            Headers.contentTypeHeader: ['application/problem+json'],
          }),
          data: {
            'status': 503,
            'code': 'service.unavailable',
            'title': 'x',
            'traceId': 't',
          },
        ),
      ),
    );
  }
}

/// 첫 `createInquiry` 하나를 400 `/replyEmail` 필드 오류로 끊습니다.
final class _RejectEmailOnce extends Interceptor {
  bool _done = false;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (_done || options.path != '/v1/support/inquiries') {
      handler.next(options);
      return;
    }
    _done = true;
    handler.reject(
      DioException.badResponse(
        statusCode: 400,
        requestOptions: options,
        response: Response<Object?>(
          requestOptions: options,
          statusCode: 400,
          headers: Headers.fromMap({
            Headers.contentTypeHeader: ['application/problem+json'],
          }),
          data: {
            'status': 400,
            'code': 'request.invalid',
            'title': 'x',
            'traceId': 't',
            'errors': [
              {'field': '/replyEmail', 'code': 'format'},
            ],
          },
        ),
      ),
    );
  }
}

void main() {
  group('contact(D102)', () {
    testWidgets('app-bar 제목은 contact.bar.title이고 안내, 고지, 주소가 보입니다', (
      tester,
    ) async {
      covers(const Covers(decisions: ['D102']));
      await _openContact(tester);
      await expectAppBarTitle(
        tester,
        SlotIds.contactBarTitle,
        _ko.contactBarTitle,
      );
      expect(find.text(_ko.contactIntroBody), findsOneWidget);
      expect(find.text(_ko.contactAttachedNotice), findsOneWidget);
      expect(
        find.text(_ko.contactAddressNote(supportEmailAddress)),
        findsOneWidget,
      );
    });

    testWidgets('내용과 메일이 있어야 보내기가 켜지고, 메일 형식이 틀리면 보내지 않고 알립니다', (tester) async {
      final container = await _openContact(tester);
      expect(_sendEnabled(tester), isFalse);

      await _fill(tester, message: '   ', email: 'me@example.com');
      expect(_sendEnabled(tester), isFalse, reason: '공백뿐인 내용');

      await _fill(tester, email: 'not-an-email');
      expect(_sendEnabled(tester), isTrue);
      await _tapSend(tester);
      expect(find.byKey(MyungliTextField.errorLineKey), findsOneWidget);
      expect(find.text(_ko.contactEmailInvalid), findsOneWidget);
      expect(_fake(container).callCountOf('createInquiry'), 0);
      // 초점이 메일 칸으로 옮겨집니다(design V55).
      final emailEditable = tester.widget<EditableText>(
        find.descendant(
          of: find.byKey(const ValueKey(SlotIds.contactEmailField)),
          matching: find.byType(EditableText),
        ),
      );
      expect(emailEditable.focusNode.hasFocus, isTrue);

      // 주소를 고치면 오류 줄이 사라집니다.
      await _fill(tester, email: 'me@example.com');
      expect(find.byKey(MyungliTextField.errorLineKey), findsNothing);
    });

    testWidgets('보내면 기기 정보와 Idempotency-Key를 붙여 보내고 toast 뒤 닫힙니다', (
      tester,
    ) async {
      covers(const Covers(exits: ['contact>settings']));
      final container = await _openContact(tester);
      await _fill(tester);
      await _tapSend(tester);

      final fake = _fake(container);
      expect(fake.callCountOf('createInquiry'), 1);
      final body = jsonDecode(
        fake.requestBodiesOf('createInquiry').single! as String,
      );
      const info = FakeDeviceInfoReader.defaultInfo;
      expect(body, {
        'message': '결제한 광고 제거권이 보이지 않아요.',
        'replyEmail': 'me@example.com',
        'appVersion': info.appVersion,
        'os': info.os,
        'deviceModel': info.deviceModel,
      });
      expect(
        fake.requestHeadersOf('createInquiry').single['idempotency-key'],
        isNotEmpty,
      );
      // 설정 화면으로 돌아가 그 화면에서 toast를 보입니다(design V55).
      await pumpUntilScreen(tester, ScreenIds.settings);
      await tester.pump();
      expect(find.byKey(const ValueKey(ScreenIds.contact)), findsNothing);
      expect(find.text(_ko.contactSentToast), findsOneWidget);
      await _dismissToast(tester);
    });

    testWidgets('보내지 못하면(503) toast로 알리고 입력을 지키며, 다시 보내면 같은 키입니다', (
      tester,
    ) async {
      final gate = _InquiryGate(failures: 1);
      await _openContact(tester, network: gate);
      await _fill(tester);
      await _tapSend(tester);

      expect(find.text(_ko.contactSendFailed), findsOneWidget);
      expect(find.byKey(const ValueKey(ScreenIds.contact)), findsOneWidget);
      expect(find.text('결제한 광고 제거권이 보이지 않아요.'), findsOneWidget);

      await _tapSend(tester);
      expect(gate.keys, hasLength(2));
      expect(gate.keys.first, isNotNull);
      expect(gate.keys.last, gate.keys.first);
      expect(find.text(_ko.contactSentToast), findsOneWidget);
      await _dismissToast(tester);
    });

    testWidgets('내용을 고쳐 다시 보내면 새 키입니다', (tester) async {
      final gate = _InquiryGate(failures: 1);
      await _openContact(tester, network: gate);
      await _fill(tester);
      await _tapSend(tester);
      await _fill(tester, message: '다른 문의입니다.');
      await _tapSend(tester);
      expect(gate.keys, hasLength(2));
      expect(gate.keys.last, isNot(gate.keys.first));
      await _dismissToast(tester);
    });

    testWidgets('server가 메일 주소를 거부하면 그 칸에 오류를 보입니다', (tester) async {
      await _openContact(tester, network: _RejectEmailOnce());
      await _fill(tester);
      await _tapSend(tester);
      expect(find.byKey(MyungliTextField.errorLineKey), findsOneWidget);
      expect(find.byKey(const ValueKey(ScreenIds.contact)), findsOneWidget);
    });

    testWidgets('설정의 문의하기 줄에서 들어옵니다', (tester) async {
      covers(const Covers(exits: ['settings>contact']));
      final container = await pumpApp(tester, scenario: 'member');
      unawaited(
        container.read(routerProvider).push<void>(pathOf(ScreenIds.settings)),
      );
      await pumpUntilScreen(tester, ScreenIds.settings);
      await settleWithIo(tester);
      await tester.scrollUntilVisible(
        find.byKey(SettingsScreen.contactRowKey),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(_ko.settingsContactLabel), findsOneWidget);
      await tester.tap(find.byKey(SettingsScreen.contactRowKey));
      await pumpUntilScreen(tester, ScreenIds.contact);
      expect(find.byKey(const ValueKey(ScreenIds.contact)), findsOneWidget);
    });
  });
}
