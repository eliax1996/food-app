set shell := ["zsh", "-cu"]

# This file is the only supported entrypoint for project operations. The helper
# script rejects direct invocation so configuration cannot drift between callers.
xcode := env_var_or_default("XCODE_PATH", "/Applications/Xcode-beta.app")
project := "count_calories.xcodeproj"
scheme := "MyApp"
configuration := "Debug"
team := "9SFF5NYD5Y"
bundle_id := "ch.elia.count-calories"
physical_destination := env_var_or_default("PHYSICAL_DESTINATION_ID", "00008140-001E23E83E89401C")
physical_device := env_var_or_default("PHYSICAL_DEVICE_ID", "FD02682B-3BA2-554C-B4A6-E6B9DCE614AD")
simulator := env_var_or_default("SIMULATOR_ID", "B171D474-2B64-4D85-B15C-F231E745BD0F")
derived_data := "/private/tmp/count_calories-derived"
iteration_timeout := env_var_or_default("ITERATION_TIMEOUT", "60")
validation_timeout := env_var_or_default("VALIDATION_TIMEOUT", "90")
ui_test_timeout := env_var_or_default("UI_TEST_TIMEOUT", "2400")
release_timeout := env_var_or_default("RELEASE_TIMEOUT", "2400")
runtime_download_timeout := env_var_or_default("RUNTIME_DOWNLOAD_TIMEOUT", "7200")
test_case_timeout := env_var_or_default("TEST_CASE_TIMEOUT", "30")

# Show the available commands.
default:
    @just --list

# Fast edit loop: run hostless core tests and incrementally compile without booting or installing.
iterate timeout=iteration_timeout: (_run "iterate" timeout "")

# Incrementally compile the simulator app without booting, installing, or testing.
check timeout=iteration_timeout: (_run "check" timeout "")

# Incrementally compile the app for the physical iPhone.
build timeout=iteration_timeout: (_run "device-build" timeout "")

# Incrementally compile and install the app on the physical iPhone.
install timeout=iteration_timeout: (_run "device-install" timeout "")

# Launch the installed app on the physical iPhone without compiling.
launch timeout=iteration_timeout: (_run "device-launch" timeout "")

# Incrementally compile, install, and launch on the physical iPhone.
run timeout=iteration_timeout: (_run "device-run" timeout "")

# Refresh signing/provisioning explicitly when a normal physical build reports a signing error.
provision timeout=validation_timeout: (_run "provision" timeout "")

# Incrementally compile the app for the simulator.
simulator-build timeout=iteration_timeout: (_run "simulator-build" timeout "")

# Incrementally compile and install the app in the simulator.
simulator-install timeout=iteration_timeout: (_run "simulator-install" timeout "")

# Incrementally compile, install, and launch in the simulator.
simulator-run timeout=iteration_timeout: (_run "simulator-run" timeout "")

# List simulator runtimes installed for configured Xcode.
simulator-runtime-list timeout=iteration_timeout: (_run "simulator-runtime-list" timeout "")

# Download/install one exact iOS simulator runtime version, such as 17.5.
simulator-runtime-install version timeout=runtime_download_timeout: (_run "simulator-runtime-install" timeout version)

# Create an iPhone simulator on newest installed iOS 17 runtime and print its UUID.
simulator-ios17-create timeout=iteration_timeout: (_run "simulator-ios17-create" timeout "")

# Shut down the configured simulator without erasing its data or build cache.
simulator-stop timeout=iteration_timeout: (_run "simulator-stop" timeout "")

# Run fast hostless tests against production nutrition, reminder, and tracking sources.
test-unit timeout=iteration_timeout: (_run "test-unit" timeout "")

# Re-run the already-built hostless tests without compiling; use only when sources are unchanged.
test-rerun timeout=iteration_timeout: (_run "test-rerun" timeout "")

# Incrementally compile and run one hostless XCTest filter (Class or Class/method).
test-one identifier timeout=iteration_timeout: (_run "test-one" timeout identifier)

# Run functional UI smoke tests without launch-performance measurement.
test-ui timeout=ui_test_timeout: (_run "test-ui" timeout "")

# Run one functional UI XCTest filter (Class/method) for focused authoring and diagnosis.
test-ui-one identifier timeout=validation_timeout: (_run "test-ui-one" timeout identifier)

