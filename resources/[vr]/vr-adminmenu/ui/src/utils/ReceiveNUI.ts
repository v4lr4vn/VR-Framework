import { onMount, onDestroy } from "svelte";

interface NuiMessage<T = unknown> {
  action: string;
  data: T;
}

export function ReceiveNUI<T = unknown>(
  action: string,
  handler: (data: T) => void
) {
  const eventListener = (event: MessageEvent<NuiMessage<T>>) => {
    const { action: eventAction, data } = event.data;

    eventAction === action && handler(data);
  };
  onMount(() => window.addEventListener("message", eventListener));
  onDestroy(() => window.removeEventListener("message", eventListener));
}

