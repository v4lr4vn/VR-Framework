<script>
  import Group from '../../../ui/kit/Group.svelte';
  import Row from '../../../ui/kit/Row.svelte';
  import Button from '../../../ui/kit/Button.svelte';
  import Segmented from '../../../ui/kit/Segmented.svelte';
  import { phone } from '../../../lib/store.svelte.js';
  import { t } from '../../../lib/i18n.js';

  // pin: the PIN flow from pinflow.svelte.js. pad: a snippet that draws the number pad.
  // (On the half open phone the number pad is drawn on the bottom half, so Settings draws it there itself.)
  let { pin, pad } = $props();

  const narrow = $derived(phone.fold === 'cover');
</script>

{#if pin.flow}
  <div class="pinbox">
    <p class="prompt">{pin.prompt}</p>
    {#if pin.flow !== 'remove' && pin.step === 'new' && !pin.firstPin}
      <Segmented
        label={t('settings.pinLength')}
        value={pin.newLength}
        onchange={(v) => (pin.newLength = v)}
        options={phone.features.pinLengths.map((n) => ({ value: n, label: t('settings.digits', { n }) }))}
      />
    {/if}
    <p class="error" class:show={pin.error}>{pin.error || ' '}</p>
    {#if phone.fold !== 'flex'}{@render pad(phone.fold === 'cover')}{/if}
  </div>
{:else}
  <Group>
    <Row title={t('settings.pin')} hint={phone.lock.enabled ? t('settings.pinOn', { n: phone.lock.length }) : t('settings.pinOff')} stack={narrow}>
      {#if phone.lock.enabled}
        <span class="btns">
          <Button onclick={() => pin.start('change')}>{t('settings.change')}</Button>
          <Button kind="danger" onclick={() => pin.start('remove')}>{t('settings.remove')}</Button>
        </span>
      {:else}
        <Button kind="primary" onclick={() => pin.start('set')}>{t('settings.setPin')}</Button>
      {/if}
    </Row>
  </Group>
{/if}

<style>
  .btns {
    display: flex;
    gap: 8px;
  }
  .pinbox {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 10px;
    padding-top: 6px;
  }
  .prompt {
    margin: 0;
    font-size: 17px;
    font-weight: 600;
  }
  .error {
    margin: 0;
    min-height: 20px;
    font-size: 13.5px;
    font-weight: 600;
    color: #e5484d;
    opacity: 0;
  }
  .error.show {
    opacity: 1;
  }
</style>
