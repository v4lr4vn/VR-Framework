import sveltePreprocess from 'svelte-preprocess'
import seqPreprocessor from 'svelte-sequential-preprocessor'
import { preprocessThrelte } from '@threlte/preprocess'

export default {
  preprocess: seqPreprocessor([sveltePreprocess(), preprocessThrelte()])
}
