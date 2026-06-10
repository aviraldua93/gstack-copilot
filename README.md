# gstack for GitHub Copilot CLI

A port of [garrytan/gstack](https://github.com/garrytan/gstack) — Garry Tan's
opinionated CEO / Eng / Design / QA / Release engineering workflow — to
[GitHub Copilot CLI](https://docs.github.com/en/copilot/how-tos/copilot-cli)
plugin format.

This repository is **both a plugin marketplace and a plugin**, so you can
install the whole thing with a single command.

## Install (one-time)

In a **fresh terminal** (not inside an active `copilot` session, because
Copilot CLI holds a lock on `~/.copilot/settings.json` while running):

```shell
# 1. Register this marketplace with Copilot CLI
copilot plugin marketplace add aviraldua93/gstack-copilot

# 2. Install the gstack plugin from the marketplace
copilot plugin install gstack@gstack-copilot

# 3. Verify
copilot plugin list
```

Inside an interactive `copilot` session:

```
/skills list      # should list all 15 gstack skills:
                  #   autoplan, browse, canary, careful, design-review, guard,
                  #   health, investigate, office-hours, plan-ceo-review,
                  #   plan-eng-review, qa, retro, review, scrape
```

## What's included (15 skills)

**Core workflow**

| Skill              | Trigger                  | What it does                                       |
| ------------------ | ------------------------ | -------------------------------------------------- |
| `review`           | "review this pr"         | Pre-landing PR review                              |
| `investigate`      | "investigate", "debug"   | Systematic root-cause debugging                    |
| `plan-ceo-review`  | "ceo review"             | Strategic plan review                              |
| `plan-eng-review`  | "eng review"             | Architecture / eng-manager-mode plan review        |
| `autoplan`         | "autoplan"               | CEO → design → eng plan pipeline                   |
| `office-hours`     | "office hours"           | Reframe a product idea before coding               |
| `retro`            | "retro"                  | Weekly engineering retrospective                   |
| `health`           | "health"                 | Code-quality dashboard                             |
| `careful`          | "careful"                | Warn before destructive commands                   |
| `guard`            | "guard"                  | Activate `careful` + freeze edits to current dir   |

**Browser / QA (requires the bundled `browse` sidecar — see `skills/browse/`)**

| Skill              | Trigger                       | What it does                                              |
| ------------------ | ----------------------------- | --------------------------------------------------------- |
| `browse`           | "browse a page", "screenshot" | Fast headless browser for QA + dogfooding                 |
| `qa`               | "qa this app"                 | Systematically QA a web app and fix bugs                  |
| `design-review`    | "design review"               | Designer's-eye QA: spacing, hierarchy, AI-slop patterns   |
| `canary`           | "monitor after deploy"        | Post-deploy canary monitoring                             |
| `scrape`           | "scrape this page"            | Pull structured data from a web page                      |

## Update / uninstall

```shell
copilot plugin update gstack          # pull latest skills
copilot plugin disable gstack         # turn off without uninstalling
copilot plugin enable gstack          # turn back on
copilot plugin uninstall gstack       # remove
copilot plugin marketplace remove gstack-copilot   # unregister this marketplace
```

## Repository layout

```
gstack-copilot/                         # this repo
├── .github/
│   └── plugin/
│       └── marketplace.json            # marketplace manifest (this is what
│                                       #   `copilot plugin marketplace add` reads)
├── plugins/
│   └── gstack/                         # the gstack plugin itself
│       ├── plugin.json                 # plugin manifest
│       └── skills/
│           ├── autoplan/SKILL.md
│           ├── browse/                 # bundles a TypeScript browser sidecar (bin/, src/, test/)
│           ├── canary/SKILL.md
│           ├── careful/SKILL.md
│           ├── design-review/SKILL.md
│           ├── guard/SKILL.md
│           ├── health/SKILL.md
│           ├── investigate/SKILL.md
│           ├── office-hours/SKILL.md
│           ├── plan-ceo-review/SKILL.md
│           ├── plan-eng-review/SKILL.md
│           ├── qa/SKILL.md
│           ├── retro/SKILL.md
│           ├── review/SKILL.md
│           └── scrape/SKILL.md
└── README.md                           # this file
```

This layout matches the convention used by
[github/awesome-copilot](https://github.com/github/awesome-copilot) and
[github/copilot-plugins](https://github.com/github/copilot-plugins):
the marketplace manifest lives at `.github/plugin/marketplace.json` and each
plugin is a subdirectory under `plugins/`.

> Copilot CLI also recognises `.claude-plugin/marketplace.json` as an
> alternate location, per the
> [official docs](https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/plugins-marketplace).
> We use `.github/plugin/` to match the GitHub-curated marketplaces.

## Tool-name mapping (from Claude Code → Copilot CLI)

The skills keep Claude's original tool names (`Bash`, `Read`, `Write`, `Edit`,
`Grep`, `Glob`, `Agent`, `WebSearch`). These are all valid aliases in Copilot
CLI per the
[custom-agents configuration reference](https://docs.github.com/en/copilot/reference/custom-agents-configuration),
so no rewrites were needed except removing `AskUserQuestion` (no Copilot
equivalent).

## Known limitations

1. **Settings.json lock during install** — Copilot CLI holds a lock on
   `~/.copilot/settings.json` while running. Install/update the plugin from a
   terminal where no `copilot` session is active.
2. **Preamble bash blocks are not auto-executed** — Claude Code auto-runs the
   bash block at the top of each `SKILL.md`; Copilot CLI does not. The model
   reads the *"## Preamble (run first)"* section and runs it via the `Bash`
   tool. Functionally equivalent, slightly different ergonomics.
3. **Bash shell on Windows** — preambles use bash. Copilot CLI's `Bash` tool
   on Windows requires Git Bash or WSL on `PATH`.
4. **No `AskUserQuestion` tool** — skills that would have asked structured
   questions now ask in free text.

## License

MIT — see [`plugins/gstack/plugin.json`](plugins/gstack/plugin.json).

## Credits

- Original concept and skills: [Garry Tan](https://github.com/garrytan) — [garrytan/gstack](https://github.com/garrytan/gstack)
- Copilot CLI port: [@aviraldua93](https://github.com/aviraldua93)
