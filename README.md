# vibePane

A lightweight macOS menu bar app for developers juggling multiple projects. Instantly see which dev servers are running, copy login credentials, check git branches — and track your Claude Code usage, all from a single popover.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue) ![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange) ![License: MIT](https://img.shields.io/badge/License-MIT-green)

## Features

- **Live port detection** — automatically detects which dev servers are running (no config needed)
- **Project quick-reference** — ports, URLs, credentials, env paths, all one click away
- **Git branch scanning** — shows current branch for each project, updated every 30s
- **Claude Code usage dashboard** — today's token count, estimated cost, and session count parsed directly from your local Claude JSONL transcripts
- **Full dashboard link** — one click to launch the [claude-usage](https://github.com/phuryn/claude-usage) web dashboard
- **Global hotkey** — `Ctrl+Option+D` toggles the panel from anywhere
- **Launch at login** — starts automatically, lives quietly in your menu bar
- **File-watched config** — edit `projects.json` and the UI updates instantly (Claude can update it too)

## Install

### Prerequisites

- macOS 14 (Sonoma) or later
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)
- Xcode 16+

### Build & Run

```bash
git clone https://github.com/northbeamsoftware/vibePane.git
cd vibePane
xcodegen generate
xcodebuild -project vibePane.xcodeproj -scheme vibePane -configuration Release build
```

Then open the built app:

```bash
open ~/Library/Developer/Xcode/DerivedData/vibePane-*/Build/Products/Release/vibePane.app
```

> **First launch:** macOS will ask for Accessibility permissions (needed for the global hotkey) and may ask to allow local network access (needed for port scanning via `lsof`). Allow both.

## Configuration

On first launch, a sample config is created at:

```
~/Library/Application Support/vibePane/projects.json
```

Edit it to add your projects:

```json
{
  "projects": [
    {
      "id": "my-app",
      "name": "My App",
      "stack": "Next.js 15",
      "ports": [3000],
      "devUrl": "http://localhost:3000",
      "prodUrl": "https://my-app.vercel.app",
      "supabaseUrl": "https://app.supabase.com/project/xxxxx",
      "login": {
        "email": "admin@example.com",
        "password": "password123"
      },
      "projectPath": "/Users/you/projects/my-app",
      "envPath": "~/projects/my-app/.env.local",
      "status": "stopped",
      "group": "Work",
      "notes": "Main SaaS product"
    }
  ],
  "metadata": {
    "version": "1.0",
    "lastUpdated": "2026-04-08T00:00:00Z"
  }
}
```

### Project fields

| Field | Required | Description |
|-------|----------|-------------|
| `id` | yes | Unique identifier |
| `name` | yes | Display name |
| `ports` | yes | Ports to monitor (green dot = listening) |
| `status` | yes | Initial status (`"stopped"`) |
| `stack` | no | Tech stack label |
| `devUrl` | no | Local development URL |
| `prodUrl` | no | Production URL |
| `supabaseUrl` | no | Supabase dashboard link |
| `login` | no | `{ email, password }` for quick copy |
| `projectPath` | no | Absolute path for git branch scanning |
| `envPath` | no | Path to .env file |
| `group` | no | Group name for organizing projects |
| `notes` | no | Freeform notes |

## Claude Code Integration

### Usage tracking

vibePane reads Claude Code's JSONL transcript files directly from `~/.claude/projects/`. No setup needed — if you use Claude Code, it just works. The mini dashboard shows:

- Today's total tokens (input + output + cache)
- Estimated cost (based on Opus pricing)
- Number of sessions today
- Color-coded token breakdown bar

### Keeping projects.json updated

Since `projects.json` is just a file, Claude Code can update it directly:

> "Add my new project to vibePane — it's a SvelteKit app on port 5173 with login admin@test.com / pass123"

The file watcher picks up changes instantly.

### Full dashboard

Click the chart icon in the usage banner to launch the [claude-usage](https://github.com/phuryn/claude-usage) web dashboard. On first click it auto-clones the repo and launches it on port 8177.

## Architecture

```
vibePane/
├── VibePaneApp.swift          # App entry, menu bar, global hotkey
├── Models/
│   └── ProjectEntry.swift     # Data models (Codable)
├── Services/
│   ├── DataStore.swift        # Central state, file watching, scanning coordination
│   ├── FileWatcher.swift      # GCD-based file system monitor
│   ├── PortScanner.swift      # lsof-based TCP port detection (5s interval)
│   ├── GitScanner.swift       # git branch detection (30s interval)
│   └── UsageScanner.swift     # Claude JSONL transcript parser (5min interval)
└── Views/
    ├── ProjectListView.swift  # Main popover content
    ├── ProjectRowView.swift   # Expandable project row
    ├── UsageBannerView.swift  # Mini usage dashboard
    └── CredentialField.swift  # Reusable label/value with copy + reveal
```

## License

MIT
