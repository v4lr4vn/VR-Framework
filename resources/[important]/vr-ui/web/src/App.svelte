<script>
  import { onMount } from 'svelte';
  import { on } from './lib/bus.js';
  import { post } from './lib/nui.js';
  import { applySettings } from './lib/settings.svelte.js';
  import Notify from './ui/Notify.svelte';
  import TextUI from './ui/TextUI.svelte';
  import Progress from './ui/Progress.svelte';
  import Context from './ui/Context.svelte';
  import ListMenu from './ui/ListMenu.svelte';
  import InputDialog from './ui/InputDialog.svelte';
  import AlertDialog from './ui/AlertDialog.svelte';
  import SkillCheck from './ui/SkillCheck.svelte';
  import Radial from './ui/Radial.svelte';

  const copy = (text) => {
    const el = document.createElement('textarea');
    el.value = String(text ?? '');
    el.style.position = 'fixed';
    el.style.opacity = '0';
    document.body.appendChild(el);
    el.select();
    document.execCommand('copy');
    el.remove();
  };

  onMount(() => {
    const a = on('config', applySettings);
    const b = on('clipboard', copy);
    post('config').then((cfg) => applySettings(cfg));
    return () => (a(), b());
  });
</script>

<Notify />
<TextUI />
<Progress />
<ListMenu />
<Context />
<Radial />
<SkillCheck />
<InputDialog />
<AlertDialog />
