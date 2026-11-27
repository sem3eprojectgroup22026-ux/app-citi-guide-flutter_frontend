import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models.dart';
import '../store.dart';
import '../widgets.dart';
import 'map_screen.dart';

class PlaceScreen extends StatefulWidget {
  final AppState state;
  final Place place;
  const PlaceScreen({super.key, required this.state, required this.place});
  @override
  State<PlaceScreen> createState() => _PlaceScreenState();
}

class _PlaceScreenState extends State<PlaceScreen> {
  final text = TextEditingController();
  int rating = 0, photo = 0;
  List<String> imageUrls = [];
  String? error;

  @override
  void initState() {
    super.initState();
    final mine = widget.state.myReviewFor(widget.place.id);
    if (mine != null) { rating=mine.rating; text.text=mine.text; }
    widget.state.loadPlaceImages(widget.place.id).then((urls){if(mounted)setState(()=>imageUrls=urls);});
    widget.state.loadReviews(widget.place.id).then((_){ final latest=widget.state.myReviewFor(widget.place.id); if(mounted&&latest!=null){setState(()=>rating=latest.rating);text.text=latest.text;} });
  }

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  Future<void> _open(String url) async {
    final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!ok && mounted) snack(context, 'Could not open the link', error: true);
  }

  String _date(int ts) {
    final d = DateTime.fromMillisecondsSinceEpoch(ts);
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${m[d.month - 1]} ${d.day}, ${d.year}';
  }

  Widget _info(IconData icon, String label, Widget value) => ListTile(dense: true, leading: Icon(icon), title: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)), subtitle: value);

  @override
  Widget build(BuildContext context) {
    final p = widget.place;
    final s = widget.state;
    final cat = catOf(p.cat);
    final c = cityOf(p.city);
    s.lastCity = c.id;
    return Scaffold(
      appBar: AppBar(title: Text(p.name, overflow: TextOverflow.ellipsis)),
      body: ListenableBuilder(
        listenable: s,
        builder: (context, _) {
          final st = s.stats(p);
          final fav = s.isFav(p.id);
          final rs = s.reviewsFor(p.id);
          final me = s.user!;
          final mine = s.myReviewFor(p.id);
          return ListView(padding: const EdgeInsets.all(16), children: [
            // gallery
            ClipRRect(borderRadius:BorderRadius.circular(16),child:imageUrls.isNotEmpty?Image.network(imageUrls[photo.clamp(0,imageUrls.length-1).toInt()],width:double.infinity,height:210,fit:BoxFit.cover,errorBuilder:(_,__,___)=>Art(seed:p.id,icon:cat.icon,hue:c.hue,label:p.name,height:210,radius:16)):p.thumbnailUrl.isNotEmpty?Image.network(p.thumbnailUrl,width:double.infinity,height:210,fit:BoxFit.cover,errorBuilder:(_,__,___)=>Art(seed:p.id,icon:cat.icon,hue:c.hue,label:p.name,height:210,radius:16)):Art(seed:p.id,icon:cat.icon,hue:c.hue,label:p.name,height:210,radius:16)),
            if(imageUrls.length>1) ...[
              const SizedBox(height:8),
              SizedBox(height:58,child:ListView.separated(scrollDirection:Axis.horizontal,itemCount:imageUrls.length,separatorBuilder:(_,__)=>const SizedBox(width:8),itemBuilder:(context,i)=>InkWell(onTap:()=>setState(()=>photo=i),child:Container(width:78,decoration:BoxDecoration(border:Border.all(color:photo==i?Theme.of(context).colorScheme.secondary:Colors.transparent,width:2),borderRadius:BorderRadius.circular(10)),child:ClipRRect(borderRadius:BorderRadius.circular(8),child:Image.network(imageUrls[i],fit:BoxFit.cover,errorBuilder:(_,__,___)=>Art(seed:'${p.id}$i',icon:cat.icon,hue:c.hue,height:50)))))),
          )],
            const SizedBox(height: 14),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Chip(label: Text('${cat.icon} ${cat.label.replaceAll(RegExp(r's$'), '')}'), visualDensity: VisualDensity.compact),
                Text(p.name, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 6, children: [
                  Stars(st.avg, size: 20),
                  Text(st.avg.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('${st.count} review${st.count == 1 ? '' : 's'}'),
                  OpenBadge(p),
                ]),
              ])),
              IconButton.filledTonal(
                tooltip: fav ? 'Remove from favourites' : 'Save to favourites',
                icon: Icon(fav ? Icons.favorite : Icons.favorite_border, color: Colors.red),
                onPressed: () => s.toggleFav(p.id).then((r){if(mounted)snack(context,r.ok?(fav?'Removed from favourites':'Saved to favourites'):r.error??'Could not update favourites',error:!r.ok);}),
              ),
            ]),
            const SizedBox(height: 12),
            Text(p.desc, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 8),
            Card(child: Column(children: [
              _info(Icons.place_outlined, 'Address', Text('${p.address}, ${c.name}')),
              _info(Icons.schedule, 'Opening hours', Text(p.hours)),
              _info(Icons.phone_outlined, 'Contact', p.phone == '—' ? const Text('Not available') : InkWell(onTap: () => _open('tel:${p.phone.replaceAll(' ', '')}'), child: Text(p.phone, style: TextStyle(color: Theme.of(context).colorScheme.primary, decoration: TextDecoration.underline)))),
              _info(Icons.language, 'Website', InkWell(onTap: () => _open(p.website), child: Text(p.website.replaceFirst(RegExp(r'^https?://'), ''), style: TextStyle(color: Theme.of(context).colorScheme.primary, decoration: TextDecoration.underline)))),
              _info(p.cat == 'event' ? Icons.event : Icons.payments_outlined, p.cat == 'event' ? 'When' : 'Price', Text(p.extra)),
            ])),
            const SizedBox(height: 16),
            Text('Location', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            PlaceMap(place: p),
            const SizedBox(height: 16),
            Text('Reviews', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Card(child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(mine == null ? 'Write a review' : 'Update your review', style: Theme.of(context).textTheme.titleMedium),
                Row(children: [
                  for (var i = 1; i <= 5; i++)
                    IconButton(
                      tooltip: '$i star${i > 1 ? 's' : ''}',
                      onPressed: () => setState(() => rating = i),
                      icon: Icon(rating >= i ? Icons.star_rounded : Icons.star_outline_rounded, size: 34, color: const Color(0xFFF5A524)),
                    ),
                ]),
                TextField(controller: text, maxLines: 3, maxLength: 600, decoration: InputDecoration(hintText: 'Share what you liked (or didn’t)…', errorText: error)),
                const SizedBox(height: 6),
                FilledButton(
                  onPressed: () {
                    s.addReview(p.id,rating,text.text).then((r){if(!mounted)return;if(!r.ok)return setState(()=>error=r.error);setState(()=>error=null);snack(context,'Thanks for your review!');});
                  },
                  child: Text(mine == null ? 'Post review' : 'Update review'),
                ),
              ]),
            )),
            const SizedBox(height: 10),
            for (final r in rs)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Card(child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      CircleAvatar(radius: 18, backgroundColor: Theme.of(context).colorScheme.secondary, child: Text(r.name.isEmpty ? '?' : r.name[0], style: const TextStyle(color: Colors.white))),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(r.userId == me.id ? '${r.name} (You)' : r.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        Row(children: [Stars(r.rating.toDouble(), size: 15), const SizedBox(width: 6), Text(_date(r.ts), style: const TextStyle(fontSize: 12, color: Colors.grey))]),
                      ])),
                    ]),
                    const SizedBox(height: 8),
                    Text(r.text),
                    const SizedBox(height: 8),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      FilterChip(
                        selected: s.likedByMe(r),
                        label: Text('👍 Helpful · ${s.likeCount(r)}'),
                        onSelected: (_) => s.toggleLike(r).then((v){if(!v.ok&&mounted)snack(context,v.error??'Could not update like',error:true);}),
                      ),
                      if (r.userId == me.id)
                        TextButton(
                          style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
                          onPressed: () async {
                            final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: const Text('Delete your review?'), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete'))]));
                            if (ok == true) {
                              s.deleteReview(r.id,p.id).then((result){if(!mounted)return;if(!result.ok){snack(context,result.error??'Could not delete review',error:true);return;}setState(() {
                                rating = 0;
                                text.clear();
                              });});
                            }
                          },
                          child: const Text('Delete'),
                        ),
                    ]),
                  ]),
                )),
              ),
          ]);
        },
      ),
    );
  }
}
