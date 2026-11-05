-- Night Shift theme (matches vr-ui). Values are sent to the clothing UI as CSS variables.
-- Colours written as "H S% L%" are used by the UI with its own opacity, so keep that format for them.
return {
    ["background"] = "216 33.3% 5.9%",            -- #0A0E14
    ["background-alt"] = "216.7 34.6% 10.2%",      -- #111823
    ["foreground"] = "212 42.9% 93.1%",           -- #E6EDF5
    ["foreground-alt"] = "214.7 19.4% 61.6%",      -- #8A9AB0
    ["muted"] = "216 32.5% 15.1%",              -- #1A2433
    ["muted-foreground"] = "212 42.9% 93.1% / 0.5",
    ["dark"] = "212 42.9% 93.1%",
    ["dark-04"] = "212 42.9% 93.1% / 0.04",
    ["dark-10"] = "212 42.9% 93.1% / 0.1",
    ["dark-40"] = "212 42.9% 93.1% / 0.4",
    ["accent"] = "37 91.3% 55.1%",             -- #F5A524
    ["destructive"] = "2.8 100% 66.1%",        -- #FF5A52
    ["border"] = "213.8 32% 19.6%",              -- #223042
    ["border-alt"] = "214.6 30.2% 16.9%",           -- #1E2938

    ["text"] = "#E6EDF5",
    ["text-alt"] = "#8A9AB0",
    ["icon"] = "#E6EDF5",

    -- Night Shift is flat, so the grain overlay is switched off
    ["noise-deg"] = "0deg",
    ["noise-from-color"] = "#00000000",
    ["noise-from-percentage"] = "0%",
    ["noise-to-color"] = "#00000000",
    ["noise-to-percentage"] = "100%",

    ["menu-gradient"] = "#0D121A",
    ["header-radial-gradient"] = "#1A2433, #0A0E14",

    ["shadow-mini"] = "0 0.2vmin 0 0.1vmin #00000066",
    ["shadow-popover"] = "0 1.2vmin 3vmin 0.4vmin #00000099",

    -- small radii, like the rest of Night Shift (6px / 8px at 1080p)
    ["none"] = "0",
    ["sm"] = "0.3vmin",
    ["DEFAULT"] = "0.4vmin",
    ["md"] = "0.55vmin",
    ["lg"] = "0.75vmin",
    ["xl"] = "0.75vmin",
    ["2xl"] = "0.9vmin",
    ["3xl"] = "1vmin",
    ["card"] = "0.75vmin",
    ["card-sm"] = "0.55vmin",
    ["card-lg"] = "0.8vmin",
    ["input"] = "0.55vmin",
    ["button"] = "0.55vmin",
}
