---
description: Monitors documentation updates and automatically generates multi-language translations as a pull request.
on:
  push:
    branches: [main]
    paths:
      - "README.md"
      - "docs/**/*.md"
  workflow_dispatch:
engine:
  id: copilot

timeout-minutes: 30
permissions:
  contents: read
  pull-requests: read
  copilot-requests: write
network:
  allowed:
    - defaults
safe-outputs:
  create-pull-request:
    title-prefix: "[translation] "
    labels: [translation, documentation]
    draft: true
    max: 1
---

# Multi-Language Documentation Translation

Documentation in this repository was just updated. Identify which documentation files changed and regenerate their translations, then open a single pull request containing all updated translation files.

## Target languages
Generate one translation per language for each changed source document:
- Spanish — suffix `.es.md`
- French — suffix `.fr.md`
- Japanese — suffix `.ja.md`
- Amharic — suffix `.am.md`

Naming: `README.md` → `README.es.md`, `docs/guide.md` → `docs/guide.es.md`, and so on. Translations live next to their source file.

## Process
1. Determine the changed documentation files. If triggered by a push, translate the Markdown files changed in the triggering commits (only `README.md` and files under `docs/`). If triggered manually, translate `README.md` and every Markdown file under `docs/`.
2. Skip files that are themselves translations (any file whose name matches `*.<lang>.md` for the suffixes above).
3. For each source file and each target language, write the full translated file.
4. Open exactly one draft pull request containing all new or updated translation files.

## Translation rules
- The first line of every translated file must be exactly: `<!-- AI-generated translation, needs human review -->`
- Translate titles and all prose into natural, idiomatic language for each target.
- Preserve all Markdown structure exactly: headings, lists, tables, images, badges, links, and anchors.
- Do NOT translate code blocks, inline code, commands, URLs, file paths, or proper nouns / product names.

## Pull request
- Title: `[translation] Update translations for changed documentation`
- The description must list each source file translated, the languages generated, and a note that these are AI-generated translations requiring review by native speakers.

## Constraints
- Create exactly one pull request.
- Do not modify any source (English) documentation file.
- If no eligible documentation files changed, do not open a pull request; end without output.
