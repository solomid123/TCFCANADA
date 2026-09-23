"""Validate the packaged device app, without claiming it is Apple-signed."""
import hashlib
import plistlib
import sys
import zipfile
from pathlib import Path

path = Path(sys.argv[1])
with zipfile.ZipFile(path) as archive:
    assert archive.testzip() is None, "IPA contains a corrupt entry"
    plists = [name for name in archive.namelist() if name.startswith("Payload/") and name.count("/") == 2 and name.endswith(".app/Info.plist")]
    assert len(plists) == 1, "Expected exactly one Payload app"
    info_path = plists[0]
    prefix = info_path.removesuffix("Info.plist")
    info = plistlib.loads(archive.read(info_path))
    cloud = plistlib.loads(archive.read(prefix + "CloudConfiguration.plist"))
    assert cloud["projectURL"].startswith("https://")
    assert cloud["publishableKey"].startswith("sb_publishable_")
    assert info["CFBundleIdentifier"] == "com.aetheris.tcfcanada"
    assert info["CFBundleSupportedPlatforms"] == ["iPhoneOS"], "Not a device build"
    assert info.get("NSMicrophoneUsageDescription"), "Missing microphone usage description"
    assert prefix + info["CFBundleExecutable"] in archive.namelist(), "Missing executable"
    assert not any(name.endswith(".xctest/") for name in archive.namelist()), "Test bundle must not be packaged"
    assert not any(".env" in Path(name).parts for name in archive.namelist()), "Environment configuration must not be packaged"
    print(f"Verified device IPA: {path}")
    print(f"Version: {info['CFBundleShortVersionString']} ({info['CFBundleVersion']})")
    print(f"Minimum iOS: {info['MinimumOSVersion']}")
    print("Connection: automatic hosted device session; no manual server setup.")
    print(f"Size: {path.stat().st_size / 1024 / 1024:.1f} MiB")
    print(f"SHA-256: {hashlib.file_digest(path.open('rb'), 'sha256').hexdigest()}")
    print("Signing: unsigned; use a sideloading tool to sign before installing.")
