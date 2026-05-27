#!/bin/bash

# Apex Shift 2D — GitHub Projects Setup
# Quick Start Guide

This script automates the setup of GitHub Projects board, labels, milestones, and initial issues for the Apex Shift 2D project.

## Prerequisites

1. **GitHub CLI installed**
   ```bash
   # macOS
   brew install gh
   
   # Linux
   sudo apt install gh
   
   # Windows
   choco install gh
   ```
   Learn more: https://cli.github.com/

2. **Authenticated with GitHub**
   ```bash
   gh auth login
   ```

3. **Project scope enabled**
   ```bash
   gh auth refresh -s project
   ```

## Usage

1. **Clone or navigate to the apex-shift-2d repository:**
   ```bash
   cd apex-shift-2d
   ```

2. **Make the script executable:**
   ```bash
   chmod +x setup-github-project.sh
   ```

3. **Run the setup script:**
   ```bash
   bash setup-github-project.sh
   ```

   The script will:
   - Verify GitHub CLI and authentication
   - Create 20+ labels organized by priority, type, and system
   - Create 6 milestones (M0 — M5)
   - Create ~40 initial issues across all milestones
   - Provide guidance for manual project setup

4. **Manual GitHub Projects Configuration:**

   After the script finishes, follow these steps in GitHub:

   a. **Create the project:**
      - Go to: https://github.com/krisstoof/apex-shift-2d/projects/new
      - Title: "Apex Shift 2D — Production Board"
      - Click "Create project"

   b. **Add custom fields (in Project Settings):**
      - **Status** (single select):
        - Ideas
        - Backlog
        - Ready
        - In Progress
        - Review / Test
        - Done
        - Blocked

      - **Priority** (single select):
        - P0 Critical
        - P1 High
        - P2 Medium
        - P3 Low

      - **Type** (single select):
        - Feature
        - Bug
        - Design
        - Tech
        - Art
        - Audio
        - UI
        - Test
        - Docs
        - Refactor
        - Production

      - **System** (single select):
        - Player
        - World
        - Survival
        - Inventory
        - Crafting
        - Building
        - AI
        - Evolution
        - UI
        - Audio
        - Save
        - Production
        - Documentation

      - **Sprint** (single select):
        - Sprint 001
        - Sprint 002
        - Sprint 003
        - Sprint 004
        - Sprint 005

      - **Risk** (single select):
        - Low
        - Medium
        - High

   c. **Create board views (in Project Views):**
      - **Board**: Group by Status (default table view)
      - **Current Sprint**: Filter by Sprint (not empty)
      - **Roadmap**: Group by Milestone
      - **Bugs**: Filter by Type = Bug
      - **AI / Evolution**: Filter by System = AI or Evolution
      - **Blocked**: Filter by Status = Blocked

5. **Start planning:**
   - Go to: https://github.com/krisstoof/apex-shift-2d/projects
   - Review all issues
   - Assign issues to sprints
   - Begin Sprint 001 planning

## Script Features

✅ **Idempotent**: Safe to run multiple times (skips existing labels/milestones)
✅ **Color-coded output**: Easy to follow progress
✅ **Error handling**: Validates GitHub CLI and authentication
✅ **Comprehensive**: 40+ issues with detailed descriptions
✅ **Organized**: Issues mapped to specific milestones with proper labels

## Issues Structure

The script creates issues organized by milestone:

- **M0 — Project Setup** (9 issues)
  - Documentation, decision logs, and planning

- **M1 — First Blood** (10 issues)
  - Core gameplay: player movement, resources, basic Varnaks

- **M2 — The Trap Lesson** (7 issues)
  - Traps and initial adaptation mechanics

- **M3 — The Pack Remembers** (5 issues)
  - Pack behavior and advanced adaptation

- **M4 — Base Under Watch** (6 issues)
  - Base building and creature behavior

- **M5 — Vertical Slice** (6 issues)
  - Polish, testing, and review preparation

## Labels

All created labels follow a naming convention:

- `priority:pX` — Issue priority (p0 = critical, p3 = low)
- `type:*` — Issue type (feature, bug, docs, etc.)
- `system:*` — Game system (player, ai, evolution, etc.)
- `status:blocked` — Currently blocked
- `good first issue` — Good for newcomers

## Troubleshooting

**"GitHub CLI is not installed"**
→ Install from https://cli.github.com/

**"Not authenticated with GitHub"**
→ Run `gh auth login`

**"Project scope not detected"**
→ Run `gh auth refresh -s project`

**Labels or milestones already exist**
→ The script skips them. This is normal and safe.

**Issues not created**
→ Check repository access and milestone names

## Next Steps After Setup

1. Review all created issues
2. Assign them to team members
3. Set up a Sprint 001 planning session
4. Begin development on M0 tasks
5. Update this documentation as needed

---

**For questions or issues with this setup, check:**
- GitHub CLI docs: https://cli.github.com/manual
- GitHub Projects docs: https://docs.github.com/en/issues/planning-and-tracking-with-projects
