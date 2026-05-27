#!/bin/bash

################################################################################
# Apex Shift 2D — GitHub Projects Setup Script
# 
# This script automates the creation of a production board, labels, milestones,
# and initial issues for the Apex Shift 2D project on GitHub.
#
# Usage:
#   bash setup-github-project.sh
#
# Prerequisites:
#   - GitHub CLI (gh) installed
#   - Authenticated with GitHub (gh auth login)
#   - Project scope enabled (gh auth refresh -s project)
#   - Existing repository
################################################################################

set -e

# Configuration
OWNER="krisstoof"
REPO="apex-shift-2d"
PROJECT_TITLE="Apex Shift 2D — Production Board"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Step 1: Check prerequisites
log_info "Checking prerequisites..."

if ! command -v gh &> /dev/null; then
    log_error "GitHub CLI (gh) is not installed."
    echo "Install it from: https://cli.github.com/"
    exit 1
fi
log_success "GitHub CLI found"

if ! gh auth status &> /dev/null; then
    log_error "Not authenticated with GitHub."
    echo "Run: gh auth login"
    exit 1
fi
log_success "GitHub authentication verified"

# Check for project scope
AUTH_STATUS=$(gh auth status 2>&1)
if ! echo "$AUTH_STATUS" | grep -q "project"; then
    log_warning "Project scope not detected in current authentication."
    echo ""
    echo "To enable GitHub Projects support, run:"
    echo "  ${YELLOW}gh auth refresh -s project${NC}"
    echo ""
    read -p "Refresh authentication now? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        gh auth refresh -s project
        log_success "Authentication refreshed with project scope"
    else
        log_warning "Skipping project scope refresh. Some features may not work."
    fi
fi

# Verify repository exists
log_info "Verifying repository ${OWNER}/${REPO}..."
if ! gh repo view "$OWNER/$REPO" &> /dev/null; then
    log_error "Repository ${OWNER}/${REPO} not found."
    exit 1
fi
log_success "Repository verified"

echo ""
echo "================================================================================"
echo "Starting Apex Shift 2D GitHub Projects Setup"
echo "================================================================================"
echo ""

# Step 2: Create Labels
log_info "Creating labels..."

create_label() {
    local name=$1
    local color=$2
    local description=$3
    
    if gh label create "$name" --color "$color" --description "$description" -R "$OWNER/$REPO" 2>/dev/null; then
        log_success "Label created: $name"
    else
        log_warning "Label already exists or error creating: $name"
    fi
}

# Priority labels
create_label "priority:p0" "d73a49" "Critical priority"
create_label "priority:p1" "ff6b6b" "High priority"
create_label "priority:p2" "ffa500" "Medium priority"
create_label "priority:p3" "ffeb3b" "Low priority"

# Type labels
create_label "type:feature" "0366d6" "New feature"
create_label "type:bug" "d73a49" "Bug fix"
create_label "type:design" "9933cc" "Design task"
create_label "type:tech" "0099ff" "Technical task"
create_label "type:art" "ff6b6b" "Art asset"
create_label "type:audio" "00cc00" "Audio work"
create_label "type:ui" "ff9900" "UI/UX task"
create_label "type:test" "cccccc" "Testing"
create_label "type:docs" "fbca04" "Documentation"
create_label "type:refactor" "9933cc" "Refactoring"
create_label "type:production" "222222" "Production task"

# System labels
create_label "system:player" "1f6feb" "Player system"
create_label "system:world" "0366d6" "World system"
create_label "system:survival" "d73a49" "Survival mechanics"
create_label "system:inventory" "6f42c1" "Inventory system"
create_label "system:crafting" "fb8500" "Crafting system"
create_label "system:building" "8b4513" "Building system"
create_label "system:ai" "ff6b6b" "AI/Creature behavior"
create_label "system:evolution" "ff00ff" "Evolution system"
create_label "system:ui" "ffd60a" "UI system"
create_label "system:audio" "06a77d" "Audio system"
create_label "system:save" "2a9d8f" "Save/Load system"
create_label "system:production" "444444" "Production/Meta"
create_label "system:documentation" "f4a261" "Documentation"

