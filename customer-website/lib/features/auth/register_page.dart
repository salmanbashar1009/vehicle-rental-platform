import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_router/jaspr_router.dart';

import '../../components/ui/ui_primitives.dart';
import '../../core/auth/auth_session.dart';
import '../../core/config/app_config.dart';
import '../../core/http/api_error.dart';

/// Customer Registration page.
@client
class RegisterPage extends StatefulComponent {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  String _fullName = '';
  String _email = '';
  String _phone = '';
  String _password = '';
  bool _submitting = false;
  String? _error;

  Future<void> _register() async {
    if (_password.length < 10) {
      setState(() => _error = 'Password must be at least 10 characters.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await CustomerAuthStore.instance.register(
        fullName: _fullName,
        email: _email,
        phone: _phone,
        password: _password,
      );
      if (mounted) Router.of(context).push('/dashboard');
    } on ApiError catch (e) {
      setState(() {
        _error = e.message;
        _submitting = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Unable to create account right now.';
        _submitting = false;
      });
    }
  }

  @override
  Component build(BuildContext context) {
    return section(classes: 'vf-section', [
      Document.head(title: 'Create Account | ${AppConfig.brandName}'),
      div(classes: 'vf-container', styles: Styles(maxWidth: 500.px), [
        div(classes: 'vf-card', [
          h1([Component.text('Create Customer Account')]),
          if (_error != null) ErrorBanner(message: _error!),
          div(classes: 'vf-field', [
            label(classes: 'vf-label', [Component.text('Full Name')]),
            input(classes: 'vf-input', value: _fullName, onInput: (v) => _fullName = v.toString()),
          ]),
          div(classes: 'vf-field', [
            label(classes: 'vf-label', [Component.text('Email')]),
            input(classes: 'vf-input', type: InputType.email, value: _email, onInput: (v) => _email = v.toString()),
          ]),
          div(classes: 'vf-field', [
            label(classes: 'vf-label', [Component.text('Phone Number')]),
            input(classes: 'vf-input', value: _phone, onInput: (v) => _phone = v.toString()),
          ]),
          div(classes: 'vf-field', [
            label(classes: 'vf-label', [Component.text('Password (min 10 chars)')]),
            input(classes: 'vf-input', type: InputType.password, value: _password, onInput: (v) => _password = v.toString()),
          ]),
          button(
            classes: 'vf-btn vf-btn--primary',
            disabled: _submitting,
            onClick: _register,
            [Component.text(_submitting ? 'Creating Account...' : 'Register')],
          ),
        ]),
      ]),
    ]);
  }
}
