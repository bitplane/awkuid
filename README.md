# awkuid

A POSIX-awk implementation of the [Liquid](https://shopify.github.io/liquid/) template
language. Generic: `template + context -> text`. It knows nothing about markdown or
front matter; an orchestrator wires it to other tools.

## Tests

Conformance against the vendored [golden-liquid](https://github.com/jg-rp/golden-liquid)
corpus (`test/golden-liquid/`, MIT).

- `make progress` -- pass rate over the whole corpus.
- `make test` -- enforces the subset in `test/golden/golden-core.txt` (the ratchet).
