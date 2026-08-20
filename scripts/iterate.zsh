#!/bin/zsh

set -euo pipefail

if [[ "${ITERATE_FROM_JUST:-}" != "1" ]]; then
    print -u2 -- "error: scripts/iterate.zsh is internal; use 'just --list'"
    exit 64
fi

action="${1:-}"
operation_timeout="${2:-300}"
argument="${3:-}"

if [[ -z "$action" || "$operation_timeout" != <1-> ]]; then
    print -u2 -- "error: invalid internal invocation"
    exit 64
fi

: "${XCODE_PATH:?}"
: "${PROJECT:?}"
: "${SCHEME:?}"
: "${CONFIGURATION:?}"
: "${DEVELOPMENT_TEAM:?}"
: "${BUNDLE_ID:?}"
: "${PHYSICAL_DESTINATION_ID:?}"
: "${PHYSICAL_DEVICE_ID:?}"
: "${SIMULATOR_ID:?}"
: "${DERIVED_DATA_ROOT:?}"
: "${TEST_CASE_TIMEOUT:?}"

export DEVELOPER_DIR="$XCODE_PATH/Contents/Developer"

readonly xcodebuild="$DEVELOPER_DIR/usr/bin/xcodebuild"
readonly xcrun="/usr/bin/xcrun"
readonly simulator_derived_data="$DERIVED_DATA_ROOT/simulator"
readonly device_derived_data="$DERIVED_DATA_ROOT/device"
readonly swiftpm_scratch="$DERIVED_DATA_ROOT/swiftpm"
readonly module_cache="$DERIVED_DATA_ROOT/module-cache"
readonly simulator_app="$simulator_derived_data/Build/Products/${CONFIGURATION}-iphonesimulator/count_calories.app"
readonly release_simulator_app="$simulator_derived_data/Build/Products/Release-iphonesimulator/count_calories.app"
readonly device_app="$device_derived_data/Build/Products/${CONFIGURATION}-iphoneos/count_calories.app"
readonly release_archive="$device_derived_data/Archives/CountCalories.xcarchive"
readonly release_export="$device_derived_data/Export"
readonly release_export_options="$device_derived_data/ExportOptions.plist"
readonly test_diagnostics="$DERIVED_DATA_ROOT/test-diagnostics"

export CLANG_MODULE_CACHE_PATH="$module_cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$module_cache"

# Run a command in its own process group and bound the whole process tree. This
# covers tools such as xcodebuild whose children can otherwise outlive a timeout.
run_with_timeout() {
    local timeout="$1"
    shift

    /usr/bin/perl -MPOSIX=:sys_wait_h,setpgid -MTime::HiRes=time,sleep -e '
        my $timeout = shift @ARGV;
        my $pid = fork();
        die "fork failed: $!\n" unless defined $pid;
        if ($pid == 0) {
            setpgid(0, 0);
            exec { $ARGV[0] } @ARGV;
            die "exec failed: $!\n";
        }
        setpgid($pid, $pid);
        my $deadline = time() + $timeout;
        my $status;
        while (1) {
            my $result = waitpid($pid, WNOHANG);
            if ($result == $pid) {
                $status = $?;
                last;
            }
            if (time() >= $deadline) {
                warn "error: command timed out after ${timeout}s; terminating its process group\n";
                kill "TERM", -$pid;
                my $grace = time() + 5;
                while (time() < $grace) {
                    if (waitpid($pid, WNOHANG) == $pid) { exit 124; }
                    sleep 0.1;
                }
                kill "KILL", -$pid;
                waitpid($pid, 0);
                exit 124;
            }
            sleep 0.1;
        }
        exit(WIFEXITED($status) ? WEXITSTATUS($status) : 128 + WTERMSIG($status));
    ' "$timeout" "$@"
}

run_step() {
    local label="$1"
    local timeout="$2"
    shift 2
    local started=$SECONDS

    print -- "→ $label (timeout ${timeout}s)"
    if run_with_timeout "$timeout" "$@"; then
        print -- "✓ $label ($((SECONDS - started))s)"
    else
        local exit_code=$?
        print -u2 -- "✗ $label failed with status $exit_code ($((SECONDS - started))s)"
        return "$exit_code"
    fi
}

