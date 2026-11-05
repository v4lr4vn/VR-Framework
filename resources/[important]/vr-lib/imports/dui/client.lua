local Dui = {}
Dui.__index = Dui
local seq = 0

function Dui:remove()
    if self.duiObject then
        SetDuiUrl(self.duiObject, 'about:blank')
        DestroyDui(self.duiObject)
        self.duiObject = nil
    end
end

function Dui:setUrl(url)
    self.url = url
    SetDuiUrl(self.duiObject, url)
end

function Dui:sendMessage(message)
    SendDuiMessage(self.duiObject, json.encode(message))
end

return {
    new = function(data)
        seq = seq + 1
        local self = setmetatable({}, Dui)
        self.id = ('%s_%s'):format(GetCurrentResourceName(), seq)
        self.url = data.url
        self.width = data.width or 1280
        self.height = data.height or 720
        self.dictName = ('vrlib_dui_dict_%s'):format(self.id)
        self.txtName = ('vrlib_dui_txt_%s'):format(self.id)
        self.duiObject = CreateDui(self.url, self.width, self.height)
        self.duiHandle = GetDuiHandle(self.duiObject)
        self.runtimeTxd = CreateRuntimeTxd(self.dictName)
        self.txdObject = CreateRuntimeTextureFromDuiHandle(self.runtimeTxd, self.txtName, self.duiHandle)
        if data.debug then print(('^5[vr-lib] dui %s created^7'):format(self.id)) end
        return self
    end,
}
