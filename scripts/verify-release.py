#!/usr/bin/env python3
"""Inspect the local App Store export without uploading it."""
import hashlib
import json
import plistlib
import subprocess
import tempfile
import zipfile
from pathlib import Path

root = Path(__file__).resolve().parent.parent
ipa = root / 'build/AppStore/KvilApp.ipa'
archive = root / 'build/Kvil.xcarchive'
metadata = json.loads((root / 'release/metadata.json').read_text())
expected = {
    'dev.hkarlsen06.kvil',
    'dev.hkarlsen06.kvil.widget',
    'dev.hkarlsen06.kvil.watchkitapp',
    'dev.hkarlsen06.kvil.watchkitapp.widget',
}
bundles = []
with tempfile.TemporaryDirectory(prefix='kvil-export-check-') as temporary:
    unpacked = Path(temporary)
    with zipfile.ZipFile(ipa) as zipped:
        names = zipped.namelist()
        assert not any(part in n for n in names for part in
                       ('.storekit', 'StoreKitTest', '.debug.dylib', '__preview')), 'Debug resources in export'
        zipped.extractall(unpacked)
    app = unpacked / 'Payload/KvilApp.app'
    for path in [app, *sorted(app.rglob('*.app')), *sorted(app.rglob('*.appex'))]:
        subprocess.run(['codesign', '--verify', '--strict', str(path)], check=True,
                       stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
        info = plistlib.loads((path / 'Info.plist').read_bytes())
        entitlement_bytes = subprocess.run(
            ['codesign', '-d', '--entitlements', ':-', str(path)], check=True,
            capture_output=True).stdout
        entitlements = plistlib.loads(entitlement_bytes)
        assert entitlements.get('get-task-allow') is False, 'Development entitlement in export'
        assert entitlements.get('com.apple.security.application-groups') == ['group.dev.hkarlsen06.kvil']
        assert info['CFBundleShortVersionString'] == metadata['version']
        assert info['MinimumOSVersion'] == '27.0'
        assert (path / 'PrivacyInfo.xcprivacy').is_file()
        assert all((path / f'{locale}.lproj').is_dir() for locale in ('en', 'nb'))
        profile = plistlib.loads(subprocess.run(
            ['security', 'cms', '-D', '-i', str(path / 'embedded.mobileprovision')],
            check=True, capture_output=True).stdout)
        assert 'ProvisionedDevices' not in profile, 'Device-limited profile in App Store export'
        bundles.append({
            'bundle': info['CFBundleIdentifier'], 'version': info['CFBundleShortVersionString'],
            'build': info['CFBundleVersion'], 'minimumOS': info['MinimumOSVersion'],
            'sdk': info['DTSDKName'], 'signatureValid': True, 'entitlements': entitlements,
            'privacyManifest': True, 'localizations': ['en', 'nb'],
            'profileName': profile['Name'],
        })
    assert {b['bundle'] for b in bundles} == expected
    assert len({b['build'] for b in bundles}) == 1, 'Mismatched embedded build numbers'
    phone = next(b for b in bundles if b['bundle'] == metadata['bundleId'])
    assert phone['entitlements'].get('com.apple.developer.healthkit') is True
    assert phone['entitlements'].get('com.apple.developer.ubiquity-kvstore-identifier')
result = {
    'archive': str(archive.relative_to(root)), 'ipa': str(ipa.relative_to(root)),
    'sha256': hashlib.sha256(ipa.read_bytes()).hexdigest(), 'bytes': ipa.stat().st_size,
    'exportedBundles': bundles, 'debugResourcesAbsent': True, 'uploaded': False,
}
(root / 'release/archive-verified.json').write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps({'status': 'SUCCESS', 'build': bundles[0]['build'],
                  'bundlesVerified': len(bundles), 'ipaSha256': result['sha256'], 'uploaded': False}))
