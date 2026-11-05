// Whole dollars with thousands separators: 12345 -> "$12,345". Negative amounts keep the minus sign in front.
export function money(n) {
  const v = Math.round(Number(n) || 0);
  const body = Math.abs(v).toLocaleString('en-US');
  return `${v < 0 ? '-' : ''}$${body}`;
}
