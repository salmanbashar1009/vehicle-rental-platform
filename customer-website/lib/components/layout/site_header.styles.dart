import 'package:jaspr/dom.dart';

/// Component-scoped styles for the site header and horizontal navigation bar.
@css
List<StyleRule> get siteHeaderStyles => [
  css('.vf-header', [
    css('&').styles(
      backgroundColor: Color('rgba(255, 255, 255, 0.96)'),
      border: Border.only(bottom: BorderSide(color: Color('var(--color-border-subtle)'), width: 1.px)),
      position: Position.sticky(top: 0.px),
      raw: {'backdrop-filter': 'blur(10px)'},
      zIndex: ZIndex(40),
    ),
    css('&__inner').styles(
      alignItems: AlignItems.center,
      display: Display.flex,
      flexWrap: FlexWrap.wrap,
      gap: Gap.all(16.px),
      justifyContent: JustifyContent.spaceBetween,
      minHeight: 74.px,
      padding: Padding.symmetric(vertical: 10.px),
    ),
    css('&__brand').styles(
      alignItems: AlignItems.center,
      color: Color('var(--color-primary-700)'),
      display: Display.inlineFlex,
      fontFamily: FontFamily('var(--font-display)'),
      fontSize: 1.25.rem,
      fontWeight: FontWeight.w800,
      gap: Gap.all(10.px),
      raw: {'letter-spacing': '-0.02em', 'flex-shrink': '0'},
    ),
    css('&__logo-mark').styles(
      alignItems: AlignItems.center,
      backgroundColor: Color('var(--color-primary-700)'),
      color: Colors.white,
      display: Display.inlineFlex,
      fontSize: 0.875.rem,
      fontWeight: FontWeight.w800,
      height: 36.px,
      justifyContent: JustifyContent.center,
      radius: BorderRadius.circular(10.px),
      width: 36.px,
    ),
    css('&__nav').styles(
      alignItems: AlignItems.center,
      display: Display.flex,
      flexWrap: FlexWrap.wrap,
      gap: Gap.all(24.px),
      justifyContent: JustifyContent.center,
    ),
    css('&__link').styles(
      color: Color('var(--color-text-secondary)'),
      fontSize: 0.9375.rem,
      fontWeight: FontWeight.w600,
      padding: Padding.symmetric(horizontal: 6.px, vertical: 6.px),
      radius: BorderRadius.circular(8.px),
      raw: {'white-space': 'nowrap', 'transition': 'color 0.15s ease, background-color 0.15s ease'},
    ),
    css('&__link:hover').styles(
      backgroundColor: Color('var(--color-primary-100)'),
      color: Color('var(--color-primary-700)'),
    ),
    css('&__actions').styles(
      alignItems: AlignItems.center,
      display: Display.flex,
      gap: Gap.all(10.px),
      raw: {'flex-shrink': '0'},
    ),
  ]),
];
