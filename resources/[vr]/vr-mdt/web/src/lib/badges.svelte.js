export const badges = $state({});

export function setBadge(id, n) {
  badges[id] = n || null;
}
