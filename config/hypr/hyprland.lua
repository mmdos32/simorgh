-- Simorgh — Hyprland configuration (Lua, Hyprland 0.55+)
-- Minimal, modern, glassy. Theme colors live in themes/active.lua
-- (managed by simorgh-theme) and are loaded at the end of this file
-- via require("themes.active").
--
-- Hyprland 0.57 dropped the legacy hyprlang (.conf) format entirely,
-- so this .lua file is the only config Hyprland reads. See:
-- https://wiki.hypr.land/configuring/

-- ---------------------------------------------------------------- Monitors
hl.monitor({
    output = "",
    mode = "preferred",
    position = "auto",
    scale = 1,
})

-- ------------------------------------------------------------ Autostart
-- Runs once when Hyprland starts (the legacy `exec-once` lines).
hl.on("hyprland.start", function()
    hl.exec_cmd("waybar")
    hl.exec_cmd("swaync")
    hl.exec_cmd("hyprpaper")
    hl.exec_cmd("/usr/lib/hyprpolkitagent/hyprpolkitagent")
    hl.exec_cmd("wl-paste --watch cliphist store 2>/dev/null || true")
    hl.exec_cmd("simorgh-welcome")
    hl.exec_cmd("kitty --class scratchpad")
end)

-- ------------------------------------------------------------ Environment
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("QT_QPA_PLATFORM", "wayland")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("GDK_BACKEND", "wayland")
hl.env("SDL_VIDEODRIVER", "wayland")
hl.env("_JAVA_AWT_WM_NONREPARENTING", "1")
hl.env("XDG_SCREENSHOTS_DIR", os.getenv("HOME") .. "/Pictures/Screenshots")

-- ---------------------------------------------------------------- Input
hl.config({
    input = {
        kb_layout = "us,ir",
        kb_variant = "",
        kb_model = "",
        kb_options = "grp:alt_shift_toggle",
        kb_rules = "",
        follow_mouse = 1,
        sensitivity = 0,
        touchpad = {
            natural_scroll = true,
            disable_while_typing = true,
            tap_to_click = true,
        },
    },
})

-- ---------------------------------------------------------------- General
hl.config({
    general = {
        gaps_in = 6,
        gaps_out = 10,
        border_size = 2,
        col = {
            -- Teal defaults; the active theme (loaded last) overrides these.
            active_border = "rgba(2dd4bfff)",
            inactive_border = "rgba(ffffff22)",
        },
        resize_on_border = true,
        allow_tearing = false,
        layout = "dwindle",
    },
})

-- ------------------------------------------------------------- Decoration
hl.config({
    decoration = {
        rounding = 14,
        rounding_power = 2,
        active_opacity = 0.92,
        inactive_opacity = 0.85,
        shadow = {
            enabled = true,
            range = 4,
            render_power = 3,
            color = "rgba(00000066)",
        },
        blur = {
            enabled = true,
            size = 10,
            passes = 3,
            vibrancy = 0.15,
        },
    },
})

-- ------------------------------------------------------------- Animations
hl.config({
    animations = {
        enabled = true,
    },
})
hl.curve("easeOut", {
    type = "bezier",
    points = { { 0.05, 0.9 }, { 0.1, 1.05 } },
})
hl.animation({ leaf = "windows", enabled = true, speed = 5, bezier = "easeOut" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 5, bezier = "easeOut", style = "popin 80%" })
hl.animation({ leaf = "border", enabled = true, speed = 8, bezier = "easeOut" })
hl.animation({ leaf = "borderangle", enabled = true, speed = 30, bezier = "easeOut", style = "loop" })
hl.animation({ leaf = "fade", enabled = true, speed = 5, bezier = "easeOut" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 5, bezier = "easeOut" })

-- ---------------------------------------------------------------- Dwindle
hl.config({
    dwindle = {
        preserve_split = true,
    },
})

hl.config({
    master = {
        new_status = "master",
    },
})

