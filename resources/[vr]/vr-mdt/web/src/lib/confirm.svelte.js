export const confirmState = $state({ open: false, title: '', text: '', yes: 'Confirm', no: 'Cancel', danger: false });

let resolver = null;

export function confirm(opts) {
  if (resolver) resolver(false);
  Object.assign(confirmState, { yes: 'Confirm', no: 'Cancel', danger: false, text: '' }, opts, { open: true });
  return new Promise((resolve) => {
    resolver = resolve;
  });
}

export function answerConfirm(value) {
  confirmState.open = false;
  const r = resolver;
  resolver = null;
  r?.(value);
}
