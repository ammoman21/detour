# Detour

**A tiny detour without leaving your reading.**

Detour is an invisible macOS app that lives behind a hotkey. You're deep in a paper or blog post, someone drops "LoRA" or "RLHF" without explanation, and instead of opening a browser tab and falling down a rabbit hole, you press `⌥ Space`. A small translucent panel slides in at the edge of your screen, you ask, you get the gist, you press `Esc`, and you're back to reading. The conversation erases itself. Nothing is saved, ever.

```
                                             ┌────────────────────┐
   ...fine-tuning methods such as LoRA       │ ⌥ Detour     Haiku │
   have become the dominant approach         ├────────────────────┤
   for adapting large models. Combined       │ what's LoRA?       │
   with RLHF pipelines, these...             │                    │
                                             │ LoRA (Low-Rank     │
        you, reading ──── ⌥Space ──────▶     │ Adaptation) trains │
                                             │ small adapter      │
                                             │ matrices instead   │
                                             │ of the full model… │
                                             └────────────────────┘
```

## Why it exists

Reading technical material means constant micro-lookups. Each one is a context switch: open a tab, search, skim three results, close the tab, find your place again. Detour collapses that loop into a keystroke. It's deliberately *not* a chat app — no history, no accounts, no window in your dock. It's a margin note that answers back.

## Features

- **Global hotkey** (`⌥ Space` by default, configurable) — works from any app, including full-screen reading. No Accessibility permission needed.
- **Non-activating translucent panel** — docks to the right edge of your screen like a margin note. It doesn't steal focus from your reading app; press `Esc` or click back into your document and it's gone.
- **Ephemeral by design** — conversations live only in memory and self-erase two minutes after you dismiss the panel (`⌘K` erases instantly). Nothing is written to disk.
- **Private** — the panel is excluded from screen recordings and screen sharing. Your API key lives in the macOS keychain. The only network call is to the Anthropic API.
- **Lightweight** — a single ~2 MB native binary. No Electron, no background daemons, negligible idle footprint.
- **Streaming answers** from Claude Haiku 4.5 by default (fast and cheap — a lookup costs a fraction of a cent). Switchable to Sonnet 5 or Opus 5 in Settings.

## Install

Detour is built from source (it's unsigned — no paid developer certificate — so building locally is also the safest way to run it). You need Xcode Command Line Tools (`xcode-select --install`).

```sh
git clone https://github.com/ammoman21/detour.git
cd detour
make install       # builds and copies Detour.app to /Applications
open /Applications/Detour.app
```

First launch shows a one-time setup panel asking for an [Anthropic API key](https://console.anthropic.com/settings/keys). Paste it, close settings, and press `⌥ Space`.

To build without installing: `make` produces `build/Detour.app`.

## Usage

| Action | How |
|---|---|
| Open / close the panel | `⌥ Space` (configurable in Settings) |
| Dismiss | `Esc`, or click back into your reading |
| Send a question | `Return` |
| Erase the conversation now | `⌘K` |
| Settings | gear icon in the panel, or the menu bar icon |
| Quit | menu bar icon → Quit Detour |

The menu bar icon can be hidden in Settings for full invisibility. If you hide it, re-open `Detour.app` from Finder to get back to Settings.

## Design notes

A few deliberate choices, documented so contributors don't "fix" them:

- **Native AppKit/SwiftUI, not Electron.** A translucent, non-activating, always-on-top panel that appears over full-screen apps is only cleanly achievable with `NSPanel` (`.nonactivatingPanel`, `.fullScreenAuxiliary`). It's also what keeps the app genuinely lightweight.
- **Carbon hotkey, not an event tap.** `RegisterEventHotKey` needs no Accessibility permission, so setup is: paste key, done.
- **Dismissal keeps the transcript for two minutes.** Pure erase-on-close punishes the core workflow (read → ask → go back to reading → follow up). Pure persistence contradicts the point of the app. The two-minute grace window covers follow-ups; the eraser and the timer cover ephemerality.
- **No conversation storage layer at all.** Not "deleted on close" — never written. There is nothing to clear because nothing exists outside process memory.
- **Bring-your-own-key.** No proxy server, no telemetry, no account. Your key, straight to the API.

## Project layout

```
Sources/Detour/
  main.swift            app entry
  AppDelegate.swift     wiring: hotkey, status item, panel, settings
  PanelController.swift the floating NSPanel + positioning
  ChatView.swift        SwiftUI chat UI
  ChatViewModel.swift   transcript state + ephemerality rules
  AnthropicClient.swift minimal SSE streaming client for /v1/messages
  HotKeyManager.swift   Carbon global hotkey
  Keychain.swift        API key storage
  Preferences.swift     model / hotkey / UI preferences
  SettingsWindow.swift  settings UI
Support/Info.plist      LSUIElement app bundle plist
Makefile                build → .app bundle → install
```

## Contributing

Issues and PRs welcome. Keep the spirit: small, native, ephemeral, subtle. Features that add persistence, accounts, or heavyweight dependencies are out of scope.

## License

[MIT](LICENSE)
