Perms = {}

local function courtJobs(...)
    local out = {}
    for _, key in ipairs({ ... }) do
        for _, job in ipairs((Config.Court or {})[key] or {}) do out[#out + 1] = job end
    end
    return out
end

Perms.list = {
    { key = 'dispatch.manage', dept = 'all', group = 'Dispatch', label = 'Run dispatch: assign units, change priority, close calls', grade = 2 },
    { key = 'bulletin.post', dept = 'all', group = 'Department', label = 'Post and pin bulletins', grade = 2 },
    { key = 'roster.view', dept = 'all', group = 'Department', label = 'See the roster', grade = 0 },
    { key = 'roster.manage', dept = 'all', group = 'Department', label = 'Hire, fire, promote, set callsigns and divisions', grade = 3 },
    { key = 'permissions.manage', dept = 'all', group = 'Department', label = 'Change what each rank can do', grade = nil },

    { key = 'records.view', dept = 'police', group = 'Records', label = 'Look up citizens, vehicles and weapons', grade = 0 },
    { key = 'records.edit', dept = 'police', group = 'Records', label = 'Edit notes and flags on records', grade = 0 },
    { key = 'licences.edit', dept = 'police', group = 'Records', label = 'Grant and revoke licences', grade = 2 },
    { key = 'mugshots.take', dept = 'police', group = 'Records', label = 'Take mugshots', grade = 0 },
    { key = 'warrants.create', dept = 'police', group = 'Warrants', label = 'Request warrants', grade = 0 },
    { key = 'bolos.manage', dept = 'police', group = 'Warrants', label = 'Create and close BOLOs', grade = 0 },
    { key = 'reports.create', dept = 'police', group = 'Reports', label = 'Write reports', grade = 0 },
    { key = 'reports.edit_any', dept = 'police', group = 'Reports', label = "Edit other officers' reports", grade = 2 },
    { key = 'reports.delete', dept = 'police', group = 'Reports', label = 'Delete reports', grade = 3 },
    { key = 'sentencing.apply', dept = 'police', group = 'Reports', label = 'Apply fines and jail time', grade = 0 },
    { key = 'cases.view', dept = 'police', group = 'Cases', label = 'See cases and evidence', grade = 0 },
    { key = 'cases.manage', dept = 'police', group = 'Cases', label = 'Open, edit and close cases', grade = 1 },
    { key = 'evidence.manage', dept = 'police', group = 'Cases', label = 'Add and remove evidence', grade = 0 },
    { key = 'penal.manage', dept = 'police', group = 'Penal code', label = 'Edit charges, fines and jail times', grade = 3 },
    { key = 'prison.manage', dept = 'police', group = 'Prison', label = 'Release inmates and change sentences', grade = 2 },
    { key = 'ia.view', dept = 'police', group = 'Internal Affairs', label = 'See Internal Affairs files', grade = 3 },
    { key = 'ia.manage', dept = 'police', group = 'Internal Affairs', label = 'Open and work Internal Affairs files', grade = 3 },
    { key = 'fto.view', dept = 'police', group = 'Training', label = 'See trainee evaluations', grade = 1 },
    { key = 'fto.manage', dept = 'police', group = 'Training', label = 'Write evaluations and sign off trainees', grade = 1 },
    { key = 'cameras.view', dept = 'police', group = 'Cameras', label = 'Watch security cameras', grade = 0 },
    { key = 'cameras.manage', dept = 'police', group = 'Cameras', label = 'Add and remove security cameras', grade = 3 },
    { key = 'bodycams.view', dept = 'police', group = 'Cameras', label = "Watch officers' bodycams", grade = 2 },

    { key = 'patients.view', dept = 'ems', group = 'Patients', label = 'See patient records', grade = 0 },
    { key = 'patients.edit', dept = 'ems', group = 'Patients', label = 'Edit patient records', grade = 0 },
    { key = 'medreports.create', dept = 'ems', group = 'Patients', label = 'Write medical reports', grade = 0 },
    { key = 'medreports.edit_any', dept = 'ems', group = 'Patients', label = "Edit other medics' reports", grade = 2 },

    { key = 'dispatch.manage', dept = 'dispatch', group = 'Dispatch', label = 'Run dispatch: create and close calls, assign units, set unit status, change priority', grade = 0 },
    { key = 'radio.multi', dept = 'dispatch', group = 'Dispatch', label = 'Listen to police and EMS channels at once from the dispatch radio', grade = 0 },
    { key = 'bulletin.post', dept = 'dispatch', group = 'Department', label = 'Post and pin bulletins', grade = 2 },
    { key = 'roster.view', dept = 'dispatch', group = 'Department', label = 'See the roster', grade = 0 },
    { key = 'roster.manage', dept = 'dispatch', group = 'Department', label = 'Hire, fire, promote, set callsigns and divisions', grade = 3 },
    { key = 'permissions.manage', dept = 'dispatch', group = 'Department', label = 'Change what each rank can do', grade = nil },
    { key = 'records.view', dept = 'dispatch', group = 'Records', label = 'Look up people, vehicles, warrants and convictions (read only)', grade = 0 },
    { key = 'bolos.manage', dept = 'dispatch', group = 'Records', label = 'Create and close BOLOs', grade = 0 },
    { key = 'reports.view', dept = 'dispatch', group = 'Records', label = 'Read police reports (read only)', grade = 0 },
    { key = 'cases.view', dept = 'dispatch', group = 'Records', label = 'See cases (read only)', grade = 0 },

    { key = 'court.view', dept = 'doj', group = 'Court', label = 'See court cases', grade = 0 },
    { key = 'court.manage', dept = 'doj', group = 'Court', label = 'File, schedule and rule on court cases', grade = 1, jobs = courtJobs('judgeJobs', 'prosecutorJobs') },
    { key = 'warrants.approve', dept = 'doj', group = 'Court', label = 'Approve and deny warrants', grade = 1, jobs = courtJobs('judgeJobs') },
    { key = 'records.view', dept = 'doj', group = 'Records', label = 'Look up citizens, vehicles and weapons', grade = 0 },
    { key = 'reports.view', dept = 'doj', group = 'Records', label = 'Read police reports', grade = 0 },
    { key = 'cases.view', dept = 'doj', group = 'Records', label = 'See cases and evidence', grade = 0 },
}

Perms.byDept = {}

for _, p in ipairs(Perms.list) do
    local depts = p.dept == 'all' and { 'police', 'ems', 'doj' } or { p.dept }
    for _, d in ipairs(depts) do
        Perms.byDept[d] = Perms.byDept[d] or {}
        Perms.byDept[d][p.key] = p
    end
end

local function forJob(p, job)
    if not p.jobs then return true end
    for _, j in ipairs(p.jobs) do
        if j == job then return true end
    end
    return false
end

function Perms.defaults(dept, grade, isboss, job)
    local out = {}
    for key, p in pairs(Perms.byDept[dept] or {}) do
        if forJob(p, job) and (isboss or (p.grade ~= nil and grade >= p.grade)) then out[key] = true end
    end
    return out
end

function Perms.exists(dept, key)
    return Perms.byDept[dept] ~= nil and Perms.byDept[dept][key] ~= nil
end

function Perms.allowedFor(dept, key, job)
    local p = Perms.byDept[dept] and Perms.byDept[dept][key]
    return p ~= nil and forJob(p, job)
end
