import Data.List (isPrefixOf, stripPrefix)
import Data.Maybe (fromMaybe)
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
import XMonad.Prompt (XPConfig (font))
import XMonad.Prompt.ConfirmPrompt (confirmPrompt)
import qualified XMonad.StackSet as W
import XMonad.Util.EZConfig (additionalKeysP)
import XMonad.Util.NamedScratchpad
import XMonad.Util.NamedWindows (getName)
import XMonad.Util.Run (safeSpawn)
import XMonad.Util.SpawnOnce (spawnOnOnce, spawnOnce)
import XMonad.Util.WorkspaceCompare (filterOutWs)

-- Zenburn
zenBg, zenFg, zenRed, zenGreen, zenYellow, zenBlue, zenMagenta, zenOrange, zenDim, zenGrey :: String
zenDim     = "#656555" -- separators, empty workspaces (matches ~/.xmobarrc)
zenGrey    = "#9f9f9f" -- window title
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

-- Fonts --------------------------------------------------------------
-- XMonad core draws no text; this is used by the confirm prompt below.
-- The xmobar font is set separately in ~/.xmobarrc.
myFont :: String
myFont = "xft:FiraCode Nerd Font:style=Medium:size=11"

myXPConfig :: XPConfig
myXPConfig = def{font = myFont}

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
  -- withEasySB also applies docks/avoidStruts; M-b (browser) and M-f (thunar)
  -- are taken, so toggle the bar with M-g
  toggleStruts XConfig{modMask = m} = (m, xK_g)

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
  , ("M-b", spawn "/opt/brave-bin/brave-browser")
  , ("M-t", spawn "/opt/thorium-browser/thorium")
  , ("M-f", spawn "thunar")
  , ("M-e", spawn "emacsclient -c")
  , ("M-'", namedScratchpadAction scratchpads "term")
  , ("M-S-z", spawn "xscreensaver-command -lock")
  , ("<Print>", unGrab *> spawn "scrot -s ~/Bilder/%F_%T.png")
  , ("M-q", spawn "xmonad --recompile; xmonad --restart")
  , ("M-S-q", confirmPrompt myXPConfig "exit XMonad?" $ io exitSuccess)
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
    -- manageSpawn matches windows by PID, which fails for apps whose window
    -- belongs to another process (emacsclient -> emacs daemon, Electron apps),
    -- so also place these by window class. Check with: xprop WM_CLASS
    , className =? "Emacs" --> doShift "Emacs"
    , className =? "Mattermost" --> doShift "Chat"
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
  spawnOnOnce "Web" "/opt/brave-bin/brave-browser"
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
-- Palette matches ~/.xmobarrc: dim "│" separators, yellow current
-- workspace with an orange underline (xmobarBorder needs xmobar >= 0.40).
myXmobarPP :: PP
myXmobarPP =
  def
    { ppSep = dim " │ "
    , ppWsSep = ""
    , ppSort = fmap (filterOutWs [scratchpadWorkspaceTag] .) (ppSort def)
    , ppTitleSanitize = xmobarStrip
    , ppCurrent = xmobarBorder "Bottom" zenOrange 2 . yellow . pad
    , ppVisible = blue . pad
    , ppHidden = fg . pad
    , ppHiddenNoWindows = dim . pad
    , ppUrgent = red . wrap "!" "!" . pad
    , ppLayout = orange . layoutName
    , ppTitle = grey . shorten 50
    }
 where
  pad = wrap " " " "
  red = xmobarColor zenRed ""
  yellow = xmobarColor zenYellow ""
  blue = xmobarColor zenBlue ""
  orange = xmobarColor zenOrange ""
  fg = xmobarColor zenFg ""
  dim = xmobarColor zenDim ""
  grey = xmobarColor zenGrey ""

-- spacingRaw prefixes layout names with "Spacing "; shorten to dwm-style tags
layoutName :: String -> String
layoutName l = case fromMaybe l (stripPrefix "Spacing " l) of
  "Tall" -> "[]="
  "Mirror Tall" -> "TTT"
  "Full" -> "[ ]"
  s
    | "ThreeCol" `isPrefixOf` s -> "|||"
    | otherwise -> s
