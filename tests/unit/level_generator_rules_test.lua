local Rules = require("tools.level_generator.rule_set")
local Layout = require("tools.level_generator.layout")
local Rng = require("tools.level_generator.rng")

-- Rule conformance: every file discovered under rules/ must satisfy the
-- uniform interface, so a new rule file needs no registration elsewhere to
-- get covered here.
test("every discovered rule conforms to the {id, canApply, apply} interface", function()
	local rules = Rules.discover()
	assertTrue(#rules >= 2, "expected at least 2 rules")

	for _, rule in ipairs(rules) do
		assertTrue(type(rule.id) == "string" and #rule.id > 0, "rule missing a string id")
		assertTrue(type(rule.canApply) == "function", rule.id .. " missing canApply")
		assertTrue(type(rule.apply) == "function", rule.id .. " missing apply")
	end
end)

test("every applicable rule returns objects, idsUsed, and a walkthroughStep", function()
	local rules = Rules.discover()
	local layout = Layout.generate(Rng.new(11), { size = "large" })

	for _, rule in ipairs(rules) do
		if rule.canApply(layout) then
			local result = rule.apply(Rng.new(11), layout, 500)
			assertTrue(type(result.objects) == "table" and #result.objects > 0, rule.id .. " returned no objects")
			assertTrue(type(result.idsUsed) == "number" and result.idsUsed > 0, rule.id .. " missing idsUsed")
			assertTrue(
				type(result.walkthroughStep) == "string" and #result.walkthroughStep > 0,
				rule.id .. " missing a walkthrough step"
			)

			-- object ids must all fall within [startId, startId + idsUsed) with no collisions
			local seen = {}
			for _, object in ipairs(result.objects) do
				assertTrue(
					object.id >= 500 and object.id < 500 + result.idsUsed,
					rule.id .. " emitted an id outside its declared range"
				)
				assertFalse(seen[object.id] == true, rule.id .. " emitted a duplicate id")
				seen[object.id] = true
			end
		end
	end
end)

test("rules are deterministic for the same seed", function()
	local rules = Rules.discover()
	local layout = Layout.generate(Rng.new(11), { size = "large" })

	for _, rule in ipairs(rules) do
		if rule.canApply(layout) then
			local a = rule.apply(Rng.new(7), layout, 500)
			local b = rule.apply(Rng.new(7), layout, 500)
			assertEqual(a.walkthroughStep, b.walkthroughStep)
			assertEqual(#a.objects, #b.objects)
		end
	end
end)
