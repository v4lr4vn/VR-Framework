<script lang="ts">
	import VisibilityProvider from '@providers/VisibilityProvider.svelte'
	import { browserMode, resName } from '@store/stores'
	import DebugBrowser from '@providers/DebugBrowser.svelte'
	import AlwaysListener from '@providers/AlwaysListener.svelte'
	import RealtorMenu from '@components/RealtorMenu.svelte'
	import { SendNUI } from '@utils/SendNUI'

	$resName = (window as any).GetParentResourceName ? (window as any).GetParentResourceName() : 'vr-realtor'

	SendNUI('uiLoaded')
</script>

<VisibilityProvider>
	<RealtorMenu />
</VisibilityProvider>

<AlwaysListener />

{#if $browserMode}
	<DebugBrowser />
{/if}