# Other labels
create_label "status:blocked" "cc0000" "Blocked progress"
create_label "good first issue" "7057ff" "Good for newcomers"

log_success "All labels processed"
echo ""

# Step 3: Create Milestones
log_info "Creating milestones..."

create_milestone() {
    local title=$1
    local description=$2
    
    if gh milestone create "$title" --description "$description" -R "$OWNER/$REPO" 2>/dev/null; then
        log_success "Milestone created: $title"
    else
        log_warning "Milestone already exists or error creating: $title"
    fi
}

create_milestone "M0 — Project Setup" "Initial project configuration and documentation"
create_milestone "M1 — First Blood" "Core gameplay loop with player, movement, and basic Varnaks"
create_milestone "M2 — The Trap Lesson" "Traps and initial adaptation mechanics"
create_milestone "M3 — The Pack Remembers" "Pack behavior and advanced adaptation"
create_milestone "M4 — Base Under Watch" "Base building and advanced Varnak tactics"
create_milestone "M5 — Vertical Slice" "Polished vertical slice ready for review"

log_success "All milestones created"
echo ""

# Step 4: Create GitHub Project
log_info "Creating GitHub Project: \"$PROJECT_TITLE\"..."

# TODO: GitHub CLI does not support custom fields for Projects (beta feature).
# Using REST API directly for this would require additional token handling.
# For now, creating project and noting that fields must be configured manually.

PROJECT_RESPONSE=$(gh project create --owner "$OWNER" --title "$PROJECT_TITLE" --format json 2>/dev/null || echo "")

if [ -z "$PROJECT_RESPONSE" ]; then
    log_warning "Could not create project via gh CLI. Using manual creation guidance below."
    log_info "Please create the project manually at: https://github.com/$OWNER/$REPO/projects/new"
    PROJECT_NUMBER=""
else
    PROJECT_NUMBER=$(echo "$PROJECT_RESPONSE" | jq -r '.number // empty' 2>/dev/null || echo "")
    if [ -n "$PROJECT_NUMBER" ]; then
        log_success "Project created with number: $PROJECT_NUMBER"
    else
        log_warning "Project creation response unclear. Check manually."
    fi
fi
echo ""

# Step 5: Create Initial Issues
log_info "Creating initial issues..."

create_issue() {
    local title=$1
    local body=$2
    local milestone=$3
    local labels=$4
    
    ISSUE_URL=$(gh issue create \
        --title "$title" \
        --body "$body" \
        --milestone "$milestone" \
        ${labels:+--label "$labels"} \
        -R "$OWNER/$REPO" \
        --json url --jq .url 2>/dev/null || echo "")
    
    if [ -n "$ISSUE_URL" ]; then
        log_success "Issue created: $title"
        echo "$ISSUE_URL"
    else
        log_error "Failed to create issue: $title"
        return 1
    fi
}

# Milestone M0 — Project Setup
log_info "Creating M0 — Project Setup issues..."

create_issue \
    "[PROD] Configure GitHub Project board" \
    "Goal:
Set up the GitHub Projects board with all necessary columns, views, and automation rules.

Acceptance criteria:
- Project board exists
- Status field configured with: Ideas, Backlog, Ready, In Progress, Review/Test, Done, Blocked
- Priority, Type, and System fields configured
- Views created: Board, Current Sprint, Roadmap, Bugs, AI/Evolution, Blocked
- Labels and milestones assigned

Out of scope:
- Automation beyond basic filtering

Notes:
This is a meta task for project organization." \
    "M0 — Project Setup" \
    "type:production,system:production,priority:p0"

create_issue \
    "[PROD] Define production workflow" \
    "Goal:
Document the development workflow, issue templates, and PR review process.

Acceptance criteria:
- Issue templates created
- PR template created
- Code review guidelines documented
- Sprint planning format defined

Out of scope:
- CI/CD pipeline setup

