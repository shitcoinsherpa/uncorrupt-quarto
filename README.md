# uncorrupt-quarto

Quarto extension that scans the spreadsheets attached to a reproducible report for Excel-mangled gene names, at render time.

Excel keeps turning your gene names into dates (`SEPT2` becomes `2-Sep`). If you cite a supplementary table from inside a Quarto document, this extension scans it during `quarto render` and embeds the corruption report inline. The report fails the render if anything was caught at high confidence, so a paper with a corrupted supplement never makes it past your own build.

## Install

```bash
quarto add shitcoinsherpa/uncorrupt-quarto
```

You also need the Python CLI on PATH (one-time, any environment):

```bash
pip install uncorrupt
```

## Use

In your `.qmd` document:

```markdown
## Supplementary Table 1

{{< uncorrupt-scan data/supp_table_1.xlsx >}}
```

When you `quarto render`, the shortcode runs `uncorrupt detect` on the file and inserts the report at that spot in the document. If anything is flagged at high confidence the build fails, so you cannot ship a paper with corrupted gene names by accident.

## See also

- [`shitcoinsherpa/UnCorrupt`](https://github.com/shitcoinsherpa/UnCorrupt) : the Python package, CLI, and Gradio UI
- [`example.qmd`](example.qmd) in this repository : a working end-to-end example

## License

Apache-2.0.
