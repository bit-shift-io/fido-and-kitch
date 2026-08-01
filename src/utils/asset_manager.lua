local AssetManager = { textures = {} }

function AssetManager.getImage(path)
	if not AssetManager.textures[path] then
		if love and love.graphics then
			AssetManager.textures[path] = love.graphics.newImage(path)
		else
			return nil
		end
	end
	return AssetManager.textures[path]
end

function AssetManager.clear()
	AssetManager.textures = {}
end

function AssetManager.getTextureCount()
	local count = 0
	for _ in pairs(AssetManager.textures) do
		count = count + 1
	end
	return count
end

return AssetManager