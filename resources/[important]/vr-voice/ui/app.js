"use strict";

const els = {
    voice: document.getElementById("voice"),
    call: document.getElementById("call"),
    radio: document.getElementById("radio"),
    range: document.getElementById("range"),
};

const state = {
    uiEnabled: true,
    voiceModes: [],
    voiceMode: 0,
    radioChannel: 0,
    radioEnabled: true,
    usingRadio: false,
    callInfo: 0,
    talking: false,
};

const render = () => {
    els.voice.classList.toggle("hidden", !state.uiEnabled);
    if (!state.uiEnabled) return;

    els.call.classList.toggle("hidden", !state.callInfo);
    els.call.classList.toggle("talking", state.talking);

    const onRadio = state.radioEnabled && state.radioChannel !== 0;
    els.radio.classList.toggle("hidden", !onRadio);
    els.radio.classList.toggle("talking", state.usingRadio);
    if (onRadio) els.radio.textContent = `${state.radioChannel} Mhz [Radio]`;

    const mode = state.voiceModes[state.voiceMode];
    els.range.classList.toggle("hidden", !mode);
    els.range.classList.toggle("talking", state.talking);
    if (mode) els.range.textContent = `${mode[1]} [Range]`;
};

const playClick = (id, volume) => {
    const click = document.getElementById(id);
    if (!click) return;
    click.currentTime = 0;
    click.volume = Math.min(1, Math.max(0, Number(volume) || 0));
    click.play().catch(() => {});
};

window.addEventListener("message", ({ data }) => {
    if (!data) return;

    if (data.uiEnabled !== undefined) state.uiEnabled = data.uiEnabled;
    if (data.voiceModes !== undefined) {
        try {
            state.voiceModes = [...JSON.parse(data.voiceModes), [0.0, "Custom"]];
        } catch {
            state.voiceModes = [];
        }
    }
    if (data.voiceMode !== undefined) state.voiceMode = data.voiceMode;
    if (data.radioChannel !== undefined) state.radioChannel = data.radioChannel;
    if (data.radioEnabled !== undefined) state.radioEnabled = data.radioEnabled;
    if (data.callInfo !== undefined) state.callInfo = data.callInfo;
    if (data.usingRadio !== undefined) state.usingRadio = data.usingRadio;
    if (data.talking !== undefined && !state.usingRadio) state.talking = data.talking;

    if (data.sound && state.radioEnabled && state.radioChannel !== 0) playClick(data.sound, data.volume);

    render();
});

fetch(`https://${GetParentResourceName()}/uiReady`, { method: "POST", body: "{}" }).catch(() => {});
