"""Refuse to ship an IPA pointed at a missing or unprepared backend."""
import json
import plistlib
import urllib.request
from pathlib import Path

root = Path(__file__).resolve().parents[1]
config = plistlib.loads((root / "apptsst/CloudConfiguration.plist").read_bytes())
assert config["projectURL"].startswith("https://"), "A hosted HTTPS project is required"
assert config["publishableKey"].startswith("sb_publishable_"), "Only the public client key may be packaged"
url = config["projectURL"] + "/functions/v1/listening-api/health"
with urllib.request.urlopen(url, timeout=30) as response:
    status = json.load(response)
assert status.get("service") == "tcf-listening" and status.get("api_version") == 1
assert status.get("seed_ready") is True, "The starter session is not ready"
print("Hosted backend verified; starter session ready.")
