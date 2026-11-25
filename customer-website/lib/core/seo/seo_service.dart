import 'dart:convert';

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../config/app_config.dart';

/// Builds per-page SEO metadata, Open Graph tags, canonical URL, and JSON-LD.
class SeoMetadata {
  const SeoMetadata({
    required this.title,
    required this.description,
    required this.path,
    this.ogType = 'website',
    this.jsonLd,
    this.noIndex = false,
  });

  final String title;
  final String description;
  final String path;
  final String ogType;
  final Map<String, dynamic>? jsonLd;
  final bool noIndex;

  String get canonicalUrl => '${AppConfig.siteUrl}$path';

  List<Component> toHeadComponents() {
    final nodes = <Component>[
      meta(name: 'description', content: description),
      link(rel: 'canonical', href: canonicalUrl),
      meta(attributes: {'property': 'og:title', 'content': '$title | ${AppConfig.brandName}'}),
      meta(attributes: {'property': 'og:description', 'content': description}),
      meta(attributes: {'property': 'og:type', 'content': ogType}),
      meta(attributes: {'property': 'og:url', 'content': canonicalUrl}),
      meta(name: 'twitter:card', content: 'summary_large_image'),
      if (noIndex) meta(name: 'robots', content: 'noindex, nofollow'),
    ];
    if (jsonLd != null) {
      nodes.add(
        script(
          attributes: {'type': 'application/ld+json'},
          content: jsonEncode(jsonLd),
        ),
      );
    }
    return nodes;
  }

  static Map<String, dynamic> organizationJsonLd() => {
    '@context': 'https://schema.org',
    '@type': 'AutoRental',
    'name': AppConfig.brandName,
    'url': AppConfig.siteUrl,
    'telephone': AppConfig.supportPhone,
    'email': AppConfig.supportEmail,
    'description': 'Chauffeur-driven vehicle rentals, airport transfers, tours, events, and cargo transport.',
  };

  static Map<String, dynamic> serviceJsonLd({
    required String name,
    required String description,
    required String slug,
  }) => {
    '@context': 'https://schema.org',
    '@type': 'Service',
    'name': name,
    'description': description,
    'provider': {'@type': 'Organization', 'name': AppConfig.brandName},
    'url': '${AppConfig.siteUrl}/services/$slug',
  };
}

/// Generates crawler-friendly /robots.txt and /sitemap.xml bodies.
class CrawlerFiles {
  const CrawlerFiles._();

  static String robotsTxt() => [
    'User-agent: *',
    'Allow: /',
    'Disallow: /dashboard',
    'Disallow: /login',
    'Disallow: /register',
    'Disallow: /booking/confirmation',
    'Sitemap: ${AppConfig.siteUrl}/sitemap.xml',
  ].join('\n');

  static String sitemapXml({
    required List<String> serviceSlugs,
    required List<String> vehicleIds,
  }) {
    final urls = <String>[
      '/',
      '/about',
      '/services',
      '/vehicles',
      '/book',
      '/contact',
      '/faq',
      '/legal/terms',
      '/legal/privacy',
      '/legal/cancellation',
      for (final slug in serviceSlugs) '/services/$slug',
      for (final id in vehicleIds) '/vehicles/$id',
    ];
    final entries = urls
        .map((u) => '  <url><loc>${AppConfig.siteUrl}$u</loc><changefreq>weekly</changefreq></url>')
        .join('\n');
    return '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n'
        '$entries\n'
        '</urlset>\n';
  }
}
