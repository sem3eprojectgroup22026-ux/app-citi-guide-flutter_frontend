import 'package:flutter/material.dart';
import 'models.dart';
import 'store.dart';
import 'data.dart';
import 'screens/place_screen.dart';

City cityOf(String id) => cities.firstWhere(
      (c) => c.id == id,
      orElse: () => City(id: id, name: '', country: '', lat: 0, lng: 0, hue: 160, blurb: '', desc: ''),
    );

void snack(BuildContext c, String msg, {bool error = false}) {
  ScaffoldMessenger.of(c)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg), backgroundColor: error ? Colors.red.shade800 : null, behavior: SnackBarBehavior.floating));
}


class Art extends StatelessWidget {
  final String seed, icon, label;
  final int hue;
  final double? height;
  final double radius;
  const Art({super.key, required this.seed, required this.icon, required this.hue, this.label = '', this.height, this.radius = 0});

  @override
  Widget build(BuildContext context) {
    final h = ((hue + seed.codeUnits.fold(0, (a, c) => (a * 31 + c) & 0xffff) % 50) % 360).toDouble();
    return Semantics(
      label: label.isEmpty ? 'Illustration' : '$label illustration',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Container(
          height: height,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [HSLColor.fromAHSL(1, h, .7, .58).toColor(), HSLColor.fromAHSL(1, (h + 45) % 360, .65, .32).toColor()],
            ),
          ),
          alignment: Alignment.center,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(icon, style: const TextStyle(fontSize: 44)),
            if (label.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                child: Text(label, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontFamily: 'serif', fontSize: 14)),
              ),
          ]),
        ),
      ),
    );
  }
}

class Stars extends StatelessWidget {
  final double value;
  final double size;
  const Stars(this.value, {super.key, this.size = 16});
  @override
  Widget build(BuildContext context) => Semantics(
        label: '${value.toStringAsFixed(1)} out of 5 stars',
        child: ExcludeSemantics(
          child: Row(mainAxisSize: MainAxisSize.min, children: List.generate(5, (i) {
            final icon = value >= i + 1 ? Icons.star_rounded : (value >= i + .5 ? Icons.star_half_rounded : Icons.star_outline_rounded);
            return Icon(icon, size: size, color: const Color(0xFFF5A524));
          })),
        ),
      );
}

class OpenBadge extends StatelessWidget {
  final Place p;
  const OpenBadge(this.p, {super.key});
  @override
  Widget build(BuildContext context) {
    final o = p.isOpenNow;
    if (o == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: o ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(99)),
      child: Text(o ? 'Open now' : 'Closed now',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: o ? const Color(0xFF166534) : const Color(0xFF991B1B))),
    );
  }
}

class UserAvatar extends StatelessWidget {
  final AppUser u;
  final double size;
  const UserAvatar(this.u, {super.key, this.size = 40});
  @override
  Widget build(BuildContext context) {
    if (u.avatar.isNotEmpty) {
      final url=u.avatar.startsWith('http')?u.avatar:'${AppState.baseUrl}${u.avatar.startsWith('/')?'':'/'}${u.avatar}';
      return CircleAvatar(radius:size/2,backgroundImage:NetworkImage(url));
    }
    final ini = u.name.trim().split(RegExp(r'\s+')).take(2).map((w) => w.isEmpty ? '' : w[0].toUpperCase()).join();
    return CircleAvatar(radius: size / 2, backgroundColor: Theme.of(context).colorScheme.secondary,
        child: Text(ini, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: size * .38)));
  }
}

class PlaceCard extends StatelessWidget {
  final Place p;
  final AppState state;
  const PlaceCard(this.p, this.state, {super.key});

