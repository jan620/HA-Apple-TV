#!/usr/bin/env python3
"""Generate HomeAssistantTV.xcodeproj from the sources on disk.

Xcode project files are tedious to keep in version control by hand and merge
badly, so the project is generated instead. This script uses only the Python
standard library — no XcodeGen, no CocoaPods, nothing to install.

    python3 Tools/generate_xcodeproj.py
    open HomeAssistantTV.xcodeproj

Re-run it whenever Swift files are added or removed.
"""

from __future__ import annotations

import argparse
import hashlib
import os
import re
import shutil
import sys

PROJECT_NAME = "HomeAssistantTV"
BUNDLE_ID = "io.homeassistant.tvos"
DEPLOYMENT_TARGET = "17.0"
SWIFT_VERSION = "5.0"

SOURCE_DIR = "Sources"
RESOURCE_DIR = "Resources"
INFO_PLIST = "Resources/Info.plist"
ASSET_CATALOG = "Resources/Assets.xcassets"

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def object_id(*parts: str) -> str:
    """Stable 24-character hex identifier, so regenerating produces no diff."""
    digest = hashlib.md5("::".join(parts).encode("utf-8")).hexdigest()
    return digest[:24].upper()


QUOTE_SAFE = re.compile(r"^[A-Za-z0-9_./]+$")


def quoted(value: str) -> str:
    if value == "":
        return '""'
    if QUOTE_SAFE.match(value):
        return value
    escaped = value.replace("\\", "\\\\").replace('"', '\\"')
    return f'"{escaped}"'


class PlistWriter:
    """Emits the OpenStep/ASCII plist dialect Xcode itself writes."""

    def __init__(self) -> None:
        self.lines: list[str] = []

    def write(self, value, indent: int = 0) -> str:
        pad = "\t" * indent
        inner = "\t" * (indent + 1)

        if isinstance(value, dict):
            if not value:
                return "{\n" + pad + "}"
            out = ["{"]
            for key in sorted(value.keys()):
                rendered = self.write(value[key], indent + 1)
                out.append(f"{inner}{quoted(key)} = {rendered};")
            out.append(pad + "}")
            return "\n".join(out)

        if isinstance(value, list):
            if not value:
                return "(\n" + pad + ")"
            out = ["("]
            for item in value:
                rendered = self.write(item, indent + 1)
                out.append(f"{inner}{rendered},")
            out.append(pad + ")")
            return "\n".join(out)

        return quoted(str(value))


def collect_sources() -> list[str]:
    result = []
    for dirpath, dirnames, filenames in os.walk(os.path.join(ROOT, SOURCE_DIR)):
        dirnames.sort()
        for name in sorted(filenames):
            if name.endswith(".swift"):
                absolute = os.path.join(dirpath, name)
                result.append(os.path.relpath(absolute, ROOT))
    return result