-- -------------------------------------------------------------- Gestures
-- 3-finger horizontal swipe switches workspaces.
-- (The legacy `gestures { workspace_swipe = true }` option no longer
-- exists in Hyprland 0.57; gestures are defined with hl.gesture now.
-- See https://wiki.hypr.land/configuring/core/binds/gestures/ )
hl.gesture({
    fingers = 3,
    direction = "horizontal",
    action = "workspace",
})

-- ------------------------------------------------- Blur layer rules (glass)
hl.layer_rule({
    match = { namespace = "waybar" },
    blur = true,
})
hl.layer_rule({
    match = { namespace = "rofi" },
    blur = true,
})
hl.layer_rule({
    match = { namespace = "swaync-control-center" },
    blur = true,
})
hl.layer_rule({
    match = { namespace = "swaync-notification-window" },
    blur = true,
})
-- Legacy `ignorezero` is a float 0.0-1.0 in Lua, not a bool:
-- 0 means "ignore fully-transparent pixels".
hl.layer_rule({
    match = { namespace = "waybar" },
    ignore_alpha = 0,
})

-- ------------------------------------------- Scratchpad terminal (SUPER + `)
hl.window_rule({
    name = "scratchpad",
    match = { class = "^(scratchpad)$" },
    float = true,
    size = { "80%", "55%" },
    center = true,
    workspace = "special:scratchpad",
})

-- ------------------------------------------------------ Window rules
-- Small dialogs float; Sung opens as a small floating mini player.
hl.window_rule({
    name = "float-pavucontrol",
    match = { class = "^(pavucontrol)$" },
    float = true,
})
hl.window_rule({
    name = "float-fileroller",
    match = { class = "^(org.gnome.FileRoller)$" },
    float = true,
})
hl.window_rule({
    name = "float-blueman",
    match = { class = "^(blueman-manager)$" },
    float = true,
})
hl.window_rule({
    name = "float-nm-editor",
    match = { class = "^(nm-connection-editor)$" },
    float = true,
})
hl.window_rule({
    name = "float-gnome-calculator",
    match = { class = "^(gnome-calculator)$" },
    float = true,
})
hl.window_rule({
    name = "float-org-gnome-calculator",
    match = { class = "^(org.gnome.Calculator)$" },
    float = true,
})
hl.window_rule({
    name = "sung-mini-player",
    match = { class = "^(sung)$" },
    float = true,
    size = { 900, 560 },
    center = true,
})
hl.window_rule({
    name = "simorgh-welcome",
    match = { class = "^(simorgh-welcome)$" },
    float = true,
    size = { "80%", "60%" },
    center = true,
})

-- ------------------------------------------------------------- Keybinds
local mainMod = "SUPER"

-- Apps
hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd("kitty"))
hl.bind(mainMod .. " + D", hl.dsp.exec_cmd("rofi -show drun"))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd("maia"))
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd("chromium"))
hl.bind(mainMod .. " + C", hl.dsp.exec_cmd("code"))
hl.bind(mainMod .. " + U", hl.dsp.exec_cmd("sung"))
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("simorgh-menu"))
hl.bind(mainMod .. " + T", hl.dsp.exec_cmd("simorgh-theme"))
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd("swaync-client -t -sw"))
hl.bind(mainMod .. " + SHIFT + N", hl.dsp.exec_cmd("swaync-client -d"))
hl.bind(mainMod .. " + K", hl.dsp.exec_cmd("simorgh-keybinds"))

-- Window management
-- killactive is a SIGKILL (hl.dsp.window.kill), not a graceful close.
hl.bind(mainMod .. " + Q", hl.dsp.window.kill())
hl.bind(mainMod .. " + SHIFT + Q", hl.dsp.exit())
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen())
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"))
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("hyprlock"))
hl.bind(mainMod .. " + SHIFT + E", hl.dsp.exec_cmd("simorgh-power"))
hl.bind(mainMod .. " + SHIFT + R", hl.dsp.exec_cmd("hyprctl reload"))

-- Window switching (SUPER + Tab)
hl.bind(mainMod .. " + Tab", hl.dsp.window.cycle_next())
hl.bind(mainMod .. " + SHIFT + Tab", hl.dsp.window.cycle_next({ next = false }))

-- Scratchpad terminal (SUPER + `)
hl.bind(mainMod .. " + grave", hl.dsp.workspace.toggle_special("scratchpad"))

-- Focus
hl.bind(mainMod .. " + left", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down", hl.dsp.focus({ direction = "down" }))

-- Focus monitor (multi-monitor)
-- NOTE: the documented Lua form is focus({ monitor = ... }); this is the
-- one mapping that could not be confirmed against a live Hyprland here —
-- VM test 4 must check SUPER+CTRL+arrows actually switch monitors.
hl.bind(mainMod .. " + CTRL + left", hl.dsp.focus({ monitor = "l" }))
hl.bind(mainMod .. " + CTRL + right", hl.dsp.focus({ monitor = "r" }))

-- Move windows
hl.bind(mainMod .. " + SHIFT + left", hl.dsp.window.move({ direction = "left" }))
hl.bind(mainMod .. " + SHIFT + right", hl.dsp.window.move({ direction = "right" }))
hl.bind(mainMod .. " + SHIFT + up", hl.dsp.window.move({ direction = "up" }))
hl.bind(mainMod .. " + SHIFT + down", hl.dsp.window.move({ direction = "down" }))

-- Resize mode (SUPER + R, arrows to resize, Esc to exit)
hl.bind(mainMod .. " + R", hl.dsp.submap("resize"))
hl.define_submap("resize", function()
    hl.bind("right", hl.dsp.window.resize({ x = 20, y = 0, relative = true }), { repeating = true })
    hl.bind("left", hl.dsp.window.resize({ x = -20, y = 0, relative = true }), { repeating = true })
    hl.bind("up", hl.dsp.window.resize({ x = 0, y = -20, relative = true }), { repeating = true })
    hl.bind("down", hl.dsp.window.resize({ x = 0, y = 20, relative = true }), { repeating = true })
    hl.bind("escape", hl.dsp.submap("reset"))
end)

-- Workspaces
hl.bind(mainMod .. " + 1", hl.dsp.focus({ workspace = 1 }))
hl.bind(mainMod .. " + 2", hl.dsp.focus({ workspace = 2 }))
hl.bind(mainMod .. " + 3", hl.dsp.focus({ workspace = 3 }))
hl.bind(mainMod .. " + 4", hl.dsp.focus({ workspace = 4 }))
hl.bind(mainMod .. " + 5", hl.dsp.focus({ workspace = 5 }))
hl.bind(mainMod .. " + 6", hl.dsp.focus({ workspace = 6 }))
hl.bind(mainMod .. " + 7", hl.dsp.focus({ workspace = 7 }))
hl.bind(mainMod .. " + 8", hl.dsp.focus({ workspace = 8 }))
hl.bind(mainMod .. " + 9", hl.dsp.focus({ workspace = 9 }))
hl.bind(mainMod .. " + 0", hl.dsp.focus({ workspace = 10 }))
hl.bind(mainMod .. " + SHIFT + 1", hl.dsp.window.move({ workspace = 1 }))
hl.bind(mainMod .. " + SHIFT + 2", hl.dsp.window.move({ workspace = 2 }))
hl.bind(mainMod .. " + SHIFT + 3", hl.dsp.window.move({ workspace = 3 }))
hl.bind(mainMod .. " + SHIFT + 4", hl.dsp.window.move({ workspace = 4 }))
hl.bind(mainMod .. " + SHIFT + 5", hl.dsp.window.move({ workspace = 5 }))
hl.bind(mainMod .. " + SHIFT + 6", hl.dsp.window.move({ workspace = 6 }))
hl.bind(mainMod .. " + SHIFT + 7", hl.dsp.window.move({ workspace = 7 }))
hl.bind(mainMod .. " + SHIFT + 8", hl.dsp.window.move({ workspace = 8 }))
hl.bind(mainMod .. " + SHIFT + 9", hl.dsp.window.move({ workspace = 9 }))
hl.bind(mainMod .. " + SHIFT + 0", hl.dsp.window.move({ workspace = 10 }))

-- Scroll through workspaces
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

-- Screenshots (saved to ~/Pictures/Screenshots)
hl.bind("Print", hl.dsp.exec_cmd("mkdir -p ~/Pictures/Screenshots && grim ~/Pictures/Screenshots/$(date +%Y-%m-%d_%H-%M-%S).png"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd("mkdir -p ~/Pictures/Screenshots && grim -g \"$(slurp)\" ~/Pictures/Screenshots/$(date +%Y-%m-%d_%H-%M-%S).png"))
hl.bind(mainMod .. " + SHIFT + C", hl.dsp.exec_cmd("grim -g \"$(slurp)\" - | wl-copy"))

-- Clipboard history (SUPER + SHIFT + V)
hl.bind(mainMod .. " + SHIFT + V", hl.dsp.exec_cmd("cliphist list | rofi -dmenu -p \"Clipboard\" -i | cliphist decode | wl-copy"))

-- Extras
hl.bind(mainMod .. " + ALT + C", hl.dsp.exec_cmd("rofi -show calc"))
hl.bind(mainMod .. " + ALT + P", hl.dsp.exec_cmd("hyprpicker -a"))
hl.bind(mainMod .. " + ALT + R", hl.dsp.exec_cmd("simorgh-record"))
hl.bind(mainMod .. " + period", hl.dsp.exec_cmd("rofi -show emoji"))
hl.bind(mainMod .. " + ALT + B", hl.dsp.exec_cmd("pkill -SIGUSR1 waybar"))
hl.bind(mainMod .. " + SHIFT + L", hl.dsp.exec_cmd("bash -c 'hyprlock & sleep 1; systemctl suspend'"))
hl.bind(mainMod .. " + Z", hl.dsp.focus({ workspace = "previous" }))

-- Move window to workspace silently (stay on current workspace)
hl.bind(mainMod .. " + CTRL + 1", hl.dsp.window.move({ workspace = 1, follow = false }))
hl.bind(mainMod .. " + CTRL + 2", hl.dsp.window.move({ workspace = 2, follow = false }))
hl.bind(mainMod .. " + CTRL + 3", hl.dsp.window.move({ workspace = 3, follow = false }))
hl.bind(mainMod .. " + CTRL + 4", hl.dsp.window.move({ workspace = 4, follow = false }))
hl.bind(mainMod .. " + CTRL + 5", hl.dsp.window.move({ workspace = 5, follow = false }))
hl.bind(mainMod .. " + CTRL + 6", hl.dsp.window.move({ workspace = 6, follow = false }))
hl.bind(mainMod .. " + CTRL + 7", hl.dsp.window.move({ workspace = 7, follow = false }))
hl.bind(mainMod .. " + CTRL + 8", hl.dsp.window.move({ workspace = 8, follow = false }))
hl.bind(mainMod .. " + CTRL + 9", hl.dsp.window.move({ workspace = 9, follow = false }))
hl.bind(mainMod .. " + CTRL + 0", hl.dsp.window.move({ workspace = 10, follow = false }))

-- Volume (wireplumber / wpctl)
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"))
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"))
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"))
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"))

-- Brightness
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl s 5%+"))
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl s 5%-"))

-- Media
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"))
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"))
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"))

-- Mouse
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- ------------------------------------------------------- Active theme
-- Managed by simorgh-theme — do not edit by hand.
-- simorgh-theme copies the chosen theme's hyprland.lua here as active.lua.
-- It loads LAST so its colors win over the teal defaults above.
require("themes.active")
