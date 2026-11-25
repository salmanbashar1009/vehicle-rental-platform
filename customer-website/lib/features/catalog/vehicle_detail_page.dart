import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_router/jaspr_router.dart';

import '../../components/ui/ui_primitives.dart';
import '../../core/config/app_config.dart';
import '../../core/http/api_client.dart';
import '../../core/http/api_error.dart';
import '../../core/models/catalog_models.dart';

/// Vehicle Details page displaying full specifications and booking CTA.
@client
class VehicleDetailPage extends StatefulComponent {
  const VehicleDetailPage({required this.vehicleId, super.key});
  final String vehicleId;

  @override
  State<VehicleDetailPage> createState() => _VehicleDetailPageState();
}

class _VehicleDetailPageState extends State<VehicleDetailPage> {
  final ApiClient _api = ApiClient();
  VehicleDto? _vehicle;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _load();
    } else {
      _loading = false;
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final json = await _api.get('/public/catalog/vehicles/${component.vehicleId}')
          as Map<String, dynamic>;
      setState(() {
        _vehicle = VehicleDto.fromJson(json);
        _loading = false;
      });
    } on ApiError catch (e) {
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Unable to load vehicle details.';
        _loading = false;
      });
    }
  }

  @override
  Component build(BuildContext context) {
    return section(classes: 'vf-section', [
      Document.head(title: 'Vehicle Specifications | ${AppConfig.brandName}'),
      div(classes: 'vf-container', [
        if (_loading)
          div(classes: 'vf-card', [Component.text('Loading vehicle specifications...')])
        else if (_error != null)
          ErrorBanner(message: _error!, onRetry: _load)
        else if (_vehicle != null)
          div(classes: 'vf-card', [
            img(
              classes: 'vf-card__media',
              src: switch (_vehicle!.category.toLowerCase()) {
                'van' || 'minivan' || 'bus' => '/images/svc_tour.jpg',
                'truck' || 'cargo' || 'pickup' => '/images/svc_cargo.jpg',
                'suv' => '/images/svc_rental.jpg',
                _ => '/images/svc_corporate.jpg',
              },
              alt: '${_vehicle!.make} ${_vehicle!.model}',
              styles: Styles(margin: Margin.only(bottom: 18.px), radius: BorderRadius.circular(12.px)),
            ),
            StatusBadge(status: _vehicle!.status),
            h1([Component.text(_vehicle!.name)]),
            p(classes: 'vf-muted', [
              Component.text('${_vehicle!.make} ${_vehicle!.model} · ${_vehicle!.year} · ${_vehicle!.fuelType}'),
            ]),
            ul([
              li([Component.text('Passenger Capacity: ${_vehicle!.seatCapacity}')]),
              li([Component.text('Luggage Capacity: ${_vehicle!.luggageCapacity}')]),
              li([Component.text('Indicative Rate: ${_vehicle!.formattedDailyRate}')]),
              li([Component.text('Facilities: ${_vehicle!.facilities.join(', ')}')]),
            ]),
            if (_vehicle!.description != null) p([Component.text(_vehicle!.description!)]),
            div(styles: Styles(display: Display.flex, gap: Gap.all(12.px), margin: Margin.only(top: 16.px)), [
              Link(
                to: '/book?vehicle_id=${_vehicle!.id}',
                classes: 'vf-btn vf-btn--primary',
                children: [Component.text('Request This Vehicle')],
              ),
              Link(
                to: '/vehicles',
                classes: 'vf-btn vf-btn--outline',
                children: [Component.text('Back to Fleet')],
              ),
            ]),
          ]),
      ]),
    ]);
  }
}
