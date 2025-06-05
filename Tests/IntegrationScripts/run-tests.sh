#!/bin/bash

# AppPilot Test Runner Script
# Comprehensive testing script for CI/CD and local development

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default configuration
TEST_SUITE="unit"
OUTPUT_DIR="test-results"
VERBOSE=false
PARALLEL=true
TEST_APP_TIMEOUT=30
SKIP_BUILD=false
GENERATE_COVERAGE=false

# Print usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Options:
    -s, --suite SUITE        Test suite to run (unit|integration|e2e|stress|all) [default: unit]
    -o, --output DIR         Output directory for test results [default: test-results]
    -v, --verbose            Enable verbose output
    -j, --no-parallel        Disable parallel test execution
    -t, --timeout SECONDS   TestApp startup timeout [default: 30]
    --skip-build            Skip building the project
    --coverage              Generate code coverage report
    -h, --help              Show this help message

Test Suites:
    unit        - Unit tests only (fast)
    integration - Integration tests with TestApp
    e2e         - End-to-end tests with full TestApp interaction
    stress      - Stress and performance tests
    all         - All test suites

Examples:
    $0 --suite unit --verbose
    $0 --suite integration --output ./results
    $0 --suite all --coverage
    $0 --suite stress --timeout 60

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -s|--suite)
            TEST_SUITE="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -j|--no-parallel)
            PARALLEL=false
            shift
            ;;
        -t|--timeout)
            TEST_APP_TIMEOUT="$2"
            shift 2
            ;;
        --skip-build)
            SKIP_BUILD=true
            shift
            ;;
        --coverage)
            GENERATE_COVERAGE=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Validate test suite
case $TEST_SUITE in
    unit|integration|e2e|stress|all)
        ;;
    *)
        echo -e "${RED}Error: Invalid test suite '$TEST_SUITE'${NC}"
        usage
        exit 1
        ;;
esac

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check Swift
    if ! command -v swift &> /dev/null; then
        log_error "Swift is not installed or not in PATH"
        exit 1
    fi
    
    # Check Xcode version
    if ! xcodebuild -version &> /dev/null; then
        log_error "Xcode is not installed or not properly configured"
        exit 1
    fi
    
    # Check accessibility permissions (simplified check)
    if [[ "$TEST_SUITE" == "integration" ]] || [[ "$TEST_SUITE" == "e2e" ]] || [[ "$TEST_SUITE" == "all" ]]; then
        log_warning "Integration/E2E tests require Accessibility permissions"
        log_warning "Make sure to grant permissions in System Preferences > Security & Privacy > Accessibility"
    fi
    
    log_success "Prerequisites check passed"
}

# Build project
build_project() {
    if [[ "$SKIP_BUILD" == true ]]; then
        log_info "Skipping build (--skip-build specified)"
        return
    fi
    
    log_info "Building AppPilot SDK..."
    
    local build_flags=""
    if [[ "$VERBOSE" == true ]]; then
        build_flags="--verbose"
    fi
    
    if [[ "$GENERATE_COVERAGE" == true ]]; then
        # Enable code coverage
        swift build --enable-code-coverage $build_flags
    else
        swift build $build_flags
    fi
    
    if [[ $? -eq 0 ]]; then
        log_success "Build completed successfully"
    else
        log_error "Build failed"
        exit 1
    fi
}

# Run unit tests
run_unit_tests() {
    log_info "Running unit tests..."
    
    local test_flags=""
    if [[ "$PARALLEL" == true ]]; then
        test_flags="--parallel"
    fi
    
    if [[ "$VERBOSE" == true ]]; then
        test_flags="$test_flags --verbose"
    fi
    
    local output_file="$OUTPUT_DIR/unit-tests.xml"
    
    # Run swift test with JUnit XML output (if supported)
    if swift test $test_flags --filter AppPilotTests 2>&1 | tee "$OUTPUT_DIR/unit-tests.log"; then
        log_success "Unit tests passed"
        return 0
    else
        log_error "Unit tests failed"
        return 1
    fi
}

# Setup TestApp for integration tests
setup_test_app() {
    log_info "Setting up TestApp for integration tests..."
    
    # Check if TestApp is already running
    if pgrep -f "TestApp" > /dev/null; then
        log_info "TestApp is already running"
        return 0
    fi
    
    # Try to find and launch TestApp
    local testapp_path=""
    
    # Common locations for TestApp
    local possible_paths=(
        "./TestApp/TestApp.app"
        "./TestApp.app"
        "../TestApp/TestApp.app"
        "./build/TestApp.app"
    )
    
    for path in "${possible_paths[@]}"; do
        if [[ -d "$path" ]]; then
            testapp_path="$path"
            break
        fi
    done
    
    if [[ -z "$testapp_path" ]]; then
        log_warning "TestApp not found in common locations"
        log_warning "Please build and run TestApp manually before running integration tests"
        return 1
    fi
    
    log_info "Launching TestApp from: $testapp_path"
    open "$testapp_path"
    
    # Wait for TestApp to start
    log_info "Waiting for TestApp to start (timeout: ${TEST_APP_TIMEOUT}s)..."
    local timeout=$TEST_APP_TIMEOUT
    while [[ $timeout -gt 0 ]]; do
        if curl -s http://localhost:8765/api/health > /dev/null 2>&1; then
            log_success "TestApp is ready"
            return 0
        fi
        sleep 1
        ((timeout--))
    done
    
    log_error "TestApp failed to start within ${TEST_APP_TIMEOUT} seconds"
    return 1
}

