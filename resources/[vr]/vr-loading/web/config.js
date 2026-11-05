// Everything a player reads on the loading screen lives in this file.
// Edit the text, save, restart the resource. No other file needs touching.
window.LOADING_CONFIG = {
  server: {
    name: 'VALRAVN',          // big wordmark
    suffix: 'ROLEPLAY',        // small line under it
    tagline: 'The city never sleeps.',
  },

  welcome: 'Welcome',          // shows as "Welcome, <player name>"
  subtitle: 'Getting your city ready.',

  // One shows at a time, changing every few seconds.
  tipSeconds: 7,
  tips: [
    'Press Z for the radial menu.',
    'Type /keybinds to choose your own keys. Nothing is bound until you pick it.',
    'Type /jobmenu to open your job menu. You can hold several jobs and switch between them.',
    'Press I, or type /hud, to move and tune your HUD.',
    'Type /emotes for emotes, dances, walks and moods, with a live preview.',
    'Type /keys to share, lend or take back the keys to your vehicles.',
  ],

  // Newest first. Keep it to three or four.
  news: [
    { date: '2 Nov', title: 'Restaurants are real jobs', text: 'Player-run restaurants now show up in your job menu, with their own staff ranks and wages.' },
    { date: '2 Nov', title: 'A new look', text: 'Housing and Clothing now match the rest of the city.' },
    { date: '30 Oct', title: 'Kitchens', text: 'Cook in batches, stock fridges and watch food spoil. Dish pictures can be added by owners.' },
  ],

  // Leave empty to hide the panel. Example: 'Be kind. Stay in character. Report bugs to staff.'
  rules: [],

  // Leave empty to hide the panel. Example: { name: 'Name', role: 'Owner' }
  staff: [],

  // Shown as text (a loading screen cannot open links). Leave empty to hide.
  // Example: { label: 'Discord', value: 'discord.gg/yourinvite' }
  links: [],

  // Optional pictures and VIDEOS behind everything. Put the files in web/backgrounds/ and list them here:
  //   backgrounds: ['backgrounds/intro.webm']                          one looping video
  //   backgrounds: ['backgrounds/a.webm', 'backgrounds/b.jpg', ...]    a mix: each one fades into the next
  //   backgrounds: [{ video: 'backgrounds/a.webm', poster: 'backgrounds/a.jpg' }]   with a picture shown until it plays
  // Videos play muted (your music is the sound). Use .webm (VP9) or .mp4 (H.264), 1080p or smaller, no audio track, about 10 to 30 seconds.
  // Every player downloads the file, so keep it small (see README). Leave empty for the built-in night city.
  backgrounds: [],

  backgroundStyle: {
    dim: 0.45,              // 0 to 0.9. Darkens the picture or video so the text stays easy to read
    imageSeconds: 9,        // how long each picture stays (when there is more than one background)
    videoMaxSeconds: 40,    // a video longer than this moves on after this long (when there is more than one background)
    hideCity: true,         // hide the animated night city while a picture or video is showing
  },

  music: {
    enabled: true,
    volume: 0.2,               // 0 to 1; the player's own choice is remembered
    tracks: [
      { file: '../song/song1.mp3', title: 'More', artist: 'Asketa & Natan Chaim' },
      { file: '../song/song2.mp3', title: 'Electric', artist: 'Akacia' },
      { file: '../song/song3.mp3', title: 'Running Wild', artist: 'Wiguez & Vizzen' },
    ],
    credit: 'Music by NoCopyrightSounds',
  },
};
