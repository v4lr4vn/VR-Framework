<script>
  import Group from '../../../ui/kit/Group.svelte';
  import Row from '../../../ui/kit/Row.svelte';
  import Label from '../../../ui/kit/Label.svelte';
  import Glyph from '../../../ui/Glyph.svelte';
  import { phone, saveSettings } from '../../../lib/store.svelte.js';
  import { t } from '../../../lib/i18n.js';

  const name = $derived(phone.settings.profile.name);
  const initial = $derived(name.trim()[0]?.toUpperCase() ?? '');
</script>

<div class="who">
  <span class="avatar">{#if initial}{initial}{:else}<Glyph name="user" size={30} stroke={1.8} />{/if}</span>
  <span class="text">
    <span class="name">{name.trim() || t('settings.noName')}</span>
    <span class="num">{phone.number || '—'}</span>
  </span>
</div>

<Label>{t('settings.name')}</Label>
<input
  class="field"
  type="text"
  maxlength="24"
  value={name}
  placeholder={t('settings.namePlaceholder')}
  aria-label={t('settings.name')}
  oninput={(e) => saveSettings({ profile: { name: e.currentTarget.value } })}
/>
<p class="hint">{t('settings.nameHint')}</p>

<Label>{t('settings.number')}</Label>
<Group>
  <Row title={t('settings.number')}><span class="val">{phone.number || '—'}</span></Row>
</Group>

<style>
  .who {
    display: flex;
    align-items: center;
    gap: 16px;
    padding: 16px 18px;
    border-radius: var(--r-l);
    background: var(--surface);
  }
  .avatar {
    width: 58px;
    height: 58px;
    border-radius: 50%;
    display: grid;
    place-items: center;
    font-size: 26px;
    font-weight: 700;
    background: var(--accent);
    color: var(--on-accent);
    flex: none;
  }
  .text {
    display: flex;
    flex-direction: column;
    min-width: 0;
  }
  .name {
    font-size: 19px;
    font-weight: 700;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }
  .num {
    font-size: 14px;
    color: var(--ink-3);
    font-family: var(--mono);
  }
  .field {
    width: 100%;
    padding: 13px 16px;
    border-radius: var(--r-m);
    border: 0;
    background: var(--surface);
    color: var(--ink);
    font-size: 16px;
    box-shadow: inset 0 0 0 1px var(--line);
  }
  .field::placeholder {
    color: var(--ink-3);
  }
  .field:focus {
    outline: 2px solid var(--accent);
  }
  .hint {
    margin: 8px 4px 0;
    font-size: 12.5px;
    color: var(--ink-3);
  }
  .val {
    font-size: 15px;
    color: var(--ink-2);
    font-family: var(--mono);
  }
</style>
