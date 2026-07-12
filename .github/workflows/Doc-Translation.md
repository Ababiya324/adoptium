---
description: Watches documentation updates and automatically generates multi-language translations as a pull request, translating only files that changed.
on:
  push:
    branches: [main]
    paths:
      - "README.md"
      - "docs/**/*.md"
      - "!docs/**/*.[a-z][a-z].md"
  workflow_dispatch:
engine:
  id: copilot
  model: gpt-4o
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

Documentation was updated. Generate translations for the documentation files that are new or out of date, then open a single pull request containing only the new or updated translation files. Do NOT re-translate documents whose translations are already current.

## Target languages
Generate one translation per language for each stale source document:
- Spanish — suffix `.es.md`
- French — suffix `.fr.md`
- Japanese — suffix `.ja.md`
- Chinese (Simplified) — suffix `.zh.md`
- German — suffix `.de.md`
- Portuguese (Brazilian) — suffix `.pt.md`
- Korean — suffix `.ko.md`
- Hindi — suffix `.hi.md`
- Arabic — suffix `.ar.md`
- Russian — suffix `.ru.md`
- Italian — suffix `.it.md`

Naming: `README.md` → `README.es.md`, `docs/guide.md` → `docs/guide.es.md`, and so on. Translations live next to their source file.

## Staleness detection (do this with shell commands, not by reading files into context)
Every translation file records the hash of the source it was generated from on its second line: `<!-- source-hash: <hash> -->`.

1. List the source documents: `README.md` at the repository root plus every `.md` file under `docs/` if that directory exists, excluding translations (any file matching `*.<lang>.md` for the suffixes above). The `docs/` directory may not exist — that is normal, and `README.md` is then the only source document. Do NOT conclude there is nothing to translate just because `docs/` is missing.
2. For each source document, compute its hash: `sha256sum <file> | cut -c1-12`.
3. For each of the 11 languages, extract the recorded hash from the existing translation (e.g. `sed -n 2p <translation>`). A (source, language) pair is **stale** if the translation file is missing or its recorded hash differs from the current source hash. A translation that does not exist yet is always stale — for example, if `README.md` exists but `README.es.md` does not, Spanish is stale and must be translated.
4. Build the full list of stale pairs BEFORE translating anything. If the list is empty, stop immediately without opening a pull request.

## Translation process
For each source document with at least one stale language:
1. Read the source file exactly once, then generate all of its stale-language translations from that single read.
2. Do not read existing translation files beyond the hash check above, and do not read source documents that have no stale pairs.
3. Write each translated file in full, starting with these two lines:
   - Line 1: `<!-- AI-generated translation, needs human review -->`
   - Line 2: `<!-- source-hash: <hash> -->` (the current 12-character hash of the source file)

## Translation rules
- Translate titles and all prose into natural, idiomatic language for each target.
- Preserve all Markdown structure exactly: headings, lists, tables, images, badges, links, and anchors.
- Do NOT translate code blocks, inline code, commands, URLs, file paths, or proper nouns / product names.

## Pull request
- Title: `[translation] Update translations for changed documentation`
- Keep the description brief: list each source file translated and the languages generated, plus a one-line note that these are AI-generated translations requiring review by native speakers.

## Constraints
- Create exactly one pull request containing only new or updated translation files.
- Do not modify any source (English) documentation file.
- If nothing is stale, do not open a pull request; end without output.