# Run integration tests
run_integration_tests() {
    log_info "Running integration tests..."
    
    # Setup TestApp
    if ! setup_test_app; then
        return 1
    fi
    
    local test_flags=""
    if [[ "$VERBOSE" == true ]]; then
        test_flags="--verbose"
    fi
    
    local output_file="$OUTPUT_DIR/integration-tests.xml"
    
    # Run integration tests
    if swift test $test_flags --filter IntegrationTests 2>&1 | tee "$OUTPUT_DIR/integration-tests.log"; then
        log_success "Integration tests passed"
        return 0
    else
        log_error "Integration tests failed"
        return 1
    fi
}

# Run E2E tests
run_e2e_tests() {
    log_info "Running E2E tests..."
    
    # Setup TestApp
    if ! setup_test_app; then
        return 1
    fi
    
    local test_flags=""
    if [[ "$VERBOSE" == true ]]; then
        test_flags="--verbose"
    fi
    
    local output_file="$OUTPUT_DIR/e2e-tests.xml"
    
    # Run E2E tests
    if swift test $test_flags --filter E2ETests 2>&1 | tee "$OUTPUT_DIR/e2e-tests.log"; then
        log_success "E2E tests passed"
        return 0
    else
        log_error "E2E tests failed"
        return 1
    fi
}

# Run stress tests
run_stress_tests() {
    log_info "Running stress tests..."
    log_warning "Stress tests may take several minutes to complete"
    
    # Setup TestApp
    if ! setup_test_app; then
        return 1
    fi
    
    local test_flags=""
    if [[ "$VERBOSE" == true ]]; then
        test_flags="--verbose"
    fi
    
    local output_file="$OUTPUT_DIR/stress-tests.xml"
    
    # Run stress tests (no parallel execution for stress tests)
    if swift test $test_flags --filter StressTests 2>&1 | tee "$OUTPUT_DIR/stress-tests.log"; then
        log_success "Stress tests passed"
        return 0
    else
        log_error "Stress tests failed"
        return 1
    fi
}

# Generate coverage report
generate_coverage() {
    if [[ "$GENERATE_COVERAGE" != true ]]; then
        return 0
    fi
    
    log_info "Generating code coverage report..."
    
    # Generate coverage data
    if swift test --enable-code-coverage > /dev/null 2>&1; then
        # Export coverage data (if tools available)
        if command -v xcov &> /dev/null; then
            xcov --output_directory "$OUTPUT_DIR/coverage"
            log_success "Coverage report generated in $OUTPUT_DIR/coverage"
        else
            log_warning "xcov not found - install it for HTML coverage reports"
        fi
    else
        log_error "Failed to generate coverage data"
        return 1
    fi
}

# Cleanup function
cleanup() {
    log_info "Cleaning up..."
    
    # Kill TestApp if we started it
    if [[ "$TEST_SUITE" == "integration" ]] || [[ "$TEST_SUITE" == "e2e" ]] || [[ "$TEST_SUITE" == "stress" ]] || [[ "$TEST_SUITE" == "all" ]]; then
        pkill -f "TestApp" > /dev/null 2>&1 || true
    fi
}

# Set up trap for cleanup
trap cleanup EXIT

# Main execution
main() {
    local start_time=$(date +%s)
    local exit_code=0
    
    log_info "Starting AppPilot test run"
    log_info "Suite: $TEST_SUITE"
    log_info "Output directory: $OUTPUT_DIR"
    log_info "Verbose: $VERBOSE"
    log_info "Parallel: $PARALLEL"
    
    check_prerequisites
    build_project
    
    case $TEST_SUITE in
        unit)
            run_unit_tests || exit_code=1
            ;;
        integration)
            run_integration_tests || exit_code=1
            ;;
        e2e)
            run_e2e_tests || exit_code=1
            ;;
        stress)
            run_stress_tests || exit_code=1
            ;;
        all)
            run_unit_tests || exit_code=1
            run_integration_tests || exit_code=1
            run_e2e_tests || exit_code=1
            run_stress_tests || exit_code=1
            ;;
    esac
    
    generate_coverage
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    if [[ $exit_code -eq 0 ]]; then
        log_success "All tests completed successfully in ${duration}s"
    else
        log_error "Some tests failed (duration: ${duration}s)"
    fi
    
    log_info "Test results saved to: $OUTPUT_DIR"
    
    exit $exit_code
}

# Run main function
main "$@"