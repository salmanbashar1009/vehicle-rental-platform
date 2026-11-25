import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../../components/ui/catalog_cards.dart';
import '../../components/ui/ui_primitives.dart';
import '../../core/config/app_config.dart';
import '../../core/http/api_client.dart';
import '../../core/http/api_error.dart';
import '../../core/models/catalog_models.dart';
import '../../core/seo/seo_service.dart';

/// Filterable Vehicle Catalogue page backed by /api/v1/public/catalog/vehicles.
@client
class VehiclesPage extends StatefulComponent {
  const VehiclesPage({super.key});

  @override
  State<VehiclesPage> createState() => _VehiclesPageState();
}

class _VehiclesPageState extends State<VehiclesPage> {
  final ApiClient _api = ApiClient();
  List<VehicleDto> _vehicles = [];
  bool _loading = true;
  String? _error;
  String _category = '';
  String _minSeats = '';
  String _facility = '';

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _loadVehicles();
    } else {
      _loading = false;
    }
  }

  Future<void> _loadVehicles() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final query = <String, String>{
        if (_category.isNotEmpty) 'category': _category,
        if (_minSeats.isNotEmpty) 'min_seats': _minSeats,
        if (_facility.isNotEmpty) 'facility': _facility,
      };
      final data = await _api.get('/public/catalog/vehicles', query: query) as Map<String, dynamic>;
      final items = (data['items'] as List<dynamic>? ?? const [])
          .map((e) => VehicleDto.fromJson(e as Map<String, dynamic>))
          .toList();
      setState(() {
        _vehicles = items;
        _loading = false;
      });
    } on ApiError catch (e) {
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Unable to reach fleet catalogue API right now.';
        _loading = false;
      });
    }
  }

  @override
  Component build(BuildContext context) {
    final seo = SeoMetadata(
      title: 'Vehicle Catalogue',
      description: 'Filter chauffeur-driven sedans, SUVs, vans, buses, and cargo trucks by capacity, facilities, and availability.',
      path: '/vehicles',
    );
    return section(classes: 'vf-section', [
      Document.head(title: '${seo.title} | ${AppConfig.brandName}', children: seo.toHeadComponents()),
      div(classes: 'vf-container', [
        h1([Component.text('Vehicle Catalogue')]),
        div(classes: 'vf-card vf-grid-4', styles: Styles(margin: Margin.only(bottom: 24.px)), [
          div(classes: 'vf-field', [
            label(classes: 'vf-label', htmlFor: 'flt-cat', [Component.text('Category')]),
            select(
              id: 'flt-cat',
              classes: 'vf-select',
              onChange: (vals) {
                _category = vals.isNotEmpty ? vals.first : '';
                _loadVehicles();
              },
              [
                option(value: '', selected: _category == '', [Component.text('All Categories')]),
                option(value: 'sedan', selected: _category == 'sedan', [Component.text('Sedan')]),
                option(value: 'suv', selected: _category == 'suv', [Component.text('SUV')]),
                option(value: 'van', selected: _category == 'van', [Component.text('Van / Hiace')]),
                option(value: 'cargo', selected: _category == 'cargo', [Component.text('Cargo / Truck')]),
              ],
            ),
          ]),
          div(classes: 'vf-field', [
            label(classes: 'vf-label', htmlFor: 'flt-seats', [Component.text('Min Seats')]),
            select(
              id: 'flt-seats',
              classes: 'vf-select',
              onChange: (vals) {
                _minSeats = vals.isNotEmpty ? vals.first : '';
                _loadVehicles();
              },
              [
                option(value: '', [Component.text('Any')]),
                option(value: '4', [Component.text('4+ Seats')]),
                option(value: '7', [Component.text('7+ Seats')]),
                option(value: '12', [Component.text('12+ Seats')]),
              ],
            ),
          ]),
          div(classes: 'vf-field', [
            label(classes: 'vf-label', htmlFor: 'flt-fac', [Component.text('Facility')]),
            select(
              id: 'flt-fac',
              classes: 'vf-select',
              onChange: (vals) {
                _facility = vals.isNotEmpty ? vals.first : '';
                _loadVehicles();
              },
              [
                option(value: '', [Component.text('Any Facility')]),
                option(value: 'ac', [Component.text('Air Conditioning')]),
                option(value: 'wifi', [Component.text('Onboard Wi-Fi')]),
              ],
            ),
          ]),
          div(styles: Styles(display: Display.flex, alignItems: AlignItems.end, margin: Margin.only(bottom: 16.px)), [
            button(
              classes: 'vf-btn vf-btn--outline',
              onClick: () {
                _category = '';
                _minSeats = '';
                _facility = '';
                _loadVehicles();
              },
              [Component.text('Reset Filters')],
            ),
          ]),
        ]),
        if (_loading)
          div(classes: 'vf-card', [Component.text('Loading fleet availability...')])
        else if (_error != null)
          ErrorBanner(message: _error!, onRetry: _loadVehicles)
        else if (_vehicles.isEmpty)
          EmptyState(
            title: 'No matching vehicles found',
            message: 'Try clearing filters or submit a custom booking request.',
            action: button(classes: 'vf-btn vf-btn--primary', onClick: _loadVehicles, [Component.text('Refresh')]),
          )
        else
          div(classes: 'vf-grid-3', [for (final v in _vehicles) VehicleCard(vehicle: v)]),
      ]),
    ]);
  }
}
