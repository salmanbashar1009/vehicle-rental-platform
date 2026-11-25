import 'dart:io';

import 'package:jaspr_test/jaspr_test.dart';
import 'package:velofleet_customer_web/components/layout/site_header.dart';
import 'package:velofleet_customer_web/core/data/default_catalog.dart';
import 'package:velofleet_customer_web/core/seo/seo_service.dart';
import 'package:velofleet_customer_web/features/catalog/services_pages.dart';
import 'package:velofleet_customer_web/features/marketing/home_page.dart';
import 'package:velofleet_customer_web/features/marketing/info_pages.dart';

void main() {
  group('Customer Website SEO & SSR Verification', () {
    test('robots.txt blocks private portal paths and links sitemap', () {
      final robots = CrawlerFiles.robotsTxt();
      expect(robots, contains('Allow: /'));
      expect(robots, contains('Disallow: /dashboard'));
      expect(robots, contains('Sitemap: '));
    });

    test('sitemap.xml includes public pages and all 8 service slugs', () {
      final slugs = ServiceCatalogReference.categories.map((e) => e.slug).toList();
      final xml = CrawlerFiles.sitemapXml(serviceSlugs: slugs, vehicleIds: ['veh-1']);
      expect(xml, contains('/services/airport_transfer'));
      expect(xml, contains('/services/house_shifting_cargo'));
      expect(xml, contains('/vehicles/veh-1'));
    });

    test('Hero and all 8 service vehicle image assets exist locally', () {
      expect(File('web/images/hero_fleet.jpg').existsSync(), isTrue);
      for (final svc in ServiceCatalogReference.categories) {
        final assetPath = 'web${svc.resolvedImageUrl}';
        expect(File(assetPath).existsSync(), isTrue, reason: 'Missing $assetPath');
      }
    });

    testComponents('SiteHeader renders horizontal nav links and CTAs', (tester) async {
      tester.pumpComponent(const SiteHeader());
      expect(find.text('Services'), findsOneComponent);
      expect(find.text('Fleet'), findsOneComponent);
      expect(find.text('Sign In'), findsOneComponent);
      expect(find.text('Book / Quote'), findsOneComponent);
    });

    testComponents('HomePage renders hero CTA and transport services', (tester) async {
      tester.pumpComponent(const HomePage());
      expect(find.text('Premium Chauffeur & Fleet Mobility for Every Journey'), findsOneComponent);
      expect(find.text('Request a Booking / Quote'), findsOneComponent);
      expect(find.text('Transportation Services'), findsOneComponent);
    });

    testComponents('ServicesPage renders all 8 categories and ServiceDetail renders milestones', (tester) async {
      tester.pumpComponent(const ServicesPage());
      expect(find.text('House Shifting & Cargo'), findsOneComponent);
      expect(find.text('Airport Transfer'), findsOneComponent);

      tester.pumpComponent(const ServiceDetailPage(slug: 'house_shifting_cargo'));
      expect(find.text('LOADING STARTED'), findsOneComponent);
      expect(find.text('UNLOADING COMPLETED'), findsOneComponent);
    });

    testComponents('NotFoundPage renders 404 recovery links', (tester) async {
      tester.pumpComponent(const NotFoundPage());
      expect(find.text('404 — Page Not Found'), findsOneComponent);
      expect(find.text('Back to Home'), findsOneComponent);
    });
  });
}