Notes:
Reference: Creating GitHub issue templates" \
    "M0 — Project Setup" \
    "type:docs,system:production,priority:p1"

create_issue \
    "[DOCS] Create Vision Document" \
    "Goal:
Write a compelling vision document explaining what Apex Shift 2D is and why it matters.

Acceptance criteria:
- Core premise explained
- Player emotions defined
- Main hook described
- Success metrics outlined

Out of scope:
- Full design document

Notes:
This is the north star for development decisions." \
    "M0 — Project Setup" \
    "type:docs,system:documentation,priority:p1"

create_issue \
    "[DOCS] Create Prototype GDD" \
    "Goal:
Write a Game Design Document focused on the vertical slice scope.

Acceptance criteria:
- Gameplay loop documented
- Player mechanics described
- Varnak mechanics described
- Evolution system explained
- Scope clearly limited to vertical slice

Out of scope:
- Full production GDD
- Advanced features

Notes:
Focus on what makes the prototype unique." \
    "M0 — Project Setup" \
    "type:docs,system:documentation,priority:p1"

create_issue \
    "[DOCS] Create Decision Log" \
    "Goal:
Start a decision log to track architectural and design choices.

Acceptance criteria:
- Decision Log file created
- First 5 decisions documented with rationale
- Template established for future decisions

Out of scope:
- Historical decisions from before this project

Notes:
Helps future developers understand why things are the way they are." \
    "M0 — Project Setup" \
    "type:docs,system:documentation,priority:p2"

create_issue \
    "[DOCS] Create Roadmap" \
    "Goal:
Create a high-level roadmap showing the path from setup to vertical slice.

Acceptance criteria:
- Milestones M0-M5 visualized
- Key deliverables per milestone listed
- Timeline estimates provided

Out of scope:
- Post-prototype features
- Detailed task breakdown (use Backlog)

Notes:
This is the big picture." \
    "M0 — Project Setup" \
    "type:docs,system:documentation,priority:p2"

create_issue \
    "[DOCS] Create Backlog" \
    "Goal:
Create a comprehensive backlog of all known tasks, features, and bugs.

Acceptance criteria:
- Issues organized by milestone
- Priority assigned to each item
- Descriptions include acceptance criteria
- Future work clearly marked as out of scope for prototype

Out of scope:
- Implementation of backlog items

Notes:
Use this as the source of truth for task selection." \
    "M0 — Project Setup" \
    "type:docs,system:documentation,priority:p2"

create_issue \
    "[TECH] Decide initial Godot project structure" \
    "Goal:
Establish the directory structure, node organization, and coding conventions.

Acceptance criteria:
- Directory layout defined (scenes/, scripts/, data/, docs/)
- Naming conventions established
- Node organization patterns defined
- Signal/event patterns decided

Out of scope:
- Actual implementation

Notes:
This is a design task, not implementation." \
    "M0 — Project Setup" \
    "type:tech,system:production,priority:p1"

create_issue \
    "[PROD] Prepare Sprint 001 plan" \
    "Goal:
Plan the first sprint focusing on core player movement and world setup.

Acceptance criteria:
- Sprint goals defined
- Issues selected from M1 backlog
- Estimated effort per issue
- Sprint review criteria established

Out of scope:
- Future sprints

Notes:
This concludes M0 and kicks off M1." \
    "M0 — Project Setup" \
    "type:production,system:production,priority:p0"

# Milestone M1 — First Blood
log_info "Creating M1 — First Blood issues..."

create_issue \
    "[PLAYER] Implement top-down player movement" \
    "Goal:
Create a functional player character that moves in 4 directions (WASD) with smooth animation.

Acceptance criteria:
- Player responds to WASD input
- Movement is smooth and responsive
- Animation plays during movement
- Player can stop smoothly

Out of scope:
- Sprinting
- Diagonal movement priority
- Complex animation blending

Notes:
Use CharacterBody2D as base. Placeholder sprite is fine." \
    "M1 — First Blood" \
    "type:feature,system:player,priority:p0"

create_issue \
    "[PLAYER] Add camera following player" \
    "Goal:
