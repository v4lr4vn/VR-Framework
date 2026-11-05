return function(coords, rotation, offset)
    if type(rotation) == 'number' then rotation = vector3(0.0, 0.0, rotation) end
    local x = math.rad(rotation.x)
    local y = math.rad(rotation.y)
    local z = math.rad(rotation.z)
    local cx, sx = math.cos(x), math.sin(x)
    local cy, sy = math.cos(y), math.sin(y)
    local cz, sz = math.cos(z), math.sin(z)
    local ox = offset.x * (cy * cz - sx * sy * sz) - offset.y * cx * sz + offset.z * (sy * cz + sx * cy * sz)
    local oy = offset.x * (cy * sz + sx * sy * cz) + offset.y * cx * cz + offset.z * (sy * sz - sx * cy * cz)
    local oz = -offset.x * cx * sy + offset.y * sx + offset.z * cx * cy
    local out = vector3(coords.x + ox, coords.y + oy, coords.z + oz)
    if coords.w then return vector4(out.x, out.y, out.z, coords.w) end
    return out
end
