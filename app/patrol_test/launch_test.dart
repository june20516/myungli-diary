import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/testing/covers.dart';
import 'package:patrol/patrol.dart';

import 'support/e2e_app.dart';

void main() {
  patrolTest('new-user 시나리오는 welcome 화면에 도착합니다', ($) async {
    covers(const Covers(exits: ['launch>welcome'], decisions: ['D50']));
    await launchApp($, flow: 'launch', scenario: 'new-user');

    await expectScreen($, ScreenIds.welcome);
  });
}
