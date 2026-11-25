/// Server entrypoint for VeloFleet Customer Website (SSR + SEO + Shelf).
library;

import 'dart:io';

import 'package:jaspr/dom.dart';
import 'package:jaspr/server.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

import 'app.dart';
import 'core/data/default_catalog.dart';
import 'core/seo/seo_service.dart';
import 'main.server.options.dart';

void main() async {
  Jaspr.initializeApp(options: defaultServerOptions);

  final router = Router();

  router.get('/robots.txt', (Request _) {
    return Response.ok(
      CrawlerFiles.robotsTxt(),
      headers: {'content-type': 'text/plain; charset=utf-8'},
    );
  });

  router.get('/sitemap.xml', (Request _) {
    final slugs = ServiceCatalogReference.categories.map((e) => e.slug).toList();
    return Response.ok(
      CrawlerFiles.sitemapXml(serviceSlugs: slugs, vehicleIds: const []),
      headers: {'content-type': 'application/xml; charset=utf-8'},
    );
  });

  router.mount(
    '/',
    serveApp((request, render) {
      return render(
        Document(
          title: 'VeloFleet | Chauffeur-Driven Vehicle Rentals',
          lang: 'en',
          head: [
            meta(name: 'viewport', content: 'width=device-width, initial-scale=1.0'),
            link(rel: 'stylesheet', href: '/styles/tokens.css'),
            link(rel: 'stylesheet', href: '/styles/primitives.css'),
            link(
              rel: 'stylesheet',
              href: 'https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&family=JetBrains+Mono:wght@500;600&family=Plus+Jakarta+Sans:wght@600;700;800&display=swap',
            ),
          ],
          body: const App(),
        ),
      );
    }),
  );

  final handler = const Pipeline().addMiddleware(logRequests()).addHandler(router.call);
  final reloadLock = activeReloadLock = Object();
  final server = await shelf_io.serve(handler, InternetAddress.anyIPv4, 8080, shared: true);

  if (reloadLock != activeReloadLock) {
    await server.close();
    return;
  }
  await activeServer?.close();
  activeServer = server;
}

HttpServer? activeServer;
Object? activeReloadLock;
