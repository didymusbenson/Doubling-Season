#!/usr/bin/env python3
"""Regenerate later-schema synthetic Hive bytes with byte-exact archived repository models.
Run from apps/tablet after flutter pub get: python3 tool/generate_later_historical_hive_fixtures.py --dart /path/to/dart
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
folder = fixtures / 'fa577ac'
manifest = json.loads((folder / 'provenance.json').read_text())
manifest['writerRuntime'] = {'dart': dart_version, 'resolvedHiveVersion': '2.2.3'}
with tempfile.TemporaryDirectory(prefix='later-historical-hive-') as temporary:
    temp = Path(temporary)
    for path, digest in manifest['sourceSha256'].items():
        data = (folder / 'source' / (path + '.txt')).read_bytes()
        assert hashlib.sha256(data).hexdigest() == digest, path
        target = temp / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
    driver = app / 'tool/historical_later_fixture_writer.dart.txt'
    manifest['writerSha256'] = hashlib.sha256(driver.read_bytes()).hexdigest()
    (temp / 'generate.dart').write_bytes(driver.read_bytes())
    output = temp / 'copy'
    output.mkdir()
    subprocess.run([args.dart, '--packages=' + str(config_path), str(temp / 'generate.dart'), str(output)], check=True)
    hashes = {}
    for name in ('items', 'decks', 'trackerWidgets', 'toggleWidgets', 'artworkPreferences', 'tokenRules'):
        path = name.lower() + '.hive'
        data = (output / path).read_bytes()
        target = folder / 'copy' / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
        hashes['copy/' + path] = hashlib.sha256(data).hexdigest()
    data = b'<map><boolean name="flutter.summoningSicknessEnabled" value="true"/></map>'
    (folder / 'copy/preferences.xml').write_bytes(data)
    hashes['copy/preferences.xml'] = hashlib.sha256(data).hexdigest()
    manifest['fixtureSha256'] = hashes
    (folder / 'provenance.json').write_text(json.dumps(manifest, indent=2) + '\n')