simulator_common_args=(
    -project "$PROJECT"
    -scheme "$SCHEME"
    -configuration "$CONFIGURATION"
    -destination "platform=iOS Simulator,id=$SIMULATOR_ID"
    -derivedDataPath "$simulator_derived_data"
    -quiet
    COMPILER_INDEX_STORE_ENABLE=NO
)

release_simulator_common_args=(
    -project "$PROJECT"
    -scheme "$SCHEME"
    -configuration Release
    -destination "platform=iOS Simulator,id=$SIMULATOR_ID"
    -derivedDataPath "$simulator_derived_data"
    -quiet
    COMPILER_INDEX_STORE_ENABLE=NO
)

release_validation_test_args=(
    -project "$PROJECT"
    -scheme "$SCHEME"
    -configuration Release
    -destination "platform=iOS Simulator,id=$SIMULATOR_ID"
    -derivedDataPath "$simulator_derived_data"
    -quiet
    COMPILER_INDEX_STORE_ENABLE=NO
    ENABLE_TESTABILITY=YES
    SWIFT_ACTIVE_COMPILATION_CONDITIONS=RELEASE_VALIDATION
)

device_common_args=(
    -project "$PROJECT"
    -scheme "$SCHEME"
    -configuration "$CONFIGURATION"
    -destination "platform=iOS,id=$PHYSICAL_DESTINATION_ID"
    -derivedDataPath "$device_derived_data"
    -quiet
    COMPILER_INDEX_STORE_ENABLE=NO
)

release_archive_args=(
    -project "$PROJECT"
    -scheme "$SCHEME"
    -configuration Release
    -destination "generic/platform=iOS"
    -derivedDataPath "$device_derived_data"
    -archivePath "$release_archive"
    -quiet
    DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM"
    COMPILER_INDEX_STORE_ENABLE=NO
)

test_options=(
    -parallel-testing-enabled NO
    -maximum-concurrent-test-simulator-destinations 1
    -test-timeouts-enabled YES
    -default-test-execution-time-allowance "$TEST_CASE_TIMEOUT"
    -maximum-test-execution-time-allowance 60
)

list_simulator_runtimes() {
    run_step "List installed simulator runtimes" "$operation_timeout" \
        "$xcrun" simctl list runtimes
}

install_simulator_runtime() {
    if ! /usr/bin/python3 -c 'import re, sys; raise SystemExit(0 if re.fullmatch(r"[0-9]+(?:\.[0-9]+){1,2}", sys.argv[1]) else 1)' "$argument"; then
        print -u2 -- "error: simulator-runtime-install requires an exact numeric version such as 17.5"
        return 64
    fi
    if run_step "Download and install iOS $argument simulator runtime with Xcode" "$operation_timeout" \
        "$xcodebuild" -downloadPlatform iOS -buildVersion "$argument"; then
        return 0
    fi

    local xcodes
    xcodes="$(command -v xcodes || true)"
    if [[ -z "$xcodes" ]]; then
        print -u2 -- "error: configured Xcode does not offer iOS $argument; install the 'xcodes' tool to use Apple's archived runtime catalog"
        return 69
    fi
    local download_directory="$DERIVED_DATA_ROOT/runtime-downloads"
    /bin/mkdir -p "$download_directory"
    run_step "Download and install archived iOS $argument simulator runtime" "$operation_timeout" \
        "$xcodes" runtimes install "iOS $argument" \
        --architecture arm64 \
        --directory "$download_directory" \
        --no-color
}

create_ios17_simulator() {
    local runtimes device_types devices runtime_id device_type_id existing_id created_id
    runtimes="$(/usr/bin/mktemp -t count-calories-runtimes.XXXXXX)"
    device_types="$(/usr/bin/mktemp -t count-calories-device-types.XXXXXX)"
    devices="$(/usr/bin/mktemp -t count-calories-devices.XXXXXX)"
    trap "/bin/rm -f '$runtimes' '$device_types' '$devices'" EXIT

    run_with_timeout 20 "$xcrun" simctl list runtimes -j > "$runtimes"
    runtime_id="$(/usr/bin/python3 -c '
import json, sys
items = []
for runtime in json.load(open(sys.argv[1])).get("runtimes", []):
    version = runtime.get("version", "")
    if runtime.get("isAvailable") and version.split(".", 1)[0] == "17":
        parts = tuple(int(part) for part in version.split("."))
        items.append((parts, runtime.get("identifier", "")))
if not items:
    raise SystemExit(1)
print(max(items)[1])
' "$runtimes")" || {
        print -u2 -- "error: no available iOS 17 simulator runtime; run 'just simulator-runtime-install 17.5' first"
        return 66
    }

    run_with_timeout 20 "$xcrun" simctl list devicetypes -j > "$device_types"
    device_type_id="$(/usr/bin/python3 -c '
