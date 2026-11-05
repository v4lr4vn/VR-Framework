(function () {
  var prefix = 'https://cfx-nui-';
  window.addEventListener('message', function (event) {
    var data = event.data;
    if (!data || data.type !== 'playSound' || typeof data.url !== 'string') return;
    if (data.url.indexOf(prefix) !== 0) return;
    try {
      var audio = new Audio(data.url);
      audio.volume = Math.max(0, Math.min(1, Number(data.volume) || 0.7));
      var started = audio.play();
      if (started && started.catch) started.catch(function () {});
    } catch (e) {}
  });
})();
