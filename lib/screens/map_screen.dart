import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data.dart';
import '../models.dart';
import '../store.dart';
import '../widgets.dart';
import 'place_screen.dart';


Future<Position> locateUser() async {
  if (!await Geolocator.isLocationServiceEnabled()) throw 'Location services are turned off.';
  var perm = await Geolocator.checkPermission();
  if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
  if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) throw 'Location permission was denied.';
  return Geolocator.getCurrentPosition().timeout(const Duration(seconds: 12), onTimeout: () => throw 'Could not get your location in time.');
}

Future<void> openExternalDirections(Place p, {LatLng? from}) async {
  final uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${p.lat},${p.lng}${from == null ? '' : '&origin=${from.latitude},${from.longitude}'}&travelmode=walking');
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

const _tiles = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
const _ua = 'com.example.city_guide';

/// Directions from the current location: draws a line, shows the distance and offers turn-by-turn in Google Maps.
class DirectionsController {
  LatLng? me;
  String message = '';
  bool busy = false;

  Future<void> run(Place p, MapController map, VoidCallback refresh) async {
    busy = true;
    message = 'Finding your location…';
    refresh();
    try {
      final pos = await locateUser();
      me = LatLng(pos.latitude, pos.longitude);
      final km = const Distance().as(LengthUnit.Kilometer, me!, LatLng(p.lat, p.lng));
      final m = const Distance().as(LengthUnit.Meter, me!, LatLng(p.lat, p.lng)).round();
      message = '📍 About ${m < 1000 ? '$m m' : '${(m / 1000).toStringAsFixed(1)} km'} in a straight line (≈ ${(km / 5 * 60).round().clamp(1, 99999)} min on foot).';
      map.fitCamera(CameraFit.bounds(bounds: LatLngBounds.fromPoints([me!, LatLng(p.lat, p.lng)]), padding: const EdgeInsets.all(48)));
    } catch (e) {
      me = null;
      message = '$e';
    }
    busy = false;
    refresh();
  }
}

Marker _youMarker(LatLng p) => Marker(point: p, width: 24, height: 24, child: Container(decoration: BoxDecoration(color: Colors.blue, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3))));

class MapScreen extends StatefulWidget {
  final AppState state;
  final String? initialCity;
  final bool standalone;
  const MapScreen({super.key, required this.state, this.initialCity, this.standalone = false});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late String cityId = widget.initialCity ?? widget.state.lastCity;
  String cat = 'all';
  Place? selected;
  final map = MapController();
  final dir = DirectionsController();

  City get city => cityOf(cityId);

  /// Make sure cityId points at a real city once the catalog has loaded.
  void _ensureCity() {
    if (cities.isNotEmpty && !cities.any((c) => c.id == cityId)) cityId = cities.first.id;
  }
  List<Place> get shown => places.where((p) => p.city == cityId && (cat == 'all' || p.cat == cat)).toList();

  void fit() {
    final pts = shown.map((p) => LatLng(p.lat, p.lng)).toList();
    if (pts.isEmpty) return;
    map.fitCamera(CameraFit.bounds(bounds: LatLngBounds.fromPoints(pts), padding: const EdgeInsets.all(48), maxZoom: 14));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListenableBuilder(listenable: widget.state, builder: (context, _) => _content(context, cs));
  }

