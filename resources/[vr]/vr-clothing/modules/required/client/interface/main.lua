local Logger = require("modules.utility.shared.logger")

if _G.Interface then
    Logger.info("(modules/interface) _G.Interface already exists, using existing instance")
    return
end

Logger.info("(modules/interface) _G.Interface not found, creating first global instance")

local Interface = {}
Interface.__index = Interface

Interface.store = {
    status = {
        app = {
            loaded = false,
            dataLoaded = false,
        }
    },
    visibility = {
        app = false,
        loadingScreen = false,
        exportPanel = false,
    },
    callbacks = {}
}

function Interface.new()
    local self = setmetatable({}, Interface)
    self:registerInitialCallbacks()

    exports("getInterfaceVisibilityState", function()
        return self.store.visibility
    end)

    return self
end

function Interface:message(action, data)
    assert(action, "(interface:message) `action` parameter is nil.")
    SendNUIMessage({
        action = action,
        data = data
    })
end

function Interface:toggle(state, affectInputFocus)
    local newState = not self.store.visibility.app

    if type(state) == "boolean" then
        newState = state
    end

    Logger.info("(interface:toggle) newState: ", newState)

    if newState and self.store.visibility.loadingScreen then
        Logger.verbosef("[client] [interface/toggle] newState is true and loading screen is visible, toggling loading screen off")
        self:setLoadingState(false)
    end

    self:message("state::visibility::app::set", newState)

    if type(affectInputFocus) == "boolean" and not affectInputFocus then
        return Logger.info("(interface:toggle) not affecting affectInputFocus")
    end

    SetNuiFocus(newState, newState)
end

function Interface:registerInitialCallbacks()
    self:on("state::visibility::app::sync", function(state, cb)
        self.store.visibility.app = state
        SetNuiFocus(state, state)
        cb(200)
    end)

    self:on("state::visibility::loading_screen::sync", function(state, cb)
        self.store.visibility.loadingScreen = state
        cb(200)
    end)

    self:on("state::visibility::export_panel::sync", function(state, cb)
        self.store.visibility.exportPanel = state
        cb(200)
    end)

    self:on("APP_LOADED", function(_, cb)
        self.store.status.app.loaded = true
        cb(200)
    end)
end

function Interface:on(event, callback)
    assert(event, "[Interface] [On] `event` parameter is nil.")
    assert(callback, "[Interface] [On] `callback` parameter is nil.")

    if not self.store.callbacks[event] then
        self.store.callbacks[event] = {}

        RegisterNuiCallback(event, function(data, cb)
            for i, handler in ipairs(self.store.callbacks[event]) do
                if handler then
                    local success, err = pcall(handler, data, cb)
                    if not success then
                        Logger.warningf("[Interface] [On] Error (%s) encountered at: (%s) (Index: %s)", err, event, i)
                    end
                else
                    Logger.debugf("[Interface] [On] Skipping callback at index (%s) for event (%s)", i, event)
                end
            end
        end)
    end

    table.insert(self.store.callbacks[event], callback)
    return #self.store.callbacks[event]
end

function Interface:removeCallback(event, index)
    assert(event, "[Interface] [RemoveCallback] `event` parameter is nil.")
    assert(index, "[Interface] [RemoveCallback] `callback` parameter is nil.")
    assert(self.store.callbacks[event], "[Interface] [RemoveCallback] Event not found, event: " .. event)
    assert(self.store.callbacks[event][index], "[Interface] [RemoveCallback] Callback not found, event: " .. event .. " index: " .. index)

    Logger.infof("[Interface] [RemoveCallback] Deleted callback for event: (%s), index: (%s)", event, index)
    self.store.callbacks[event][index] = false
end

function Interface:setLoadingState(state)
    local newState = (type(state) == "boolean") and state or not self.store.visibility.loadingScreen
    self:message("state::visibility::loading_screen::set", newState)
end

function Interface:syncCharacterAppearanceStateAndSettingsState(config)
    if not config then
        Logger.warning("[Interface] [syncCharacterAppearanceStateAndSettingsState] config is nil, using empty table")
        config = {}
    end

    self:setLoadingState(true)

    local bridge = require("game.bridge")

    if not self.store.status.app.dataLoaded then
        local locale = GetConvar("vr-clothing:locale", "en")
        local selectedLocale = Locales[locale] or Locales.en

        local theme = require("shared.theme")

        self:message("state::locales::set", selectedLocale.UI)
        self:message("state::visibility::frame::set", "5j15hmhm4-kk7dd--k1-86b5-36nb1d131efe76f829")
        self:message("state::theme::set", theme)

        self.store.status.app.dataLoaded = true
        Logger.verbosef("[modules/interface/syncCharacterAppearanceStateAndSettingsState] Successfully loaded all the required data.")
    end

    local appearance = client.getAppearance()
    local settings = bridge:getAppearanceSettings()

    self:message("state::script::config::set", config)
    self:message("state::game::store::appearance::data::set", settings)
    self:message("state::character::appearance::set", appearance)

    if appearance.tattoos then
        client.setPedTattoos(cache.ped, appearance.tattoos)
    end
end

_G.Interface = Interface.new()