Implement a camera that smoothly follows the player with slight lag.

Acceptance criteria:
- Camera tracks player position
- Camera has smooth follow (not snappy)
- Camera respects world bounds

Out of scope:
- Advanced camera techniques
- Zoom mechanics

Notes:
Use Camera2D node." \
    "M1 — First Blood" \
    "type:feature,system:player,priority:p1"

create_issue \
    "[SURVIVAL] Add health, hunger and stamina" \
    "Goal:
Implement player stat system with three core stats.

Acceptance criteria:
- Health stat: decreases when attacked, reset on start
- Hunger stat: slowly decreases over time, affects behavior
- Stamina stat: decreases on sprint/attack, regenerates
- Stats have min/max bounds
- Stats are accessible to other systems

Out of scope:
- Complex stat interactions
- Equipment effects

Notes:
Use a PlayerStats.gd script." \
    "M1 — First Blood" \
    "type:feature,system:survival,priority:p0"

create_issue \
    "[WORLD] Create test map" \
    "Goal:
Build a small test map for gameplay.

Acceptance criteria:
- Map is 64x64 tiles
- Player spawns at center
- Map has varied terrain
- Boundaries are clear
- Performance is acceptable

Out of scope:
- Procedural generation
- Advanced decoration

Notes:
Can be built manually or generated with code." \
    "M1 — First Blood" \
    "type:feature,system:world,priority:p1"

create_issue \
    "[WORLD] Add resource nodes" \
    "Goal:
Create interactive resource nodes that players can harvest.

Acceptance criteria:
- Three node types: Tree (wood), Rock (stone), Bush (fiber)
- Nodes respond to player interaction (E key)
- Resources added to inventory
- Node despawns or disables after harvest
- Visual feedback on interaction

Out of scope:
- Respawning nodes
- Complex harvest animations

Notes:
Start with simple colored shapes." \
    "M1 — First Blood" \
    "type:feature,system:world,priority:p1"

create_issue \
    "[INVENTORY] Add basic inventory" \
    "Goal:
Implement a simple inventory system to track collected resources.

Acceptance criteria:
- Inventory tracks: wood, stone, fiber, meat, hide, bone
- add_item(name, amount) method works
- remove_item(name, amount) method works
- has_item(name, amount) returns boolean
- get_amount(name) returns count
- Inventory data is serializable

Out of scope:
- UI display (separate task)
- Item stacking limits
- Weight system

Notes:
Use a dictionary as backend." \
    "M1 — First Blood" \
    "type:feature,system:inventory,priority:p0"

create_issue \
    "[CRAFTING] Add first crafting recipes" \
    "Goal:
Implement crafting system with initial recipes.

Acceptance criteria:
- Recipes stored in data/recipes.json:
  - campfire = 3 wood + 2 stone
  - spear = 2 wood + 1 stone + 1 fiber
  - trap = 2 wood + 2 fiber
  - wall = 3 wood
  - storage_box = 4 wood
- Crafting validates recipe requirements
- Crafting consumes resources from inventory
- Crafting spawns built object at player position
- Key shortcuts: 1-5 for each recipe

Out of scope:
- Crafting UI menus
- Complex recipes
- Ingredient substitution

Notes:
Use hotkeys for initial prototype." \
    "M1 — First Blood" \
    "type:feature,system:crafting,priority:p0"

create_issue \
    "[AI] Add first Varnak placeholder" \
    "Goal:
Create a basic Varnak creature with placeholder visuals.

Acceptance criteria:
- Varnak is a CharacterBody2D with simple shape
- Varnak has health and speed stats
- Varnak moves smoothly
- Multiple Varnaks can exist on map
- Varnaks have basic bounding box

Out of scope:
- AI behavior
- Combat
- Adaptation

Notes:
Just get the creature on screen and moving." \
    "M1 — First Blood" \
    "type:feature,system:ai,priority:p1"

create_issue \
    "[AI] Add basic Varnak detection and chase" \
    "Goal:
