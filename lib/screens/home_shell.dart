import 'package:flutter/material.dart';
import '../data.dart';
import '../models.dart';
import '../store.dart';
import '../widgets.dart';
import 'map_screen.dart';
import 'profile_screen.dart';

class HomeShell extends StatefulWidget {
  final AppState state;
  const HomeShell({super.key, required this.state});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final pages = <Widget>[
      CitiesScreen(state: s),
      SearchScreen(state: s),
      MapScreen(state: s),
      SavedScreen(state: s),
      ProfileScreen(state: s),
    ];
    return Scaffold(
      body: SafeArea(child: IndexedStack(index: tab, children: pages)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.location_city_outlined), selectedIcon: Icon(Icons.location_city), label: 'Cities'),
          NavigationDestination(icon: Icon(Icons.search), label: 'Search'),
          NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: 'Map'),
          NavigationDestination(icon: Icon(Icons.favorite_border), selectedIcon: Icon(Icons.favorite), label: 'Saved'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}


class CitiesScreen extends StatefulWidget {
  final AppState state;
  const CitiesScreen({super.key, required this.state});
  @override
  State<CitiesScreen> createState() => _CitiesScreenState();
}

class _CitiesScreenState extends State<CitiesScreen> {
  String q = '';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final first = widget.state.user?.name.split(' ').first ?? '';
    return ListenableBuilder(listenable: widget.state, builder: (context, _) => _body(context, cs, first));
  }

  Widget _body(BuildContext context, ColorScheme cs, String first) {
    final list = cities.where((c) => '${c.name} ${c.country}'.toLowerCase().contains(q.toLowerCase())).toList();
    return ListView(padding: const EdgeInsets.all(16), children: [
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), gradient: LinearGradient(colors: [cs.primary, const Color(0xFF134E4A)])),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Where to, $first?', style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold, fontFamily: 'serif')),
          const SizedBox(height: 4),
          const Text('Pick a city to see what’s worth your time.', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 14),
          TextField(
            onChanged: (v) => setState(() => q = v),
            decoration: InputDecoration(hintText: 'Filter cities…', prefixIcon: const Icon(Icons.search), filled: true, fillColor: cs.surface, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
          ),
        ]),
      ),
      const SizedBox(height: 16),
      if (cities.isEmpty)
        Padding(padding: const EdgeInsets.all(32), child: Center(child: Column(children: [
          if (widget.state.initializing) const CircularProgressIndicator() else ...[
            const Text('Could not load cities. The server may be waking up.', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(140, 44)), onPressed: widget.state.loadCities, child: const Text('Retry')),
          ],
        ])))
      else if (list.isEmpty) const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No cities match your filter.'))),
      for (final c in list)
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CityScreen(state: widget.state, city: c))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                c.imageUrl.isNotEmpty ? Image.network(c.imageUrl,width:double.infinity,height:140,fit:BoxFit.cover,errorBuilder:(_,__,___)=>Art(seed:c.id,icon:'🏙️',hue:c.hue,label:c.name,height:140)) : Art(seed: c.id, icon: '🏙️', hue: c.hue, label: c.name, height: 140),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${c.name}, ${c.country}', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(c.blurb, style: TextStyle(color: Theme.of(context).hintColor)),
                    const SizedBox(height: 8),
                    Text('${places.where((p) => p.city == c.id).length} places to explore →', style: TextStyle(color: cs.primary, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ]),
            ),
          ),
        ),
    ]);
  }
}


class CityScreen extends StatefulWidget {
  final AppState state;
  final City city;
  const CityScreen({super.key, required this.state, required this.city});
  @override
  State<CityScreen> createState() => _CityScreenState();
}

class _CityScreenState extends State<CityScreen> {
  final f = Filters();

  @override
  void initState() {
    super.initState();
    widget.state.lastCity = widget.city.id;
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.city;
    return Scaffold(
      appBar: AppBar(title: Text(c.name)),
      body: ListenableBuilder(
        listenable: widget.state,
        builder: (context, _) {
          final list = f.apply(widget.state, places.where((p) => p.city == c.id));
          return ListView(padding: const EdgeInsets.all(16), children: [
            c.imageUrl.isNotEmpty ? ClipRRect(borderRadius:BorderRadius.circular(18),child:Image.network(c.imageUrl,width:double.infinity,height:170,fit:BoxFit.cover,errorBuilder:(_,__,___)=>Art(seed:c.id,icon:'🏙️',hue:c.hue,label:c.name,height:170))) : Art(seed: c.id, icon: '🏙️', hue: c.hue, label: '${c.name}, ${c.country}', height: 170, radius: 18),
            const SizedBox(height: 14),
            Text(c.desc, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.map),
                label: const Text('View on map'),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(appBar: AppBar(title: Text('${c.name} map')), body: MapScreen(state: widget.state, initialCity: c.id, standalone: true)))),
              ),
            ),
            const SizedBox(height: 16),
            Text('Explore ${c.name}', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            FilterBar(f: f, onChanged: () => setState(() {})),
            const SizedBox(height: 10),
            Text('${list.length} result${list.length == 1 ? '' : 's'}', style: TextStyle(color: Theme.of(context).hintColor)),
            const SizedBox(height: 6),
            if (list.isEmpty) const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('Nothing matches these filters.'))),
            for (final p in list) Padding(padding: const EdgeInsets.only(bottom: 12), child: PlaceCard(p, widget.state)),
          ]);
        },
      ),
    );
  }
}


class SearchScreen extends StatefulWidget {
  final AppState state;
  const SearchScreen({super.key, required this.state});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final f = Filters();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) {
        final list = f.apply(widget.state, places);
        return ListView(padding: const EdgeInsets.all(16), children: [
          Text('Search', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          TextField(
            onChanged: (v) => setState(() => f.q = v),
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(hintText: 'Name or keyword: museum, ramen, jazz…', prefixIcon: Icon(Icons.search)),
          ),
          const SizedBox(height: 12),
          FilterBar(f: f, withCity: true, onChanged: () => setState(() {})),
          const SizedBox(height: 10),
          Text('${list.length} result${list.length == 1 ? '' : 's'}${f.q.isEmpty ? '' : ' for “${f.q}”'}', style: TextStyle(color: Theme.of(context).hintColor)),
          const SizedBox(height: 6),
          if (list.isEmpty) const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No places found. Try a different keyword or loosen the filters.', textAlign: TextAlign.center))),
          for (final p in list) Padding(padding: const EdgeInsets.only(bottom: 12), child: PlaceCard(p, widget.state)),
        ]);
      },
    );
  }
}


class SavedScreen extends StatelessWidget {
  final AppState state;
  const SavedScreen({super.key, required this.state});
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final list = places.where((p) => state.isFav(p.id)).toList();
        return ListView(padding: const EdgeInsets.all(16), children: [
          Text('Saved places', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (list.isEmpty) const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('You haven’t saved anything yet.\nTap the heart on any place.', textAlign: TextAlign.center))),
          for (final p in list) Padding(padding: const EdgeInsets.only(bottom: 12), child: PlaceCard(p, state)),
        ]);
      },
    );
  }
}