  @override
  Widget build(BuildContext context) {
    final st = state.stats(p);
    final fav = state.isFav(p.id);
    final cat = catOf(p.cat);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PlaceScreen(state: state, place: p))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Stack(children: [
            p.thumbnailUrl.isNotEmpty ? Image.network(p.thumbnailUrl,width:double.infinity,height:130,fit:BoxFit.cover,errorBuilder:(_,__,___)=>Art(seed:p.id,icon:cat.icon,hue:cityOf(p.city).hue,label:p.name,height:130)) : Art(seed: p.id, icon: cat.icon, hue: cityOf(p.city).hue, label: p.name, height: 130),
            Positioned(left: 10, top: 10, child: Chip(label: Text(cat.label.replaceAll(RegExp(r's$'), ''), style: const TextStyle(fontSize: 11, color: Colors.white)),
                backgroundColor: Colors.black54, padding: EdgeInsets.zero, visualDensity: VisualDensity.compact, side: BorderSide.none)),
            Positioned(right: 4, top: 4, child: IconButton.filled(
              style: IconButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.surface),
              tooltip: fav ? 'Remove from favourites' : 'Add to favourites',
              icon: Icon(fav ? Icons.favorite : Icons.favorite_border, color: Colors.red),
              onPressed: () => state.toggleFav(p.id).then((r){if(context.mounted)snack(context,r.ok?(fav?'Removed from favourites':'Saved to favourites'):r.error??'Could not update favourites',error:!r.ok);}),
            )),
          ]),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 6, children: [
                Stars(st.avg),
                Text(st.avg.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('(${st.count})', style: TextStyle(color: Theme.of(context).hintColor)),
                OpenBadge(p),
              ]),
              const SizedBox(height: 6),
              Text(p.desc, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: Theme.of(context).hintColor)),
              const SizedBox(height: 6),
              Text('🕒 ${p.hours}', style: const TextStyle(fontSize: 12.5)),
              Text('📞 ${p.phone}', style: const TextStyle(fontSize: 12.5)),
            ]),
          ),
        ]),
      ),
    );
  }
}


class Filters {
  String cat = 'all', city = 'all', q = '', sort = 'rating';
  double minRating = 0;

  List<Place> apply(AppState s, Iterable<Place> src) {
    final toks = q.toLowerCase().split(RegExp(r'\s+')).where((t) => t.isNotEmpty);
    final l = src.where((p) {
      if (cat != 'all' && p.cat != cat) return false;
      if (city != 'all' && p.city != city) return false;
      if (s.stats(p).avg < minRating) return false;
      final hay = '${p.name} ${p.desc} ${p.address} ${p.cat} ${p.extra} ${cityOf(p.city).name}'.toLowerCase();
      return toks.every(hay.contains);
    }).toList();
    switch (sort) {
      case 'name':
        l.sort((a, b) => a.name.compareTo(b.name));
      case 'reviews':
        l.sort((a, b) => s.stats(b).count.compareTo(s.stats(a).count));
      default:
        l.sort((a, b) => s.stats(b).avg.compareTo(s.stats(a).avg));
    }
    return l;
  }
}

class FilterBar extends StatelessWidget {
  final Filters f;
  final bool withCity;
  final VoidCallback onChanged;
  const FilterBar({super.key, required this.f, required this.onChanged, this.withCity = false});

  @override
  Widget build(BuildContext context) {
    Widget dd<T>(String label, T value, List<DropdownMenuItem<T>> items, void Function(T) on) => Expanded(
          child: DropdownButtonFormField<T>(
            value: value, items: items, isExpanded: true,
            decoration: InputDecoration(labelText: label, isDense: true, border: const OutlineInputBorder()),
            onChanged: (v) {
              if (v != null) {
                on(v);
                onChanged();
              }
            },
          ),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          for (final c in [const Category('all', 'All', ''), ...categories])
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(label: Text('${c.icon} ${c.label}'.trim()), selected: f.cat == c.id, onSelected: (_) {
                f.cat = c.id;
                onChanged();
              }),
            ),
        ]),
      ),
      const SizedBox(height: 10),
      Row(children: [
        if (withCity) ...[
          dd<String>('City', f.city, [const DropdownMenuItem(value: 'all', child: Text('All')), ...cities.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))], (v) => f.city = v),
          const SizedBox(width: 8),
        ],
        dd<double>('Min rating', f.minRating, [0.0, 3.0, 3.5, 4.0, 4.5].map((v) => DropdownMenuItem(value: v, child: Text(v == 0 ? 'Any' : '$v★+'))).toList(), (v) => f.minRating = v),
        const SizedBox(width: 8),
        dd<String>('Sort by', f.sort, const [
          DropdownMenuItem(value: 'rating', child: Text('Top rated')),
          DropdownMenuItem(value: 'reviews', child: Text('Most reviewed')),
          DropdownMenuItem(value: 'name', child: Text('Name A–Z')),
        ], (v) => f.sort = v),
      ]),
    ]);
  }
}
