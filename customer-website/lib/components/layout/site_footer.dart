import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_router/jaspr_router.dart';

import '../../core/config/app_config.dart';

/// Footer shared across all pages with legal, service, and contact links.
class SiteFooter extends StatelessComponent {
  const SiteFooter({super.key});

  @override
  Component build(BuildContext context) {
    return footer(classes: 'vf-footer', [
      div(classes: 'vf-container vf-grid-4', [
        div([
          h3([Component.text(AppConfig.brandName)]),
          p(classes: 'vf-footer__muted', [
            Component.text(
              'Chauffeur-driven passenger, corporate, event, airport, and cargo mobility.',
            ),
          ]),
        ]),
        div([
          h4([Component.text('Explore')]),
          ul(classes: 'vf-footer__list', [
            li([Link(to: '/services', children: [Component.text('Services')])]),
            li([Link(to: '/vehicles', children: [Component.text('Vehicle Catalogue')])]),
            li([Link(to: '/book', children: [Component.text('Request a Quote')])]),
            li([Link(to: '/dashboard', children: [Component.text('Customer Portal')])]),
          ]),
        ]),
        div([
          h4([Component.text('Company')]),
          ul(classes: 'vf-footer__list', [
            li([Link(to: '/about', children: [Component.text('About Us')])]),
            li([Link(to: '/faq', children: [Component.text('FAQs')])]),
            li([Link(to: '/contact', children: [Component.text('Contact Support')])]),
          ]),
        ]),
        div([
          h4([Component.text('Policies & Contact')]),
          ul(classes: 'vf-footer__list', [
            li([Link(to: '/legal/terms', children: [Component.text('Terms & Conditions')])]),
            li([Link(to: '/legal/privacy', children: [Component.text('Privacy Policy')])]),
            li([Link(to: '/legal/cancellation', children: [Component.text('Cancellation Policy')])]),
            li([Component.text(AppConfig.supportPhone)]),
          ]),
        ]),
      ]),
      div(classes: 'vf-container vf-footer__bottom', [
        Component.text('© 2026 ${AppConfig.brandName}. All rights reserved.'),
      ]),
    ]);
  }

  @css
  static List<StyleRule> get styles => [
    css('.vf-footer', [
      css('&').styles(
        backgroundColor: Color('var(--color-primary-900)'),
        color: Colors.white,
        margin: Margin.only(top: 48.px),
        padding: Padding.only(top: 56.px, bottom: 28.px),
      ),
      css('h3, h4').styles(color: Colors.white, margin: Margin.only(bottom: 14.px)),
      css('a').styles(color: Color('#E2E8F0')),
      css('&__muted').styles(color: Color('#CBD5E1'), fontSize: 0.9375.rem),
      css('&__list').styles(
        display: Display.flex,
        flexDirection: FlexDirection.column,
        gap: Gap.all(10.px),
        listStyle: ListStyle.none,
        margin: Margin.zero,
        padding: Padding.zero,
      ),
      css('&__bottom').styles(
        border: Border.only(top: BorderSide(color: Color('rgba(255,255,255,0.16)'), width: 1.px)),
        color: Color('#CBD5E1'),
        fontSize: 0.875.rem,
        margin: Margin.only(top: 36.px),
        padding: Padding.only(top: 22.px),
      ),
    ]),
  ];
}
