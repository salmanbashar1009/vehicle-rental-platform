import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

/// Guest customer contact inputs rendered when user is not signed in.
class BookingGuestContactSection extends StatelessComponent {
  const BookingGuestContactSection({
    required this.name,
    required this.email,
    required this.phone,
    required this.onNameChanged,
    required this.onEmailChanged,
    required this.onPhoneChanged,
    super.key,
  });

  final String name;
  final String email;
  final String phone;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<String> onEmailChanged;
  final ValueChanged<String> onPhoneChanged;

  @override
  Component build(BuildContext context) {
    return div(classes: 'vf-grid-3', [
      div(classes: 'vf-field', [
        label(classes: 'vf-label', htmlFor: 'bk-name', [Component.text('Your Name')]),
        input(
          id: 'bk-name',
          classes: 'vf-input',
          value: name,
          onInput: (val) => onNameChanged(val.toString()),
        ),
      ]),
      div(classes: 'vf-field', [
        label(classes: 'vf-label', htmlFor: 'bk-email', [Component.text('Email')]),
        input(
          id: 'bk-email',
          classes: 'vf-input',
          type: InputType.email,
          value: email,
          onInput: (val) => onEmailChanged(val.toString()),
        ),
      ]),
      div(classes: 'vf-field', [
        label(classes: 'vf-label', htmlFor: 'bk-phone', [Component.text('Phone')]),
        input(
          id: 'bk-phone',
          classes: 'vf-input',
          value: phone,
          onInput: (val) => onPhoneChanged(val.toString()),
        ),
      ]),
    ]);
  }
}
