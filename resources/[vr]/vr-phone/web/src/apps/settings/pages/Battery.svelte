<script>
  import { onMount } from 'svelte';
  import Group from '../../../ui/kit/Group.svelte';
  import Row from '../../../ui/kit/Row.svelte';
  import Label from '../../../ui/kit/Label.svelte';
  import Switch from '../../../ui/kit/Switch.svelte';
  import AppTile from '../../../ui/AppTile.svelte';
  import Glyph from '../../../ui/Glyph.svelte';
  import { phone, saveSettings, setLowPower } from '../../../lib/store.svelte.js';
  import { post } from '../../../lib/nui.js';
  import { appLabel } from '../../../lib/apps.js';
  import { t } from '../../../lib/i18n.js';

  const s = $derived(phone.settings);
  const st = $derived(phone.status);
  const level = $derived(Math.max(0, Math.min(100, Math.round(st.battery))));
  const low = $derived(level <= 20 && !st.charging);
  const color = $derived(low ? '#e5484d' : st.charging ? '#27a869' : st.lowPower ? '#e0a100' : 'var(--accent)');

  // The ring: a circle whose stroke is drawn for part of its length.
  const R = 44;
  const C = 2 * Math.PI * R;

  // Battery use by app since the player logged in. Asked for when the page opens, then every few seconds.
  let usage = $state([]);
  let loaded = $state(false);

  async function load() {
    const result = await post('batteryUsage');
    if (result?.ok && Array.isArray(result.usage)) usage = result.usage;
    loaded = true;
  }

  onMount(() => {
    load();
    const id = setInterval(load, 8000);
    return () => clearInterval(id);
  });

  const top = $derived(usage.reduce((m, u) => Math.max(m, u.percent), 0.01));
  const label = (app) => (app === 'standby' || app === 'home' ? t(`battery.use.${app}`) : appLabel(app));
</script>

<div class="hero">
  <svg class="ring" width="112" height="112" viewBox="0 0 112 112" aria-hidden="true">
    <circle cx="56" cy="56" r={R} fill="none" stroke="var(--surface-3)" stroke-width="10" />
    <circle
      cx="56"
      cy="56"
      r={R}
      fill="none"
      stroke={color}
      stroke-width="10"
      stroke-linecap="round"
      stroke-dasharray="{(C * level) / 100} {C}"
      transform="rotate(-90 56 56)"
    />
  </svg>
  <span class="big">{level}<small>%</small></span>
  <span class="state">
    {#if !st.powered}
      {t('battery.stateOff')}
    {:else if st.charging}
      <Glyph name="bolt" size={15} stroke={2.4} /> {t('battery.stateCharging')}
    {:else if st.lowPower}
      <Glyph name="leaf" size={15} stroke={2.2} /> {t('battery.stateLowPower')}
    {:else}
      {t('battery.stateOn')}
    {/if}
  </span>
</div>

<Group>
  <Row title={t('settings.lowPower')} hint={t('settings.lowPowerHint')}>
    <Switch checked={st.lowPower} onchange={(v) => setLowPower(v)} label={t('settings.lowPower')} />
  </Row>
  <Row title={t('settings.autoLowPower')} hint={t('settings.autoLowPowerHint')}>
    <Switch checked={s.battery.autoLowPower} onchange={(v) => saveSettings({ battery: { autoLowPower: v } })} label={t('settings.autoLowPower')} />
  </Row>
  <Row title={t('settings.showPercent')}>
    <Switch checked={s.battery.showPercent} onchange={(v) => saveSettings({ battery: { showPercent: v } })} label={t('settings.showPercent')} />
  </Row>
</Group>

<Label>{t('battery.usage')}</Label>
{#if usage.length === 0}
  <p class="hint">{loaded ? t('battery.usageEmpty') : t('battery.usageLoading')}</p>
{:else}
  <div class="usage">
    {#each usage as u (u.app)}
      <div class="u">
        {#if u.app === 'standby' || u.app === 'home'}
          <span class="plain"><Glyph name={u.app === 'standby' ? 'power' : 'grid'} size={18} /></span>
        {:else}
          <AppTile id={u.app} size={30} />
        {/if}
        <span class="info">
          <span class="line"><span class="nm">{label(u.app)}</span><span class="pc">{u.percent.toFixed(1)}%</span></span>
          <span class="track"><span class="fill" style:width="{Math.max(3, (u.percent / top) * 100)}%"></span></span>
        </span>
      </div>
    {/each}
  </div>
{/if}

<style>
  .hero {
    position: relative;
    display: flex;
    flex-direction: column;
    align-items: center;
    padding: 6px 0 18px;
  }
  .big {
    position: absolute;
    left: 0;
    right: 0;
    top: 42px;
    line-height: 36px;
    text-align: center;
    font-size: 30px;
    font-weight: 700;
    letter-spacing: -0.02em;
  }
  .big small {
    font-size: 15px;
    font-weight: 700;
    color: var(--ink-3);
  }
  .state {
    margin-top: 8px;
    display: flex;
    align-items: center;
    gap: 5px;
    font-size: 14px;
    font-weight: 600;
    color: var(--ink-2);
  }
  .hint {
    margin: 0 4px;
    font-size: 13.5px;
    color: var(--ink-3);
  }
  .usage {
    display: flex;
    flex-direction: column;
    gap: 12px;
  }
  .u {
    display: flex;
    align-items: center;
    gap: 12px;
  }
  .plain {
    width: 30px;
    height: 30px;
    flex: none;
    border-radius: 9px;
    display: grid;
    place-items: center;
    background: var(--surface-3);
    color: var(--ink-2);
  }
  .info {
    flex: 1;
    min-width: 0;
    display: flex;
    flex-direction: column;
    gap: 5px;
  }
  .line {
    display: flex;
    justify-content: space-between;
    font-size: 14px;
    font-weight: 600;
  }
  .pc {
    color: var(--ink-3);
  }
  .track {
    display: block;
    height: 6px;
    border-radius: 3px;
    background: var(--surface-3);
    overflow: hidden;
  }
  .fill {
    display: block;
    height: 100%;
    border-radius: 3px;
    background: var(--accent);
  }
</style>
