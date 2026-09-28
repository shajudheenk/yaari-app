import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';
import 'data.dart';

/// Where the customer is shopping from.
///
/// Every search, and the map on the booking screen, start from here. It is
/// remembered between launches: somebody who lives in Clapham should not have
/// to re-pick London every time they open the app.
class Place extends ChangeNotifier {
  Place._(this._area);

  static const _key = 'yaari.area';

  ServiceArea? _area;
  List<ServiceArea> _all = const [];

  ServiceArea? get area => _area;
  List<ServiceArea> get all => _all;

  double get lat => _area?.lat ?? Config.fallbackLat;
  double get lng => _area?.lng ?? Config.fallbackLng;
  String get name => _area?.name ?? Config.fallbackArea;
  String get city => _area?.city ?? Config.fallbackCity;
  String get postcodePrefix => _area?.postcodePrefix ?? Config.fallbackPostcode;

  /// Areas grouped by city, cities in alphabetical order, so the picker can
  /// render sections without knowing which cities exist.
  Map<String, List<ServiceArea>> get byCity {
    final out = <String, List<ServiceArea>>{};
    for (final a in _all.where((a) => a.isLive)) {
      out.putIfAbsent(a.city, () => []).add(a);
    }
    return out;
  }

  static Future<Place> load() async {
    final place = Place._(null);
    try {
      place._all = await Api.areas();
      final saved = (await SharedPreferences.getInstance()).getString(_key);

      place._area = place._all.firstWhere(
        (a) => a.isLive && a.name == saved,
        // No saved choice, or the area was retired since. Prefer the
        // configured launch area, then any live area, then the compiled-in
        // fallback — picking whichever happened to sort first would put a new
        // customer somewhere arbitrary.
        orElse: () => place._all.firstWhere(
          (a) => a.isLive && a.name == Config.fallbackArea,
          orElse: () => place._all.firstWhere(
            (a) => a.isLive,
              orElse: () => ServiceArea(
              name: Config.fallbackArea,
              city: Config.fallbackCity,
              postcodePrefix: Config.fallbackPostcode,
              isLive: true,
              lat: Config.fallbackLat,
              lng: Config.fallbackLng,
            ),
          ),
        ),
      );
    } catch (_) {
      // Offline on first run. The compiled-in fallback keeps the app usable.
    }
    return place;
  }

  Future<void> choose(ServiceArea a) async {
    if (a.name == _area?.name) return;
    _area = a;
    notifyListeners();
    try {
      await (await SharedPreferences.getInstance()).setString(_key, a.name);
    } catch (_) {
      // Remembering is a convenience; failing to save must not break the app.
    }
  }
}