Implement basic AI: detect player and chase.

Acceptance criteria:
- Varnak detects player within range (300 units)
- Varnak chases player when detected
- Chase behavior is smooth
- Varnak loses interest if player escapes

Out of scope:
- Pack behavior
- Complex pathfinding
- Attack behavior

Notes:
Use simple line-of-sight for detection." \
    "M1 — First Blood" \
    "type:feature,system:ai,priority:p1"

create_issue \
    "[UI] Add basic HUD" \
    "Goal:
Create a heads-up display showing player stats.

Acceptance criteria:
- Health bar displayed
- Hunger bar displayed
- Stamina bar displayed
- Resource count shown (wood, stone, fiber)
- Current day shown
- Layout is clean and readable

Out of scope:
- Detailed inventory UI
- Stats tooltips
- Animations

Notes:
Use Control nodes and simple text." \
    "M1 — First Blood" \
    "type:feature,system:ui,priority:p1"

# Milestone M2 — The Trap Lesson
log_info "Creating M2 — The Trap Lesson issues..."

create_issue \
    "[BUILDING] Add trap placement" \
    "Goal:
Allow players to craft and place traps that can kill Varnaks.

Acceptance criteria:
- Trap object placed at player position via crafting
- Trap is a static object with collision
- Trap has area detection for creatures
- Multiple traps can exist
- Trap has visual indicator

Out of scope:
- Trap animation
- Trap reset mechanics

Notes:
Use Area2D for detection." \
    "M2 — The Trap Lesson" \
    "type:feature,system:building,priority:p0"

create_issue \
    "[AI] Allow Varnak to trigger trap" \
    "Goal:
Varnaks that touch traps take damage or die.

Acceptance criteria:
- Varnak detects trap via area overlap
- Varnak takes obrażenia (damage)
- Varnak dies if health reaches 0
- Trap is consumed after activation
- Event emitted on trap kill

Out of scope:
- Trap repair
- Varnak avoidance of traps yet

Notes:
Trap should deal instant high damage." \
    "M2 — The Trap Lesson" \
    "type:feature,system:ai,priority:p1"

create_issue \
    "[EVOLUTION] Add EventBus" \
    "Goal:
Create a global event system for communication between systems.

Acceptance criteria:
- EventBus is autoload/singleton
- Supports emit_event(event_name, payload)
- Supports connect_event(event_name, callback)
- Events can carry dictionary data
- EventBus is accessible globally

Out of scope:
- Complex event prioritization
- Event history logging

Notes:
Simple pub/sub pattern." \
    "M2 — The Trap Lesson" \
    "type:tech,system:evolution,priority:p0"

create_issue \
    "[EVOLUTION] Track Varnak deaths by trap" \
    "Goal:
EventBus tracks how many Varnaks are killed by traps.

Acceptance criteria:
- Event 'varnak_killed_by_trap' emitted when trap kills Varnak
- EvolutionDirector listens and increments counter
- Counter is readable in debug display

Out of scope:
- Persistence
- Analytics

Notes:
Foundation for adaptation." \
    "M2 — The Trap Lesson" \
    "type:feature,system:evolution,priority:p0"

create_issue \
    "[EVOLUTION] Add Evolution Director" \
    "Goal:
Create the core system that tracks pressure on Varnaks and triggers generation changes.

Acceptance criteria:
- Tracks: trap_kills, player_kills, fire_scares, wall_attacks
- Stores current generation (starts at 1)
- Stores Varnak species profile (stats)
- Can be triggered to change generation
- New generation gets adapted stats
- Debug output shows new generation profile

Out of scope:
- Full genetic simulation
- Multiple species

Notes:
This is the heart of the prototype mechanic." \
    "M2 — The Trap Lesson" \
    "type:feature,system:evolution,priority:p0"

create_issue \
    "[EVOLUTION] Add generation change debug action" \
    "Goal:
Allow manual generation change via keyboard (for testing).

Acceptance criteria:
- Press G to manually trigger generation change
- Console shows old and new stats
- Event 'generation_changed' emitted
- New Varnaks spawn with new profile

