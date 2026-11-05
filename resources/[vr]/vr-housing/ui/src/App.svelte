<script lang="ts">
	import VisibilityProvider from '@providers/VisibilityProvider.svelte'
	import {
		CURRENTFURNITURE,
		FURNITURES,
		browserMode,
		resName,
	} from '@store/stores'
	import DebugBrowser from '@providers/DebugBrowser.svelte'
	import AlwaysListener from '@providers/AlwaysListener.svelte'
	import Menu from '@components/Menu.svelte'

	import Modeler from '@components/Modeler.svelte'
	import ModelStore from '@store/ModelStore'

	$resName = (window as any).GetParentResourceName ? (window as any).GetParentResourceName() : 'vr-housing'

	const { show } = ModelStore

</script>

<VisibilityProvider>
	{#if $FURNITURES}
		<Menu />
		<Modeler />
	{/if}
</VisibilityProvider>

<AlwaysListener />
{#if $browserMode}
	<DebugBrowser />
	<body class=" bg-neutral-700"></body>
{/if}
