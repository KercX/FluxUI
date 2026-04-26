<!-- Banner -->
<p align="center">
  <img src="https://via.placeholder.com/1200x300/1e1e2e/ffffff?text=Flux+UI" alt="Flux UI Banner" width="100%">
</p>

<h1 align="center">Flux UI</h1>
<p align="center">
  <strong>The most complete UI library for Roblox executors</strong><br>
  Modern • 150+ features • Auto‑save • Keybind HUD • Acrylic glass
</p>

<p align="center">
  <a href="#features">Features</a> •
  <a href="#installation">Installation</a> •
  <a href="#quick-start">Quick Start</a> •
  <a href="#api-reference">API</a> •
  <a href="#examples">Examples</a> •
  <a href="#documentation">Docs</a> •
  <a href="#license">License</a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/version-8.0-blue" alt="Version">
  <img src="https://img.shields.io/badge/features-150+-brightgreen" alt="Features">
  <img src="https://img.shields.io/badge/platform-Roblox%20Executor-red" alt="Platform">
  <img src="https://img.shields.io/badge/license-MIT-green" alt="License">
</p>

---

## Features

| Category | Features |
|----------|----------|
| **Core Engine** | Strict Luau, OOP architecture, auto‑save config, device detection, performance mode, flag system, auto‑update, plugin support |
| **Visuals** | Acrylic blur, drop shadows, dark/light themes, glassmorphism, rounded corners, smooth tab transitions, custom scrollbars |
| **Components (40+)** | Button (ripple, icon), Toggle, Slider (int/float), Step Slider, Dual Slider, Dropdown (single/multi/searchable), Keybind (HUD), Color Picker (alpha), TextBox (secure/number), Checkbox, Radio Group |
| **Feedback** | Toasts (queued), Progress bars, Circular progress, Spinner, Tooltips, Status dots, Badges, Modals (blur background), Image display |
| **Advanced UX** | Window dragging (boundary), resizing, edge snapping, minimize to tray, global toggle key (Right Shift), keybind HUD (draggable), config reset, theme export/import, help tab |

---

## Installation

Add this line to your executor script:

```lua
local FluxUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/KercX/FluxUI/refs/heads/main/src/main.lua"))()
'''
