#!/usr/bin/env python3
"""Validate a built, storage-isolated phone preview before combining Pages."""
import argparse
import json
import os
import re
from pathlib import Path

BASE = '/Doubling-Season/preview/phone/'
NAMESPACE = 'phone_preview_v1'


def verify_bootstrap(bootstrap):
    # Flutter 3.41.2 bundles the loader implementation in this file. Its method
    # destructures serviceWorkerSettings even when --pwa-strategy=none emits the
    # default no-argument call. Inspect the invocation, not that library symbol.
    # Only the standard generated bootstrap is supported here; custom/legacy
    # entrypoints fail closed. The publisher also verifies actual registrations
    # in an isolated browser across boot and reload.
    calls = re.findall(r'_flutter\s*\.\s*loader\s*\.\s*load\s*\(([^)]*)\)', bootstrap)
    assert calls == [''], 'Preview requires one unconfigured Flutter loader call'
    assert re.search(r'_flutter\.loader\.load\(\);\s*$', bootstrap), 'Unexpected bootstrap entrypoint'
    assert not re.search(r'_flutter\s*\.\s*loader\s*\.\s*loadEntrypoint\s*\(', bootstrap), 'Legacy worker entrypoint found'


def verify(root):
    meta = json.loads((root / 'preview.json').read_text())
    assert re.fullmatch(r'[0-9a-f]{40}', meta['commit']), 'Missing exact preview SHA'
    assert isinstance(meta['publisherRunId'], int) and meta['publisherRunId'] > 0, 'Missing publisher run'
    expected = os.environ.get('EXPECTED_PREVIEW_COMMIT', '')
    assert not expected or meta['commit'] == expected, 'Retained artifact differs from published preview'
    assert meta['storageNamespace'] == NAMESPACE, 'Unsafe storage namespace'
    assert meta['baseHref'] == BASE, 'Incorrect preview route'
    assert f'<base href="{BASE}">' in (root / 'index.html').read_text()
    for name in ('main.dart.js', 'flutter_bootstrap.js', 'manifest.json',
                 'assets/packages/doubling_season/assets/token_database.json'):
        assert (root / name).is_file() and (root / name).stat().st_size
    assert NAMESPACE.encode() in (root / 'main.dart.js').read_bytes(), 'Namespace missing from compiled app'
    worker = root / 'flutter_service_worker.js'
    assert not worker.exists() or not worker.stat().st_size, 'Preview must not install an offline worker'
    verify_bootstrap((root / 'flutter_bootstrap.js').read_text())
    return meta


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('root', type=Path)
    args = parser.parse_args()
    print(json.dumps(verify(args.root)))
