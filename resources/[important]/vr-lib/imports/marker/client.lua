local Marker = {}
Marker.__index = Marker

local function vec(v, d)
    if v == nil then return d end
    if type(v) == 'table' and not v.x then return vector3(v[1] or 0.0, v[2] or 0.0, v[3] or 0.0) end
    return v
end

function Marker:draw()
    local c = self.color
    DrawMarker(
        self.type,
        self.coords.x, self.coords.y, self.coords.z,
        self.direction.x, self.direction.y, self.direction.z,
        self.rotation.x, self.rotation.y, self.rotation.z,
        self.width, self.width, self.height,
        c.r or c[1] or 255, c.g or c[2] or 255, c.b or c[3] or 255, c.a or c[4] or 100,
        self.bobUpAndDown, self.faceCamera, 2, self.rotate, self.textureDict, self.textureName, self.invert
    )
end

return {
    new = function(data)
        local self = setmetatable({}, Marker)
        self.type = data.type or 1
        self.coords = vec(data.coords)
        self.width = (data.width or 2.0) + 0.0
        self.height = (data.height or 1.0) + 0.0
        self.color = data.color or { r = 245, g = 165, b = 36, a = 100 }
        self.rotation = vec(data.rotation, vector3(0.0, 0.0, 0.0))
        self.direction = vec(data.direction, vector3(0.0, 0.0, 0.0))
        self.bobUpAndDown = data.bobUpAndDown == true
        self.faceCamera = data.faceCamera ~= false
        self.rotate = data.rotate == true
        self.textureDict = data.textureDict
        self.textureName = data.textureName
        self.invert = data.invert == true
        return self
    end,
}
