export const ERR = {
  not_ready: 'The creator is still loading, try again',
  not_admin: 'Admins only',
  bad_request: 'Something went wrong, try again',
  bad_bank: 'That bank no longer exists',
  bad_element: 'That entry no longer exists',
  bad_type: 'That type does not exist',
  bad_value: 'That value is not allowed',
  bad_name: 'Use 2 to 40 letters, numbers or dashes',
  bad_needs: 'That requirement is not allowed',
  needs_loop: 'That would make the steps wait on each other',
  exists: 'A bank with that name already exists',
  limit: 'You reached the limit',
  no_position: 'Could not read your position',
  slow_down: 'Slow down a little',
  failed: 'Something went wrong, try again',
  no_doorlock: 'vr-doorlock is not running',
  bad_door: 'That is not a usable door',
  door_added: 'That door is already on this step',
  door_failed: 'The door could not be made',
  no_session: 'The connection was lost',
};

export const errorText = (code) => ERR[code] || ERR.failed;

export const rgb = (c, a = 1) => `rgba(${c[0]}, ${c[1]}, ${c[2]}, ${a})`;

export const clock = (s) => {
  s = Math.max(0, Math.floor(s));
  const m = Math.floor(s / 60);
  return `${m}:${String(s % 60).padStart(2, '0')}`;
};