# Run one functional UI test in optimized Release configuration with test seams.
test-ui-release-one identifier timeout=validation_timeout: (_run "test-ui-release-one" timeout identifier)

# Run the app-hosted unit target when iOS-specific test hosting needs verification.
test-app-unit timeout=validation_timeout: (_run "test-app-unit" timeout "")

# Run all app-hosted unit tests in optimized Release-validation configuration.
test-app-release timeout=ui_test_timeout: (_run "test-app-release" timeout "")

# Run one app-hosted unit test in Debug configuration.
test-app-one identifier timeout=validation_timeout: (_run "test-app-one" timeout identifier)

# Run one app-hosted unit test in optimized Release validation configuration.
test-app-release-one identifier timeout=validation_timeout: (_run "test-app-release-one" timeout identifier)

# Run launch-performance measurement explicitly; never part of the edit loop or correctness gate.
test-performance timeout=validation_timeout: (_run "test-performance" timeout "")

# Run the automated correctness gate: hostless unit tests plus an incremental app compile.
test timeout=validation_timeout: (_run "test-all" timeout "")

# Summarize the most recent simulator test result without launching a new test.
test-results timeout=iteration_timeout: (_run "test-results" timeout "")

# Export attachments from most recent simulator test result into test diagnostics.
test-artifacts timeout=iteration_timeout: (_run "test-artifacts" timeout "")

# Show recent privacy-safe Count Calories unified logs from configured simulator.
simulator-logs timeout=iteration_timeout: (_run "simulator-logs" timeout "")

# Run unit tests, compile, install, and launch; UI automation remains an explicit recipe.
validate timeout=validation_timeout: (_run "validate" timeout "")

# Build/sign/archive and launch pure Release artifact without rerunning tests.
release-artifact-check timeout=release_timeout: (_run "release-artifact-check" timeout "")

# Rebuild signed archive and attempt App Store Connect IPA export without tests.
release-export-check timeout=release_timeout: (_run "release-export-check" timeout "")

# Current-runtime diagnostic: full optimized/artifact gate, but not minimum-iOS release approval.
release-config-check timeout=release_timeout: (_run "release-config-check" timeout "")

# Production gate: iOS 17 checks plus App Store Connect distribution IPA export.
release-validate timeout=release_timeout: (_run "release-validate" timeout "")

# Run the complete test suite on the physical iPhone.
device-test timeout=validation_timeout: (_run "device-test" timeout "")

# Test, install, and launch on the physical iPhone without a second build.
device-validate timeout=validation_timeout: (_run "device-validate" timeout "")

# Verify configured tools and destinations without compiling.
doctor timeout=iteration_timeout: (_run "doctor" timeout "")

# Restart the configured simulator without erasing its data or build cache.
simulator-reset timeout=iteration_timeout: (_run "simulator-reset" timeout "")

# Erase all data from configured disposable simulator, then leave it shut down.
simulator-erase timeout=iteration_timeout: (_run "simulator-erase" timeout "")

# Recover from a stuck test session and clear all derived build data.
recover timeout=iteration_timeout: (_run "recover" timeout "")

# Remove all simulator/device build products and test results.
clean timeout=iteration_timeout: (_run "clean" timeout "")

[private]
_run action timeout argument:
    @ITERATE_FROM_JUST=1 \
    XCODE_PATH="{{ xcode }}" \
    PROJECT="{{ project }}" \
    SCHEME="{{ scheme }}" \
    CONFIGURATION="{{ configuration }}" \
    DEVELOPMENT_TEAM="{{ team }}" \
    BUNDLE_ID="{{ bundle_id }}" \
    PHYSICAL_DESTINATION_ID="{{ physical_destination }}" \
    PHYSICAL_DEVICE_ID="{{ physical_device }}" \
    SIMULATOR_ID="{{ simulator }}" \
    DERIVED_DATA_ROOT="{{ derived_data }}" \
    TEST_CASE_TIMEOUT="{{ test_case_timeout }}" \
    /usr/bin/lockf -t 0 "{{ derived_data }}.operation.lock" \
        ./scripts/iterate.zsh "{{ action }}" "{{ timeout }}" "{{ argument }}"
