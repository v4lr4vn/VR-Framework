return function(path, pattern)
    local resource = GetCurrentResourceName()
    local base = GetResourcePath(resource)
    local windows = package and package.config and package.config:sub(1, 1) == '\\'
    local dir = ('%s/%s'):format(base, path):gsub('//', '/')
    local command = windows and ('dir "%s" /b'):format(dir:gsub('/', '\\')) or ("ls -1 '%s'"):format(dir:gsub("'", ''))
    local handle = io.popen(command)
    if not handle then return {}, 0 end
    local files = {}
    for line in handle:lines() do
        if not pattern or line:match(pattern) then files[#files + 1] = line end
    end
    handle:close()
    return files, #files
end
