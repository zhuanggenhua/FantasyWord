"""Run the Godot SceneTree scripts and preserve the difference between pass and skip."""
from argparse import ArgumentParser
from concurrent.futures import ThreadPoolExecutor
import json
import os
from pathlib import Path
import re
import subprocess
from tempfile import TemporaryDirectory


ROOT = Path(__file__).resolve().parent.parent
EXPECTED_SOURCE_FREE = json.loads(
    (ROOT / "tests/source_free_expectations.json").read_text(encoding="utf-8")
)
INDICATOR = "test_source_player_movement_indicator.gd"
INDICATOR_MISSING = "需要私有锁定的 SPS_GUI.png；未运行场景。"
ERROR = re.compile(r"(?im)(?:^|\s)(?:SCRIPT ERROR:|ERROR:|FAIL(?:ED)?\b|Assertion failed)")
ZERO = re.compile(r"(?:^|[^0-9])0/0(?:$|[^0-9])")
CUSTOM_MARKERS = {
    "test_equipment_workbench_demo.gd": r"EquipmentSystemDemo：([1-9]\d*)/\1；\w+",
    "test_flamethrower_timeline.gd": r"喷火时间轴：([1-9]\d*)/\1",
    "test_singleton_transit_steering.gd": r"FantasyWord singleton Transit: ([1-9]\d*)/\1",
    "test_terrain_surface_presentation.gd": r"terrain_surface_presentation: [1-9]\d* checks, 0 failures",
    "test_workbench_mount_validation.gd": r"战马无装备直显：([1-9]\d*)/\1；\w+",
}


def classify(suite, code, output, source_free):
    if ERROR.search(output):
        return "FAIL"
    lines = [line.strip() for line in output.splitlines() if line.strip()]
    # This older probe reports its missing authorized asset using exit 2.
    if (
        source_free
        and suite == INDICATOR
        and code == 2
        and [line for line in lines if not line.startswith("Godot Engine ")]
        == [INDICATOR_MISSING]
    ):
        return "SKIP"
    if code != 0:
        return "FAIL"

    expected = EXPECTED_SOURCE_FREE.get(suite, [])
    skips = [line for line in lines if line.startswith("SKIP") or line in expected]
    markers = [line for line in lines if re.match(r"^PASS\s", line)]
    positive = any(not ZERO.search(line) for line in markers)
    custom = CUSTOM_MARKERS.get(suite)
    if custom is not None:
        positive |= any(re.fullmatch(custom, line) is not None for line in lines)

    if skips:
        if not source_free or sorted(skips) != sorted(expected):
            return "FAIL"
        if suite == "test_flamethrower_cue_visual.gd":
            return "PARTIAL"  # The missing-resource rejection is exercised.
        return "PARTIAL" if positive else "SKIP"

    return "PASS" if positive else "FAIL"


def run_suite(suite, source_free):
    env = os.environ.copy()
    if source_free:
        for name in list(env):
            if name.startswith(("FORMAL_", "CLICKMOVE", "FANTASYWORD_")):
                del env[name]
    with TemporaryDirectory(prefix="godot-suite-") as temp_dir:
        for key, subdir in {
            "HOME": "home",
            "XDG_DATA_HOME": "data",
            "XDG_CONFIG_HOME": "config",
            "XDG_CACHE_HOME": "cache",
        }.items():
            path = Path(temp_dir) / subdir
            path.mkdir()
            env[key] = str(path)
        try:
            result = subprocess.run(
                [env.get("GODOT", "godot"), "--headless", "--path", str(ROOT),
                 "--script", f"res://tests/{suite}"],
                env=env,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                encoding="utf-8",
                errors="replace",
                timeout=45,
                check=False,
            )
            output = result.stdout
            code = result.returncode
        except subprocess.TimeoutExpired as error:
            output = (error.stdout or b"").decode("utf-8", "replace") + "\nSuite timed out.\n"
            code = 124
        except OSError as error:
            output, code = str(error), 127
    return classify(suite, code, output, source_free), code, output


def main():
    parser = ArgumentParser()
    parser.add_argument("--source-free", action="store_true", help="strip original-asset inputs; report only documented asset skips")
    parser.add_argument("--jobs", type=int, default=1)
    args = parser.parse_args()
    if not 1 <= args.jobs <= 8:
        parser.error("--jobs must be in 1..8")
    suites = sorted(path.name for path in (ROOT / "tests").glob("test_*.gd"))
    if not suites:
        parser.error("no Godot suites found")
    results = {key: 0 for key in ("PASS", "PARTIAL", "SKIP", "FAIL")}
    with ThreadPoolExecutor(max_workers=args.jobs) as pool:
        submitted = pool.map(lambda suite: run_suite(suite, args.source_free), suites)
        for suite, (status, code, output) in zip(suites, submitted):
            print(f"== {suite} ==")
            print(output, end="" if output.endswith("\n") else "\n")
            print(f"RESULT {status} {suite} (exit {code})", flush=True)
            results[status] += 1
    print(f"SUMMARY total={len(suites)} " + " ".join(f"{key}={value}" for key, value in results.items()))
    return int(results["FAIL"] > 0)


if __name__ == "__main__":
    raise SystemExit(main())
