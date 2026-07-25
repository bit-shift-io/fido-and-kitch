#!/bin/sh
# Runs all three test tiers in sequence and reports each tier's outcome.
# Skips the e2e tier in CI (no display/real LÖVE binary there), always
# announcing the skip rather than silently omitting it.

overall_status=0

run_tier() {
	tier_name="$1"
	tier_script="$2"

	echo "== ${tier_name} =="
	if ./"${tier_script}"; then
		echo "== ${tier_name}: passed =="
	else
		echo "== ${tier_name}: failed =="
		overall_status=1
	fi
	echo
}

run_tier "unit" "test-unit.sh"
run_tier "integration" "test-integration.sh"

if [ -n "$CI" ]; then
	echo "== e2e =="
	echo "== e2e: skipped (CI environment detected; no display/real LÖVE binary) =="
	echo
else
	run_tier "e2e" "test-e2e.sh"
fi

exit $overall_status
