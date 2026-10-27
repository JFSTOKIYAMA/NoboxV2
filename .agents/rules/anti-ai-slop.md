# Anti AI Slop Policy (Nobox Project)

Strict guidelines to prevent generic, low-effort, or hallucinated AI patterns across code, UI/UX, and copy.

---

## 1. UI & Design Safeguards (Anti-Slop Visuals)
- **No Generic AI Palettes**: Never use cliché purple-to-cyan gradient soups or arbitrary neon glows without purpose. Colors must follow the official Nobox palette:
  - Deep Dark Canvas: `#090D16` / `#0F1523`
  - Electric Primary: `#0066FF`
  - Crisp Cyan Accent: `#38BDF8`
- **No Cliché Layouts**: Never generate repetitive card grids filled with generic icons (sparkles, rocket, robot) and empty cards. Every widget must serve a concrete functional or UX purpose.
- **Micro-Interactions Over Chaos**: Use smooth, subtle easing (`Curves.easeInOutCubic` or `Curves.easeInOutSine`) rather than hyperactive or jarring loops.
- **Respect Typography**: Use crisp tracking (`letterSpacing`), proper font weights, and tabular figures for numbers. Never leave default generic typography unstyled.

---

## 2. Code Quality & Architecture
- **Zero Redundant Wrappers**: Do not wrap widgets in unnecessary `Container`, `Padding`, or `Expanded` when a direct property or widget suffices (`SizedBox`, `margin`, etc.).
- **No Obvious / Noisy Comments**: Never write AI slop comments like:
  ```dart
  // WRONG (AI Slop):
  // This is a container widget
  // Next we increment the counter by 1
  _counter++;
  ```
  Only write comments that explain *why*, non-obvious architecture, or domain logic.
- **Strict Typing & Immutability**:
  - Always prefer `const` constructors where possible.
  - Mark local variables and fields as `final` whenever re-assignment is not needed.
  - Always declare return types explicitly for functions and methods.
- **Modern APIs Only**:
  - Never use deprecated members (e.g. use `.withValues(alpha: ...)` instead of `.withOpacity(...)`).
  - Do not invent fake packages or unnecessary third-party dependencies when Flutter native primitives are cleaner and more reliable.

---

## 3. Copywriting & Content (No Corporate AI Fluff)
- **Authentic Tone**: Crisp, professional, and clear.
- **Banned Buzzwords**: Avoid fluff such as:
  - "Empower your workflow"
  - "Seamless next-generation AI-driven synergy"
  - "Unleash the full potential"
- State clearly what the feature does, how it works, and how the user can interact with it.
