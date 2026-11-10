#!/usr/bin/env python3
"""Regenerate synthetic Hive bytes with byte-exact archived repository models.
Run from apps/tablet after flutter pub get: python3 tool/generate_historical_hive_fixtures.py --dart /path/to/dart
Does not use current app adapters or download source. Requires locked Hive 2.2.3.
"""
import argparse
import hashlib
import json
import re
from pathlib import Path
import subprocess
import tempfile
from urllib.parse import urljoin, urlparse, unquote

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--dart', default='dart')
args = parser.parse_args()
app = Path(__file__).resolve().parents[1]
fixtures = app / 'test/fixtures/historical_hive'
lock = (app / 'pubspec.lock').read_text()
if not re.search(r'^  hive:\n(?:(?!^  \w).|\n)*?    version: \"2\.2\.3\"', lock, re.MULTILINE):
    raise SystemExit('Fixture generation requires locked Hive 2.2.3')
config_path = app / '.dart_tool/package_config.json'
config = json.loads(config_path.read_text())
hive = next(package for package in config['packages'] if package['name'] == 'hive')
hive_uri = urlparse(urljoin(config_path.as_uri(), hive['rootUri']))
if hive_uri.scheme != 'file':
    raise SystemExit('Expected a local resolved Hive package')
hive_pubspec = (Path(unquote(hive_uri.path)) / 'pubspec.yaml').read_text()
if not re.search(r'^version: 2\.2\.3\s*$', hive_pubspec, re.MULTILINE):
    raise SystemExit('Resolved Hive package is not 2.2.3')
dart_version = subprocess.check_output([args.dart, '--version'], text=True).strip()
if 'Dart SDK version: 3.11.0 ' not in dart_version:
    raise SystemExit('Use Dart 3.11.0 for reproducible frozen fixtures')
for schema in ('3715778', 'd9e19b6'):
    folder = fixtures / schema
    manifest = json.loads((folder / 'provenance.json').read_text())
    manifest['writerRuntime'] = {'dart': dart_version, 'resolvedHiveVersion': '2.2.3'}
    with tempfile.TemporaryDirectory(prefix='historical-hive-writer-') as temporary:
        temp = Path(temporary)
        for path, digest in manifest['sourceSha256'].items():
            data = (folder / 'source' / (path + '.txt')).read_bytes()
            assert hashlib.sha256(data).hexdigest() == digest, path
            target = temp / path
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
        order = 'order: 8.5,' if schema == 'd9e19b6' else ''
        (temp / 'generate.dart').write_text('''
import 'dart:io';
import 'package:hive/hive.dart';
import 'lib/models/item.dart';
import 'lib/models/token_counter.dart';
import 'lib/models/deck.dart';
import 'lib/models/token_template.dart';
Future<void> main(List<String> args) async {
  Hive.init(args.first);
  Hive.registerAdapter(ItemAdapter());
  Hive.registerAdapter(TokenCounterAdapter());
  Hive.registerAdapter(DeckAdapter());
  Hive.registerAdapter(TokenTemplateAdapter());
  final items = await Hive.openBox<Item>('items');
  final item = Item(name: 'Historical Goblin', pt: '1/1', colors: 'R',
    abilities: 'Haste', amount: 9, tapped: 3, summoningSick: 2,
    counters: [TokenCounter(name: 'charge', amount: 4)],
    createdAt: DateTime.utc(2025, 12, 1), ORDER);
  await items.put(7, item);
  // Exercise a real overwritten frame and a real tombstone.
  item.amount = 11;
  await item.save();
  await items.put('deleted', Item(name: 'Deleted', pt: '2/2',
    createdAt: DateTime.utc(2025, 12, 1)));
  await items.delete('deleted');
  if (args.length > 1) {
    await items.put(8, Item(name: 'Earlier Spirit', pt: '1/1', amount: 2,
      createdAt: DateTime.utc(2025, 11, 1)));
  }
  final decks = await Hive.openBox<Deck>('decks');
  await decks.put('preset', Deck(name: 'Historical setup',
    templates: [TokenTemplate.fromItem(item)]));
  await Hive.close();
  await File('${args.first}/preferences.xml').writeAsString(
    '<map><boolean name="flutter.summoningSicknessEnabled" value="true"/></map>');
}
'''.replace('ORDER', order))
        hashes = {}
        for variant in ('copy', 'multi'):
            output = temp / variant
            output.mkdir()
            command = [args.dart, '--packages=' + str(app / '.dart_tool/package_config.json'), str(temp / 'generate.dart'), str(output)]
            if variant == 'multi':
                command.append('multi')
            subprocess.run(command, check=True)
            for name in ('items.hive', 'decks.hive', 'preferences.xml'):
                data = (output / name).read_bytes()
                target = folder / variant / name
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(data)
                hashes[variant + '/' + name] = hashlib.sha256(data).hexdigest()
        manifest['fixtureSha256'] = hashes
        (folder / 'provenance.json').write_text(json.dumps(manifest, indent=2) + '\n')
