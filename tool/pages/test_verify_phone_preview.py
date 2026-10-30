import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('preview', Path(__file__).with_name('verify_phone_preview.py'))
preview = importlib.util.module_from_spec(spec)
spec.loader.exec_module(preview)


class PreviewValidation(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.metadata = {'commit': 'a' * 40, 'storageNamespace': preview.NAMESPACE, 'baseHref': preview.BASE, 'publisherRunId': 123}
        self.write('preview.json', json.dumps(self.metadata))
        self.write('index.html', f'<base href="{preview.BASE}">')
        for name in ('main.dart.js', 'flutter_bootstrap.js', 'manifest.json',
                     'assets/packages/doubling_season/assets/token_database.json'):
            self.write(name, preview.NAMESPACE)

    def write(self, name, content):
        p = self.root / name
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(content)

    def test_accepts_isolated_complete_build(self):
        self.assertEqual(preview.verify(self.root), self.metadata)

    def test_rejects_production_namespace(self):
        self.metadata['storageNamespace'] = ''
        self.write('preview.json', json.dumps(self.metadata))
        with self.assertRaises(AssertionError):
            preview.verify(self.root)

    def test_rejects_missing_compiled_namespace(self):
        self.write('main.dart.js', 'ordinary production app')
        with self.assertRaises(AssertionError):
            preview.verify(self.root)

    def test_rejects_worker_and_registration(self):
        for name, content in [('flutter_service_worker.js', 'worker'),
                              ('flutter_bootstrap.js', 'serviceWorkerSettings: {}')]:
            with self.subTest(name=name):
                self.write(name, content)
                with self.assertRaises(AssertionError):
                    preview.verify(self.root)
                self.write(name, '')
        self.write('flutter_bootstrap.js', 'bootstrap')
        preview.verify(self.root)

    def test_rejects_wrong_route_or_empty_payload(self):
        self.write('index.html', '<base href="/Doubling-Season/tablet/">')
        with self.assertRaises(AssertionError):
            preview.verify(self.root)
        self.write('index.html', f'<base href="{preview.BASE}">')
        self.write('assets/packages/doubling_season/assets/token_database.json', '')
        with self.assertRaises(AssertionError):
            preview.verify(self.root)


if __name__ == '__main__':
    unittest.main()
