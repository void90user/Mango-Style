# Mango-Style
### An awsome configuration for MangoWM with a mostly orange theme with a hint of green :)
Made for Arch Linux (use with SystemD) feel free to fork it for other distros/init-systems!

![Showcase](screenshot.png "image") 


### Full modification guide coming soon.

## Dependencies:
**All:**
- `mangowm` (v0.15.X)
- `rofi`
- `waybar-git`*  
  _Only the git version works as intended!_
- `xdg-desktop-portal-wlr` 

**Waybar modules:**
- custom/notifications
  - `swaync`
- pulseaudio
  - `pavucontrol`*  
  _(works without it)_
- custom/wifi
  - `iwd` (optionally /w Network Manager)
  - `inotify-tools`
- Most modules
  - `ttf-jetbrains-mono-nerd`*  
  _Any nerd font works,but best experience with this font._

**Rofi:**
- `cosmic-icon-theme`*  
_Optional, has fallback icon theme_

**Wallpaper rotator scripts:**
- `swaybg`  

**Recommended:**
- `polkit-gnome` (policy manager)
- `wl-clipboard` & `wl-clip-presist` (better clipboard)
- `nwg-look` (GTK theme manager)
- `qt5ct` & `qt6ct` (qt/KDE app theme manager)

### Used themes:
GTK: [orchis-nord-theme](https://aur.archlinux.org/packages/orchis-nord-theme-git) _*AUR_  
QT: [kvantum-theme-orchis](https://aur.archlinux.org/packages/kvantum-theme-orchis-git) _*AUR_  
Icons: `cosmic-icon-theme`

## Credits:

- Wallpapers: https://github.com/atraxsrc/tokyonight-wallpapers  

- Rofi configs: https://github.com/adi1090x/rofi  
_(Heavily relied on this for configurning, included some of their themes)_
