export const money = (n) => {
  const v = Math.round(Number(n) || 0);
  const s = Math.abs(v).toLocaleString('en-US');
  return `${v < 0 ? '-' : ''}$${s}`;
};

export const signed = (n) => {
  const v = Math.round(Number(n) || 0);
  if (v === 0) return '$0';
  return `${v > 0 ? '+' : '-'}$${Math.abs(v).toLocaleString('en-US')}`;
};

export const acct = (n) => {
  const s = String(n || '');
  return s.replace(/(\d{2})(\d{4})(\d{4})/, '$1 $2 $3');
};

const pad = (n) => String(n).padStart(2, '0');

export const date = (t) => {
  if (!t) return '';
  const d = new Date(t * 1000);
  return `${pad(d.getDate())}/${pad(d.getMonth() + 1)}/${d.getFullYear()}`;
};

export const dateTime = (t) => {
  if (!t) return '';
  const d = new Date(t * 1000);
  return `${pad(d.getDate())}/${pad(d.getMonth() + 1)} ${pad(d.getHours())}:${pad(d.getMinutes())}`;
};

export const ago = (t, now = Date.now() / 1000) => {
  const s = Math.max(0, Math.round(now - t));
  if (s < 60) return 'just now';
  if (s < 3600) return `${Math.floor(s / 60)}m ago`;
  if (s < 86400) return `${Math.floor(s / 3600)}h ago`;
  if (s < 86400 * 7) return `${Math.floor(s / 86400)}d ago`;
  return date(t);
};

export const until = (t, now = Date.now() / 1000) => {
  const s = Math.round(t - now);
  if (s <= 0) return 'now';
  if (s < 3600) return `in ${Math.max(1, Math.floor(s / 60))}m`;
  if (s < 86400) return `in ${Math.floor(s / 3600)}h ${pad(Math.floor((s % 3600) / 60))}m`;
  return `in ${Math.floor(s / 86400)}d ${Math.floor((s % 86400) / 3600)}h`;
};

export const TYPE = {
  personal: { label: 'Personal', icon: 'fa-user' },
  savings: { label: 'Savings', icon: 'fa-piggy-bank' },
  shared: { label: 'Shared', icon: 'fa-users' },
  job: { label: 'Business', icon: 'fa-briefcase' },
  gang: { label: 'Organisation', icon: 'fa-people-group' },
};

export const KIND = {
  deposit: { icon: 'fa-arrow-down', label: 'Deposit' },
  withdraw: { icon: 'fa-arrow-up', label: 'Withdrawal' },
  transfer_in: { icon: 'fa-arrow-right-to-bracket', label: 'Transfer in' },
  transfer_out: { icon: 'fa-arrow-right-from-bracket', label: 'Transfer out' },
  interest: { icon: 'fa-percent', label: 'Interest' },
  loan: { icon: 'fa-hand-holding-dollar', label: 'Loan' },
  repayment: { icon: 'fa-file-invoice-dollar', label: 'Repayment' },
  fee: { icon: 'fa-receipt', label: 'Fee' },
  salary: { icon: 'fa-briefcase', label: 'Salary' },
  payment_in: { icon: 'fa-circle-down', label: 'Payment in' },
  payment_out: { icon: 'fa-cart-shopping', label: 'Payment' },
  commission: { icon: 'fa-coins', label: 'Commission' },
  adjust: { icon: 'fa-scale-balanced', label: 'Adjustment' },
  opened: { icon: 'fa-flag', label: 'Opened' },
};
