#!/usr/bin/env python3
"""Run the vendored golden-liquid suite against build/awkuid.

Dev/CI dependency only (mirrors awkdown's spec runner) -- the shipped engine is
pure awk. golden-liquid is a big JSON corpus with partials and alternate results,
which Python loads trivially.

INTEGRATION CONTRACT -- fill in render() once awkuid's CLI + context format lock:
  - Each case's `data` (arbitrary nested/typed JSON) must reach awkuid as its
    variable context. Current plan: the awkyaml TSV event stream on stdin.
  - `template` is the source; `templates` is a name->source map of partials for
    {% include %}/{% render %} (write to a temp dir, pass via -I).
  - Proposed CLI:  awkuid -I <partials_dir> <template_file>  < <context_events>
Until render() is wired, the harness reports "pending" and stays green so the
fresh repo isn't red from day one.
"""
import argparse
import json
import os
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
CORPUS = ROOT / "test/golden-liquid/golden_liquid.json"
ENGINE = ROOT / "build/awkuid"


class EngineMissing(Exception):
    pass


def render(template, data, templates):
    """template + context(data) + partials(templates) -> output string.

    Raises EngineMissing if build/awkuid doesn't exist yet.
    TODO(codex): wire the awkuid invocation per the contract above.
    """
    if not ENGINE.exists():
        raise EngineMissing()
    raise NotImplementedError("wire awkuid invocation in render()")


def load_cases():
    return json.loads(CORPUS.read_text())["tests"]


def acceptable(case):
    if "results" in case:
        return case["results"]
    if "result" in case:
        return [case["result"]]
    return None  # an `invalid` (expected-error) case


def check(case):
    try:
        out = render(case["template"], case.get("data", {}), case.get("templates", {}))
    except NotImplementedError:
        raise EngineMissing()
    if case.get("invalid"):
        return out is None
    want = acceptable(case)
    return want is not None and out in want


def main():
    ap = argparse.ArgumentParser(description="run golden-liquid against build/awkuid")
    ap.add_argument("--core", help="file of case names that MUST pass (enforced; exit 1 on regression)")
    ap.add_argument("--tag", action="append", default=[], help="only run cases carrying this tag")
    args = ap.parse_args()

    corpus = load_cases()
    cases = corpus
    if args.tag:
        want = set(args.tag)
        cases = [c for c in cases if want & set(c.get("tags", []))]
    core = None
    if args.core and os.path.exists(args.core):
        core = {ln.strip() for ln in open(args.core) if ln.strip() and not ln.startswith("#")}
        cases = [c for c in cases if c["name"] in core]

    passed, failed, failures = 0, 0, []
    try:
        for c in cases:
            if check(c):
                passed += 1
            else:
                failed += 1
                failures.append(c["name"])
    except EngineMissing:
        scope = f"{len(cases)} selected" if (args.tag or core) else f"{len(corpus)} total"
        print(f"golden: engine not built / harness not wired -- {scope} cases pending")
        return 0

    print(f"golden: {passed} passed, {failed} failed ({len(corpus)} in corpus)")
    if core is not None and failed:
        for n in failures[:20]:
            print(f"  FAIL: {n}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
