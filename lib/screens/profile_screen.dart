import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../data.dart';
import '../models.dart';
import '../store.dart';
import '../widgets.dart';
import 'auth_screens.dart' show PasswordField;
import 'place_screen.dart';

class ProfileScreen extends StatefulWidget {
  final AppState state;
  const ProfileScreen({super.key, required this.state});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final name = TextEditingController(), phone = TextEditingController();
  final oldPw = TextEditingController(), newPw = TextEditingController(), cfPw = TextEditingController();
  String? nameErr, phoneErr, pwErr;
  String? _loadedFor;

  @override
  void dispose() {
    for (final c in [name, phone, oldPw, newPw, cfPw]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> pickPhoto() async {
    try {
      final f = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 256, maxHeight: 256, imageQuality: 85);
      if (f == null) return;
      final result=await widget.state.uploadAvatar(f.path);
      if (mounted) snack(context, result.ok?'Photo updated':result.error??'Upload failed',error:!result.ok);
    } catch (_) {
      if (mounted) snack(context, 'Could not read that image.', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final u = s.user;
        if (u == null) return const SizedBox.shrink();
        if (_loadedFor != u.id) { s.loadMyReviews();
          _loadedFor = u.id;
          name.text = u.name;
          phone.text = u.phone;
        }
        final mine = s.myReviews();
        final favs = places.where((p) => u.favorites.contains(p.id)).toList();
        final cs = Theme.of(context).colorScheme;
        Widget panel(String title, List<Widget> kids) => Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              ...kids,
            ])));
        return ListView(padding: const EdgeInsets.all(16), children: [
          Text('Your profile', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          panel('Account', [
            Row(children: [
              UserAvatar(u, size: 76),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(u.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                Text(u.email, style: TextStyle(color: Theme.of(context).hintColor)),
                Wrap(children: [
                  TextButton.icon(onPressed: pickPhoto, icon: const Icon(Icons.photo_camera_outlined), label: const Text('Change photo')),
                  if (u.avatar.isNotEmpty) TextButton(onPressed: () async { final r=await s.removeAvatar(); if(mounted)snack(context,r.ok?'Photo removed':r.error??'Could not remove photo',error:!r.ok); }, child: const Text('Remove')),
                ]),
              ])),
            ]),
            const SizedBox(height: 12),
            TextField(controller: name, textCapitalization: TextCapitalization.words, decoration: InputDecoration(labelText: 'Full name', errorText: nameErr)),
            const SizedBox(height: 12),
            TextField(controller: phone, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: 'Contact number', errorText: phoneErr)),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                final n = name.text.trim(), ph = phone.text.trim();
                setState(() {
                  nameErr = n.length < 2 ? 'Please enter your name.' : null;
                  phoneErr = ph.isNotEmpty && !RegExp(r'^[+\d][\d\s\-()]{5,19}$').hasMatch(ph) ? 'Enter a valid phone number.' : null;
                });
                if (nameErr != null || phoneErr != null) return;
                s.updateProfile(name:n,phone:ph).then((r){if(mounted)snack(context,r.ok?'Profile saved':r.error??'Could not save profile',error:!r.ok);});
              },
              child: const Text('Save profile'),
            ),
          ]),
          const SizedBox(height: 12),
          panel('Preferences', [
            SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Event alerts'), subtitle: const Text('New events in cities you follow'), value: u.prefs['events'] ?? false, onChanged: (v) => s.setPref('events', v).then((r){if(!r.ok&&mounted)snack(context,r.error??'Could not save preference',error:true);})),
            SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Review activity'), subtitle: const Text('When someone likes your review'), value: u.prefs['reviews'] ?? false, onChanged: (v) => s.setPref('reviews', v).then((r){if(!r.ok&&mounted)snack(context,r.error??'Could not save preference',error:true);})),
            SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Travel news & tips'), subtitle: const Text('Occasional highlights'), value: u.prefs['news'] ?? false, onChanged: (v) => s.setPref('news', v).then((r){if(!r.ok&&mounted)snack(context,r.error??'Could not save preference',error:true);})),
            const Divider(),
            const Text('Favourite attractions', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            if (favs.isEmpty) const Text('None yet – tap the heart on any place.'),
            Wrap(spacing: 8, children: [
              for (final p in favs)
                ActionChip(label: Text('${catOf(p.cat).icon} ${p.name}'), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PlaceScreen(state: s, place: p)))),
            ]),
          ]),
          const SizedBox(height: 12),
          panel('My reviews (${mine.length})', [
            if (mine.isEmpty) const Text('You haven’t reviewed anywhere yet.'),
            for (final r in mine)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(places.where((p) => p.id == r.placeId).map((p) => p.name).firstOrNull ?? 'Unknown place'),
                subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Stars(r.rating.toDouble(), size: 15), Text(r.text)]),
                onTap: () {
                  final pl = places.where((p) => p.id == r.placeId).firstOrNull;
                  if (pl != null) Navigator.push(context, MaterialPageRoute(builder: (_) => PlaceScreen(state: s, place: pl)));
                },
              ),
          ]),
          const SizedBox(height: 12),
          panel('Change password', [
            PasswordField(controller: oldPw, label: 'Current password'),
            const SizedBox(height: 12),
            PasswordField(controller: newPw, label: 'New password', meter: true),
            const SizedBox(height: 12),
            PasswordField(controller: cfPw, label: 'Confirm new password', action: TextInputAction.done),
            if (pwErr != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(pwErr!, style: TextStyle(color: cs.error, fontWeight: FontWeight.w600))),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () {
                s.changePassword(oldPw.text,newPw.text,cfPw.text).then((r){if(!mounted)return;setState(()=>pwErr=r.ok?null:r.error);if(r.ok){
                  oldPw.clear();
                  newPw.clear();
                  cfPw.clear();
                  snack(context, 'Password changed');
                }});
              },
              child: const Text('Update password'),
            ),
          ]),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: cs.error, minimumSize: const Size.fromHeight(48)),
            icon: const Icon(Icons.logout),
            label: const Text('Log out'),
            onPressed: () => s.logout(), // main.dart swaps back to the login screen
          ),
          const SizedBox(height: 8),
        ]);
      },
    );
  }
}
