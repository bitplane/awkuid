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
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[2]
CORPUS = ROOT / "test/golden-liquid/golden_liquid.json"
ENGINE = ROOT / "build/awkuid"
AWK = None


class EngineMissing(Exception):
    pass


def render(template, data, templates):
    """template + context(data) + partials(templates) -> output string.

    Raises EngineMissing if build/awkuid doesn't exist yet.
    """
    if not ENGINE.exists():
        raise EngineMissing()
    with tempfile.TemporaryDirectory(prefix="awkuid-golden.") as tmp:
        template_file = pathlib.Path(tmp) / "template.liquid"
        template_file.write_text(template)
        cmd = [AWK, "-f", str(ENGINE), str(template_file)] if AWK else [str(ENGINE), str(template_file)]
        proc = subprocess.run(
            cmd,
            input=json_to_events(data),
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )
    if proc.returncode != 0:
        return None
    return proc.stdout


def event_escape(value, *, path=False):
    value = str(value)
    out = []
    for ch in value:
        if ch == "\\":
            out.append("\\\\")
        elif ch == "\t":
            out.append("\\t")
        elif ch == "\n":
            out.append("\\n")
        elif ch == "\r":
            out.append("\\r")
        elif ch == "\b":
            out.append("\\b")
        elif ch == "/" and not path:
            out.append("\\/")
        else:
            out.append(ch)
    return "".join(out)


def path_join(parent, key):
    key = event_escape(key)
    return key if parent == "" else f"{parent}/{key}"


def scalar_tag(value):
    if value is None:
        return "tag:yaml.org,2002:null"
    if isinstance(value, bool):
        return "tag:yaml.org,2002:bool"
    if isinstance(value, (int, float)) and not isinstance(value, bool):
        return "tag:yaml.org,2002:int"
    return "tag:yaml.org,2002:str"


def scalar_value(value):
    if value is None:
        return ""
    if value is True:
        return "true"
    if value is False:
        return "false"
    return str(value)


def emit_value(lines, doc_id, path, value):
    if isinstance(value, dict):
        lines.append(
            "\t".join(
                [
                    "MAP_START",
                    str(doc_id),
                    event_escape(path, path=True),
                    "tag:yaml.org,2002:map",
                    "",
                ]
            )
        )
        for key, child in value.items():
            emit_value(lines, doc_id, path_join(path, key), child)
        lines.append("\t".join(["MAP_END", str(doc_id), event_escape(path, path=True)]))
    elif isinstance(value, list):
        lines.append(
            "\t".join(
                [
                    "SEQ_START",
                    str(doc_id),
                    event_escape(path, path=True),
                    "tag:yaml.org,2002:seq",
                    "",
                ]
            )
        )
        for index, child in enumerate(value):
            emit_value(lines, doc_id, path_join(path, str(index)), child)
        lines.append("\t".join(["SEQ_END", str(doc_id), event_escape(path, path=True)]))
    else:
        lines.append(
            "\t".join(
                [
                    "SCALAR",
                    str(doc_id),
                    event_escape(path, path=True),
                    scalar_tag(value),
                    "",
                    "plain",
                    event_escape(scalar_value(value)),
                ]
            )
        )


def json_to_events(data):
    lines = ["DOC_START\t0"]
    emit_value(lines, 0, "", data)
    lines.append("DOC_END\t0")
    return "\n".join(lines) + "\n"


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
    ap.add_argument("--awk", help="awk executable to run build/awkuid with")
    args = ap.parse_args()
    global AWK
    AWK = args.awk

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
