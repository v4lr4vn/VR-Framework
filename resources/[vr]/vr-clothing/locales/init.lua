Locales = {}

function _L(key)
	local lang = GetConvar("vr-clothing:locale", "en")
	if not Locales[lang] then
		lang = "en"
	end
	local value = Locales[lang]
	for k in key:gmatch("[^.]+") do
		value = value[k]
		if not value then
			print("Missing locale for: " .. key)
			return ""
		end
	end
	return value
end
