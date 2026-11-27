import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'data.dart';
import 'models.dart';

class Result {
 final bool ok; final String? error; final Map<String,String> errors; final String? code; final bool sent;
 const Result.ok({this.code,this.sent=true}):ok=true,error=null,errors=const{};
 const Result.fail(this.error,{this.errors=const{}}):ok=false,code=null,sent=false;
}
List<String> passwordIssues(String p){final x=<String>[];if(p.length<8)x.add('at least 8 characters');if(!RegExp(r'[A-Z]').hasMatch(p))x.add('an uppercase letter');if(!RegExp(r'[a-z]').hasMatch(p))x.add('a lowercase letter');if(!RegExp(r'\d').hasMatch(p))x.add('a number');return x;}
int passwordScore(String p){var s=0;if(p.length>=8)s++;if(RegExp(r'[A-Z]').hasMatch(p)&&RegExp(r'[a-z]').hasMatch(p))s++;if(RegExp(r'\d').hasMatch(p))s++;if(RegExp(r'[^A-Za-z0-9]').hasMatch(p)||p.length>=12)s++;return s;}

class AppState extends ChangeNotifier {
 static const baseUrl='https://app-citi-guide-backend.onrender.com';
 static const _secure=FlutterSecureStorage();
 final SharedPreferences _prefs;
 String? _access,_refresh;
 Future<void>? _refreshFuture;
 AppUser? user;
 bool loading=false;
 bool initializing=false;
 String? loadError;
 final Map<String,List<Review>> _reviews={};
 final Map<String,Review> _mine={};
 final Map<String,Review> _allMine={};
 final Map<String,Place> _placeById={};
 AppState._(this._prefs);
 static Future<AppState> load({bool connect=true}) async {
  final s=AppState._(await SharedPreferences.getInstance());
  try { s._access=await _secure.read(key:'access_token'); s._refresh=await _secure.read(key:'refresh_token'); } catch (_) { s._access=null; s._refresh=null; }
  if(connect){ await s.initialize(); }
  return s;
 }
 Future<void> initialize() async { initializing=true; notifyListeners(); try { await loadCities(); if(_refresh!=null){try{await _refreshSession();await _loadUserAndCatalog();}catch(_){await _clearSession();}} } finally { initializing=false; notifyListeners(); } }
 Map<String,String> get _headers=>{'Accept':'application/json','Content-Type':'application/json',if(_access!=null)'Authorization':'Bearer $_access'};
 Uri _uri(String path,[Map<String,String>? query])=>Uri.parse('$baseUrl$path').replace(queryParameters:query);
 Map<String,dynamic> _decode(http.Response r){if(r.body.isEmpty)return {};try{return jsonDecode(r.body) as Map<String,dynamic>;}catch(_){return {};}}
 String _message(http.Response r){final j=_decode(r);return j['message']?.toString()??'Request failed (${r.statusCode}).';}
 Future<http.Response> _request(String method,String path,{Object? body,Map<String,String>? query,bool auth=true,bool retry=true}) async {
  final uri=_uri(path,query);final headers={..._headers};if(!auth)headers.remove('Authorization');
  Future<http.Response> send()=>switch(method){'GET'=>http.get(uri,headers:headers),'POST'=>http.post(uri,headers:headers,body:jsonEncode(body)),'PUT'=>http.put(uri,headers:headers,body:jsonEncode(body)),'PATCH'=>http.patch(uri,headers:headers,body:jsonEncode(body)),'DELETE'=>http.delete(uri,headers:headers),_=>http.get(uri,headers:headers)};
  var response=await send().timeout(const Duration(seconds:180));
  if(response.statusCode==401&&auth&&retry&&_refresh!=null){await _refreshSession();return _request(method,path,body:body,query:query,auth:auth,retry:false);}
  return response;
 }
 Future<void> _refreshSession() {
  if(_refreshFuture!=null)return _refreshFuture!;
  final task=_performRefresh();
  _refreshFuture=task;
  return task.whenComplete(()=>_refreshFuture=null);
 }
 Future<void> _performRefresh() async {
  final r=await http.post(_uri('/api/auth/refresh'),headers:{'Content-Type':'application/json'},body:jsonEncode({'refreshToken':_refresh})).timeout(const Duration(seconds:180));
  if(r.statusCode<200||r.statusCode>=300){await _clearSession();throw Exception('Session expired. Please log in again.');}
  await _saveTokens(_decode(r));
 }
 Future<void> _saveTokens(Map<String,dynamic> j) async {
  _access=j['accessToken']?.toString();_refresh=j['refreshToken']?.toString();
  if(_access==null||_refresh==null)throw Exception('The server returned an invalid session.');
  await _secure.write(key:'access_token',value:_access);await _secure.write(key:'refresh_token',value:_refresh);
  final u=j['user'];if(u is Map<String,dynamic>)user=AppUser.fromJson(u);
 }
 Future<void> _clearSession() async { _access=null;_refresh=null;user=null;await _secure.delete(key:'access_token');await _secure.delete(key:'refresh_token');_reviews.clear();_mine.clear();_allMine.clear();notifyListeners(); }
 Future<void> loadCities() async {try{final r=await _request('GET','/api/cities');if(r.statusCode>=200&&r.statusCode<300){cities..clear()..addAll((jsonDecode(r.body) as List).map((e)=>City.fromJson(e)));}}catch(e){loadError=e.toString();}notifyListeners();}
 Future<void> _loadUserAndCatalog() async {
  final me=await _request('GET','/api/me');if(me.statusCode<200||me.statusCode>=300)throw Exception(_message(me));user=AppUser.fromJson(_decode(me));
  await loadCities();
  final results=await Future.wait([_request('GET','/api/places',query:{'page':'0','size':'100','sort':'rating'}),_request('GET','/api/me/favorites'),_request('GET','/api/me/reviews')]);
  if(results[0].statusCode>=200&&results[0].statusCode<300){final j=_decode(results[0]);final items=(j['items'] as List? ?? []);places..clear()..addAll(items.map((e)=>Place.fromJson(e)));_placeById..clear()..addEntries(places.map((p)=>MapEntry(p.id,p)));}
  if(results[1].statusCode>=200&&results[1].statusCode<300){final ids=(jsonDecode(results[1].body) as List).map((e)=>Place.fromJson(e).id).toSet();user!.favorites=ids.toList();}
  if(results[2].statusCode>=200&&results[2].statusCode<300){for(final e in jsonDecode(results[2].body) as List){final r=Review.fromJson(e);_mine[r.placeId]=r;_allMine[r.id]=r;}}
  notifyListeners();
 }
 Future<Result> login(String email,String password) async {loading=true;notifyListeners();try{final r=await _request('POST','/api/auth/login',auth:false,body:{'email':email.trim(),'password':password});if(r.statusCode<200||r.statusCode>=300)return Result.fail(_message(r));await _saveTokens(_decode(r));await _loadUserAndCatalog();return const Result.ok();}catch(e){return Result.fail(e.toString());}finally{loading=false;notifyListeners();}}
 Future<Result> register(String name,String email,String password,String confirm) async {loading=true;notifyListeners();try{final r=await _request('POST','/api/auth/register',auth:false,body:{'name':name.trim(),'email':email.trim(),'password':password,'confirmPassword':confirm});if(r.statusCode<200||r.statusCode>=300){final j=_decode(r);return Result.fail(_message(r),errors:Map<String,String>.from(j['fieldErrors']??{}));}await _saveTokens(_decode(r));await _loadUserAndCatalog();return const Result.ok();}catch(e){return Result.fail(e.toString());}finally{loading=false;notifyListeners();}}
 Future<void> logout() async {try{if(_refresh!=null)await _request('POST','/api/auth/logout',body:{'refreshToken':_refresh},auth:false,retry:false);}catch(_){}await _clearSession();places.clear();notifyListeners();}
 Future<Result> requestReset(String email) async {if(!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$').hasMatch(email.trim()))return const Result.fail('Enter a valid email address.');try{final r=await _request('POST','/api/auth/forgot-password',auth:false,body:{'email':email.trim()});if(r.statusCode<200||r.statusCode>=300)return Result.fail(_message(r));return const Result.ok(sent:true);}catch(e){return Result.fail(e.toString());}}
 Future<Result> resetPassword(String email,String code,String pw,String confirm) async {try{final r=await _request('POST','/api/auth/reset-password',auth:false,body:{'email':email,'code':code,'password':pw,'confirmPassword':confirm});return r.statusCode>=200&&r.statusCode<300?const Result.ok():Result.fail(_message(r));}catch(e){return Result.fail(e.toString());}}
 Future<Result> changePassword(String oldPw,String pw,String confirm) async {try{final r=await _request('POST','/api/me/change-password',body:{'currentPassword':oldPw,'newPassword':pw,'confirmPassword':confirm});if(r.statusCode<200||r.statusCode>=300)return Result.fail(_message(r));await _saveTokens(_decode(r));return const Result.ok();}catch(e){return Result.fail(e.toString());}}
 Future<Result> updateProfile({String? name,String? phone}) async {try{final r=await _request('PATCH','/api/me',body:{if(name!=null)'name':name,if(phone!=null)'phone':phone});if(r.statusCode<200||r.statusCode>=300)return Result.fail(_message(r));user=AppUser.fromJson(_decode(r));notifyListeners();return const Result.ok();}catch(e){return Result.fail(e.toString());}}
 Future<Result> setPref(String key,bool value) async {final prefs={...?user?.prefs,key:value};try{final r=await _request('PATCH','/api/me',body:{'prefs':prefs});if(r.statusCode<200||r.statusCode>=300)return Result.fail(_message(r));user=AppUser.fromJson(_decode(r));notifyListeners();return const Result.ok();}catch(e){return Result.fail(e.toString());}}
 bool isFav(String id)=>user?.favorites.contains(id)??false;
 Future<Result> toggleFav(String id) async {final was=isFav(id);final path='/api/me/favorites/$id';try{final r=await _request(was?'DELETE':'PUT',path);if(r.statusCode<200||r.statusCode>=300)return Result.fail(_message(r));if(was)user?.favorites.remove(id);else user?.favorites.add(id);notifyListeners();return const Result.ok();}catch(e){return Result.fail(e.toString());}}
 Future<List<String>> loadPlaceImages(String id) async {try{final r=await _request('GET','/api/places/$id');if(r.statusCode<200||r.statusCode>=300)return const [];final body=_decode(r);final raw=body['images'];if(raw is! List)return const [];return raw.whereType<Map>().map((e)=>e['url']?.toString()??'').where((url)=>url.startsWith('https://')||url.startsWith('http://')).toList();}catch(_){return const [];}}
 List<Review> reviewsFor(String id)=>_reviews[id]??[];
 Future<void> loadReviews(String id) async {try{final r=await _request('GET','/api/places/$id/reviews');if(r.statusCode>=200&&r.statusCode<300){final list=(jsonDecode(r.body) as List).map((e)=>Review.fromJson(e)).toList();_reviews[id]=list;for(final x in list){if(x.mine)_mine[id]=x;}}}catch(_){}notifyListeners();}
 Review? myReviewFor(String id)=>_mine[id];
 List<Review> myReviews()=>_allMine.values.toList();
 Future<void> loadMyReviews() async {try{final r=await _request('GET','/api/me/reviews');if(r.statusCode>=200&&r.statusCode<300){_allMine.clear();for(final e in jsonDecode(r.body) as List){final x=Review.fromJson(e);_mine[x.placeId]=x;_allMine[x.id]=x;}}}catch(_){}notifyListeners();}
 int likeCount(Review r)=>r.likeCount;
 bool likedByMe(Review r)=>r.likedByMe;
 Future<Result> toggleLike(Review r) async {try{final x=await _request(r.likedByMe?'DELETE':'PUT','/api/reviews/${r.id}/like');if(x.statusCode<200||x.statusCode>=300)return Result.fail(_message(x));_reviews.remove(r.placeId);notifyListeners();await loadReviews(r.placeId);return const Result.ok();}catch(e){return Result.fail(e.toString());}}
 Future<Result> addReview(String placeId,int rating,String text) async {try{final r=await _request('PUT','/api/places/$placeId/reviews',body:{'rating':rating,'text':text.trim()});if(r.statusCode<200||r.statusCode>=300)return Result.fail(_message(r));_reviews.remove(placeId);_mine.remove(placeId);_allMine.removeWhere((k,v)=>v.placeId==placeId);await loadReviews(placeId);await loadMyReviews();return const Result.ok();}catch(e){return Result.fail(e.toString());}}
 Future<Result> deleteReview(String id,String placeId) async {try{final r=await _request('DELETE','/api/reviews/$id');if(r.statusCode<200||r.statusCode>=300)return Result.fail(_message(r));_reviews.remove(placeId);_mine.remove(placeId);_allMine.remove(id);await loadReviews(placeId);await loadMyReviews();return const Result.ok();}catch(e){return Result.fail(e.toString());}}
 ({double avg,int count}) stats(Place p){final rs=_reviews[p.id]??[];if(rs.isEmpty)return(avg:p.base,count:p.reviewCount);return(avg:rs.fold<int>(0,(a,r)=>a+r.rating)/rs.length,count:rs.length);}
 String get lastCity=>_prefs.getString('cg_lastcity')??(cities.isNotEmpty?cities.first.id:'');
 set lastCity(String v)=>_prefs.setString('cg_lastcity',v);
 Future<Result> uploadAvatar(String path) async {try{final req=http.MultipartRequest('PUT',_uri('/api/me/avatar'));req.headers['Authorization']='Bearer $_access';req.files.add(await http.MultipartFile.fromPath('file',path));final streamed=await req.send();final r=await http.Response.fromStream(streamed);if(r.statusCode<200||r.statusCode>=300)return Result.fail(_message(r));user=AppUser.fromJson(_decode(r));notifyListeners();return const Result.ok();}catch(e){return Result.fail(e.toString());}}
 Future<Result> removeAvatar() async {try{final r=await _request('DELETE','/api/me/avatar');if(r.statusCode<200||r.statusCode>=300)return Result.fail(_message(r));user=AppUser.fromJson(_decode(r));notifyListeners();return const Result.ok();}catch(e){return Result.fail(e.toString());}}
}
