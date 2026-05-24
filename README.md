# awkuid

A POSIX-awk implementation of the [Liquid](https://shopify.github.io/liquid/) template
language. Generic: `template + context -> text`. It knows nothing about markdown or
front matter; an orchestrator wires it to other tools.

`awkuid` reads an awkyaml-compatible TSV event stream on stdin and a template
file path as its first argument:

```sh
awkuid template.liquid < context.events
```

The current engine is intentionally tiny: it loads context events and renders
basic `{{ variable }}` output expressions. Tags, control flow, includes, and
most filters are still future ratchet work.

## Tests

Conformance against the vendored [golden-liquid](https://github.com/jg-rp/golden-liquid)
corpus (`test/golden-liquid/`, MIT).

- `make progress` -- pass rate over the whole corpus.
- `make test` -- enforces the subset in `test/golden/golden-core.txt` (the ratchet).

The golden runner converts fixture JSON data into awkyaml-compatible events
itself, so awkuid's core tests do not need awkyaml installed.
