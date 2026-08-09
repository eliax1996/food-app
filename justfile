set shell := ["zsh", "-cu"]

# This file is the only supported entrypoint for project operations. The helper
# script rejects direct invocation so configuration cannot drift between callers.
xcode := "/Applications/Xcode-beta.app"
project := "count_calories.xcodeproj"
scheme := "MyApp"
configuration := "Debug"
team := "9SFF5NYD5Y"
bundle_id := "ch.elia.count-calories"
physical_destination := "00008140-001E23E83E89401C"
physical_device := "FD02682B-3BA2-554C-B4A6-E6B9DCE614AD"
simulator := "B171D474-2B64-4D85-B15C-F231E745BD0F"
derived_data := "/private/tmp/count_calories-derived"
iteration_timeout := env_var_or_default("ITERATION_TIMEOUT", "60")
validation_timeout := env_var_or_default("VALIDATION_TIMEOUT", "90")
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

# Shut down the configured simulator without erasing its data or build cache.
simulator-stop timeout=iteration_timeout: (_run "simulator-stop" timeout "")

# Run fast hostless tests against production nutrition, reminder, and tracking sources.
test-unit timeout=iteration_timeout: (_run "test-unit" timeout "")

# Re-run the already-built hostless tests without compiling; use only when sources are unchanged.
test-rerun timeout=iteration_timeout: (_run "test-rerun" timeout "")

# Incrementally compile and run one hostless XCTest filter (Class or Class/method).
test-one identifier timeout=iteration_timeout: (_run "test-one" timeout identifier)

# Run functional UI smoke tests without launch-performance measurement.
test-ui timeout=validation_timeout: (_run "test-ui" timeout "")

# Run one functional UI XCTest filter (Class/method) for focused authoring and diagnosis.
test-ui-one identifier timeout=validation_timeout: (_run "test-ui-one" timeout identifier)

# Run the app-hosted unit target when iOS-specific test hosting needs verification.
test-app-unit timeout=validation_timeout: (_run "test-app-unit" timeout "")

# Run launch-performance measurement explicitly; never part of the edit loop or correctness gate.
test-performance timeout=validation_timeout: (_run "test-performance" timeout "")

# Run the automated correctness gate: hostless unit tests plus an incremental app compile.
test timeout=validation_timeout: (_run "test-all" timeout "")

# Summarize the most recent simulator test result without launching a new test.
test-results timeout=iteration_timeout: (_run "test-results" timeout "")

# Run unit tests, compile, install, and launch; UI automation remains an explicit recipe.
validate timeout=validation_timeout: (_run "validate" timeout "")

# Run the complete test suite on the physical iPhone.
device-test timeout=validation_timeout: (_run "device-test" timeout "")

# Test, install, and launch on the physical iPhone without a second build.
device-validate timeout=validation_timeout: (_run "device-validate" timeout "")

# Verify configured tools and destinations without compiling.
doctor timeout=iteration_timeout: (_run "doctor" timeout "")

# Restart the configured simulator without erasing its data or build cache.
simulator-reset timeout=iteration_timeout: (_run "simulator-reset" timeout "")

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
