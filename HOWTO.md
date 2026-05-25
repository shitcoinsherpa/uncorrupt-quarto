# UnCorrupt : Quarto extension

A Quarto shortcode that runs `uncorrupt detect` at render time and emits a styled corruption-flag block directly into the rendered document.

## Install (one-time, per Quarto project)

```sh
# Inside a Quarto project root:
quarto add shitcoinsherpa/uncorrupt --branch main
```

This clones the extension into `_extensions/uncorrupt/` in your project.

For local dev (without going through GitHub):
```sh
cp -r packaging/quarto_extension/_extensions/uncorrupt \
   /path/to/your/quarto/project/_extensions/
```

## Prerequisites

```sh
pip install uncorrupt   # or: conda install -c bioconda uncorrupt
```

The shortcode shells out to the `uncorrupt` CLI; the binary must be on PATH at render time.

## Use

In any `.qmd` document:

```qmd
{{< uncorrupt-scan path="data/supp_table_1.xlsx" >}}

{{< uncorrupt-scan path="supplementary/" recursive=true >}}
```

Output appears as a Quarto `callout` block:
- **Green / `callout-tip`** : no corruption found
- **Red / `callout-important`** : one or more high- or mid-confidence flags, with a per-row table

## Render

```sh
quarto render paper.qmd
```

The scan runs automatically. If the CLI isn't installed or produces no output, a `callout-warning` block surfaces the error rather than failing the render.

## Why this exists

The "literate-programming reproducible paper" persona (Quarto / RStudio / Jupyter notebook authors) typically does a final render right before depositing the paper + data. Adding `{{< uncorrupt-scan >}}` to that document is a zero-friction way to validate every supplementary file at the moment it's deposited.

A red callout in the final PDF / HTML is impossible to miss; a green one becomes a small "validation badge" the author can reference in the methods.

## Limits

- Shells out to a subprocess : adds 5-30 s to render time per file (depending on file size and whether the multi-species xref pool needs loading).
- Requires the `uncorrupt` CLI installed on the rendering machine.
- Won't catch corruption introduced AFTER the Quarto render (e.g., if a co-author edits the file in Excel between render and deposit). For that case, use the GitHub Action that runs on every commit.
