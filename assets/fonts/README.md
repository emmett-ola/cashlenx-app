# Bundled Chinese Interface Fonts

CashLenX bundles interface-specific subsets of Noto Sans SC and Noto Sans TC so
Flutter Web can render Simplified and Traditional Chinese before showing the
first localized frame. The fonts are licensed under the SIL Open Font License
1.1 in `OFL.txt`.

The current source files come from Google Fonts commit
`bd8f81ddb5c74d5c8897b36ad88b440266245103`:

- `ofl/notosanssc/NotoSansSC[wght].ttf`
- `ofl/notosanstc/NotoSansTC[wght].ttf`

Their source SHA-256 values are:

- Noto Sans SC: `a3041811a78c361b1de50f953c805e0244951c21c5bd412f7232ef0d899af0da`
- Noto Sans TC: `864727d210d54f2537bbe23b3a839436c3992af72de9322af5270897246bd44f`

The current subset SHA-256 values are:

- Noto Sans SC UI: `718f5ab77419b8395651271a811177d533fe15ed810d1e423600b2686c5e2555`
- Noto Sans TC UI: `831916b0a0b0eaa437b2a7a2378107f5325460513f718bc1e720b110f228db6f`

The subset includes Latin text, common punctuation and currency symbols, CJK
punctuation, and every non-Latin code point currently present in `lib/**/*.dart`.
Regenerate both assets after changing localized interface text:

```bash
python3 tool/update_cjk_font_subsets.py \
  --simplified-font /path/to/NotoSansSC.ttf \
  --traditional-font /path/to/NotoSansTC.ttf
```

This subset is for repository-owned interface copy. User-provided text may use
the platform fallback chain for characters outside the manifest.