def build_objects(sources: list[str]) -> tuple[dict, str]:
    objects: dict[str, dict] = {}

    # --- File references and build files -------------------------------------
    source_build_files: list[str] = []
    file_refs: dict[str, str] = {}

    for path in sources:
        ref = object_id("fileRef", path)
        build = object_id("buildFile", path)
        file_refs[path] = ref
        objects[ref] = {
            "isa": "PBXFileReference",
            "lastKnownFileType": "sourcecode.swift",
            "path": os.path.basename(path),
            "sourceTree": "<group>",
        }
        objects[build] = {
            "isa": "PBXBuildFile",
            "fileRef": ref,
        }
        source_build_files.append(build)

    plist_ref = object_id("fileRef", INFO_PLIST)
    objects[plist_ref] = {
        "isa": "PBXFileReference",
        "lastKnownFileType": "text.plist.xml",
        "path": os.path.basename(INFO_PLIST),
        "sourceTree": "<group>",
    }

    assets_ref = object_id("fileRef", ASSET_CATALOG)
    assets_build = object_id("buildFile", ASSET_CATALOG)
    objects[assets_ref] = {
        "isa": "PBXFileReference",
        "lastKnownFileType": "folder.assetcatalog",
        "path": os.path.basename(ASSET_CATALOG),
        "sourceTree": "<group>",
    }
    objects[assets_build] = {"isa": "PBXBuildFile", "fileRef": assets_ref}

    product_ref = object_id("product")
    objects[product_ref] = {
        "isa": "PBXFileReference",
        "explicitFileType": "wrapper.application",
        "includeInIndex": "0",
        "path": f"{PROJECT_NAME}.app",
        "sourceTree": "BUILT_PRODUCTS_DIR",
    }

    # --- Group tree mirroring the directory layout ---------------------------
    # children[directory] = list of child object ids
    directories: dict[str, list[str]] = {}

    def ensure_group(relative_dir: str) -> str:
        if relative_dir in directories:
            return object_id("group", relative_dir)
        group_id = object_id("group", relative_dir)
        directories[relative_dir] = []
        objects[group_id] = {
            "isa": "PBXGroup",
            "children": directories[relative_dir],
            "path": os.path.basename(relative_dir),
            "sourceTree": "<group>",
        }
        parent = os.path.dirname(relative_dir)
        if parent:
            parent_id = ensure_group(parent)
            objects[parent_id]["children"].append(group_id)
        return group_id

    for path in sources:
        group_id = ensure_group(os.path.dirname(path))
        objects[group_id]["children"].append(file_refs[path])

    resources_group = ensure_group(RESOURCE_DIR)
    objects[resources_group]["children"].extend([plist_ref, assets_ref])

    products_group = object_id("group", "Products")
    objects[products_group] = {
        "isa": "PBXGroup",
        "children": [product_ref],
        "name": "Products",
        "sourceTree": "<group>",
    }

    main_group = object_id("group", "__main__")
    objects[main_group] = {
        "isa": "PBXGroup",
        "children": [
            object_id("group", SOURCE_DIR),
            resources_group,
            products_group,
        ],
        "sourceTree": "<group>",
    }

    # Groups are emitted with sorted children so regeneration is deterministic.
    for entry in objects.values():
        if entry.get("isa") == "PBXGroup":
            entry["children"] = sorted(set(entry["children"]))

    # --- Build phases --------------------------------------------------------
    sources_phase = object_id("phase", "sources")
    objects[sources_phase] = {
        "isa": "PBXSourcesBuildPhase",
        "buildActionMask": "2147483647",
        "files": sorted(source_build_files),
        "runOnlyForDeploymentPostprocessing": "0",
    }

    resources_phase = object_id("phase", "resources")
    objects[resources_phase] = {
        "isa": "PBXResourcesBuildPhase",
        "buildActionMask": "2147483647",
        "files": [assets_build],
        "runOnlyForDeploymentPostprocessing": "0",
    }

    frameworks_phase = object_id("phase", "frameworks")
    objects[frameworks_phase] = {
        "isa": "PBXFrameworksBuildPhase",
        "buildActionMask": "2147483647",
        "files": [],
        "runOnlyForDeploymentPostprocessing": "0",
    }

    # --- Build configurations ------------------------------------------------
    shared_project_settings = {
        "ALWAYS_SEARCH_USER_PATHS": "NO",
        "CLANG_ENABLE_MODULES": "YES",
        "CLANG_ENABLE_OBJC_ARC": "YES",
        "COPY_PHASE_STRIP": "NO",
        "ENABLE_STRICT_OBJC_MSGSEND": "YES",
        "GCC_NO_COMMON_BLOCKS": "YES",
        "SDKROOT": "appletvos",
        "SWIFT_VERSION": SWIFT_VERSION,
        "TVOS_DEPLOYMENT_TARGET": DEPLOYMENT_TARGET,
        "TARGETED_DEVICE_FAMILY": "3",
    }

    project_debug = object_id("config", "project", "Debug")
    objects[project_debug] = {
        "isa": "XCBuildConfiguration",
        "buildSettings": dict(
            shared_project_settings,
            DEBUG_INFORMATION_FORMAT="dwarf",
            ENABLE_TESTABILITY="YES",
            GCC_OPTIMIZATION_LEVEL="0",
            GCC_PREPROCESSOR_DEFINITIONS="DEBUG=1 $(inherited)",
            MTL_ENABLE_DEBUG_INFO="INCLUDE_SOURCE",
            ONLY_ACTIVE_ARCH="YES",
            SWIFT_ACTIVE_COMPILATION_CONDITIONS="DEBUG",
            SWIFT_OPTIMIZATION_LEVEL="-Onone",
        ),
        "name": "Debug",
    }

    project_release = object_id("config", "project", "Release")
    objects[project_release] = {
        "isa": "XCBuildConfiguration",
        "buildSettings": dict(
            shared_project_settings,
            DEBUG_INFORMATION_FORMAT="dwarf-with-dsym",
            ENABLE_NS_ASSERTIONS="NO",
            MTL_ENABLE_DEBUG_INFO="NO",
            SWIFT_COMPILATION_MODE="wholemodule",
            SWIFT_OPTIMIZATION_LEVEL="-O",
            VALIDATE_PRODUCT="YES",
        ),
        "name": "Release",
    }

    shared_target_settings = {
        "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": "AccentColor",
        "CODE_SIGN_STYLE": "Automatic",
        "CURRENT_PROJECT_VERSION": "1",
        "ENABLE_PREVIEWS": "YES",
        "GENERATE_INFOPLIST_FILE": "NO",
        "INFOPLIST_FILE": INFO_PLIST,
        "LD_RUNPATH_SEARCH_PATHS": "$(inherited) @executable_path/Frameworks",
        "MARKETING_VERSION": "1.0",
        "PRODUCT_BUNDLE_IDENTIFIER": BUNDLE_ID,
        "PRODUCT_NAME": "$(TARGET_NAME)",
        "SWIFT_EMIT_LOC_STRINGS": "YES",
    }

    target_debug = object_id("config", "target", "Debug")
    objects[target_debug] = {
        "isa": "XCBuildConfiguration",
        "buildSettings": dict(shared_target_settings),
        "name": "Debug",
    }

    target_release = object_id("config", "target", "Release")
    objects[target_release] = {
        "isa": "XCBuildConfiguration",
        "buildSettings": dict(shared_target_settings),
        "name": "Release",
    }

    project_config_list = object_id("configList", "project")
    objects[project_config_list] = {
        "isa": "XCConfigurationList",
        "buildConfigurations": [project_debug, project_release],
        "defaultConfigurationIsVisible": "0",
        "defaultConfigurationName": "Release",
    }

    target_config_list = object_id("configList", "target")
    objects[target_config_list] = {
        "isa": "XCConfigurationList",
        "buildConfigurations": [target_debug, target_release],
        "defaultConfigurationIsVisible": "0",
        "defaultConfigurationName": "Release",
    }

    # --- Target and project --------------------------------------------------
    target_id = object_id("target", PROJECT_NAME)
    objects[target_id] = {
        "isa": "PBXNativeTarget",
        "buildConfigurationList": target_config_list,
        "buildPhases": [sources_phase, frameworks_phase, resources_phase],
        "buildRules": [],
        "dependencies": [],
        "name": PROJECT_NAME,
        "productName": PROJECT_NAME,
        "productReference": product_ref,
        "productType": "com.apple.product-type.application",
    }

    project_id = object_id("project")
    objects[project_id] = {
        "isa": "PBXProject",
        "attributes": {
            "BuildIndependentTargetsInParallel": "1",
            "LastSwiftUpdateCheck": "1500",
            "LastUpgradeCheck": "1500",
            "TargetAttributes": {
                target_id: {"CreatedOnToolsVersion": "15.0"},
            },
        },
        "buildConfigurationList": project_config_list,
        "compatibilityVersion": "Xcode 14.0",
        "developmentRegion": "de",
        "hasScannedForEncodings": "0",
        "knownRegions": ["de", "en", "Base"],
        "mainGroup": main_group,
        "productRefGroup": products_group,
        "projectDirPath": "",
        "projectRoot": "",
        "targets": [target_id],
    }

    return objects, project_id


