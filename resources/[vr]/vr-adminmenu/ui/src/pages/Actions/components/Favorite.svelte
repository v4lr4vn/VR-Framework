<script>
	import { onMount } from "svelte"

    export let data

    let favorite = localStorage.getItem(`favorite-${data}`) === 'true';

    const toggleFavorite = () => {
        event.stopPropagation();
        favorite = !favorite;
        localStorage.setItem(`favorite-${data}`, favorite);
    };

	onMount(() => {
	})
</script>

<button 
    class="{favorite ? 'fas' : 'far'} fa-star"
    on:click={toggleFavorite}
>
</button>
