/* vr-phone app SDK
 *
 * Put this in the page of an app you add with exports['vr-phone']:AddApp:
 *   <script src="https://cfx-nui-vr-phone/html/sdk.js"></script>
 *
 * It gives the page `window.VRPhone`:
 *   VRPhone.ready(fn)          fn runs once the phone has said hello (fn gets the same object as VRPhone.info)
 *   VRPhone.info               { app, number, dark, accent, fold ('cover' | 'flex' | 'open'), resource }
 *   VRPhone.on('theme', fn)    the colours or dark mode changed
 *   VRPhone.on('fold', fn)     the phone was folded or opened ('cover', 'flex' or 'open')
 *   VRPhone.onBack(fn)         the phone's back button / Esc. Return true when your page handled it (closed a sheet, went up a level).
 *                              When you return anything else the phone goes to the home screen.
 *   VRPhone.post(name, data)   calls a NUI callback of YOUR resource (RegisterNUICallback in your script) and returns the JSON answer
 *   VRPhone.close()            puts the phone away
 *   VRPhone.home()             goes to the home screen
 *   VRPhone.open(appId)        opens another app
 *
 * The page also gets CSS variables that follow the player's theme, so it can look like the rest of the phone:
 *   --vr-bg  --vr-surface  --vr-surface-2  --vr-ink  --vr-ink-2  --vr-ink-3  --vr-line  --vr-accent  --vr-on-accent
 * and <html data-vr-theme="dark|light">.
 * Typing in a text box and the Esc key are handled for you.
 */
(function () {
  if (window.VRPhone) return;

  var VARS = {
    '--vr-bg': 'bg', '--vr-surface': 'surface', '--vr-surface-2': 'surface2', '--vr-ink': 'ink', '--vr-ink-2': 'ink2',
    '--vr-ink-3': 'ink3', '--vr-line': 'line', '--vr-accent': 'accent', '--vr-on-accent': 'onAccent',
  };
  var listeners = { theme: [], fold: [] };
  var readyCallbacks = [];
  var backHandler = null;
  var started = false;
  var host = (location.hostname.match(/^cfx-nui-(.+)$/) || [])[1] || '';

  var info = { app: '', number: '', dark: false, accent: '#7a5cff', fold: 'cover', resource: host };

  function send(type, data) {
    try {
      parent.postMessage({ vr: 'app', type: type, data: data }, '*');
    } catch (e) {}
  }

  function paint(colors) {
    if (!colors) return;
    var root = document.documentElement;
    for (var name in VARS) {
      if (colors[VARS[name]]) root.style.setProperty(name, colors[VARS[name]]);
    }
    root.setAttribute('data-vr-theme', info.dark ? 'dark' : 'light');
  }

  function fire(name) {
    var list = listeners[name] || [];
    for (var i = 0; i < list.length; i++) {
      try {
        list[i](info);
      } catch (e) {
        console.error(e);
      }
    }
  }

  window.addEventListener('message', function (event) {
    if (event.source !== parent) return;
    var m = event.data;
    if (!m || m.vr !== 'phone') return;
    var d = m.data || {};
    if (m.type === 'init' || m.type === 'theme') {
      info.app = d.app || info.app;
      info.number = d.number || info.number;
      info.dark = d.dark === true;
      info.accent = d.accent || info.accent;
      if (d.fold) info.fold = d.fold;
      paint(d.colors);
      if (m.type === 'init') {
        started = true;
        var cbs = readyCallbacks;
        readyCallbacks = [];
        for (var i = 0; i < cbs.length; i++) {
          try {
            cbs[i](info);
          } catch (e) {
            console.error(e);
          }
        }
      } else {
        fire('theme');
      }
    } else if (m.type === 'fold') {
      info.fold = d.fold || info.fold;
      fire('fold');
    } else if (m.type === 'back') {
      var handled = false;
      try {
        handled = backHandler ? backHandler() === true : false;
      } catch (e) {}
      send('back', { id: d.id, handled: handled });
    }
  });

  // Typing: the game must not read keys as movement while a text box has focus.
  function isText(el) {
    return el && (el.tagName === 'TEXTAREA' || (el.tagName === 'INPUT' && el.type !== 'range' && el.type !== 'checkbox' && el.type !== 'radio' && el.type !== 'button'));
  }
  document.addEventListener('focusin', function (e) {
    if (isText(e.target)) send('typing', { active: true });
  });
  document.addEventListener('focusout', function (e) {
    if (isText(e.target)) send('typing', { active: false });
  });
  document.addEventListener('keydown', function (e) {
    if (e.key === 'Escape') {
      e.preventDefault();
      send('escape');
    }
  });

  window.VRPhone = {
    info: info,
    ready: function (fn) {
      if (typeof fn !== 'function') return;
      if (started) fn(info);
      else readyCallbacks.push(fn);
    },
    on: function (name, fn) {
      if (listeners[name] && typeof fn === 'function') listeners[name].push(fn);
    },
    onBack: function (fn) {
      backHandler = typeof fn === 'function' ? fn : null;
    },
    post: function (name, data) {
      if (!host) return Promise.reject(new Error('VRPhone.post only works inside the game'));
      return fetch('https://' + host + '/' + name, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data === undefined ? {} : data),
      }).then(function (r) {
        return r.json();
      });
    },
    close: function () {
      send('close');
    },
    home: function () {
      send('home');
    },
    open: function (id) {
      send('open', { id: String(id) });
    },
  };

  // Say hello until the phone answers (the phone may not be listening yet when the page loads).
  var tries = 0;
  (function hello() {
    if (started || tries++ > 40) return;
    send('hello');
    setTimeout(hello, 250);
  })();
})();
