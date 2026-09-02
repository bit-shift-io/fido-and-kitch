-- Frame capture requires real rendering, which this (headless) tier's
-- love.* mock cannot provide -- calling it here must be a loud, explicit
-- error naming the e2e tier as the requirement, never a silent no-op
-- (DECISIONS.md Q6/Q13).
local Capture = require("tests.support.capture")

test("calling Capture.capture from the headless tier raises an explicit error naming the e2e tier", function()
	local ok, err = pcall(Capture.capture, "should_never_be_written")

	assertFalse(ok, "expected Capture.capture to raise an error outside the e2e tier")
	assertTrue(
		tostring(err):find("e2e", 1, true) ~= nil,
		"expected the error message to name the e2e tier: " .. tostring(err)
	)
end)