  Widget _content(BuildContext context, ColorScheme cs) {
    if (cities.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (widget.state.initializing) const CircularProgressIndicator() else const Icon(Icons.cloud_off, size: 40),
            const SizedBox(height: 12),
            Text(widget.state.initializing ? 'Loading cities…' : 'Could not load cities.\nThe server may be waking up.', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            if (!widget.state.initializing) FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(140, 44)), onPressed: widget.state.loadCities, child: const Text('Retry')),
          ]),
        ),
      );
    }
    _ensureCity();
    final sel = selected;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Row(children: [
          if (!widget.standalone) Text('Map', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          if (!widget.standalone) const SizedBox(width: 16),
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: cityId, isExpanded: true,
              decoration: const InputDecoration(labelText: 'City', isDense: true),
              items: cities.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
              onChanged: (v) {
                if (v == null) return;
                setState(() {
                  cityId = v;
                  selected = null;
                  dir.me = null;
                  dir.message = '';
                });
                widget.state.lastCity = v;
                WidgetsBinding.instance.addPostFrameCallback((_) => fit());
              },
            ),
          ),
        ]),
      ),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(children: [
          for (final c in [const Category('all', 'All', ''), ...categories])
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(label: Text('${c.icon} ${c.label}'.trim()), selected: cat == c.id, onSelected: (_) {
                setState(() {
                  cat = c.id;
                  selected = null;
                });
                WidgetsBinding.instance.addPostFrameCallback((_) => fit());
              }),
            ),
        ]),
      ),
      Expanded(
        child: FlutterMap(
          mapController: map,
          options: MapOptions(
            initialCenter: LatLng(city.lat, city.lng), initialZoom: 12,
            onMapReady: fit,
            onTap: (_, __) => setState(() => selected = null),
          ),
          children: [
            TileLayer(urlTemplate: _tiles, userAgentPackageName: _ua),
            if (dir.me != null && sel != null) PolylineLayer(polylines: [Polyline(points: [dir.me!, LatLng(sel.lat, sel.lng)], strokeWidth: 4, color: cs.secondary)]),
            MarkerLayer(markers: [
              for (final p in shown)
                Marker(
                  point: LatLng(p.lat, p.lng), width: 44, height: 44,
                  child: Semantics(
                    button: true, label: p.name,
                    child: GestureDetector(
                      onTap: () => setState(() {
                        selected = p;
                        dir.message = '';
                        dir.me = null;
                      }),
                      child: Container(
                        decoration: BoxDecoration(color: cs.surface, shape: BoxShape.circle, border: Border.all(color: p == sel ? cs.primary : cs.secondary, width: 3), boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black38)]),
                        alignment: Alignment.center,
                        child: Text(catOf(p.cat).icon, style: const TextStyle(fontSize: 18)),
                      ),
                    ),
                  ),
                ),
              if (dir.me != null) _youMarker(dir.me!),
            ]),
            const RichAttributionWidget(attributions: [TextSourceAttribution('© OpenStreetMap contributors')]),
          ],
        ),
      ),
      if (sel != null)
        Material(
          elevation: 8,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Expanded(child: Text(sel.name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold))),
                Stars(widget.state.stats(sel).avg),
              ]),
              Text(sel.address, style: TextStyle(color: Theme.of(context).hintColor)),
              if (dir.message.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(dir.message)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: OutlinedButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PlaceScreen(state: widget.state, place: sel))), child: const Text('Details'))),
                const SizedBox(width: 8),
                Expanded(child: FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                  icon: const Icon(Icons.directions), label: const Text('Directions'),
                  onPressed: dir.busy ? null : () => dir.run(sel, map, () => setState(() {})),
                )),
              ]),
              if (dir.me != null) TextButton(onPressed: () => openExternalDirections(sel, from: dir.me), child: const Text('Open turn-by-turn in Google Maps')),
            ]),
          ),
        )
      else
        Padding(padding: const EdgeInsets.all(10), child: Text('Tap a marker for details and directions.', style: TextStyle(color: Theme.of(context).hintColor))),
    ]);
  }
}

/// Small map for the place detail page with its own directions button.
class PlaceMap extends StatefulWidget {
  final Place place;
  const PlaceMap({super.key, required this.place});
  @override
  State<PlaceMap> createState() => _PlaceMapState();
}

class _PlaceMapState extends State<PlaceMap> {
  final map = MapController();
  final dir = DirectionsController();

  @override
  Widget build(BuildContext context) {
    final p = widget.place;
    final cs = Theme.of(context).colorScheme;
    final dest = LatLng(p.lat, p.lng);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
        height: 240,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: FlutterMap(
            mapController: map,
            options: MapOptions(initialCenter: dest, initialZoom: 15),
            children: [
              TileLayer(urlTemplate: _tiles, userAgentPackageName: _ua),
              if (dir.me != null) PolylineLayer(polylines: [Polyline(points: [dir.me!, dest], strokeWidth: 4, color: cs.secondary)]),
              MarkerLayer(markers: [
                Marker(point: dest, width: 44, height: 44, child: Container(decoration: BoxDecoration(color: cs.surface, shape: BoxShape.circle, border: Border.all(color: cs.secondary, width: 3)), alignment: Alignment.center, child: Text(catOf(p.cat).icon, style: const TextStyle(fontSize: 18)))),
                if (dir.me != null) _youMarker(dir.me!),
              ]),
              const RichAttributionWidget(attributions: [TextSourceAttribution('© OpenStreetMap contributors')]),
            ],
          ),
        ),
      ),
      const SizedBox(height: 10),
      FilledButton.icon(
        style: FilledButton.styleFrom(minimumSize: const Size(0, 46)),
        icon: const Icon(Icons.directions), label: const Text('Get directions'),
        onPressed: dir.busy ? null : () => dir.run(p, map, () => setState(() {})),
      ),
      if (dir.message.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(dir.message)),
      TextButton(onPressed: () => openExternalDirections(p, from: dir.me), child: const Text('Open turn-by-turn in Google Maps')),
    ]);
  }
}