import json, sys
items = json.load(open(sys.argv[1])).get("devicetypes", [])
for preferred in ("iPhone 15 Pro", "iPhone 15", "iPhone 14 Pro", "iPhone 14"):
    for item in items:
        if item.get("name") == preferred:
            print(item["identifier"])
            raise SystemExit(0)
for item in items:
    if item.get("name", "").startswith("iPhone"):
        print(item["identifier"])
        raise SystemExit(0)
raise SystemExit(1)
' "$device_types")" || {
        print -u2 -- "error: no iPhone simulator device type is installed"
        return 66
    }

    run_with_timeout 20 "$xcrun" simctl list devices -j > "$devices"
    existing_id="$(/usr/bin/python3 -c '
import json, sys
data, runtime_id = json.load(open(sys.argv[1])), sys.argv[2]
for device in data.get("devices", {}).get(runtime_id, []):
    if device.get("name") == "Count Calories iOS 17" and device.get("isAvailable", True):
        print(device["udid"])
        raise SystemExit(0)
raise SystemExit(1)
' "$devices" "$runtime_id")" || true
    if [[ -n "$existing_id" ]]; then
        print -- "✓ Existing Count Calories iOS 17 simulator: $existing_id"
        return 0
    fi

    print -- "→ Create Count Calories iOS 17 simulator"
    created_id="$(run_with_timeout 30 "$xcrun" simctl create \
        "Count Calories iOS 17" "$device_type_id" "$runtime_id")"
    print -- "✓ Created Count Calories iOS 17 simulator: $created_id"
}

verify_required_simulator_os() {
    local required_major="${REQUIRED_SIMULATOR_OS_MAJOR:-}"
    [[ -z "$required_major" ]] && return 0
    if [[ "$required_major" != <1-> ]]; then
        print -u2 -- "error: REQUIRED_SIMULATOR_OS_MAJOR must be an integer"
        return 64
    fi

    local runtimes
    runtimes="$(/usr/bin/mktemp -t count-calories-runtimes.XXXXXX)"
    if ! run_with_timeout 20 "$xcrun" simctl list devices -j > "$runtimes"; then
        /bin/rm -f "$runtimes"
        return 1
    fi
    if /usr/bin/python3 -c '
import json, sys
path, device_id, major = sys.argv[1:]
data = json.load(open(path))
for runtime, devices in data.get("devices", {}).items():
    if any(device.get("udid") == device_id for device in devices):
        marker = f"iOS-{major}-"
        raise SystemExit(0 if marker in runtime else 2)
raise SystemExit(3)
' "$runtimes" "$SIMULATOR_ID" "$required_major"; then
        :
    else
        local exit_code=$?
        /bin/rm -f "$runtimes"
        print -u2 -- "error: configured simulator $SIMULATOR_ID is not on required iOS $required_major runtime (status $exit_code)"
        return 1
    fi
    /bin/rm -f "$runtimes"
    print -- "✓ Configured simulator uses required iOS $required_major runtime"
}

ensure_simulator_ready() {
    local device_list
    device_list="$(/usr/bin/mktemp -t count-calories-devices.XXXXXX)"
    if ! run_with_timeout 20 "$xcrun" simctl list devices > "$device_list"; then
        /bin/rm -f "$device_list"
        return 1
    fi

    if ! /usr/bin/grep -Fq "$SIMULATOR_ID) (Booted)" "$device_list"; then
        run_step "Boot simulator" 30 "$xcrun" simctl boot "$SIMULATOR_ID"
    fi
    /bin/rm -f "$device_list"
    run_step "Wait for simulator readiness" 45 "$xcrun" simctl bootstatus "$SIMULATOR_ID" -b
}

terminate_simulator_app() {
    run_with_timeout 15 "$xcrun" simctl terminate "$SIMULATOR_ID" "$BUNDLE_ID" >/dev/null 2>&1 || true
}

