import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../../core/config/app_config.dart';
import '../../core/seo/seo_service.dart';

/// Interactive Contact Us page with accessible inquiry validation.
@client
class ContactPage extends StatefulComponent {
  const ContactPage({super.key});

  @override
  State<ContactPage> createState() => _ContactPageState();
}

class _ContactPageState extends State<ContactPage> {
  String _name = '';
  String _email = '';
  String _message = '';
  bool _submitted = false;
  String? _error;

  void _submit() {
    if (_name.trim().length < 2 || !_email.contains('@') || _message.trim().length < 10) {
      setState(() => _error = 'Please enter your name, a valid email, and a short message.');
      return;
    }
    setState(() {
      _error = null;
      _submitted = true;
    });
  }

  @override
  Component build(BuildContext context) {
    final seo = SeoMetadata(
      title: 'Contact Us',
      description: 'Reach VeloFleet dispatch and customer support for corporate accounts, events, and custom bookings.',
      path: '/contact',
    );
    return section(classes: 'vf-section', [
      Document.head(title: '${seo.title} | ${AppConfig.brandName}', children: seo.toHeadComponents()),
      div(classes: 'vf-container vf-grid-2', [
        div(classes: 'vf-card', [
          h1([Component.text('Contact Dispatch & Support')]),
          p(classes: 'vf-muted', [Component.text('24/7 operational support for active trips and corporate enquiries.')]),
          p([strong([Component.text('Phone: ')]), Component.text(AppConfig.supportPhone)]),
          p([strong([Component.text('Email: ')]), Component.text(AppConfig.supportEmail)]),
        ]),
        div(classes: 'vf-card', [
          h2([Component.text('Send a Message')]),
          if (_submitted)
            div(classes: 'vf-badge vf-badge--success', [
              Component.text('Inquiry received. Our team will respond shortly.'),
            ])
          else ...[
            if (_error != null)
              p(styles: Styles(color: Color('var(--color-error-fg)')), [Component.text(_error!)]),
            div(classes: 'vf-field', [
              label(classes: 'vf-label', htmlFor: 'contact-name', [Component.text('Full Name')]),
              input(
                id: 'contact-name',
                classes: 'vf-input',
                value: _name,
                onInput: (val) => _name = val.toString(),
              ),
            ]),
            div(classes: 'vf-field', [
              label(classes: 'vf-label', htmlFor: 'contact-email', [Component.text('Email Address')]),
              input(
                id: 'contact-email',
                classes: 'vf-input',
                type: InputType.email,
                value: _email,
                onInput: (val) => _email = val.toString(),
              ),
            ]),
            div(classes: 'vf-field', [
              label(classes: 'vf-label', htmlFor: 'contact-msg', [Component.text('Message')]),
              textarea(
                id: 'contact-msg',
                classes: 'vf-textarea',
                onInput: (val) => _message = val,
                [Component.text(_message)],
              ),
            ]),
            button(classes: 'vf-btn vf-btn--primary', onClick: _submit, [Component.text('Send Inquiry')]),
          ],
        ]),
      ]),
    ]);
  }
}
