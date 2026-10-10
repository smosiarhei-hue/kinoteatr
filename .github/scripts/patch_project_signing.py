# Path: .github/scripts/patch_project_signing.py
"""Patch project.yml with developer signing credentials."""

import re
import sys
from pathlib import Path


TARGET_SETTINGS_HEADER = re.compile(r"^ {4}settings:\n {6}base:\n", re.M)


def upsert_target_setting(content: str, key: str, value: str) -> str:
    """Replace a build setting in the target's settings.base block, or add it when absent."""
    entry = f"        {key}: {value}"
    pattern = re.compile(rf"^ *{re.escape(key)}:.*$", re.M)
    if pattern.search(content):
        return pattern.sub(lambda _: entry, content, count=1)
    header = TARGET_SETTINGS_HEADER.search(content)
    if not header:
        raise ValueError("target settings.base block not found in project.yml")
    return content[: header.end()] + entry + "\n" + content[header.end():]


def patch_project(project_path: Path, bundle_id: str, team_id: str, identity: str, profile_uuid: str = "") -> str:
    content = project_path.read_text(encoding="utf-8")

    # Replace bundle identifier
    content = re.sub(
        r"PRODUCT_BUNDLE_IDENTIFIER:\s*[A-Za-z0-9_.-]+",
        f"PRODUCT_BUNDLE_IDENTIFIER: {bundle_id}",
        content,
    )
    content = re.sub(
        r"CFBundleURLName:\s*[A-Za-z0-9_.-]+",
        f"CFBundleURLName: {bundle_id}",
        content,
    )

    # Enable signing. Keys already present are rewritten; keys missing from
    # project.yml (for example DEVELOPMENT_TEAM) are added to the target block.
    content = upsert_target_setting(content, "DEVELOPMENT_TEAM", f'"{team_id}"')
    content = upsert_target_setting(content, "CODE_SIGN_IDENTITY", f'"{identity}"')
    content = upsert_target_setting(content, "CODE_SIGN_STYLE", "Manual")
    if profile_uuid:
        content = upsert_target_setting(content, "PROVISIONING_PROFILE_SPECIFIER", profile_uuid)
    content = re.sub(r"CODE_SIGNING_ALLOWED:\s*NO", "CODE_SIGNING_ALLOWED: YES", content)
    content = re.sub(r"CODE_SIGNING_REQUIRED:\s*NO", "CODE_SIGNING_REQUIRED: YES", content)

    project_path.write_text(content, encoding="utf-8")
    return content


if __name__ == "__main__":
    if len(sys.argv) < 4:
        print("Usage: patch_project_signing.py <bundle_id> <team_id> <identity> [profile_uuid] [project_path]")
        sys.exit(1)

    bundle_id_arg = sys.argv[1]
    team_id_arg = sys.argv[2]
    identity_arg = sys.argv[3]
    profile_uuid_arg = sys.argv[4] if len(sys.argv) > 4 else ""
    project_path_arg = Path(sys.argv[5]) if len(sys.argv) > 5 else Path("project.yml")

    patch_project(project_path_arg, bundle_id_arg, team_id_arg, identity_arg, profile_uuid_arg)
    print(f"Successfully patched {project_path_arg} for bundle {bundle_id_arg}, team {team_id_arg}")
