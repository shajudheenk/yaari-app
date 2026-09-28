import 'package:flutter_test/flutter_test.dart';
import 'package:yaari_customer/data.dart';

Trade _trade(String slug, String name, {String? short}) => Trade(
      id: slug,
      slug: slug,
      name: name,
      shortName: short ?? name,
      icon: 'wheel',
      blurb: null,
      accent: 'ember',
      imageUrl: null,
      heroUrl: null,
    );

Service _service(String name, {String? description}) => Service(
      id: name,
      name: name,
      description: description,
      ratePence: 3500,
      rateUnit: 'hour',
      durationMinutes: 60,
      isPopular: false,
      heroUrl: null,
    );

void main() {
  final electrician = _trade('electrician', 'Electrician');
  final plumber = _trade('plumber', 'Plumber');
  final appliance = _trade('appliance-repair', 'Appliance repair', short: 'Appliances');
  final pets = _trade('pet-care', 'Dog walking & pet care', short: 'Dog walking');

  final search = CatalogueSearch(
    [electrician, plumber, appliance, pets],
    {
      'electrician': [_service('Socket or light fitting'), _service('Full wiring check')],
      'plumber': [_service('Leaking tap', description: 'Kitchen or bathroom')],
      'appliance-repair': [_service('Washing machine repair')],
      'pet-care': [_service('30 minute dog walk')],
    },
  );

  test('an empty query returns nothing rather than everything', () {
    expect(search.query(''), isEmpty);
    expect(search.query('   '), isEmpty);
  });

  test('a name that starts with the query outranks one that contains it', () {
    // "Plumber" starts with "pl"; nothing else should come first.
    expect(search.query('pl').first.trade.slug, 'plumber');
  });

  test('the trade itself outranks its own services', () {
    final hits = search.query('electric');
    expect(hits.first.trade.slug, 'electrician');
    expect(hits.first.service, isNull,
        reason: 'the trade should lead, with its jobs underneath');
  });

  test('searching the problem finds the trade that fixes it', () {
    // Nothing in the catalogue contains the word "leak" except one service,
    // but a plumber is what someone with a leak actually needs.
    expect(search.query('leak').map((h) => h.trade.slug), contains('plumber'));
    expect(search.query('boiler'), isEmpty,
        reason: 'no gas engineer in this fixture, so nothing should match');
  });

  test('synonyms reach trades whose name shares no words with the query', () {
    expect(search.query('washing machine').map((h) => h.trade.slug),
        contains('appliance-repair'));
    expect(search.query('puppy').map((h) => h.trade.slug), contains('pet-care'));
  });

  test('a short name matches even when the full name does not start with it', () {
    // The grid calls it "Dog walking"; the catalogue calls it
    // "Dog walking & pet care". Typing either has to work.
    expect(search.query('dog').map((h) => h.trade.slug), contains('pet-care'));
  });

  test('matching is case insensitive and ignores surrounding space', () {
    expect(search.query('  PLUMBER '), isNotEmpty);
    expect(search.query('  PLUMBER ').first.trade.slug, 'plumber');
  });

  test('nonsense matches nothing', () {
    expect(search.query('qwertyuiop'), isEmpty);
  });

  test('a service hit carries the trade it belongs to, for the next screen', () {
    final hit = search.query('socket').first;
    expect(hit.service, isNotNull);
    expect(hit.trade.slug, 'electrician');
    expect(hit.title, 'Socket or light fitting');
  });
}
