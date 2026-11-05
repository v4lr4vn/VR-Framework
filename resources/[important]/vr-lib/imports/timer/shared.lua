local Timer = {}
Timer.__index = Timer

local function now()
    return GetGameTimer()
end

function Timer:run()
    if self.running then return end
    self.running = true
    local function loop()
        while self.running and not self.paused do
            if self:getTimeLeft('ms') <= 0 then
                self.running = false
                self:onEnd()
                return
            end
            Wait(0)
        end
        self.running = false
    end
    if self.async then CreateThread(loop) else loop() end
end

function Timer:onEnd()
    if self.done then return end
    self.done = true
    if self.cb then self.cb() end
end

function Timer:forceEnd(triggerOnEnd)
    if self.done then return end
    self.paused = true
    self.running = false
    self.remaining = 0
    if triggerOnEnd then self:onEnd() else self.done = true end
end

function Timer:pause()
    if self.paused or self.done then return end
    self.remaining = self:getTimeLeft('ms')
    self.paused = true
end

function Timer:play()
    if not self.paused or self.done then return end
    self.paused = false
    self.startTime = now()
    self.duration = self.remaining
    self:run()
end

function Timer:isPaused()
    return self.paused == true
end

function Timer:restart(async)
    self.done = false
    self.paused = false
    self.running = false
    self.startTime = now()
    self.duration = self.initial
    if async ~= nil then self.async = async end
    self:run()
end

function Timer:getTimeLeft(format)
    local ms
    if self.done then
        ms = 0
    elseif self.paused then
        ms = self.remaining or 0
    else
        ms = math.max(0, self.duration - (now() - self.startTime))
    end
    if format == 'ms' then return ms end
    if format == 's' then return ms / 1000 end
    if format == 'm' then return ms / 60000 end
    if format == 'h' then return ms / 3600000 end
    return {
        ms = ms,
        s = ms / 1000,
        m = ms / 60000,
        h = ms / 3600000,
    }
end

return function(time, onEnd, async)
    if type(time) ~= 'number' or time < 0 then error('timer requires a positive number', 2) end
    local self = setmetatable({ initial = time, duration = time, startTime = now(), cb = onEnd, async = async ~= false, paused = false, done = false }, Timer)
    self:run()
    return self
end
