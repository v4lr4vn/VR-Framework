Config.Jobs.builder = {
    label = 'Builder',
    job = 'builder',
    icon = 'fa-helmet-safety',
    description = 'Haul materials, hammer, drill and weld to finish the build with your crew',
    crew = 3,
    depot = {
        ped = 's_m_y_construct_01',
        coords = vec4(-163.5, -1004.6, 28.3, 250.0),
        blip = { sprite = 566, colour = 47, scale = 0.8, label = 'Building Site' },
    },
    sites = {
        {
            label = 'Alta Street build',
            tasks = {
                { type = 'carry', label = 'Move the blocks', from = vec3(-171.0, -1011.0, 28.3), to = vec3(-150.0, -1020.0, 28.3) },
                { type = 'carry', label = 'Move the blocks', from = vec3(-173.0, -1013.0, 28.3), to = vec3(-148.0, -1022.0, 28.3) },
                { type = 'hammer', label = 'Frame the wall', at = vec3(-152.0, -1018.0, 28.3) },
                { type = 'drill', label = 'Fix the anchors', at = vec3(-146.0, -1018.0, 28.3) },
                { type = 'weld', label = 'Weld the beam', at = vec3(-144.0, -1024.0, 28.3) },
                { type = 'hammer', label = 'Nail the boards', at = vec3(-150.0, -1026.0, 28.3) },
                { type = 'carry', label = 'Carry the pipes', from = vec3(-175.0, -1009.0, 28.3), to = vec3(-142.0, -1020.0, 28.3) },
                { type = 'weld', label = 'Weld the joint', at = vec3(-140.0, -1022.0, 28.3) },
            },
        },
    },
    work = {
        hammer = { seconds = 7, scenario = 'WORLD_HUMAN_HAMMERING', label = 'Hammering' },
        drill = { seconds = 8, scenario = 'WORLD_HUMAN_CONST_DRILL', label = 'Drilling' },
        weld = { seconds = 10, scenario = 'WORLD_HUMAN_WELDING', label = 'Welding' },
    },
    workRange = 3.0,
    carryRange = 3.5,
    carryModel = 'prop_cons_blocks01',
    onePercentWorth = 12,
    xpFull = 400,
    completionBonus = 100,
    penaltyIncomplete = 0,
}
