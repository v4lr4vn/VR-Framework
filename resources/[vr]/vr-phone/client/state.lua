Phone = Phone or {}

Phone.State = {
    open = false,    -- the phone is out and the player is using it
    busy = false,    -- the phone is waiting for the server to answer
    fold = 'open',   -- 'cover', 'flex' or 'open'
    typing = false,  -- a text box has focus, so movement keys must not move the character
    call = false,    -- a phone call is active. Only then is the phone held to the ear.
    camera = false,  -- the Camera app is on: the mouse turns the game camera, the screen is only a viewfinder
}
