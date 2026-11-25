import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_router/jaspr_router.dart';

import '../../core/config/app_config.dart';
import 'site_header.styles.dart';

/// Top sticky navigation header shared across public and portal pages.
class SiteHeader extends StatelessComponent {
  const SiteHeader({super.key});

  @override
  Component build(BuildContext context) {
    return header(classes: 'vf-header', [
      div(classes: 'vf-container vf-header__inner', [
        Link(
          to: '/',
          classes: 'vf-header__brand',
          children: [
            span(classes: 'vf-header__logo-mark', [Component.text('VF')]),
            span(classes: 'vf-header__brand-name', [Component.text(AppConfig.brandName)]),
          ],
        ),
        nav(classes: 'vf-header__nav', attributes: {'aria-label': 'Primary Navigation'}, [
          Link(to: '/services', classes: 'vf-header__link', children: [Component.text('Services')]),
          Link(to: '/vehicles', classes: 'vf-header__link', children: [Component.text('Fleet')]),
          Link(to: '/about', classes: 'vf-header__link', children: [Component.text('About')]),
          Link(to: '/faq', classes: 'vf-header__link', children: [Component.text('FAQ')]),
          Link(to: '/contact', classes: 'vf-header__link', children: [Component.text('Contact')]),
        ]),
        div(classes: 'vf-header__actions', [
          Link(to: '/login', classes: 'vf-btn vf-btn--outline', children: [Component.text('Sign In')]),
          Link(to: '/book', classes: 'vf-btn vf-btn--primary', children: [Component.text('Book / Quote')]),
        ]),
      ]),
    ]);
  }

  @css
  static List<StyleRule> get styles => siteHeaderStyles;
}
