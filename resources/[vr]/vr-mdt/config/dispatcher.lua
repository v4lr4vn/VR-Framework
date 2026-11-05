Config.Dispatcher = {
    autoDuty = true,

    zones = {
        { label = 'Mission Row dispatch centre', coords = vec3(455.12, -959.69, 30.45), radius = 30.0 },
    },

    computers = {
        { label = 'Dispatch desk 1', coords = vec3(465.42, -954.26, 30.45), radius = 1.2 },
    },

    computerRange = 2.5,

    radio = {
        channels = {
            { id = 1, label = 'LSPD Main', dept = 'police' },
            { id = 2, label = 'LSPD Tac 1', dept = 'police' },
            { id = 3, label = 'LSPD Tac 2', dept = 'police' },
            { id = 5, label = 'EMS Main', dept = 'ems' },
            { id = 6, label = 'EMS Tac', dept = 'ems' },
            { id = 9, label = 'Interop', dept = 'all' },
        },
        listen = { 1, 5 },
        transmit = 1,
        radial = true,
    },
}
