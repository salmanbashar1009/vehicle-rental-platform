import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

/// Reusable ordered stops editor for BookingWizardPage.
class BookingStopsSection extends StatelessComponent {
  const BookingStopsSection({
    required this.pickupAddress,
    required this.destinationAddress,
    required this.waypoints,
    required this.onPickupChanged,
    required this.onDestinationChanged,
    required this.onAddWaypoint,
    required this.onRemoveWaypoint,
    required this.onUpdateWaypoint,
    super.key,
  });

  final String pickupAddress;
  final String destinationAddress;
  final List<String> waypoints;
  final ValueChanged<String> onPickupChanged;
  final ValueChanged<String> onDestinationChanged;
  final VoidCallback onAddWaypoint;
  final ValueChanged<int> onRemoveWaypoint;
  final void Function(int index, String value) onUpdateWaypoint;

  @override
  Component build(BuildContext context) {
    return div([
      div(classes: 'vf-field', [
        label(classes: 'vf-label', htmlFor: 'bk-pickup', [Component.text('Pickup Address')]),
        input(
          id: 'bk-pickup',
          classes: 'vf-input',
          value: pickupAddress,
          onInput: (v) => onPickupChanged(v.toString()),
        ),
      ]),
      for (var i = 0; i < waypoints.length; i++)
        div(classes: 'vf-field', [
          label(classes: 'vf-label', [Component.text('Intermediate Stop ${i + 1}')]),
          div(styles: Styles(display: Display.flex, gap: Gap.all(8.px)), [
            input(
              classes: 'vf-input',
              value: waypoints[i],
              onInput: (v) => onUpdateWaypoint(i, v.toString()),
            ),
            button(
              classes: 'vf-btn vf-btn--outline',
              onClick: () => onRemoveWaypoint(i),
              [Component.text('Remove')],
            ),
          ]),
        ]),
      button(
        classes: 'vf-btn vf-btn--outline',
        onClick: onAddWaypoint,
        [Component.text('+ Add Intermediate Stop')],
      ),
      div(classes: 'vf-field', styles: Styles(margin: Margin.only(top: 16.px)), [
        label(classes: 'vf-label', htmlFor: 'bk-dest', [Component.text('Destination Address')]),
        input(
          id: 'bk-dest',
          classes: 'vf-input',
          value: destinationAddress,
          onInput: (v) => onDestinationChanged(v.toString()),
        ),
      ]),
    ]);
  }
}