stop_simulator() {
    local device_list
    device_list="$(/usr/bin/mktemp -t count-calories-devices.XXXXXX)"
    if ! run_with_timeout 20 "$xcrun" simctl list devices > "$device_list"; then
        /bin/rm -f "$device_list"
        return 1
    fi

    if /usr/bin/grep -Fq "$SIMULATOR_ID) (Booted)" "$device_list"; then
        /bin/rm -f "$device_list"
        terminate_simulator_app
        run_step "Shut down simulator" 30 "$xcrun" simctl shutdown "$SIMULATOR_ID"
    else
        /bin/rm -f "$device_list"
        print -- "✓ Simulator already shut down"
    fi
}

reset_simulator() {
    run_with_timeout 30 "$xcrun" simctl shutdown "$SIMULATOR_ID" >/dev/null 2>&1 || true
    ensure_simulator_ready
}

erase_simulator() {
    stop_simulator
    run_step "Erase configured simulator data" "$operation_timeout" \
        "$xcrun" simctl erase "$SIMULATOR_ID"
}

build_simulator() {
    run_step "Incremental simulator build" "$operation_timeout" \
        "$xcodebuild" build "${simulator_common_args[@]}"
}

build_release_simulator() {
    run_step "Release simulator build" "$operation_timeout" \
        "$xcodebuild" build "${release_simulator_common_args[@]}"
}

install_simulator() {
    ensure_simulator_ready
    terminate_simulator_app
    run_step "Install simulator app" 60 "$xcrun" simctl install "$SIMULATOR_ID" "$simulator_app"
}

install_release_simulator() {
    ensure_simulator_ready
    terminate_simulator_app
    run_step "Install Release simulator app" 60 \
        "$xcrun" simctl install "$SIMULATOR_ID" "$release_simulator_app"
}

launch_simulator() {
    terminate_simulator_app
    run_step "Launch simulator app" 30 "$xcrun" simctl launch "$SIMULATOR_ID" "$BUNDLE_ID"
}

launch_release_simulator() {
    terminate_simulator_app
    local started=$SECONDS
    local output
    print -- "→ Launch pure Release simulator app (timeout 30s)"
    if output="$(run_with_timeout 30 "$xcrun" simctl launch "$SIMULATOR_ID" "$BUNDLE_ID")"; then
        print -- "$output"
        print -- "✓ Launch pure Release simulator app ($((SECONDS - started))s)"
    else
        local exit_code=$?
        print -u2 -- "✗ Launch pure Release simulator app failed with status $exit_code"
        return "$exit_code"
    fi
    local pid="${output##*: }"
    if [[ "$pid" != <1-> ]]; then
        print -u2 -- "error: could not parse pure Release app PID from: $output"
        return 1
    fi
    /bin/sleep 3
    run_step "Verify pure Release app remains alive" 10 /bin/kill -0 "$pid"
}

build_device() {
    run_step "Incremental physical-device build" "$operation_timeout" \
        "$xcodebuild" build "${device_common_args[@]}"
}

archive_release() {
    /bin/rm -rf "$release_archive"
    run_step "Signed Release archive" "$operation_timeout" \
        "$xcodebuild" archive "${release_archive_args[@]}"
    run_step "Validate archived app" 20 \
        /bin/test -d "$release_archive/Products/Applications/count_calories.app"
    run_step "Validate archived widget extension" 20 \
        /bin/test -d "$release_archive/Products/Applications/count_calories.app/PlugIns/count_caloriesWidget.appex"
    run_step "Verify archived app signature" 30 \
        /usr/bin/codesign --verify --deep --strict \
        "$release_archive/Products/Applications/count_calories.app"
    run_step "Verify archived widget signature" 30 \
        /usr/bin/codesign --verify --strict \
        "$release_archive/Products/Applications/count_calories.app/PlugIns/count_caloriesWidget.appex"
}

