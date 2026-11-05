Locale = {}
Locale.__index = Locale

local function translate(phrase, subs)
    if not subs then return phrase end
    for k, v in pairs(subs) do
        phrase = phrase:gsub('%%{' .. k .. '}', (tostring(v):gsub('%%', '%%%%')))
    end
    return phrase
end

function Locale.new(_, opts)
    local self = setmetatable({}, Locale)
    self.fallback = opts.fallbackLang and Locale:new({ warnOnMissing = false, phrases = opts.fallbackLang.phrases }) or false
    self.warnOnMissing = opts.warnOnMissing ~= false
    self.phrases = {}
    self:extend(opts.phrases or {})
    return self
end

function Locale:extend(phrases, prefix)
    for key, phrase in pairs(phrases) do
        local fullKey = prefix and (prefix .. '.' .. key) or key
        if type(phrase) == 'table' then
            self:extend(phrase, fullKey)
        else
            self.phrases[fullKey] = phrase
        end
    end
end

function Locale:clear() self.phrases = {} end

function Locale:replace(phrases)
    self:clear()
    self:extend(phrases or {})
end

function Locale:locale(newLocale)
    if newLocale then self.currentLocale = newLocale end
    return self.currentLocale
end

function Locale:has(key)
    return self.phrases[key] ~= nil
end

function Locale:delete(target, prefix)
    if type(target) == 'string' then
        self.phrases[target] = nil
        return
    end
    for key, phrase in pairs(target) do
        local fullKey = prefix and (prefix .. '.' .. key) or key
        if type(phrase) == 'table' then self:delete(phrase, fullKey) else self.phrases[fullKey] = nil end
    end
end

function Locale:t(key, subs)
    local phrase = self.phrases[key]
    if type(phrase) == 'string' then return translate(phrase, subs) end
    if self.warnOnMissing then print(('^3Warning: Missing phrase for key: "%s"^0'):format(key)) end
    if self.fallback then return self.fallback:t(key, subs) end
    return key
end
