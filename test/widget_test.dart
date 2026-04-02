import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wx_login/main.dart';

void main() {
  testWidgets('renders social login guide page', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp(enableSdkBootstrap: false));

    expect(find.text('微信 / QQ 第三方登录 Demo'), findsOneWidget);
    expect(find.text('文章内容拆解'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('登录演示'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('登录演示'), findsOneWidget);
  });
}
