const errors = {
  bad_request: "That didn't work. Check what you entered.",
  not_allowed: "You don't have permission to do that.",
  no_access: "Your job doesn't have MDT access.",
  off_duty: 'Go on duty first.',
  not_at_desk: 'The dispatch MDT only works inside the dispatch centre.',
  not_loaded: 'Load a character first.',
  not_ready: 'The MDT is still starting up.',
  not_found: "That doesn't exist anymore.",
  slow_down: 'Slow down a little.',
  server_error: 'Something went wrong.',
  save_failed: "Couldn't save that. Try again.",
  call_closed: 'That call is closed.',
  unit_unavailable: "That unit can't take this call.",
  in_use: "That's still in use.",
  already_exists: 'That already exists.',
  too_large: 'That file is too large.',
  not_nearby: 'They need to be close to you.',
  no_target: 'Nobody close enough.',
  cant_self: "You can't do that to yourself.",
  not_in_prison: "They're not in prison.",
  locked: "That's locked.",
  no_money: "They don't have enough money.",
};

const extra = import.meta.glob('./lang/*.js', { eager: true });
for (const m of Object.values(extra)) Object.assign(errors, m.default || {});

export function errorText(key) {
  return errors[key] || errors.server_error;
}
