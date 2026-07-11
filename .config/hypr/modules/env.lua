---------------------------
---- ENV & PERMISSIONS ----
---------------------------

-- https://wiki.hypr.land/Configuring/Advanced-and-Cool/Environment-variables/
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

-- https://wiki.hypr.land/Configuring/Advanced-and-Cool/Permissions/
-- Changes here require a Hyprland restart (not applied on-the-fly).
hl.permission("/usr/(bin|local/bin)/grim", "screencopy", "allow")
hl.permission("/usr/(lib|libexec|lib64)/xdg-desktop-portal-hyprland", "screencopy", "allow")
