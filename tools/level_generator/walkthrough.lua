-- Emits the human-readable solution steps for a plan (tools.level_generator.plan).
-- One take-key / use-cage pair per objective, in plan order, ending with a
-- reminder that the exit opens on its own once every cage is used
-- (DECISIONS.md Q13 -- there's no bird/actor_count step to route through).
local Walkthrough = {}

function Walkthrough.build(plan, flourishSteps)
	local lines = {}
	for _, objective in ipairs(plan) do
		table.insert(lines, string.format(
			'P1: take the %s key (zone %d).', objective.color, objective.keyZoneIndex
		))
		table.insert(lines, string.format(
			'P1: use the %s cage (zone %d) to unlock it.', objective.color, objective.cageZoneIndex
		))
	end
	table.insert(lines, 'Once every cage has been used, the exit opens automatically -- walk both players through it to finish.')
	for _, step in ipairs(flourishSteps or {}) do
		table.insert(lines, step)
	end
	return table.concat(lines, '\n') .. '\n'
end

return Walkthrough
