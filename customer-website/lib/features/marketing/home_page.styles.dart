import 'package:jaspr/dom.dart';

/// Component-scoped CSS for Homepage executive hero showcase and trust metrics.
@css
List<StyleRule> get homePageStyles => [
  css('.vf-hero', [
    css('&').styles(
      color: Colors.white,
      padding: Padding.only(top: 64.px, bottom: 72.px),
      raw: {
        'background': 'linear-gradient(135deg, #09254A 0%, #0F3D7A 55%, #1654A8 100%)',
      },
    ),
    css('&__grid').styles(
      alignItems: AlignItems.center,
      display: Display.grid,
      gap: Gap.all(40.px),
      raw: {'grid-template-columns': '1fr'},
    ),
    css.media(MediaQuery.screen(minWidth: 960.px), [
      css('&__grid').styles(raw: {'grid-template-columns': '1.08fr 0.92fr'}),
    ]),
    css('h1').styles(
      color: Colors.white,
      fontSize: 2.75.rem,
      margin: Margin.only(top: 14.px, bottom: 16.px),
      raw: {'line-height': '1.12'},
    ),
    css('&__lead').styles(
      color: Color('#E2E8F0'),
      fontSize: 1.125.rem,
      margin: Margin.only(bottom: 28.px),
      maxWidth: 580.px,
    ),
    css('&__cta-row').styles(
      display: Display.flex,
      flexWrap: FlexWrap.wrap,
      gap: Gap.all(14.px),
    ),
    css('&__visual').styles(
      position: Position.relative(),
    ),
    css('&__image').styles(
      border: Border.all(color: Color('rgba(255, 255, 255, 0.2)'), width: 1.px),
      radius: BorderRadius.circular(18.px),
      width: 100.percent,
      raw: {
        'aspect-ratio': '16 / 10',
        'object-fit': 'cover',
        'box-shadow': '0 24px 48px rgba(0, 0, 0, 0.35)',
      },
    ),
    css('&__float-pill').styles(
      backgroundColor: Color('rgba(15, 23, 42, 0.85)'),
      border: Border.all(color: Color('rgba(255, 255, 255, 0.22)'), width: 1.px),
      color: Colors.white,
      fontSize: 0.8125.rem,
      fontWeight: FontWeight.w600,
      margin: Margin.only(top: 12.px),
      padding: Padding.symmetric(horizontal: 14.px, vertical: 10.px),
      radius: BorderRadius.circular(12.px),
      raw: {'backdrop-filter': 'blur(8px)'},
    ),
    css('&__metrics').styles(
      display: Display.grid,
      gap: Gap.all(16.px),
      margin: Margin.only(top: 48.px),
      raw: {'grid-template-columns': 'repeat(auto-fit, minmax(200px, 1fr))'},
    ),
    css('&__metric').styles(
      backgroundColor: Color('rgba(255, 255, 255, 0.09)'),
      border: Border.all(color: Color('rgba(255, 255, 255, 0.14)'), width: 1.px),
      padding: Padding.all(18.px),
      radius: BorderRadius.circular(14.px),
    ),
  ]),
];
