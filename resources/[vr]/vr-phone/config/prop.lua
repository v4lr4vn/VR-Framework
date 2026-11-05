Config = Config or {}

-- The phone in the player's hand.
-- The model below is a stand-in. Replace it with the foldable model when it is ready.
-- Add the model's stream files to this resource (or a separate stream resource) and change `model`.
Config.Prop = {
    model = 'prop_npc_phone_02',
    bone = 28422, -- right hand
    offset = vector3(0.0, 0.0, 0.0),
    rotation = vector3(0.0, 0.0, 0.0),

    -- Where the phone sits in the hand during a selfie (the arm is held out). Change these if it looks wrong in the hand.
    selfie = {
        offset = vector3(0.0, 0.0, 0.0),
        rotation = vector3(0.0, 0.0, 0.0),
    },

    -- Upper-body animations, on foot and in a vehicle.
    --   hold  = the phone held in front of you. Used for every fold state, including the small screen.
    --   call  = the phone held to your ear. Only used while a phone call is active.
    anims = {
        foot = {
            intro = { dict = 'cellphone@', name = 'cellphone_text_in', flag = 50 },
            hold = { dict = 'cellphone@', name = 'cellphone_text_read_base', flag = 49 },
            call = { dict = 'cellphone@', name = 'cellphone_call_listen_base', flag = 49 },
            outro = { dict = 'cellphone@', name = 'cellphone_text_out', flag = 48 },
            -- The front (selfie) camera: the arm is held out in front of you with the phone in the hand.
            selfie = { dict = 'cellphone@self', name = 'selfie', flag = 49 },
        },
        vehicle = {
            intro = { dict = 'anim@cellphone@in_car@ps', name = 'cellphone_text_in', flag = 50 },
            hold = { dict = 'anim@cellphone@in_car@ps', name = 'cellphone_text_read_base', flag = 49 },
            call = { dict = 'anim@cellphone@in_car@ps', name = 'cellphone_call_listen_base', flag = 49 },
            outro = { dict = 'anim@cellphone@in_car@ps', name = 'cellphone_text_out', flag = 48 },
            selfie = { dict = 'cellphone@self', name = 'selfie', flag = 49 },
        },
    },
}
