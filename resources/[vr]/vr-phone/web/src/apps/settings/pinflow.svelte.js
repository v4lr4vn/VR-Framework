// The PIN screens in Settings: set a PIN, change it, or remove it. One step at a time.
// Settings.svelte makes one of these and hands it to the Security page and the number pad.
import { phone, setLockState } from '../../lib/store.svelte.js';
import { post } from '../../lib/nui.js';
import { t } from '../../lib/i18n.js';

export function createPinFlow() {
  let flow = $state(null); // 'set' | 'change' | 'remove' | null
  let step = $state('old'); // 'old' | 'new' | 'confirm'
  let newLength = $state(4);
  let firstPin = $state('');
  let error = $state('');
  let oldPin = '';

  function start(kind) {
    flow = kind;
    step = kind === 'set' ? 'new' : 'old';
    newLength = phone.lock.length || 4;
    oldPin = '';
    firstPin = '';
    error = '';
  }

  function end() {
    flow = null;
    error = '';
    oldPin = '';
    firstPin = '';
  }

  function explain(result) {
    if (result?.lockedFor > 0) {
      phone.lockUntil = Date.now() + result.lockedFor * 1000;
      return t('lock.wait', { time: `${Math.floor(result.lockedFor / 60)}:${String(result.lockedFor % 60).padStart(2, '0')}` });
    }
    if (result?.reason === 'wrong') return t('lock.wrong');
    if (result?.reason === 'busy') return t('err.busy');
    return t('settings.pinFailed');
  }

  // Called with each finished PIN. Returns true when the pad should clear and move on.
  async function submit(pin) {
    error = '';
    if (flow === 'remove') {
      const result = await post('removePin', { pin });
      if (result?.ok) {
        setLockState({ enabled: false });
        end();
        return true;
      }
      error = explain(result);
      return false;
    }

    if (step === 'old') {
      oldPin = pin;
      step = 'new';
      return true;
    }

    if (step === 'new') {
      firstPin = pin;
      step = 'confirm';
      return true;
    }

    // confirm
    if (pin !== firstPin) {
      error = t('settings.pinMismatch');
      step = 'new';
      firstPin = '';
      return false;
    }
    const result = await post('setPin', { pin, old: flow === 'change' ? oldPin : undefined });
    if (result?.ok) {
      setLockState({ enabled: true, length: result.length || pin.length });
      end();
      return true;
    }
    error = explain(result);
    if (result?.reason === 'wrong' || result?.lockedFor > 0) {
      step = 'old';
      oldPin = '';
    } else {
      step = 'new';
    }
    firstPin = '';
    return false;
  }

  return {
    get flow() {
      return flow;
    },
    get step() {
      return step;
    },
    get newLength() {
      return newLength;
    },
    set newLength(value) {
      newLength = value;
    },
    get firstPin() {
      return firstPin;
    },
    get error() {
      return error;
    },
    get padLength() {
      return step === 'old' ? phone.lock.length || 4 : newLength;
    },
    get waitLeft() {
      return Math.max(0, Math.ceil((phone.lockUntil - Date.now()) / 1000));
    },
    get prompt() {
      if (flow === 'remove' || step === 'old') return t('settings.pinCurrent');
      return step === 'new' ? t('settings.pinNew') : t('settings.pinConfirm');
    },
    start,
    end,
    submit,
  };
}
