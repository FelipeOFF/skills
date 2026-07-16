# Frontend Project Style — Claude Code Skill

A configurable design system and style guide skill for frontend projects. Ensures all generated frontend code follows your project's design system.

## What it does

- **Auto-detects** if a `PROJECT_STYLE.md` exists in your project
- **Onboards** you with questions about your stack, colors, typography, and layout preferences
- **Generates** a `PROJECT_STYLE.md` with your design tokens
- **Enforces** consistent styling across all generated components

## Supported Stacks

React, Next.js, Angular, Vue, HTML/CSS — with TypeScript support.

## Supported Component Libraries

shadcn/ui, MUI, Chakra UI, and more.

## Installation

### Via `npx skills`

```bash
npx skills add git@github.com:FelipeOFF/frontend-project-style-skill.git
```

### Manual

Copy `SKILL.md` to `.claude/skills/frontend-project-style/SKILL.md` in your project or home directory.

## How it works

1. Checks for `PROJECT_STYLE.md` in your project root or `~/.claude/`
2. If not found, runs an onboarding flow collecting your design preferences
3. Generates `PROJECT_STYLE.md` with your design tokens
4. All subsequent frontend code generation follows your design system

## Design Tokens Covered

- **Colors**: Primary, background, surface, border, text, success/error/warning
- **Typography**: Heading font, body font, mono font with size scale
- **Layout**: Border radius (none/subtle/modern/rounded), density (compact/balanced/spacious)
- **Dark Mode**: Light only, dark only, or both
- **Component Patterns**: Buttons, cards, inputs with consistent styling

## License

MIT