Out of scope:
- Automatic generation timing (M3)

Notes:
Essential for rapid testing." \
    "M2 — The Trap Lesson" \
    "type:feature,system:evolution,priority:p1"

create_issue \
    "[AI] Add trap awareness parameter" \
    "Goal:
Add trap_awareness stat to Varnak that affects behavior toward traps.

Acceptance criteria:
- Varnak has trap_awareness stat (0-100)
- High awareness: Varnak avoids trap areas
- Low awareness: Varnak ignores traps
- Stat can be modified by EvolutionDirector

Out of scope:
- Complex avoidance pathfinding
- Machine learning simulation

Notes:
Use simple raycasting or area checking." \
    "M2 — The Trap Lesson" \
    "type:feature,system:ai,priority:p1"

create_issue \
    "[UI] Show generation and Varnak parameters" \
    "Goal:
Display current generation and key Varnak stats in HUD.

Acceptance criteria:
- Generation number shown
- trap_awareness displayed
- fire_fear displayed
- aggression displayed
- pack_coordination displayed
- Updates when generation changes

Out of scope:
- Detailed species info screen

Notes:
Add to existing HUD." \
    "M2 — The Trap Lesson" \
    "type:feature,system:ui,priority:p1"

# Milestone M3 — The Pack Remembers
log_info "Creating M3 — The Pack Remembers issues..."

create_issue \
    "[AI] Add simple pack behaviour" \
    "Goal:
Varnaks coordinate in groups and communicate threats.

Acceptance criteria:
- Multiple Varnaks detect player together
- Varnaks increase aggression when grouped
- Grouped Varnaks have improved coordination
- pack_coordination stat affects behavior

Out of scope:
- Complex formation control
- Tactical intelligence

Notes:
Use proximity checks to find allies." \
    "M3 — The Pack Remembers" \
    "type:feature,system:ai,priority:p1"

create_issue \
    "[AI] Add stalk behaviour" \
    "Goal:
Varnaks can stalk player from distance and wait for opportunities.

Acceptance criteria:
- Varnak enters stalk mode at medium range
- Stalking Varnak keeps distance
- Stalking Varnak tracks player movement
- stalk_tendency stat affects frequency of stalking
- Varnak switches to chase if opportunity arises

Out of scope:
- Long-range strategic behavior

Notes:
Adds tension and unpredictability." \
    "M3 — The Pack Remembers" \
    "type:feature,system:ai,priority:p2"

create_issue \
    "[AI] Add flee behaviour" \
    "Goal:
Varnaks can flee when threatened or injured.

Acceptance criteria:
- Varnak flees when health < 30%
- Varnak flees from fire/campfire
- fire_fear stat affects flee threshold
- Fleeing Varnak pathfinds away from threat

Out of scope:
- Complex threat assessment

Notes:
Makes combat more dynamic." \
    "M3 — The Pack Remembers" \
    "type:feature,system:ai,priority:p2"

create_issue \
    "[EVOLUTION] Increase pack coordination after repeated player kills" \
    "Goal:
When players kill many Varnaks, next generation has better coordination.

Acceptance criteria:
- Event 'varnak_killed_by_player' tracked
- If player_kills >= 3 in generation:
  - pack_coordination increases
  - aggression increases
- EvolutionDirector updates profile
- Debug output shows changes

Out of scope:
- Diminishing returns
- Max stat limits

Notes:
Shows that Varnaks adapt to how you play." \
    "M3 — The Pack Remembers" \
    "type:feature,system:evolution,priority:p1"

create_issue \
    "[TEST] Playtest whether adaptation is noticeable" \
    "Goal:
Verify that players can perceive the adaptation between generations.

Acceptance criteria:
- Playtester can describe behavioral differences
- Second generation noticeably different from first
- Changes feel intentional (not random)
- Feedback: adaptation is interesting or frustrating?

Out of scope:
- Balance tuning
- Design changes

Notes:
Critical feedback for M3 success." \
    "M3 — The Pack Remembers" \
    "type:test,system:ai,priority:p1"

