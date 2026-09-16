#!/usr/bin/env python3
"""Inspect the local App Store export without uploading it."""
import argparse
import hashlib
import json
import plistlib
import subprocess
import tempfile
import zipfile
from pathlib import Path

root = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--ipa', type=Path, default=root / 'build/AppStore/KvilApp.ipa')
parser.add_argument('--archive', type=Path, default=root / 'build/Kvil.xcarchive')
parser.add_argument('--output', type=Path, default=root / 'release/archive-verified.json')
args = parser.parse_args()
ipa = args.ipa.resolve()
archive = args.archive.resolve()
metadata = json.loads((root / 'release/metadata.json').read_text())
cloudkit_container = 'iCloud.dev.hkarlsen06.kvil'
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
        executable = (path / info['CFBundleExecutable']).read_bytes()
        assert not any(marker in executable for marker in (
            b'KvilQA-', b'schedule-qa-', b'KVIL_RUN_LIVE_CLOUDKIT', b'KVIL_AUDIT_'
        )), 'Debug audit hooks in export'
        entitlement_bytes = subprocess.run(
            ['codesign', '-d', '--entitlements', ':-', str(path)], check=True,
            capture_output=True).stdout
        entitlements = plistlib.loads(entitlement_bytes)
        assert entitlements.get('get-task-allow') is False, 'Development entitlement in export'
        assert entitlements.get('com.apple.security.application-groups') == ['group.dev.hkarlsen06.kvil']
        assert info['CFBundleShortVersionString'] == metadata['version']
        assert info['MinimumOSVersion'] == '27.0'
        privacy = plistlib.loads((path / 'PrivacyInfo.xcprivacy').read_bytes())
        accessed_apis = privacy.get('NSPrivacyAccessedAPITypes', [])
        if info['CFBundleIdentifier'] == metadata['bundleId']:
            assert any(
                entry.get('NSPrivacyAccessedAPIType') == 'NSPrivacyAccessedAPICategoryUserDefaults'
                and 'CA92.1' in entry.get('NSPrivacyAccessedAPITypeReasons', [])
                for entry in accessed_apis
            ), 'Phone export is missing the UserDefaults CA92.1 privacy declaration'
        assert all((path / f'{locale}.lproj').is_dir() for locale in ('en', 'nb'))
        profile = plistlib.loads(subprocess.run(
            ['security', 'cms', '-D', '-i', str(path / 'embedded.mobileprovision')],
            check=True, capture_output=True).stdout)
        assert 'ProvisionedDevices' not in profile, 'Device-limited profile in App Store export'
        if info['CFBundleIdentifier'] == metadata['bundleId']:
            assert entitlements.get('com.apple.developer.icloud-container-identifiers') == [
                cloudkit_container
            ], 'Phone export has the wrong CloudKit container'
            assert entitlements.get('com.apple.developer.icloud-services') == ['CloudKit'], \
                'Phone export is missing the CloudKit service'
            assert entitlements.get('com.apple.developer.icloud-container-environment') == 'Production', \
                'Phone export is not using the production CloudKit environment'
            assert entitlements.get('aps-environment') == 'production', \
                'Phone export is missing production push authorization'
            assert 'remote-notification' in info.get('UIBackgroundModes', []), \
                'Phone export cannot receive background CloudKit notifications'
            profile_entitlements = profile.get('Entitlements', {})
            assert cloudkit_container in profile_entitlements.get(
                'com.apple.developer.icloud-container-identifiers', []
            ), 'Phone distribution profile does not authorize the CloudKit container'
            profile_services = profile_entitlements.get('com.apple.developer.icloud-services', [])
            assert profile_services == '*' or profile_services == 'CloudKit' or (
                isinstance(profile_services, list) and 'CloudKit' in profile_services
            ), 'Phone distribution profile does not authorize CloudKit'
            profile_environment = profile_entitlements.get(
                'com.apple.developer.icloud-container-environment')
            assert profile_environment == 'Production' or (
                isinstance(profile_environment, list) and 'Production' in profile_environment
            ), 'Phone distribution profile does not authorize production CloudKit'
            assert profile_entitlements.get('aps-environment') == 'production', \
                'Phone distribution profile does not authorize production push'
        bundles.append({
            'bundle': info['CFBundleIdentifier'], 'version': info['CFBundleShortVersionString'],
            'build': info['CFBundleVersion'], 'minimumOS': info['MinimumOSVersion'],
            'sdk': info['DTSDKName'], 'signatureValid': True, 'entitlements': entitlements,
            'privacyManifest': True, 'accessedAPIs': accessed_apis, 'localizations': ['en', 'nb'],
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
    'exportedBundles': bundles, 'debugResourcesAbsent': True, 'debugAuditHooksAbsent': True,
    'uploaded': False,
    'cloudKit': {'container': cloudkit_container, 'environment': 'Production',
                 'productionProfileVerified': True, 'backgroundPushConfigured': True},
}
args.output.write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps({'status': 'SUCCESS', 'build': bundles[0]['build'],
                  'bundlesVerified': len(bundles), 'ipaSha256': result['sha256'], 'uploaded': False}))
