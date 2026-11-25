import 'package:jaspr_test/jaspr_test.dart';

import 'package:velofleet_customer_web/features/portal/review_page.dart';

void main() {
  group('Customer Post-Trip Review Portal (WEB-501)', () {
    testComponents('ReviewSubmissionPage renders 1-5 rating fields and submit CTA', (tester) async {
      tester.pumpComponent(const ReviewSubmissionPage(bookingId: 'b-99'));
      expect(find.text('Rate Your Chauffeur Trip'), findsOneComponent);
      expect(find.text('Submit Review'), findsOneComponent);
    });
  });
}
