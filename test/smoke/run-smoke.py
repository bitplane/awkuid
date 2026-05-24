#!/usr/bin/env python3
import argparse
import pathlib
import subprocess
import sys
import tempfile


ROOT = pathlib.Path(__file__).resolve().parents[2]
ENGINE = ROOT / "build/awkuid"

EVENTS = "DOC_START\t0\nMAP_START\t0\t\ttag:yaml.org,2002:map\t\nMAP_END\t0\t\nDOC_END\t0\n"

CASES = [
    ('{{ "hello" | base64_encode }}', "aGVsbG8="),
    ('{{ "Zm9v" | base64_decode }}', "foo"),
    ('{{ "January 1, 2000" | date: "%b %d, %y" }}', "Jan 01, 00"),
    ('{{ "#/! @" | url_encode }}', "%23%2F%21+%40"),
    ('{% if "a>b" > "a" %}yes{% else %}no{% endif %}', "yes"),
    ('A{%- if false -%}\n  no\n{%- else -%}\n  yes\n{%- endif -%}B', "AyesB"),
]


def render(awk, template):
    with tempfile.TemporaryDirectory(prefix="awkuid-smoke.") as tmp:
        path = pathlib.Path(tmp) / "template.liquid"
        path.write_text(template)
        proc = subprocess.run(
            [awk, "-f", str(ENGINE), str(path)],
            input=EVENTS.encode(),
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )
    return proc.returncode, proc.stdout.decode(), proc.stderr.decode()


def render_with_include(awk):
    with tempfile.TemporaryDirectory(prefix="awkuid-smoke.") as tmp:
        root = pathlib.Path(tmp)
        include_dir = root / "includes"
        include_dir.mkdir()
        (include_dir / "card.html.liquid").write_text("{{ include.html }}")
        path = root / "template.liquid"
        path.write_text('{% include card.html html="hello" %}')
        proc = subprocess.run(
            [awk, "-v", f"liquid_template_dir={include_dir}", "-f", str(ENGINE), str(path)],
            input=EVENTS.encode(),
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )
    return proc.returncode, proc.stdout.decode(), proc.stderr.decode()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--awk", default="awk")
    args = parser.parse_args()

    failed = 0
    for template, expected in CASES:
        code, out, err = render(args.awk, template)
        if code != 0 or out != expected:
            failed += 1
            print(f"FAIL smoke: {template}", file=sys.stderr)
            print(f"  expected: {expected!r}", file=sys.stderr)
            print(f"  actual:   {out!r}", file=sys.stderr)
            if err:
                print(err, file=sys.stderr)
    code, out, err = render_with_include(args.awk)
    if code != 0 or out != "hello":
        failed += 1
        print("FAIL smoke: Jekyll-style include args", file=sys.stderr)
        print("  expected: 'hello'", file=sys.stderr)
        print(f"  actual:   {out!r}", file=sys.stderr)
        if err:
            print(err, file=sys.stderr)
    total = len(CASES) + 1
    print(f"smoke: {total - failed} passed, {failed} failed")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