def render(objects: dict, root_object: str) -> str:
    writer = PlistWriter()
    document = {
        "archiveVersion": "1",
        "classes": {},
        "objectVersion": "56",
        "objects": objects,
        "rootObject": root_object,
    }
    return "// !$*UTF8*$!\n" + writer.write(document) + "\n"


def validate(objects: dict, root_object: str) -> list[str]:
    """Catch dangling references before Xcode ever opens the file."""
    problems: list[str] = []
    known = set(objects.keys())
    pattern = re.compile(r"^[0-9A-F]{24}$")

    def check(value, origin: str) -> None:
        if isinstance(value, dict):
            for key, item in value.items():
                check(item, f"{origin}.{key}")
        elif isinstance(value, list):
            for index, item in enumerate(value):
                check(item, f"{origin}[{index}]")
        elif isinstance(value, str) and pattern.match(value) and value not in known:
            problems.append(f"{origin} verweist auf unbekanntes Objekt {value}")

    for identifier, entry in objects.items():
        check(entry, f"{entry.get('isa', '?')}({identifier})")

    if root_object not in known:
        problems.append("rootObject fehlt")

    for identifier, entry in objects.items():
        if "isa" not in entry:
            problems.append(f"Objekt {identifier} hat kein isa")

    return problems


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--check",
        action="store_true",
        help="Nur prüfen und Zusammenfassung ausgeben, nichts schreiben.",
    )
    args = parser.parse_args()

    sources = collect_sources()
    if not sources:
        print(f"Keine Swift-Dateien unter {SOURCE_DIR}/ gefunden.", file=sys.stderr)
        return 1

    objects, root_object = build_objects(sources)

    problems = validate(objects, root_object)
    if problems:
        for problem in problems:
            print(f"FEHLER: {problem}", file=sys.stderr)
        return 1

    content = render(objects, root_object)

    print(f"{len(sources)} Swift-Dateien, {len(objects)} Projektobjekte.")

    if args.check:
        print("Projektstruktur ist konsistent (nichts geschrieben).")
        return 0

    project_dir = os.path.join(ROOT, f"{PROJECT_NAME}.xcodeproj")
    if os.path.isdir(project_dir):
        shutil.rmtree(project_dir)
    os.makedirs(project_dir)

    with open(os.path.join(project_dir, "project.pbxproj"), "w", encoding="utf-8") as handle:
        handle.write(content)

    workspace_dir = os.path.join(project_dir, "project.xcworkspace")
    os.makedirs(workspace_dir)
    with open(os.path.join(workspace_dir, "contents.xcworkspacedata"), "w", encoding="utf-8") as handle:
        handle.write(
            '<?xml version="1.0" encoding="UTF-8"?>\n'
            '<Workspace version="1.0">\n'
            '   <FileRef location = "self:">\n'
            "   </FileRef>\n"
            "</Workspace>\n"
        )

    print(f"Geschrieben: {os.path.relpath(project_dir, ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
