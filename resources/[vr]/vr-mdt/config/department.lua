Config.Roster = {
    divisions = {
        police = { 'Patrol', 'Traffic', 'Detectives', 'Gang unit', 'SWAT', 'K9', 'Air support', 'Marine', 'FTO', 'Trainee' },
        ems = { 'Paramedic', 'Fire rescue', 'Search and rescue', 'Air ambulance', 'Critical care', 'Trainee' },
        doj = { 'Criminal court', 'Civil court', 'Prosecution', 'Public defense', 'Clerk' },
        dispatch = { 'Police dispatch', 'EMS dispatch', 'Supervisor', 'Trainee' },
    },
    hireDivisions = {
        police = { 'Trainee' },
    },
    maxDivisions = 8,
    sessionsShown = 20,
    keepDutyDays = 120,
    heartbeatSeconds = 60,
}

Config.Fto = {
    traineeDivision = 'Trainee',
    graduateDivision = 'Patrol',
    phases = 4,
    categories = { 'Driving', 'Officer safety', 'Report writing', 'Radio', 'Knowledge of law', 'Conduct' },
}

Config.Bulletin = {
    pageSize = 20,
    maxExpiryDays = 90,
    purgeExpiredDays = 30,
}
