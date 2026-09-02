-- Former WIP scratch ('wip trails') that defined its own love.load/love.draw,
-- which collides with the e2e runner's love callbacks (src/main.lua drives
-- every *_test.lua through the runner surface), so the suite crashed with
-- 'bad argument #1 to draw (Drawable expected, got nil)' before any test ran.
-- Converted to a proper harness test that preserves the original concern: do
-- LÖVE 12 meshes carry per-vertex color, as trail rendering would need? Pure
-- API-surface assertion; no game and no rendering involved.
--
-- Run with: bin/love.AppImage . e2e=tests/e2e/vertex_color_test.lua
test("meshes carry a per-vertex color attribute (LÖVE 12)", function()
	local mesh = love.graphics.newMesh({
		{ 100, 300, 0, 0, 1, 0, 0 },
		{ 200, 300, 0, 0, 0, 1, 0 },
		{ 150, 200, 0, 0, 0, 0, 1 },
	}, "triangles")

	assertEqual(3, mesh:getVertexCount(), "expected the 3 triangle vertices")

	-- 'VertexColor' is the attribute name LÖVE 12 uses for a mesh's
	-- per-vertex RGBA (the default format is
	-- VertexPosition,VertexTexCoord,VertexColor); pinning it here guards the
	-- trail/mesh path from silently losing tinting on some LÖVE bump.
	local hasVertexColor = false
	for _, attrib in ipairs(mesh:getVertexFormat()) do
		if attrib.name == "VertexColor" then
			hasVertexColor = true
		end
	end
	assertTrue(hasVertexColor, "expected a vertexcolor attribute in the mesh vertex format")
end)
