import 'package:tripling_table/domain/table_state.dart';

const redundantUtilityKinds = [
  'life_total',
  'poison_counters',
  'energy_counters',
  'experience_counters',
  'radiation_counters',
  'citys_blessing',
  'monarch',
  'day_night',
];
const retainedUtilityKinds = [
  'mana_pool',
  'storm_count',
  'krenko_mob_boss',
  'krenko_tin_street',
  'cathars_crusade',
  'academy_manufactor',
  'rhys_the_redeemed',
  'hare_apparent',
  'brudiclad_telchor_engineer',
];
const legacyNames = [
  'Life Total',
  'Poison Counters',
  'Energy Counters',
  'Experience Counters',
  'Radiation Counters',
  "City’s Blessing",
  'Monarch',
  'Day / Night',
];
TabletState legacyUtilityState({bool artwork = false}) {
  final state = TabletState.initial();
  for (final player in state.session.players) {
    player.life = 37;
    player.counters.addAll({
      'poison': 5,
      'energy': 8,
      'experience': 3,
      'radiation': 2,
    });
    player.citysBlessing = true;
    player.mana['W'] = 3;
    player.utilities.firstWhere((u) => u.kind == 'storm_count').value = 7;
    player.utilities.insertAll(0, [
      for (var n = 0; n < redundantUtilityKinds.length; n++)
        UtilityState(
          id: '${player.id}-legacy-$n',
          kind: redundantUtilityKinds[n],
          name: legacyNames[n],
          description: 'Saved description $n',
          colors: n.isEven ? 'UG' : 'W',
          value: 700 + n,
          defaultValue: 3 + n,
          isActive: false,
          visible: n != 7,
          artworkUrl: artwork ? 'https://example.test/legacy-$n.png' : null,
          configuration: {
            'type': n < 5 ? 'tracker' : 'toggle',
            'tapIncrement': 1,
            'offDescription': 'Saved inactive description',
            'retainedConfig': {'marker': n},
            'artworkOptions': [
              {
                'url': 'https://example.test/legacy-$n.png',
                'set': 'OLD',
                'artist': 'Saved artist',
              },
            ],
          },
        ),
    ]);
  }
  state.session.monarchPlayerId = state.session.players.first.id;
  state.session.dayNight = 'day';
  return state;
}
