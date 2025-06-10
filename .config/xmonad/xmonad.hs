import System.Exit
import XMonad
import XMonad.Hooks.DynamicLog
import XMonad.Hooks.EwmhDesktops
import XMonad.Hooks.ManageDocks
import XMonad.Hooks.StatusBar
import XMonad.Hooks.StatusBar.PP
import XMonad.Layout.Spacing
import XMonad.Layout.ThreeColumns
import XMonad.Util.EZConfig
import XMonad.Util.Loggers
import XMonad.Util.Run
import XMonad.Util.SpawnOnce

-- Zenburn color scheme
zenburn_bg = "#3f3f3f"
zenburn_fg = "#dcdccc"
zenburn_red = "#cc9393"
zenburn_green = "#7f9f7f"
zenburn_yellow = "#f0dfaf"
zenburn_blue = "#8cd0d3"
zenburn_magenta = "#dc8cc3"
zenburn_cyan = "#93e0e3"
zenburn_white = "#ffffff"
zenburn_orange = "#dfaf8f"

main :: IO ()
main = do
  xmproc <- spawnPipe "xmobar ~/.xmobarrc"
  xmonad $
    ewmhFullscreen . ewmh . docks $
      myConfig
        { logHook =
            dynamicLogWithPP
              myXmobarPP
                { ppOutput = hPutStrLn xmproc
                }
        }

myConfig =
  def
    { modMask = mod4Mask -- Use Super key as mod key
    , terminal = "kitty" -- Default terminal
    , borderWidth = 2
    , normalBorderColor = zenburn_bg
    , focusedBorderColor = zenburn_orange
    , layoutHook = myLayout
    , manageHook = myManageHook
    , startupHook = myStartupHook
    , workspaces = myWorkspaces
    }
    `additionalKeysP` [ ("M-<Return>", spawn "kitty")
                      , ("M-S-<Return>", spawn "rofi -show drun")
                      , ("M-C-<Return>", spawn "rofi -show run")
                      , ("M-b", spawn "thorium-browser || /opt/thorium-browser/thorium || /usr/bin/thorium-browser")
                      , ("M-e", spawn "thunar")
                      , ("M-S-e", spawn "emacsclient -c ")
                      , ("M-S-z", spawn "xscreensaver-command -lock")
                      , ("M-S-=", unGrab *> spawn "scrot -s")
                      , ("M-S-q", io exitSuccess)
                      ]

-- Workspaces
myWorkspaces = ["1", "2", "3", "4", "5", "6", "7", "8", "9"]

-- Layout
myLayout = avoidStruts $ spacingRaw True (Border 0 5 5 5) True (Border 5 5 5 5) True $ layoutHook def

-- Manage Hook
myManageHook :: ManageHook
myManageHook =
  composeAll
    [ className =? "Gimp" --> doFloat
    , className =? "nm-applet" --> doFloat
    , className =? "Blueman-applet" --> doFloat
    , className =? "Blueman-manager" --> doFloat
    , resource =? "desktop_window" --> doIgnore
    , resource =? "kdesktop" --> doIgnore
    ]
    <+> manageDocks

-- Startup Hook
myStartupHook :: X ()
myStartupHook = do
  spawnOnce "setxkbmap se -option caps:swapescape" -- Swedish layout with caps/esc swap
  spawnOnce "nitrogen --restore &" -- Restore wallpaper
  -- Removed the xmobar spawn - main function handles this now
  spawn "pkill trayer; sleep 2" -- Kill existing trayer
  spawn "trayer --edge top --align right --widthtype request --height 22 --transparent true --tint 0x3f3f3f --margin 0 --distance 0 --padding 2 &" -- Start trayer
  spawn "sleep 3; nm-applet &" -- Network manager applet (delayed)
  spawn "sleep 4; blueman-applet &" -- Bluetooth manager applet (delayed)

-- XMobar PP
myXmobarPP :: PP
myXmobarPP =
  def
    { ppSep = magenta " | "
    , ppTitleSanitize = xmobarStrip
    , ppCurrent = wrap " " "" . xmobarBorder "Top" zenburn_orange 2
    , ppHidden = blue . wrap " " ""
    , ppHiddenNoWindows = lowWhite . wrap " " ""
    , ppUrgent = red . wrap (yellow "!") (red "!")
    , ppLayout = green
    , ppTitle = yellow . shorten 60
    }
 where
  formatWith = xmobarColor
  red = formatWith zenburn_red ""
  green = formatWith zenburn_green ""
  yellow = formatWith zenburn_yellow ""
  blue = formatWith zenburn_blue ""
  magenta = formatWith zenburn_magenta ""
  lowWhite = formatWith zenburn_fg ""

--
