<script>
  let { value, min = 0, max = 1, step = 0.01, onchange, label = '' } = $props();
  const fill = $derived(((value - min) / (max - min)) * 100);
</script>

<input
  class="slider"
  type="range"
  {min}
  {max}
  {step}
  {value}
  aria-label={label}
  style:--fill="{fill}%"
  oninput={(e) => onchange?.(Number(e.currentTarget.value))}
/>

<style>
  .slider {
    -webkit-appearance: none;
    appearance: none;
    width: 100%;
    height: 28px;
    background: transparent;
    margin: 0;
    cursor: pointer;
  }
  .slider::-webkit-slider-runnable-track {
    height: 6px;
    border-radius: 3px;
    background: linear-gradient(90deg, var(--accent) var(--fill), var(--surface-3) var(--fill));
  }
  .slider::-webkit-slider-thumb {
    -webkit-appearance: none;
    appearance: none;
    width: 22px;
    height: 22px;
    margin-top: -8px;
    border-radius: 50%;
    background: #fff;
    border: 0;
    box-shadow: 0 1px 4px rgba(0, 0, 0, 0.35);
  }
</style>
