export const money = (n) => `$${Math.round(Number(n) || 0).toLocaleString('en-US')}`;

export const ERR = {
  not_ready: 'The job menu is not ready yet, try again in a moment',
  no_character: 'Choose a character first',
  bad_request: 'Something went wrong, try again',
  slow_down: 'Slow down a little',
  failed: 'Something went wrong, try again',
  already: 'You are already doing that',
  not_held: 'That job is not on your list',
  no_job: 'That job is not available right now',
  no_leave: 'Ask a manager or an admin to remove this job',
  deny_duty: 'Clock in and out at your own station',
  no_duty: 'You need a job to go on duty',
};

export const errorText = (code) => ERR[code] || ERR.failed;
