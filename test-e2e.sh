#!/bin/sh
# Runs the e2e tier: launches one real LÖVE process per tests/e2e/*_test.lua
# file, in the same style as run.sh's binary discovery, and aggregates each
# file's outcome into one summary and exit status.
#
# Flags forwarded to LÖVE as launch arguments (issues 03/06):
#   --paced              pace playback to real time (one simulated frame per drawn frame)
#   --filmstrip[=N]       capture every Nth simulated frame (default interval 10)

LOCAL_LOVE="$PWD/bin/love.AppImage"

find_love_binary() {
	if [ -f "$LOCAL_LOVE" ]; then
		echo "$LOCAL_LOVE"
		return 0
	fi
	if command -v love >/dev/null 2>&1; then
		command -v love
		return 0
	fi
	return 1
}

LOVE_BIN=$(find_love_binary)
if [ -z "$LOVE_BIN" ]; then
	echo "error: no LÖVE binary found (looked for $LOCAL_LOVE and 'love' on PATH)."
	echo "Install LÖVE (see ./setup.sh) or place a bundled binary at bin/love.AppImage to run the e2e tier."
	exit 1
fi

love_args=""
for a in "$@"; do
	case "$a" in
		--paced)
			love_args="$love_args e2e-paced"
			;;
		--filmstrip)
			love_args="$love_args e2e-filmstrip"
			;;
		--filmstrip=*)
			interval="${a#--filmstrip=}"
			love_args="$love_args e2e-filmstrip e2e-filmstrip-interval=$interval"
			;;
		*)
			# assume a specific test file path
			love_args="$love_args $a"
			;;
	esac
done

E2E_DIR="tests/e2e"
files=$(ls "$E2E_DIR"/*_test.lua 2>/dev/null)

if [ -z "$files" ]; then
	echo "no e2e test files found under $E2E_DIR"
	exit 0
fi

overall_status=0
passed_files=0
failed_files=0
cancelled_files=0

for f in $files; do
	echo "== $f =="
	"$LOVE_BIN" . "e2e=$f" $love_args
	status=$?

	if [ $status -eq 0 ]; then
		passed_files=$((passed_files + 1))
	elif [ $status -eq 2 ]; then
		echo "== $f: CANCELLED =="
		cancelled_files=$((cancelled_files + 1))
	else
		echo "== $f: FAILED =="
		failed_files=$((failed_files + 1))
		overall_status=1
	fi
	echo
done

echo "e2e summary: ${passed_files} file(s) passed, ${failed_files} file(s) failed, ${cancelled_files} file(s) cancelled"

exit $overall_status
