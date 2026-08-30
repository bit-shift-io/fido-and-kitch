-- A purely decorative prop with two independently-ordered Sprite layers --
-- e.g. a base that should render behind other props sharing its footprint,
-- and a top piece that should render in front of them. Exists to exercise
-- the multi-sprite renderOrder split (Entity:hasSplitRenderOrder,
-- Map:drawEntities in src/map/init.lua): since its two Sprites carry
-- different renderOrder values by default, this entity always draws as two
-- separate units in the global sort rather than as one atomic entity.
local LayeredProp = Class{__includes = Entity}

function LayeredProp:init(object)
	Entity.init(self, object, 'layered_prop')

	local props = object.properties or {}
	local position = Rect.centreOfMapObject(object)
	local shape_arguments = Rect.shapeArgs(object.width, object.height)

	self.backSprite = self:addComponent(Sprite{
		image = props.backImage,
		position = position,
		shape_arguments = shape_arguments,
		renderOrder = tonumber(props.backRenderOrder) or -1,
	})

	self.frontSprite = self:addComponent(Sprite{
		image = props.frontImage,
		position = position,
		shape_arguments = shape_arguments,
		renderOrder = tonumber(props.frontRenderOrder) or 1,
	})
end

return LayeredProp
