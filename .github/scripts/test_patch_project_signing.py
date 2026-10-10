# Path: .github/scripts/test_patch_project_signing.py
"""Unit tests for project.yml signing patch script."""

import tempfile
import unittest
from pathlib import Path

from patch_project_signing import patch_project, upsert_target_setting


# Mirrors the real Kinoteatr project.yml: the target declares no
# DEVELOPMENT_TEAM, CODE_SIGN_IDENTITY or provisioning profile, and uses
# automatic signing.
SAMPLE_PROJECT_YML = """name: Kinoteatr
options:
  bundleIdPrefix: com.grove.street
  deploymentTarget:
    iOS: "17.0"
  createIntermediateGroups: true

settings:
  base:
    SWIFT_VERSION: "5.9"
    MARKETING_VERSION: "1.0.0"
    CURRENT_PROJECT_VERSION: "1"
    GENERATE_INFOPLIST_FILE: true

targets:
  Kinoteatr:
    type: application
    platform: iOS
    sources:
      - path: Kinoteatr
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: app.hare5681.lyra4838
        INFOPLIST_FILE: Kinoteatr/Support/Info.plist
        TARGETED_DEVICE_FAMILY: "1,2"
        CODE_SIGN_STYLE: Automatic
"""


def patched(tmpdir, **overrides):
    file_path = Path(tmpdir) / "project.yml"
    file_path.write_text(SAMPLE_PROJECT_YML, encoding="utf-8")
    arguments = {
        "project_path": file_path,
        "bundle_id": "app.hare5681.lyra4838",
        "team_id": "4RVYU38Y85",
        "identity": "iPhone Distribution: Yi Guo (4RVYU38Y85)",
        "profile_uuid": "test-uuid",
    }
    arguments.update(overrides)
    patch_project(**arguments)
    return file_path.read_text(encoding="utf-8")


class TestUpsertTargetSetting(unittest.TestCase):
    def test_replaces_existing_key(self):
        content = SAMPLE_PROJECT_YML
        result = upsert_target_setting(content, "CODE_SIGN_STYLE", "Manual")
        self.assertIn("        CODE_SIGN_STYLE: Manual\n", result)
        self.assertNotIn("CODE_SIGN_STYLE: Automatic", result)

    def test_inserts_missing_key_into_target_block(self):
        result = upsert_target_setting(SAMPLE_PROJECT_YML, "DEVELOPMENT_TEAM", '"4RVYU38Y85"')
        self.assertIn('\n        DEVELOPMENT_TEAM: "4RVYU38Y85"\n', result)
        self.assertEqual(result.count("DEVELOPMENT_TEAM"), 1)
        # The root settings block (two-space indent) must stay untouched.
        root_block = result.split("settings:\n  base:\n", 1)[1].split("\ntargets:", 1)[0]
        self.assertNotIn("DEVELOPMENT_TEAM", root_block)

    def test_is_idempotent(self):
        once = upsert_target_setting(SAMPLE_PROJECT_YML, "DEVELOPMENT_TEAM", '"4RVYU38Y85"')
        twice = upsert_target_setting(once, "DEVELOPMENT_TEAM", '"4RVYU38Y85"')
        self.assertEqual(once, twice)

    def test_rejects_manifest_without_target_block(self):
        with self.assertRaises(ValueError):
            upsert_target_setting("name: Kinoteatr\n", "DEVELOPMENT_TEAM", '"4RVYU38Y85"')


class TestPatchProjectSigning(unittest.TestCase):
    def test_keeps_bundle_id_and_enables_signing(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            result = patched(tmpdir)
            self.assertIn("PRODUCT_BUNDLE_IDENTIFIER: app.hare5681.lyra4838", result)
            self.assertIn("CODE_SIGN_STYLE: Manual", result)
            self.assertNotIn("CODE_SIGN_STYLE: Automatic", result)

    def test_adds_missing_signing_keys(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            result = patched(tmpdir)
            self.assertIn('        DEVELOPMENT_TEAM: "4RVYU38Y85"', result)
            self.assertIn('        CODE_SIGN_IDENTITY: "iPhone Distribution: Yi Guo (4RVYU38Y85)"', result)
            self.assertIn("        PROVISIONING_PROFILE_SPECIFIER: test-uuid", result)

    def test_rewrites_placeholder_signing_values(self):
        source = SAMPLE_PROJECT_YML + '        CODE_SIGNING_ALLOWED: NO\n        CODE_SIGNING_REQUIRED: NO\n'
        with tempfile.TemporaryDirectory() as tmpdir:
            file_path = Path(tmpdir) / "project.yml"
            file_path.write_text(source, encoding="utf-8")
            patch_project(file_path, "app.hare5681.lyra4838", "4RVYU38Y85", "iPhone Distribution", "uuid")
            result = file_path.read_text(encoding="utf-8")
            self.assertNotIn("CODE_SIGNING_ALLOWED: NO", result)
            self.assertNotIn("CODE_SIGNING_REQUIRED: NO", result)

    def test_rewrites_url_scheme_bundle_id(self):
        source = SAMPLE_PROJECT_YML + "      properties:\n        CFBundleURLName: com.grove.street.kinoteatr\n"
        with tempfile.TemporaryDirectory() as tmpdir:
            file_path = Path(tmpdir) / "project.yml"
            file_path.write_text(source, encoding="utf-8")
            patch_project(file_path, "app.hare5681.lyra4838", "4RVYU38Y85", "iPhone Distribution", "uuid")
            result = file_path.read_text(encoding="utf-8")
            self.assertIn("CFBundleURLName: app.hare5681.lyra4838", result)
            self.assertNotIn("com.grove.street.kinoteatr", result)

    def test_patching_is_repeatable(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            first = patched(tmpdir)
            second = patched(tmpdir)
            self.assertEqual(first, second)


if __name__ == "__main__":
    unittest.main()