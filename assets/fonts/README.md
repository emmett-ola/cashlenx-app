# Bundled Chinese Fonts

CashLenX bundles complete Noto Sans SC and Noto Sans TC fonts so Flutter Web can
render both repository-owned interface copy and dynamically loaded Chinese text
before showing the first application frame. The fonts are licensed under the
SIL Open Font License 1.1 in `OFL.txt`.

The current source files come from Google Fonts commit
`bd8f81ddb5c74d5c8897b36ad88b440266245103`:

- `ofl/notosanssc/NotoSansSC[wght].ttf`
- `ofl/notosanstc/NotoSansTC[wght].ttf`

Their source SHA-256 values are:

- Noto Sans SC: `a3041811a78c361b1de50f953c805e0244951c21c5bd412f7232ef0d899af0da`
- Noto Sans TC: `864727d210d54f2537bbe23b3a839436c3992af72de9322af5270897246bd44f`

The installed asset SHA-256 values match the pinned source files:

- Noto Sans SC UI: `a3041811a78c361b1de50f953c805e0244951c21c5bd412f7232ef0d899af0da`
- Noto Sans TC UI: `864727d210d54f2537bbe23b3a839436c3992af72de9322af5270897246bd44f`

The `-UI.ttf` filenames are retained for application compatibility, but the
assets are not glyph subsets. Reinstall both assets from the pinned source files
with:

```bash
python3 tool/update_cjk_font_subsets.py \
  --simplified-font /path/to/NotoSansSC.ttf \
  --traditional-font /path/to/NotoSansTC.ttf
```

Do not replace these files with repository-text subsets. Category names,
transaction descriptions, profile data, and future API responses can contain
Chinese characters that are not present in the application source tree.
