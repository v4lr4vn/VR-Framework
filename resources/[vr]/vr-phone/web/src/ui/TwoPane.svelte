<script>
  import { phone } from '../lib/store.svelte.js';

  // The fold-aware layout for apps with a list and a detail view.
  //   open: list on the left half, detail on the right half (the crease runs between them)
  //   flex: detail on the top half, list on the bottom half (the list becomes the controls)
  // `swap` puts the detail on the left when the phone is open (the flex layout does not change).
  // closed (cover): there is room for one column. `cover` says what to do:
  //   'switch' (default) shows the list, or the detail while `showDetail` is true. The app handles Back.
  //   'stack' shows the detail and then the list below it, in one scrolling column.
  // `bleed` lets the detail fill its whole half with no padding (a map). It then has to keep clear of the status bar itself.
  let { list, detail, swap = false, cover = 'switch', showDetail = false, bleed = false } = $props();
</script>

{#if phone.fold === 'cover'}
  <div class="pane narrow">
    <div class="scroll" class:bleed={bleed && showDetail && cover !== 'stack'}>
      {#if cover === 'stack'}
        {@render detail()}
        <div class="gapper"></div>
        {@render list()}
      {:else if showDetail}
        {@render detail()}
      {:else}
        {@render list()}
      {/if}
    </div>
  </div>
{:else if phone.fold === 'open'}
  <div class="pane open">
    <section class="left"><div class="scroll" class:bleed={bleed && swap}>{@render (swap ? detail : list)()}</div></section>
    <section class="right"><div class="scroll" class:bleed={bleed && !swap}>{@render (swap ? list : detail)()}</div></section>
  </div>
{:else}
  <div class="pane flex">
    <section class="top"><div class="scroll" class:bleed={bleed}>{@render detail()}</div></section>
    <section class="bottom"><div class="scroll">{@render list()}</div></section>
  </div>
{/if}

<style>
  .pane {
    position: absolute;
    inset: 0;
    display: flex;
  }
  .pane.flex {
    flex-direction: column;
  }
  section {
    flex: 1;
    min-width: 0;
    min-height: 0;
    display: flex;
  }
  .scroll {
    flex: 1;
    min-width: 0;
    overflow-y: auto;
  }
  .narrow .scroll {
    padding: 50px 18px 44px;
  }
  .gapper {
    height: 22px;
  }
  .open .left .scroll {
    padding: 56px 22px 44px 32px;
  }
  .open .right .scroll {
    padding: 56px 32px 44px 22px;
  }
  .flex .top .scroll {
    padding: 52px 36px 10px;
  }
  .flex .bottom .scroll {
    padding: 18px 36px 44px;
  }
  .pane .scroll.bleed {
    position: relative;
    overflow: hidden;
    padding: 0 !important;
  }
</style>