# Milestone M4 — Base Under Watch
log_info "Creating M4 — Base Under Watch issues..."

create_issue \
    "[BUILDING] Add wall placement" \
    "Goal:
Allow players to build walls for base defense.

Acceptance criteria:
- Wall placed via crafting
- Wall is a solid obstacle
- Multiple walls can be chained
- Wall has collision and health
- Wall has visual indicator

Out of scope:
- Wall damage animation
- Gate mechanics

Notes:
Simple rectangular obstacle." \
    "M4 — Base Under Watch" \
    "type:feature,system:building,priority:p1"

create_issue \
    "[BUILDING] Add storage box" \
    "Goal:
Create a storage container for food preservation.

Acceptance criteria:
- Storage box placed via crafting
- Can hold meat/hide items
- Storage box has collision
- Placeholder for inventory UI interaction

Out of scope:
- Full inventory management
- Storage limits

Notes:
Mostly visual for now." \
    "M4 — Base Under Watch" \
    "type:feature,system:building,priority:p2"

create_issue \
    "[AI] Add base curiosity behaviour" \
    "Goal:
Varnaks investigate bases and stored resources.

Acceptance criteria:
- Varnak detects storage box at range
- Varnak moves toward storage
- base_curiosity stat affects investigation range
- Investigation can be interrupted by threat

Out of scope:
- Storage destruction
- Raiding mechanics

Notes:
Creates base defense challenges." \
    "M4 — Base Under Watch" \
    "type:feature,system:ai,priority:p2"

create_issue \
    "[AI] Add Varnak interest in stored meat" \
    "Goal:
Varnaks are attracted to meat in storage boxes.

Acceptance criteria:
- Varnak can smell stored meat
- food_smell_sensitivity affects detection range
- High sensitivity: detect from far away
- Varnak prioritizes reaching storage

Out of scope:
- Actual meat consumption
- Food decay

Notes:
Another evolution pressure point." \
    "M4 — Base Under Watch" \
    "type:feature,system:ai,priority:p2"

create_issue \
    "[AI] Add wall attack placeholder" \
    "Goal:
Varnaks attempt to break through walls.

Acceptance criteria:
- Varnak detects wall as obstacle
- Varnak can attack wall
- Wall takes damage
- Wall health decreases
- When health = 0, wall is destroyed

Out of scope:
- Structured attack tactics
- Wall reconstruction

Notes:
Adds pressure to defensive structures." \
    "M4 — Base Under Watch" \
    "type:feature,system:ai,priority:p2"

create_issue \
    "[TEST] Playtest base safety" \
    "Goal:
Test whether players can build effective defenses.

Acceptance criteria:
- Player can survive one night with walls + fire
- Defenses feel effective but not overpowered
- Varnaks present a real threat
- Feedback: base building is satisfying

Out of scope:
- Balance fixes (separate task)

Notes:
Core survival mechanic validation." \
    "M4 — Base Under Watch" \
    "type:test,system:building,priority:p1"

# Milestone M5 — Vertical Slice
log_info "Creating M5 — Vertical Slice issues..."

create_issue \
    "[SAVE] Add placeholder save/load structure" \
    "Goal:
Create infrastructure for save/load even if not fully implemented.

Acceptance criteria:
- save_system.gd exists
- save_game() method placeholder
- load_game() method placeholder
- TODO comments explain future implementation

Out of scope:
- Full save functionality
- Data persistence

Notes:
Architectural readiness." \
    "M5 — Vertical Slice" \
    "type:tech,system:save,priority:p3"

create_issue \
    "[UI] Add generation summary screen" \
    "Goal:
Create a screen showing generation stats and how Varnaks adapted.

Acceptance criteria:
- Screen shows previous generation stats
- Screen shows new generation stats
- Highlights what changed
- Explains why (what pressure caused change)
- Can be triggered after generation change

Out of scope:
- Detailed simulation graphs

Notes:
Educational and satisfying." \
    "M5 — Vertical Slice" \
    "type:feature,system:ui,priority:p2"

