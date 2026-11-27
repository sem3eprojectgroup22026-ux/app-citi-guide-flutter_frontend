class City {
  final String id, name, country, blurb, desc, timezone, imageUrl;
  final double lat, lng;
  final int hue;
  final int placeCount;
  const City({required this.id, required this.name, required this.country, required this.lat, required this.lng, required this.hue, required this.blurb, required this.desc, this.timezone='UTC', this.imageUrl='', this.placeCount=0});
  factory City.fromJson(Map<String,dynamic> j)=>City(id:'${j['id']}',name:j['name']??'',country:j['country']??'',lat:(j['lat'] as num).toDouble(),lng:(j['lng'] as num).toDouble(),hue:(j['hue'] as num?)?.toInt()??160,blurb:j['blurb']??'',desc:j['description']??'',timezone:j['timezone']??'UTC',imageUrl:j['imageUrl']??'',placeCount:(j['placeCount'] as num?)?.toInt()??0);
}
class Place {
  final String id, city, cat, name, desc, address, phone, website, hours, extra;
  final double lat,lng,base;
  final double? open,close;
  final bool? backendOpen;
  final bool isFavorite; final int reviewCount; final String thumbnailUrl;
  const Place({required this.id,required this.city,required this.cat,required this.name,required this.desc,required this.address,required this.phone,required this.website,required this.lat,required this.lng,required this.base,required this.hours,this.open,this.close,required this.extra,this.backendOpen,this.isFavorite=false,this.reviewCount=0,this.thumbnailUrl=''});
  bool? get isOpenNow => backendOpen ?? ((open==null||close==null)?(RegExp(r'24 h|Always',caseSensitive:false).hasMatch(hours)?true:null):_isOpen());
  bool _isOpen(){final n=DateTime.now();final h=n.hour+n.minute/60;return close!>24?(h>=open!||h<close!-24):(h>=open!&&h<close!);}
  factory Place.fromJson(Map<String,dynamic> j)=>Place(id:'${j['id']}',city:j['cityId']??'',cat:j['category']??'attraction',name:j['name']??'',desc:j['description']??'',address:j['address']??'',phone:j['phone']??'',website:j['website']??'',lat:(j['lat'] as num).toDouble(),lng:(j['lng'] as num).toDouble(),base:(j['avgRating'] as num?)?.toDouble()??0,hours:j['hoursText']??'',extra:j['extra']??'',backendOpen:j['isOpenNow'] as bool?,isFavorite:j['isFavorite'] as bool? ?? false,reviewCount:(j['reviewCount'] as num?)?.toInt()??0,thumbnailUrl:j['thumbnailUrl']??'');
}
class Category {final String id,label,icon;const Category(this.id,this.label,this.icon);}
const categories=<Category>[Category('attraction','Attractions','🏛️'),Category('restaurant','Restaurants','🍽️'),Category('hotel','Hotels','🛏️'),Category('event','Events','🎟️')];
Category catOf(String id)=>categories.firstWhere((c)=>c.id==id,orElse:()=>categories.first);
class Review {
 final String id,placeId,name,text; final String? userId; final int rating,ts,seedLikes; final int likeCount; final bool likedByMe,mine;
 const Review({required this.id,required this.placeId,this.userId,required this.name,required this.rating,required this.text,required this.ts,this.seedLikes=0,this.likeCount=0,this.likedByMe=false,this.mine=false});
 factory Review.fromJson(Map<String,dynamic> j)=>Review(id:'${j['id']}',placeId:j['placeId']??'',userId:j['userId']?.toString(),name:j['authorName']??'',rating:(j['rating'] as num).toInt(),text:j['text']??'',ts:DateTime.tryParse(j['createdAt']??'')?.millisecondsSinceEpoch??DateTime.now().millisecondsSinceEpoch,likeCount:(j['likeCount'] as num?)?.toInt()??0,likedByMe:j['likedByMe']??false,mine:j['mine']??false);
}
class AppUser {
 final String id,email; String name,phone,avatar; List<String> favorites; Map<String,bool> prefs;
 AppUser({required this.id,required this.name,required this.email,this.phone='',this.avatar='',List<String>? favorites,Map<String,bool>? prefs}):favorites=favorites??[],prefs=prefs??{'events':true,'reviews':true,'news':false};
 factory AppUser.fromJson(Map<String,dynamic> j)=>AppUser(id:'${j['id']}',name:j['name']??'',email:j['email']??'',phone:j['phone']??'',avatar:j['avatarUrl']??'',prefs:{'events':j['prefs']?['events']??true,'reviews':j['prefs']?['reviews']??true,'news':j['prefs']?['news']??false});
}