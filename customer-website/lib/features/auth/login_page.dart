import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_router/jaspr_router.dart';

import '../../components/ui/ui_primitives.dart';
import '../../core/auth/auth_session.dart';
import '../../core/config/app_config.dart';
import '../../core/http/api_error.dart';
import '../../core/web/browser_nav.dart';

/// Customer Sign-In page.
@client
class LoginPage extends StatefulComponent {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  String _identifier = '';
  String _password = '';
  bool _submitting = false;
  String? _error;

  Future<void> _login() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await CustomerAuthStore.instance.login(identifier: _identifier, password: _password);
      if (mounted) navigateTo(context, '/dashboard');
    } on ApiError catch (e) {
      setState(() {
        _error = e.message;
        _submitting = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Unable to sign in right now.';
        _submitting = false;
      });
    }
  }

  @override
  Component build(BuildContext context) {
    return section(classes: 'vf-section', [
      Document.head(title: 'Customer Sign In | ${AppConfig.brandName}'),
      div(classes: 'vf-container', styles: Styles(maxWidth: 480.px), [
        div(classes: 'vf-card', [
          h1([Component.text('Customer Sign In')]),
          p(classes: 'vf-muted', [Component.text('Manage reservations, quotations, and active trip tracking.')]),
          if (_error != null) ErrorBanner(message: _error!),
          div(classes: 'vf-field', [
            label(classes: 'vf-label', [Component.text('Email or Phone')]),
            input(classes: 'vf-input', value: _identifier, onInput: (v) => _identifier = v.toString()),
          ]),
          div(classes: 'vf-field', [
            label(classes: 'vf-label', [Component.text('Password')]),
            input(classes: 'vf-input', type: InputType.password, value: _password, onInput: (v) => _password = v.toString()),
          ]),
          button(
            classes: 'vf-btn vf-btn--primary',
            disabled: _submitting,
            onClick: _login,
            [Component.text(_submitting ? 'Signing In...' : 'Sign In')],
          ),
          p(styles: Styles(margin: Margin.only(top: 16.px)), [
            Component.text('New customer? '),
            Link(to: '/register', children: [Component.text('Create an account')]),
          ]),
        ]),
      ]),
    ]);
  }
}
