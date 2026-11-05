"use strict";

const resourceName = typeof GetParentResourceName === "function" ? GetParentResourceName() : "vr-core";

const fetchNui = async (event, data = {}) => {
    const resp = await fetch(`https://${resourceName}/${event}`, {
        method: "POST",
        headers: { "Content-Type": "application/json; charset=UTF-8" },
        body: JSON.stringify(data),
    });
    return resp.json();
};

const ESCAPES = { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" };
const ALLOWED_TAGS = /&lt;(\/?)(b|strong|i|em|u|small|br|span)\s*\/?&gt;/gi;
const safeHtml = (value) =>
    String(value ?? "")
        .replace(/[&<>"']/g, (c) => ESCAPES[c])
        .replace(ALLOWED_TAGS, "<$1$2>");

const DEFAULT_CONFIG = {
    NotificationStyling: { group: false, position: "right", progress: true, max: 5 },
    VariantDefinitions: {
        success: { classes: "success", icon: "check_circle" },
        primary: { classes: "primary", icon: "notifications" },
        warning: { classes: "warning", icon: "warning" },
        error: { classes: "error", icon: "error" },
        police: { classes: "police", icon: "local_police" },
        ambulance: { classes: "ambulance", icon: "medical_services" },
    },
};

const POSITIONS = {
    "top-left": { top: "16px", left: "16px" },
    "top-right": { top: "16px", right: "16px" },
    top: { top: "16px", left: "50%", transform: "translateX(-50%)" },
    "bottom-left": { bottom: "16px", left: "16px" },
    "bottom-right": { bottom: "16px", right: "16px" },
    bottom: { bottom: "16px", left: "50%", transform: "translateX(-50%)" },
    left: { top: "50%", left: "16px", transform: "translateY(-50%)" },
    right: { top: "50%", right: "16px", transform: "translateY(-50%)" },
    center: { top: "50%", left: "50%", transform: "translate(-50%, -50%)" },
};

const notifyContainer = document.getElementById("notify-container");
const active = new Map();
let config = null;
let configPromise = null;

const loadConfig = () => {
    configPromise ??= fetchNui("getNotifyConfig")
        .catch(() => null)
        .then((cfg) => {
            config = cfg && cfg.VariantDefinitions ? cfg : DEFAULT_CONFIG;
            const styling = { ...DEFAULT_CONFIG.NotificationStyling, ...config.NotificationStyling };
            config.NotificationStyling = styling;
            Object.assign(notifyContainer.style, POSITIONS[styling.position] ?? POSITIONS.right);
            notifyContainer.classList.toggle("from-bottom", String(styling.position).startsWith("bottom"));
            return config;
        });
    return configPromise;
};

const removeNotify = (key) => {
    const entry = active.get(key);
    if (!entry) return;
    active.delete(key);
    clearTimeout(entry.timer);
    entry.el.classList.remove("show");
    entry.el.classList.add("hide");
    setTimeout(() => entry.el.remove(), 350);
};

const scheduleRemoval = (key, entry, duration) => {
    clearTimeout(entry.timer);
    if (duration > 0) entry.timer = setTimeout(() => removeNotify(key), duration);
};

const showNotify = async ({ text, caption, type, length, icon }) => {
    const cfg = config ?? (await loadConfig());
    const styling = cfg.NotificationStyling;
    const variant = cfg.VariantDefinitions[type] ?? cfg.VariantDefinitions.primary;
    const duration = Number(length ?? 5000);
    const key = styling.group ? `${type}|${text}|${caption ?? ""}` : Symbol();

    const existing = active.get(key);
    if (existing) {
        existing.count += 1;
        let badge = existing.el.querySelector(".notify-count");
        if (!badge) {
            badge = document.createElement("span");
            badge.className = "notify-count";
            existing.el.appendChild(badge);
        }
        badge.textContent = `x${existing.count}`;
        const bar = existing.el.querySelector(".notify-progress");
        if (bar) {
            bar.style.animation = "none";
            void bar.offsetWidth;
            bar.style.animation = "";
        }
        scheduleRemoval(key, existing, duration);
        return;
    }

    const el = document.createElement("div");
    el.className = `notify-item ${variant.classes}`;

    const iconEl = document.createElement("span");
    iconEl.className = "notify-icon material-icons";
    iconEl.textContent = icon || variant.icon;

    const content = document.createElement("div");
    content.className = "notify-content";
    content.innerHTML = `<div class="notify-message">${safeHtml(text)}</div>` + (caption ? `<div class="notify-caption">${safeHtml(caption)}</div>` : "");

    el.append(iconEl, content);
    if (styling.progress && duration > 0) {
        const bar = document.createElement("div");
        bar.className = "notify-progress";
        bar.style.animationDuration = `${duration}ms`;
        el.appendChild(bar);
    }

    notifyContainer.appendChild(el);
    const entry = { el, timer: 0, count: 1 };
    active.set(key, entry);

    const max = Number(styling.max) || 5;
    while (active.size > max) removeNotify(active.keys().next().value);

    requestAnimationFrame(() => requestAnimationFrame(() => el.classList.add("show")));
    scheduleRemoval(key, entry, duration);
};

const drawContainer = document.getElementById("drawtext-container");
const drawEl = document.getElementById("drawtext");
const POSITION_CLASSES = ["left", "right", "top"];
let hideTimer = 0;
let swapTimer = 0;

const setPosition = (position) => {
    drawEl.classList.remove(...POSITION_CLASSES);
    drawEl.classList.add(POSITION_CLASSES.includes(position) ? position : "left");
};

const drawText = ({ text, position }) => {
    clearTimeout(hideTimer);
    clearTimeout(swapTimer);
    drawEl.classList.remove("show", "pressed");
    setPosition(position);
    drawEl.innerHTML = safeHtml(text);
    drawContainer.style.display = "block";
    requestAnimationFrame(() => requestAnimationFrame(() => drawEl.classList.add("show")));
};

const changeText = ({ text, position }) => {
    clearTimeout(hideTimer);
    clearTimeout(swapTimer);
    drawEl.classList.remove("show");
    drawEl.classList.add("pressed");
    swapTimer = setTimeout(() => drawText({ text, position }), 500);
};

const hideText = () => {
    clearTimeout(swapTimer);
    drawEl.classList.remove("show");
    hideTimer = setTimeout(() => {
        drawEl.classList.remove("pressed", ...POSITION_CLASSES);
        drawContainer.style.display = "none";
    }, 500);
};

window.addEventListener("message", ({ data }) => {
    if (!data) return;
    switch (data.action) {
        case "notify":
            return void showNotify(data);
        case "DRAW_TEXT":
            return drawText(data.data ?? {});
        case "CHANGE_TEXT":
            return changeText(data.data ?? {});
        case "HIDE_TEXT":
            return hideText();
        case "KEY_PRESSED":
            return drawEl.classList.add("pressed");
    }
});

window.addEventListener("load", loadConfig);
