import System.Exit (exitSuccess)
import XMonad
import XMonad.Hooks.EwmhDesktops (ewmh, ewmhFullscreen)
import XMonad.Hooks.ManageHelpers (isDialog, transience')
import XMonad.Actions.SpawnOn (manageSpawn)
import XMonad.Hooks.StatusBar
import XMonad.Hooks.StatusBar.PP
import XMonad.Hooks.UrgencyHook
import XMonad.Layout.NoBorders (smartBorders)
import XMonad.Layout.Spacing
import XMonad.Layout.ThreeColumns
import XMonad.Prompt.ConfirmPrompt (confirmPrompt)
import qualified XMonad.StackSet as W
import XMonad.Util.EZConfig (additionalKeysP)
import XMonad.Util.NamedScratchpad
import XMonad.Util.NamedWindows (getName)
import XMonad.Util.Run (safeSpawn)
import XMonad.Util.SpawnOnce (spawnOnOnce, spawnOnce)
import XMonad.Util.WorkspaceCompare (filterOutWs)

-- Zenburn
zenBg, zenFg, zenRed, zenGreen, zenYellow, zenBlue, zenMagenta, zenOrange :: String
zenBg      = "#3f3f3f"
zenFg      = "#dcdccc"
zenRed     = "#cc9393"
zenGreen   = "#7f9f7f"
zenYellow  = "#f0dfaf"
zenBlue    = "#8cd0d3"
zenMagenta = "#dc8cc3"
zenOrange  = "#dfaf8f"

myTerminal :: String
myTerminal = "kitty"

myWorkspaces :: [String]
myWorkspaces = ["Web", "Term", "Emacs", "Chat", "Etc"]

main :: IO ()
main =
  xmonad
    . withUrgencyHook LibNotifyUrgencyHook
    . withEasySB (statusBarProp "xmobar" (pure myXmobarPP)) toggleStruts
    . ewmhFullscreen
    . ewmh
    $ myConfig
 where
  -- withEasySB also applies docks/avoidStruts; M-b is taken by the browser
  toggleStruts XConfig{modMask = m} = (m, xK_f)

myConfig =
  def
    { modMask = mod4Mask
    , terminal = myTerminal
    , workspaces = myWorkspaces
    , borderWidth = 2
    , normalBorderColor = zenBg
    , focusedBorderColor = zenOrange
    , layoutHook = myLayout
    , manageHook = myManageHook
    , startupHook = myStartupHook
    }
    `additionalKeysP` myKeys

-- Keys ---------------------------------------------------------------
myKeys :: [(String, X ())]
myKeys =
  [ ("M-<Return>", spawn myTerminal)
  , ("M-S-<Return>", windows W.swapMaster) -- default M-<Return>, displaced
  , ("M-p", spawn "rofi -show drun")
  , ("M-S-p", spawn "rofi -show run")
  , ("M-b", spawn "thorium-browser")
  , ("M-e", spawn "thunar")
  , ("M-S-e", spawn "emacsclient -c")
  , ("M-`", namedScratchpadAction scratchpads "term")
  , ("M-S-z", spawn "xscreensaver-command -lock")
  , ("<Print>", unGrab *> spawn "scrot -s ~/Pictures/%F_%T.png")
  , ("M-S-q", confirmPrompt def "exit XMonad?" $ io exitSuccess)
  , ("<XF86AudioRaiseVolume>", spawn "wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+")
  , ("<XF86AudioLowerVolume>", spawn "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-")
  , ("<XF86AudioMute>", spawn "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle")
  ]

-- Scratchpads --------------------------------------------------------
scratchpads :: [NamedScratchpad]
scratchpads =
  [ NS "term" (myTerminal ++ " --class scratchpad")
       (className =? "scratchpad")
       (customFloating $ W.RationalRect 0.1 0.1 0.8 0.8)
  ]

-- Layout -------------------------------------------------------------
myLayout =
  smartBorders
    . spacingRaw True (Border 0 5 5 5) True (Border 5 5 5 5) True
    $ tiled ||| Mirror tiled ||| ThreeColMid 1 (3 / 100) (1 / 2) ||| Full
 where
  tiled = Tall 1 (3 / 100) (1 / 2)

-- Manage hook --------------------------------------------------------
myManageHook :: ManageHook
myManageHook =
  composeAll
    [ manageSpawn
    , namedScratchpadManageHook scratchpads
    , isDialog --> doFloat
    , transience'
    , className =? "Gimp" --> doFloat
    , className =? "Blueman-manager" --> doFloat
    ]

-- Startup ------------------------------------------------------------
myStartupHook :: X ()
myStartupHook = do
  spawnOnce "setxkbmap -layout se -option '' -option caps:swapescape"
  spawnOnce "picom --config ~/.config/picom/picom.conf -b"
  spawnOnce "nitrogen --restore"
  spawnOnce "trayer --edge top --align right --widthtype request --height 22 --transparent true --alpha 0 --tint 0x3f3f3f --padding 2 --monitor primary"
  spawnOnce "nm-applet"
  spawnOnce "blueman-applet"
  spawnOnce "dunst"
  spawnOnOnce "Web" "/usr/bin/thorium-browser"
  spawnOnOnce "Term" "/usr/bin/kitty"
  spawnOnOnce "Emacs" "/usr/bin/emacsclient -c"
  spawnOnOnce "Chat" "/usr/bin/mattermost-desktop"

-- Urgency ------------------------------------------------------------
data LibNotifyUrgencyHook = LibNotifyUrgencyHook
  deriving (Read, Show)

instance UrgencyHook LibNotifyUrgencyHook where
  urgencyHook LibNotifyUrgencyHook w = do
    name <- getName w
    ws <- gets windowset
    mapM_
      (\tag -> safeSpawn "notify-send" ["-u", "normal", show name ++ " wants attention", "Workspace " ++ tag])
      (W.findTag w ws)

-- Bar ----------------------------------------------------------------
myXmobarPP :: PP
myXmobarPP =
  def
    { ppSep = magenta " | "
    , ppSort = fmap (filterOutWs [scratchpadWorkspaceTag] .) (ppSort def)
    , ppTitleSanitize = xmobarStrip
    , ppCurrent = wrap " " "" . xmobarBorder "Top" zenOrange 2
    , ppHidden = blue . wrap " " ""
    , ppHiddenNoWindows = lowWhite . wrap " " ""
    , ppUrgent = wrap (" " ++ yellow "!") (red "!") . red
    , ppLayout = green
    , ppTitle = yellow . shorten 60
    }
 where
  red = xmobarColor zenRed ""
  green = xmobarColor zenGreen ""
  yellow = xmobarColor zenYellow ""
  blue = xmobarColor zenBlue ""
  magenta = xmobarColor zenMagenta ""
  lowWhite = xmobarColor zenFg ""
