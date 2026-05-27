# Apex Shift 2D — Production Repository

**Apex Shift 2D** is a 2D top-down survival prototype in Godot 4.x where creatures adapt to your playstyle across generations.

🎮 **Genre**: Survival, Roguelike  
🎨 **Style**: 2D Top-Down, Placeholder Art  
⚙️ **Engine**: Godot 4.x (GDScript)  
📊 **Scope**: Vertical Slice Prototype  

## Quick Links

- 🎯 **[Issues & Roadmap](https://github.com/krisstoof/apex-shift-2d/issues)**
- 📋 **[GitHub Projects Board](https://github.com/krisstoof/apex-shift-2d/projects)** (after setup)
- 📖 **[Vision Document](./docs/vision.md)** (to be created)
- 🗺️ **[Roadmap](./docs/roadmap.md)** (to be created)

## Project Structure

This repository contains:

```
apex-shift-2d/
├── setup-github-project.sh          # Automation script for GitHub Projects
├── SETUP-GITHUB-PROJECTS.md         # Setup guide
├── README.md                        # This file
│
├── docs/                            # Project documentation
│   ├── vision.md                    # Game vision & core concept
│   ├── prototype-gdd.md             # Design document
│   ├── roadmap.md                   # Development roadmap
│   ├── backlog.md                   # All known tasks
│   └── decision-log.md              # Architecture decisions
│
├── game/                            # (To be created) Godot project
│   ├── project.godot
│   ├── scenes/
│   ├── scripts/
│   ├── data/
│   └── assets/
│
└── tools/                           # Development utilities
    └── setup-github-project.sh      # (Already in root, documented here)
```

## Core Concept

**The Problem**: Survival games feel static. Creatures don't adapt to your tactics.

**The Solution**: Apex Shift 2D introduces **Adaptive Generations**.

- **Gen 1**: Varnaks are cautious, scared of fire, fall for traps easily.
- **You kill many with traps?** → **Gen 2**: Varnaks develop trap awareness, avoid your tricks.
- **You build fires everywhere?** → **Gen 3**: Varnaks ignore fire, become bolder.
- **You're very aggressive?** → **Gen 4**: Varnaks hunt in coordinated packs.

Every decision you make shapes the next generation. The creatures remember.

## Development Roadmap

The project is divided into **5 major milestones** plus final polish:

| Milestone | Goal | Status |
|-----------|------|--------|
| **M0** | Project setup, documentation, architecture | 🎯 Setup |
| **M1** | Player movement, world, basic Varnaks | ⏳ Planned |
| **M2** | Traps and first adaptation logic | ⏳ Planned |
| **M3** | Pack behavior and advanced adaptation | ⏳ Planned |
| **M4** | Base building and creature pressure | ⏳ Planned |
| **M5** | Vertical slice: polish, test, review | ⏳ Planned |

See detailed breakdown in **[Roadmap](./docs/roadmap.md)** (to be created).

## Getting Started

### Prerequisites

- **Godot 4.x** (download from [godotengine.org](https://godotengine.org))
- **Git** (for cloning this repository)
- **GitHub CLI** (optional, for project automation)

### Setup GitHub Projects (Optional)

To set up the production board with issues and milestones:

```bash
chmod +x setup-github-project.sh
bash setup-github-project.sh
```

Follow the guide: **[SETUP-GITHUB-PROJECTS.md](./SETUP-GITHUB-PROJECTS.md)**

### Running the Game (When Ready)

1. Open Godot 4.x
2. Click **"Open Project"**
3. Navigate to this repository and select `game/project.godot`
4. Press **F5** or click **Play**

*(Godot project will be created during M0)*

## File Structure (Game)

When the Godot project is created, it will follow this structure:

```
game/
├── project.godot                 # Godot project file
├── scenes/
│   ├── main.tscn                # Main scene
│   ├── player/player.tscn
│   ├── creatures/varnak.tscn
│   ├── world/world.tscn
│   ├── buildings/
│   ├── ui/hud.tscn
│   └── systems/
├── scripts/
│   ├── player/
│   ├── creatures/
│   ├── world/
│   ├── buildings/
│   ├── ui/
│   └── systems/
├── data/
│   ├── items.json
│   ├── recipes.json
│   └── species_varnak.json
└── assets/
    ├── sprites/
    ├── audio/
    └── fonts/
```

## Documentation

Key documents *(to be created during M0)*:

- **[vision.md](./docs/vision.md)** — Why this game matters, emotional goals
- **[prototype-gdd.md](./docs/prototype-gdd.md)** — Design, mechanics, scope
- **[roadmap.md](./docs/roadmap.md)** — Timeline and milestones
- **[backlog.md](./docs/backlog.md)** — All known tasks and features
- **[decision-log.md](./docs/decision-log.md)** — Why we made certain choices

## Development Workflow

1. **Planning**: Check the [Issues](https://github.com/krisstoof/apex-shift-2d/issues) page
2. **Assignment**: Pick an issue and assign it to yourself
3. **Development**: Create a branch, make changes, commit
4. **Pull Request**: Open a PR with a clear description
5. **Review**: Get feedback, iterate
6. **Merge**: Integrate into main branch

**Labels help organize work:**
- `priority:pX` — Urgency
- `type:*` — Task category
- `system:*` — Game system
- `status:blocked` — Waiting on something else

**Milestones track progress:**
- M0 → M5 show the development phases
- Issues are assigned to specific milestones

## Key Systems

### 1. **Player**
- Top-down movement (WASD)
- Stats: Health, Hunger, Stamina
- Inventory for resources
- Crafting interface

### 2. **World**
- Procedural-ish terrain
- Resource nodes: trees, rocks, bushes
- Interaction system (E-key)

### 3. **Varnaks** (Creatures)
- AI opponents that hunt the player
- Adaptive stats:
  - `aggression` — How eager to attack
  - `fire_fear` — Scared of campfires
  - `trap_awareness` — Good at avoiding traps
  - `pack_coordination` — Hunts in groups
  - And more...

### 4. **Evolution System** ⭐
- Tracks how you play (trap kills, aggression, etc.)
- Changes Varnak generation every X days
- Creatures adapt to your tactics
- **This is the core mechanic**

### 5. **Buildings**
- Campfire: Scares Varnaks away
- Traps: Kill careless creatures
- Walls: Defend your base
- Storage: Keep food safe

## Current Status

🚀 **Phase**: Pre-production (M0 Planning)

- ✅ Repository created
- ✅ GitHub Projects automation script created
- ✅ Initial documentation structure ready
- ⏳ Awaiting M0 completion (docs, architecture)
- ⏳ M1 development to begin (player movement, world)

## Contributing

This is a prototype project led by [@krisstoof](https://github.com/krisstoof).

For now, development is focused on delivering the vertical slice. Future contributions welcome!

## License

*To be decided during project setup.*

---

## Resources

- **Godot 4 Docs**: https://docs.godotengine.org/
- **GDScript Reference**: https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/
- **GitHub CLI Guide**: https://cli.github.com/manual

---

**Last Updated**: 2026-05-27  
**Current Owner**: [@krisstoof](https://github.com/krisstoof)