export_release() {
    /bin/mkdir -p "$device_derived_data"
    /bin/rm -rf "$release_export"
    /bin/cat > "$release_export_options" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>destination</key>
    <string>export</string>
    <key>method</key>
    <string>app-store-connect</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>stripSwiftSymbols</key>
    <true/>
    <key>teamID</key>
    <string>$DEVELOPMENT_TEAM</string>
    <key>uploadSymbols</key>
    <true/>
</dict>
</plist>
EOF
    run_step "Export App Store Connect IPA" "$operation_timeout" \
        "$xcodebuild" -exportArchive \
        -archivePath "$release_archive" \
        -exportPath "$release_export" \
        -exportOptionsPlist "$release_export_options" \
        -allowProvisioningUpdates \
        -quiet
    local ipas=("$release_export"/*.ipa(N))
    if (( ${#ipas} != 1 )); then
        print -u2 -- "error: expected one exported IPA, found ${#ipas}"
        return 1
    fi
    print -- "✓ Exported distribution IPA: $ipas[1]"
}

install_device() {
    run_step "Install physical-device app" 90 \
        "$xcrun" devicectl device install app --timeout 80 --device "$PHYSICAL_DEVICE_ID" "$device_app"
}

launch_device() {
    run_step "Launch physical-device app" 45 \
        "$xcrun" devicectl device process launch --timeout 35 --terminate-existing \
        --device "$PHYSICAL_DEVICE_ID" "$BUNDLE_ID"
}

capture_simulator_app_logs() {
    /bin/mkdir -p "$test_diagnostics"
    local output="$test_diagnostics/count-calories-$(/bin/date +%Y%m%d-%H%M%S).log"
    if run_with_timeout 30 "$xcrun" simctl spawn "$SIMULATOR_ID" log show \
        --last 15m \
        --style compact \
        --predicate 'subsystem == "ch.elia.count-calories"' > "$output"; then
        print -- "→ Captured Count Calories logs: $output"
    else
        print -u2 -- "warning: could not capture Count Calories simulator logs"
        /bin/rm -f "$output"
    fi
}

run_simulator_tests() {
    local scope="$1"
    shift
    ensure_simulator_ready
    terminate_simulator_app

    if run_step "$scope" "$operation_timeout" \
        "$xcodebuild" test "${simulator_common_args[@]}" "${test_options[@]}" "$@"; then
        return 0
    else
        local exit_code=$?
        capture_simulator_app_logs
        if (( exit_code == 124 )); then
            print -u2 -- "Test infrastructure timed out; resetting the simulator for the next iteration."
            reset_simulator || true
        fi
        return "$exit_code"
    fi
}

run_release_validation_tests() {
    local scope="$1"
    shift
    ensure_simulator_ready
    terminate_simulator_app

    if run_step "$scope" "$operation_timeout" \
        "$xcodebuild" test "${release_validation_test_args[@]}" "${test_options[@]}" "$@"; then
        return 0
    else
        local exit_code=$?
        capture_simulator_app_logs
        if (( exit_code == 124 )); then
            print -u2 -- "Release-validation test infrastructure timed out; resetting simulator."
            reset_simulator || true
        fi
        return "$exit_code"
    fi
}

run_device_tests() {
    run_step "Complete physical-device test suite" "$operation_timeout" \
        "$xcodebuild" test "${device_common_args[@]}" \
        -parallel-testing-enabled NO \
        -test-timeouts-enabled YES \
        -default-test-execution-time-allowance "$TEST_CASE_TIMEOUT" \
        -maximum-test-execution-time-allowance 60
}

run_core_tests() {
    local label="$1"
    shift
    run_step "$label" "$operation_timeout" \
        "$xcrun" swift test \
        --package-path . \
        --cache-path "$DERIVED_DATA_ROOT/swiftpm-cache" \
        --config-path "$DERIVED_DATA_ROOT/swiftpm-config" \
        --security-path "$DERIVED_DATA_ROOT/swiftpm-security" \
        --scratch-path "$swiftpm_scratch" \
        --disable-sandbox \
        --disable-index-store \
        "$@"
}

run_isolated_release_ui_tests() {
    local -a identifiers
    identifiers=("${(@f)$(/usr/bin/python3 -c '
from pathlib import Path
import re
methods = []
for path in sorted(Path("count_caloriesUITests").glob("*.swift")):
    methods.extend(re.findall(r"^\s*func\s+(test[A-Za-z0-9_]+)\s*\(", path.read_text(), re.MULTILINE))
for method in sorted(set(methods)):
    if method != "testLaunchPerformance":
        print(method)
')}")
    if (( ${#identifiers} == 0 )); then
        print -u2 -- "error: no functional UI tests discovered for isolated minimum-runtime validation"
        return 66
    fi

    local index=0
    local identifier
    for identifier in "${identifiers[@]}"; do
        (( index += 1 ))
        reset_simulator
        run_release_validation_tests \
            "Release-config functional UI test $index/${#identifiers} ($identifier)" \
            "-only-testing:count_caloriesUITests/CountCaloriesUITests/$identifier"
    done
    print -- "✓ Release-config functional UI tests: ${#identifiers} isolated tests passed"
}

run_release_candidate() {
    run_core_tests "Hostless core tests"
    run_release_validation_tests "Release-config app-hosted unit tests" \
        "-only-testing:count_caloriesTests"
    if [[ "${REQUIRED_SIMULATOR_OS_MAJOR:-}" == "17" ]]; then
        # Xcode 27's archived iOS 17 XCTest bridge can crash inside
        # XCTAutomationSupport after sustained cross-test diagnostics. A fresh
        # simulator service per journey preserves complete assertions without
        # treating that source-less bridge crash as an app result.
        run_isolated_release_ui_tests
    else
        reset_simulator
        run_release_validation_tests "Release-config functional UI tests" \
            "-only-testing:count_caloriesUITests" \
            "-skip-testing:count_caloriesUITests/CountCaloriesUITests/testLaunchPerformance"
    fi
    archive_release
    build_release_simulator
    install_release_simulator
    launch_release_simulator
}

case "$action" in
    iterate)
        run_core_tests "Hostless core tests"
        build_simulator
        ;;
    check)
        build_simulator
        ;;
    simulator-build)
        build_simulator
        ;;
    simulator-install)
        build_simulator
        install_simulator
        ;;
    simulator-run)
        build_simulator
        install_simulator
        launch_simulator
        ;;
    simulator-runtime-list)
        list_simulator_runtimes
        ;;
    simulator-runtime-install)
        install_simulator_runtime
        ;;
    simulator-ios17-create)
        create_ios17_simulator
        ;;
    test-unit)
        run_core_tests "Hostless core tests"
        ;;
    test-rerun)
        run_core_tests "Hostless core tests without rebuilding" --skip-build
        ;;
    test-one)
        if [[ -z "$argument" ]]; then
            print -u2 -- "error: test-one requires an XCTest filter such as NutritionLookupTests/testClientMapsOpenFoodFactsResponse"
            exit 64
        fi
        run_core_tests "Selected hostless test" --filter "$argument"
        ;;
    test-ui)
        reset_simulator
        run_simulator_tests "Functional UI smoke tests" \
            "-only-testing:count_caloriesUITests" \
            "-skip-testing:count_caloriesUITests/CountCaloriesUITests/testLaunchPerformance"
        ;;
    test-ui-one)
        if [[ -z "$argument" ]]; then
            print -u2 -- "error: test-ui-one requires an XCTest filter such as CountCaloriesUITests/testAddingDefaultMealUpdatesToday"
            exit 64
        fi
        reset_simulator
        run_simulator_tests "Selected functional UI test" \
            "-only-testing:count_caloriesUITests/$argument"
        ;;
    test-ui-release-one)
        if [[ -z "$argument" ]]; then
            print -u2 -- "error: test-ui-release-one requires an XCTest filter"
            exit 64
        fi
        reset_simulator
        run_release_validation_tests "Selected Release-config UI test" \
            "-only-testing:count_caloriesUITests/$argument"
        ;;
    test-app-unit)
        run_simulator_tests "App-hosted unit tests" "-only-testing:count_caloriesTests"
        ;;
    test-app-release)
        run_release_validation_tests "Release-config app-hosted unit tests" \
            "-only-testing:count_caloriesTests"
        ;;
    test-app-one)
        if [[ -z "$argument" ]]; then
            print -u2 -- "error: test-app-one requires a test filter such as WeightMeasurementStoreTests/testAddingTwoSameDayMeasurementsPreservesBoth"
            exit 64
        fi
        run_simulator_tests "Selected app-hosted unit test" \
            "-only-testing:count_caloriesTests/$argument"
        ;;
    test-app-release-one)
        if [[ -z "$argument" ]]; then
            print -u2 -- "error: test-app-release-one requires a test filter"
            exit 64
        fi
        run_release_validation_tests "Selected Release-config app-hosted unit test" \
            "-only-testing:count_caloriesTests/$argument"
        ;;
    test-performance)
        reset_simulator
        run_simulator_tests "Launch-performance test" \
            "-only-testing:count_caloriesUITests/CountCaloriesUITests/testLaunchPerformance"
        ;;
    test-all)
        run_core_tests "Hostless core tests"
        build_simulator
        ;;
    test-results)
        result_bundles=("$simulator_derived_data"/Logs/Test/*.xcresult(Nom))
        if (( ${#result_bundles} == 0 )); then
            print -u2 -- "error: no simulator test result exists; run a test recipe first"
            exit 66
        fi
        run_step "Summarize latest test result" "$operation_timeout" \
            "$xcrun" xcresulttool get test-results summary --path "$result_bundles[1]"
        run_step "List latest test details" "$operation_timeout" \
            "$xcrun" xcresulttool get test-results tests --path "$result_bundles[1]"
        ;;
    test-artifacts)
        result_bundles=("$simulator_derived_data"/Logs/Test/*.xcresult(Nom))
        if (( ${#result_bundles} == 0 )); then
            print -u2 -- "error: no simulator test result exists; run a test recipe first"
            exit 66
        fi
        artifact_directory="$test_diagnostics/latest-attachments"
        /bin/rm -rf "$artifact_directory"
        /bin/mkdir -p "$artifact_directory"
        run_step "Export latest test attachments" "$operation_timeout" \
            "$xcrun" xcresulttool export attachments \
            --path "$result_bundles[1]" \
            --output-path "$artifact_directory"
        print -- "✓ Exported attachments: $artifact_directory"
        ;;
    simulator-logs)
        ensure_simulator_ready
        run_step "Show recent Count Calories logs" "$operation_timeout" \
            "$xcrun" simctl spawn "$SIMULATOR_ID" log show \
            --last 30m \
            --style compact \
            --predicate 'subsystem == "ch.elia.count-calories"'
        ;;
    validate)
        run_core_tests "Hostless core tests"
        build_simulator
        install_simulator
        launch_simulator
        ;;
    release-artifact-check)
        archive_release
        build_release_simulator
        install_release_simulator
        launch_release_simulator
        ;;
    release-export-check)
        archive_release
        export_release
        ;;
    release-config-check)
        run_release_candidate
        ;;
    release-validate)
        REQUIRED_SIMULATOR_OS_MAJOR=17
        verify_required_simulator_os
        run_release_candidate
        export_release
        ;;
    device-build)
        build_device
        ;;
    device-install)
        build_device
        install_device
        ;;
    device-launch)
        launch_device
        ;;
    device-run)
        build_device
        install_device
        launch_device
        ;;
    device-test)
        run_device_tests
        ;;
    device-validate)
        run_device_tests
        install_device
        launch_device
        ;;
    provision)
        run_step "Refresh signing and provisioning" "$operation_timeout" \
            "$xcodebuild" build "${device_common_args[@]}" \
            DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" \
            -allowProvisioningUpdates \
            -allowProvisioningDeviceRegistration
        ;;
    simulator-stop)
        stop_simulator
        ;;
    simulator-reset)
        reset_simulator
        ;;
    simulator-erase)
        erase_simulator
        ;;
    recover)
        reset_simulator
        if [[ "$DERIVED_DATA_ROOT" != "/private/tmp/count_calories-derived" ]]; then
            print -u2 -- "error: refusing to remove unexpected derived-data path: $DERIVED_DATA_ROOT"
            exit 64
        fi
        run_step "Remove derived data" "$operation_timeout" /bin/rm -rf -- "$DERIVED_DATA_ROOT"
        ;;
    clean)
        if [[ "$DERIVED_DATA_ROOT" != "/private/tmp/count_calories-derived" ]]; then
            print -u2 -- "error: refusing to remove unexpected derived-data path: $DERIVED_DATA_ROOT"
            exit 64
        fi
        run_step "Remove derived data" "$operation_timeout" /bin/rm -rf -- "$DERIVED_DATA_ROOT"
        ;;
    doctor)
        run_step "Check Xcode" 20 "$xcodebuild" -version
        run_step "Check simulator" 20 "$xcrun" simctl list devices
        run_step "Check connected devices" 30 "$xcrun" devicectl list devices --timeout 20
        ;;
    *)
        print -u2 -- "error: unknown operation: $action"
        exit 64
        ;;
esac
