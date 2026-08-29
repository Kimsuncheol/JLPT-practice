import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt_practice/app/app.dart';

void main() {
  test('stable system insets preserve landscape cutout padding', () {
    const landscapeInsets = EdgeInsets.fromLTRB(44, 0, 28, 12);
    const mediaQuery = MediaQueryData(
      size: Size(844, 390),
      padding: landscapeInsets,
      viewPadding: landscapeInsets,
    );

    final stable = mediaQueryWithStableSystemInsets(mediaQuery, 20);

    expect(stable.padding, const EdgeInsets.fromLTRB(44, 0, 28, 20));
    expect(stable.viewPadding, const EdgeInsets.fromLTRB(44, 0, 28, 20));
  });

  test('right navigation bar reveal does not change safe content width', () {
    const hiddenNavigationBar = MediaQueryData(
      size: Size(844, 390),
      padding: EdgeInsets.zero,
      viewPadding: EdgeInsets.only(right: 48),
    );
    const visibleNavigationBar = MediaQueryData(
      size: Size(844, 390),
      padding: EdgeInsets.only(right: 48),
      viewPadding: EdgeInsets.only(right: 48),
    );

    final hidden = mediaQueryWithStableSystemInsets(hiddenNavigationBar, 0);
    final visible = mediaQueryWithStableSystemInsets(visibleNavigationBar, 0);

    expect(hidden.padding.right, 48);
    expect(visible.padding.right, hidden.padding.right);
    expect(
      hidden.size.width - hidden.padding.horizontal,
      visible.size.width - visible.padding.horizontal,
    );
  });
}
