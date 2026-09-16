#!/usr/bin/env bash
set -euo pipefail
ARCHIVE_PATH="${XCODE_EXPORT_AGENT_ARCHIVE_PATH:-build/Kvil.xcarchive}"
EXPORT_PATH="${XCODE_EXPORT_AGENT_EXPORT_PATH:-build/AppStore}"
LOG_PATH="${XCODE_EXPORT_AGENT_LOG_PATH:-build/export.log}"
mkdir -p "$(dirname "$LOG_PATH")"
if [ -n "${KVIL_ASC_ENV_FILE:-}" ]; then
  source "$KVIL_ASC_ENV_FILE"
fi
PROVISIONING_ARGS=(-allowProvisioningUpdates)
if [ -n "${ASC_KEY_PATH:-}" ]; then
  PROVISIONING_ARGS+=(-authenticationKeyPath "$ASC_KEY_PATH" -authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID")
fi
set +e
xcodebuild -exportArchive -archivePath "$ARCHIVE_PATH" -exportPath "$EXPORT_PATH" -exportOptionsPlist release/ExportOptions.plist "${PROVISIONING_ARGS[@]}" >"$LOG_PATH" 2>&1
EXPORT_RESULT=$?
set -e
python3 - "$EXPORT_RESULT" "$ARCHIVE_PATH" "$EXPORT_PATH" "$LOG_PATH" <<'PYJSON'
import json, sys
from pathlib import Path
code, archive, export, log = sys.argv[1:]
print(json.dumps({"status": "SUCCESS" if code == "0" else "FAILURE", "archive_path": archive, "export_path": export, "log_path": log, "ipa_files": [str(p) for p in Path(export).glob("*.ipa")], "uploaded": False}))
PYJSON
exit "$EXPORT_RESULT"
