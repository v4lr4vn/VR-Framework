const params = new URLSearchParams(window.location.search);

export const mockState = {
  dept: params.get('dept') || 'police',
  boss: params.get('boss') !== '0',
  now: () => Math.floor(Date.now() / 1000),
  push: null,
};

export function push(name, payload) {
  window.postMessage({ type: 'push', name, payload }, '*');
}