create_issue \
    "[AUDIO] Add placeholder creature sounds" \
    "Goal:
Add basic sound effects for Varnak behaviors.

Acceptance criteria:
- Varnak vocalization on attack
- Varnak vocalization on death
- Placeholder audio (can be programmer art)
- Sounds are muffled/scary

Out of scope:
- Full sound design
- Music

Notes:
Placeholder audio is fine." \
    "M5 — Vertical Slice" \
    "type:audio,system:audio,priority:p3"

create_issue \
    "[TEST] Full 30-minute playtest" \
    "Goal:
Conduct a complete playthrough of the vertical slice.

Acceptance criteria:
- Playtest session lasts 30 minutes
- All core features tested
- No critical crashes
- Feedback collected on all systems

Out of scope:
- Balance fixes (separate tasks)

Notes:
Final validation before review." \
    "M5 — Vertical Slice" \
    "type:test,system:production,priority:p0"

create_issue \
    "[BUG] Fix critical vertical slice bugs" \
    "Goal:
Identify and fix any critical bugs found during vertical slice playtest.

Acceptance criteria:
- No crashes during 30-minute session
- No permanent progression blockers
- All core mechanics functional

Out of scope:
- Minor polish
- Edge cases

Notes:
Bug bash before review." \
    "M5 — Vertical Slice" \
    "type:bug,system:production,priority:p0"

create_issue \
    "[PROD] Prepare prototype review" \
    "Goal:
Prepare presentation and documentation for prototype review.

Acceptance criteria:
- Playable vertical slice ready
- Vision doc updated with results
- Design doc shows what worked/didn't
- Quick-start guide written
- Review presentation prepared

Out of scope:
- Post-prototype planning

Notes:
This concludes the vertical slice phase." \
    "M5 — Vertical Slice" \
    "type:production,system:production,priority:p0"

log_success "All issues created"
echo ""

# Step 6: Summary
echo "================================================================================"
echo "GitHub Projects Setup Complete!"
echo "================================================================================"
echo ""
log_success "All labels created"
log_success "All milestones created"
log_success "All issues created"
echo ""

echo "Next steps:"
echo ""
echo "1. Create GitHub Project (if not created via CLI):"
echo "   https://github.com/$OWNER/$REPO/projects/new"
echo ""
echo "2. Add custom fields to the project (in Project Settings):"
echo ""
echo "   Status (single select):"
echo "   - Ideas"
echo "   - Backlog"
echo "   - Ready"
echo "   - In Progress"
echo "   - Review / Test"
echo "   - Done"
echo "   - Blocked"
echo ""
echo "   Priority (single select):"
echo "   - P0 Critical"
echo "   - P1 High"
echo "   - P2 Medium"
echo "   - P3 Low"
echo ""
echo "   Type (single select):"
echo "   - Feature, Bug, Design, Tech, Art, Audio, UI, Test, Docs, Refactor, Production"
echo ""
echo "   System (single select):"
echo "   - Player, World, Survival, Inventory, Crafting, Building, AI, Evolution"
echo "   - UI, Audio, Save, Production, Documentation"
echo ""
echo "   Sprint (single select):"
echo "   - Sprint 001, Sprint 002, Sprint 003, Sprint 004, Sprint 005"
echo ""
echo "   Risk (single select):"
echo "   - Low, Medium, High"
echo ""
echo "3. Create board views (in Project Views):"
echo "   - Board: grouped by Status"
echo "   - Current Sprint: filtered by Sprint"
echo "   - Roadmap: grouped by Milestone"
echo "   - Bugs: filtered by Type = Bug"
echo "   - AI / Evolution: filtered by System = AI or Evolution"
echo "   - Blocked: filtered by Status = Blocked"
echo ""
echo "4. View all issues:"
echo "   https://github.com/$OWNER/$REPO/issues"
echo ""
echo "5. View project (after manual setup):"
echo "   https://github.com/$OWNER/$REPO/projects"
echo ""
echo "================================================================================"
