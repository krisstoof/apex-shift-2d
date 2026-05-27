# Apex Shift 2D — Vision Document

## The Core Idea

**Apex Shift 2D** is a survival game where creatures **remember and adapt**.

Traditional survival games feature static opponents. They have fixed behaviors, fixed difficulty curves. You learn their patterns, optimize your strategy, and the game becomes predictable.

**Apex Shift 2D** does something different: the creatures you fight learn how you fight *them*.

## The Promise

**"Every survival tactic you use makes you vulnerable to the next threat."**

You rely on traps? The next generation avoids them.  
You hide in fire? They become fire-resistant.  
You're aggressive? They hunt in packs.  

This creates a **dynamic tension**: you're always one generation ahead, then caught off guard. The game stays fresh because your opponents are evolving.

## Emotional Goals

**What the player should feel:**

1. **Agency** — "My choices matter and have real consequences."
2. **Tension** — "I'm not safe. Things are changing."
3. **Pride** — "I survived, but at a cost."
4. **Learning** — "Oh no, they learned that trick!"
5. **Adaptation** — "I need to find a new strategy."

Not frustration or unfairness — just constant evolution.

## Why This Matters

Survival games risk becoming **grinds**. You find the optimal strategy and repeat it until you win.

Apex Shift 2D forces **continuous innovation**. You can't use the same trick twice. You must observe, adapt, and evolve along with the creatures.

This mirrors real evolution: predators and prey drive each other to new extremes.

## The Vertical Slice

For this prototype, we're building a **minimal vertical slice** that proves this core mechanic works:

- Simple player character that can move, gather resources, craft tools, and build defenses
- One creature type: the Varnak
- **One generation cycle**: You play, then pressure (how you killed creatures) changes the next generation
- Emergent complexity from simple rules

**Scope is intentionally small** to validate the idea before expanding.

---

## Inspiration

This concept draws from:
- **Dwarf Fortress**: Procedural narratives where emergent systems tell stories
- **Creatures**: Digital life learning through interaction
- **Dark Souls**: Tensional difficulty that respects player agency
- **Into the Breach**: Every action has tactical weight

## Success Criteria

By the end of M5, the prototype is successful if:

1. ✅ Player can survive one night against Varnaks
2. ✅ Varnaks die from traps
3. ✅ Generation change is noticeable (Varnaks behave differently)
4. ✅ Players understand the consequence chain:
   - "I killed many with traps" → "Next gen avoids traps"
5. ✅ The game is playable for 30 minutes without crashes
6. ✅ Players want to see what the next generation does

## Key Design Pillars

| Pillar | Meaning |
|--------|---------|
| **Adaptation** | Systems respond to player choices |
| **Clarity** | Players understand cause and effect |
| **Tension** | Difficulty is dynamic, never static |
| **Simplicity** | Core mechanic is easy to grasp |
| **Iteration** | Quick cycles enable quick learning |

---

**Next**: See [prototype-gdd.md](./prototype-gdd.md) for mechanical details.
