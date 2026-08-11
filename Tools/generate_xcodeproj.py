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
TEST_TARGET_NAME = "HomeAssistantTVTests"
BUNDLE_ID = "io.homeassistant.tvos"
DEPLOYMENT_TARGET = "17.0"
SWIFT_VERSION = "5.0"

SOURCE_DIR = "Sources"
TEST_DIR = "Tests"
RESOURCE_DIR = "Resources"
INFO_PLIST = "Resources/Info.plist"
ASSET_CATALOG = "Resources/Assets.xcassets"
STOREKIT_CONFIG = "Resources/Products.storekit"

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


def collect_sources(directory: str) -> list[str]:
    result = []
    for dirpath, dirnames, filenames in os.walk(os.path.join(ROOT, directory)):
        dirnames.sort()
        for name in sorted(filenames):
            if name.endswith(".swift"):
                absolute = os.path.join(dirpath, name)
                result.append(os.path.relpath(absolute, ROOT))
    return result


def build_objects(sources: list[str], test_sources: list[str]) -> tuple[dict, str]:
    objects: dict[str, dict] = {}

    # --- File references and build files -------------------------------------
    source_build_files: list[str] = []
    test_build_files: list[str] = []
    file_refs: dict[str, str] = {}

    for path in sources + test_sources:
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
        if path in test_sources:
            test_build_files.append(build)
        else:
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

    test_product_ref = object_id("product", "tests")
    if test_sources:
        objects[test_product_ref] = {
            "isa": "PBXFileReference",
            "explicitFileType": "wrapper.cfbundle",
            "includeInIndex": "0",
            "path": f"{TEST_TARGET_NAME}.xctest",
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

    for path in sources + test_sources:
        group_id = ensure_group(os.path.dirname(path))
        objects[group_id]["children"].append(file_refs[path])

    resources_group = ensure_group(RESOURCE_DIR)
    objects[resources_group]["children"].extend([plist_ref, assets_ref])

    products_group = object_id("group", "Products")
    objects[products_group] = {
        "isa": "PBXGroup",
        "children": [product_ref] + ([test_product_ref] if test_sources else []),
        "name": "Products",
        "sourceTree": "<group>",
    }

    main_children = [object_id("group", SOURCE_DIR), resources_group, products_group]
    if test_sources:
        main_children.append(object_id("group", TEST_DIR))

    main_group = object_id("group", "__main__")
    objects[main_group] = {
        "isa": "PBXGroup",
        "children": main_children,
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

    # --- Test target ---------------------------------------------------------
    test_target_id = object_id("target", TEST_TARGET_NAME)
    if test_sources:
        test_sources_phase = object_id("phase", "test-sources")
        objects[test_sources_phase] = {
            "isa": "PBXSourcesBuildPhase",
            "buildActionMask": "2147483647",
            "files": sorted(test_build_files),
            "runOnlyForDeploymentPostprocessing": "0",
        }

        test_frameworks_phase = object_id("phase", "test-frameworks")
        objects[test_frameworks_phase] = {
            "isa": "PBXFrameworksBuildPhase",
            "buildActionMask": "2147483647",
            "files": [],
            "runOnlyForDeploymentPostprocessing": "0",
        }

        # Host-based unit tests: the bundle is loaded into the app so
        # `@testable import` can reach internal types.
        test_settings = {
            "BUNDLE_LOADER": "$(TEST_HOST)",
            "TEST_HOST": f"$(BUILT_PRODUCTS_DIR)/{PROJECT_NAME}.app/{PROJECT_NAME}",
            "CODE_SIGN_STYLE": "Automatic",
            "GENERATE_INFOPLIST_FILE": "YES",
            "PRODUCT_BUNDLE_IDENTIFIER": f"{BUNDLE_ID}.tests",
            "PRODUCT_NAME": "$(TARGET_NAME)",
        }

        test_debug = object_id("config", "test", "Debug")
        objects[test_debug] = {
            "isa": "XCBuildConfiguration",
            "buildSettings": dict(test_settings),
            "name": "Debug",
        }
        test_release = object_id("config", "test", "Release")
        objects[test_release] = {
            "isa": "XCBuildConfiguration",
            "buildSettings": dict(test_settings),
            "name": "Release",
        }

        test_config_list = object_id("configList", "test")
        objects[test_config_list] = {
            "isa": "XCConfigurationList",
            "buildConfigurations": [test_debug, test_release],
            "defaultConfigurationIsVisible": "0",
            "defaultConfigurationName": "Release",
        }

        proxy_id = object_id("proxy", "app")
        objects[proxy_id] = {
            "isa": "PBXContainerItemProxy",
            "containerPortal": object_id("project"),
            "proxyType": "1",
            "remoteGlobalIDString": object_id("target", PROJECT_NAME),
            "remoteInfo": PROJECT_NAME,
        }

        dependency_id = object_id("dependency", "app")
        objects[dependency_id] = {
            "isa": "PBXTargetDependency",
            "target": object_id("target", PROJECT_NAME),
            "targetProxy": proxy_id,
        }

        objects[test_target_id] = {
            "isa": "PBXNativeTarget",
            "buildConfigurationList": test_config_list,
            "buildPhases": [test_sources_phase, test_frameworks_phase],
            "buildRules": [],
            "dependencies": [dependency_id],
            "name": TEST_TARGET_NAME,
            "productName": TEST_TARGET_NAME,
            "productReference": test_product_ref,
            "productType": "com.apple.product-type.bundle.unit-test",
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
            "TargetAttributes": dict(
                {target_id: {"CreatedOnToolsVersion": "15.0"}},
                **(
                    {
                        test_target_id: {
                            "CreatedOnToolsVersion": "15.0",
                            "TestTargetID": target_id,
                        }
                    }
                    if test_sources
                    else {}
                ),
            ),
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
        "targets": [target_id] + ([test_target_id] if test_sources else []),
    }

    return objects, project_id


SCHEME_TEMPLATE = """<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1500" version="1.7">
   <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES">
      <BuildActionEntries>
         <BuildActionEntry buildForTesting="YES" buildForRunning="YES" \
buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">
            {app_reference}
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction buildConfiguration="Debug" \
selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" \
selectedLauncherIdentifier="Xcode.DebuggerFoundation.Launcher.LLDB" \
shouldUseLaunchSchemeArgsEnv="YES">
      <Testables>
{testables}
      </Testables>
   </TestAction>
   <LaunchAction buildConfiguration="Debug" \
selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" \
selectedLauncherIdentifier="Xcode.DebuggerFoundation.Launcher.LLDB" \
launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" \
debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES">
      <BuildableProductRunnable runnableDebuggingMode="0">
         {app_reference}
      </BuildableProductRunnable>{storekit}
   </LaunchAction>
   <ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" \
savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES">
      <BuildableProductRunnable runnableDebuggingMode="0">
         {app_reference}
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction buildConfiguration="Debug"/>
   <ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>
"""


def buildable_reference(blueprint_id: str, name: str, product: str) -> str:
    return (
        '<BuildableReference BuildableIdentifier="primary" '
        f'BlueprintIdentifier="{blueprint_id}" '
        f'BuildableName="{product}" '
        f'BlueprintName="{name}" '
        f'ReferencedContainer="container:{PROJECT_NAME}.xcodeproj"/>'
    )


def render_scheme(has_tests: bool) -> str:
    """A shared scheme so `xcodebuild -scheme` and Cmd-U work on a fresh clone.

    Without one, Xcode invents a scheme per target on first open and the test
    bundle is not wired into the app scheme's test action.
    """
    app_reference = buildable_reference(
        object_id("target", PROJECT_NAME), PROJECT_NAME, f"{PROJECT_NAME}.app"
    )

    testables = ""
    if has_tests:
        test_reference = buildable_reference(
            object_id("target", TEST_TARGET_NAME),
            TEST_TARGET_NAME,
            f"{TEST_TARGET_NAME}.xctest",
        )
        testables = (
            '         <TestableReference skipped="NO">\n'
            f"            {test_reference}\n"
            "         </TestableReference>"
        )

    # Lets the tip jar show real products in a local build, without anything
    # existing in App Store Connect yet. The path is relative to the scheme.
    storekit = ""
    if os.path.exists(os.path.join(ROOT, STOREKIT_CONFIG)):
        storekit = (
            "\n      <StoreKitConfigurationFileReference "
            f'identifier = "../../../{STOREKIT_CONFIG}">\n'
            "      </StoreKitConfigurationFileReference>"
        )

    return SCHEME_TEMPLATE.format(
        app_reference=app_reference,
        testables=testables,
        storekit=storekit,
    )


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

    sources = collect_sources(SOURCE_DIR)
    if not sources:
        print(f"Keine Swift-Dateien unter {SOURCE_DIR}/ gefunden.", file=sys.stderr)
        return 1

    test_sources = collect_sources(TEST_DIR)

    objects, root_object = build_objects(sources, test_sources)

    problems = validate(objects, root_object)
    if problems:
        for problem in problems:
            print(f"FEHLER: {problem}", file=sys.stderr)
        return 1

    content = render(objects, root_object)

    print(
        f"{len(sources)} Swift-Dateien, {len(test_sources)} Testdateien, "
        f"{len(objects)} Projektobjekte."
    )

    if args.check:
        print("Projektstruktur ist konsistent (nichts geschrieben).")
        return 0

    project_dir = os.path.join(ROOT, f"{PROJECT_NAME}.xcodeproj")
    if os.path.isdir(project_dir):
        shutil.rmtree(project_dir)
    os.makedirs(project_dir)

    with open(os.path.join(project_dir, "project.pbxproj"), "w", encoding="utf-8") as handle:
        handle.write(content)

    schemes_dir = os.path.join(project_dir, "xcshareddata", "xcschemes")
    os.makedirs(schemes_dir)
    with open(os.path.join(schemes_dir, f"{PROJECT_NAME}.xcscheme"), "w", encoding="utf-8") as handle:
        handle.write(render_scheme(bool(test_sources)))

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
