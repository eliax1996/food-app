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
readonly device_app="$device_derived_data/Build/Products/${CONFIGURATION}-iphoneos/count_calories.app"

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

device_common_args=(
    -project "$PROJECT"
    -scheme "$SCHEME"
    -configuration "$CONFIGURATION"
    -destination "platform=iOS,id=$PHYSICAL_DESTINATION_ID"
    -derivedDataPath "$device_derived_data"
    -quiet
    COMPILER_INDEX_STORE_ENABLE=NO
)

test_options=(
    -parallel-testing-enabled NO
    -maximum-concurrent-test-simulator-destinations 1
    -test-timeouts-enabled YES
    -default-test-execution-time-allowance "$TEST_CASE_TIMEOUT"
    -maximum-test-execution-time-allowance 60
)

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

build_simulator() {
    run_step "Incremental simulator build" "$operation_timeout" \
        "$xcodebuild" build "${simulator_common_args[@]}"
}

install_simulator() {
    ensure_simulator_ready
    terminate_simulator_app
    run_step "Install simulator app" 60 "$xcrun" simctl install "$SIMULATOR_ID" "$simulator_app"
}

launch_simulator() {
    terminate_simulator_app
    run_step "Launch simulator app" 30 "$xcrun" simctl launch "$SIMULATOR_ID" "$BUNDLE_ID"
}

build_device() {
    run_step "Incremental physical-device build" "$operation_timeout" \
        "$xcodebuild" build "${device_common_args[@]}"
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
        if (( exit_code == 124 )); then
            print -u2 -- "Test infrastructure timed out; resetting the simulator for the next iteration."
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
            "-skip-testing:count_caloriesUITests/CountCaloriesUITests/testLaunchPerformance"
        ;;
    test-app-unit)
        run_simulator_tests "App-hosted unit tests" "-only-testing:count_caloriesTests"
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
    validate)
        run_core_tests "Hostless core tests"
        build_simulator
        install_simulator
        launch_simulator
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
