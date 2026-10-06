#!/usr/bin/env python
"""Run the GUT suite headless and verify the log's positive signature. Exit 0 green, 2 failures, 3 instrument failure."""
import argparse, os, re, subprocess, sys, pathlib
ROOT = pathlib.Path(__file__).resolve().parent.parent
GODOT = os.environ.get("GODOT_EXE", r"C:\Dev\InfiniteEmpire\GodotExe\Godot_v4.6.2-stable_win64_console.exe")
LOG = ROOT / "build" / "test_log.txt"
BAD = [re.compile(p) for p in (r"SCRIPT ERROR", r"Parse Error", r"^ERROR:", r"does not extend GutTest", r"Failed to load script")]

def run(cmd):
    p = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True, encoding="utf-8", errors="replace")
    return p.returncode, (p.stdout or "") + (p.stderr or "")

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--file"); ap.add_argument("--select"); ap.add_argument("--no-import", action="store_true")
    a = ap.parse_args()
    (ROOT / "build").mkdir(exist_ok=True); (ROOT / "build" / ".gdignore").touch()
    tracked = subprocess.run(["git", "ls-files", "assets/audio/licensed"], cwd=ROOT, capture_output=True, text=True).stdout.strip()
    if tracked:
        print("run_tests: INSTRUMENT FAIL licensed audio is tracked by git:\n" + tracked); return 3
    if not a.no_import:
        code, out = run([GODOT, "--headless", "--path", str(ROOT), "--import"])
        if code != 0 or "Parse Error" in out or "SCRIPT ERROR" in out:
            print(out[-4000:]); print("run_tests: INSTRUMENT FAIL import"); return 3
    gut = [GODOT, "--headless", "--path", str(ROOT), "-s", "addons/gut/gut_cmdln.gd", "-gexit", "-glog=1"]
    gut += [f"-gtest={a.file}"] if a.file else ["-gdir=res://test", "-ginclude_subdirs"]
    if a.select: gut.append(f"-gselect={a.select}")
    code, out = run(gut)
    LOG.write_text(out, encoding="utf-8")
    noise = [re.compile(l.strip()) for l in (ROOT / "tools" / "known_log_noise.txt").read_text().splitlines() if l.strip() and not l.startswith("#")]
    bad_lines = [l for l in out.splitlines() if any(b.search(l) for b in BAD) and not any(n.search(l) for n in noise)]
    m_scripts = re.search(r"^Scripts\s+(\d+)", out, re.M); m_tests = re.search(r"^Tests\s+(\d+)", out, re.M)
    m_pass = re.search(r"^Passing Tests\s+(\d+)", out, re.M); m_fail = re.search(r"^Failing Tests\s+(\d+)", out, re.M)
    m_pend = re.search(r"^Risky/Pending\s+(\d+)", out, re.M)
    scripts = int(m_scripts.group(1)) if m_scripts else 0; tests = int(m_tests.group(1)) if m_tests else 0
    passing = int(m_pass.group(1)) if m_pass else 0; failing = int(m_fail.group(1)) if m_fail else 0
    pending = int(m_pend.group(1)) if m_pend else 0
    print(f"run_tests: Scripts={scripts} Tests={tests} Passing={passing} Failing={failing} Pending={pending} (log: {LOG})")
    if bad_lines:
        print("run_tests: INSTRUMENT FAIL error lines:\n  " + "\n  ".join(bad_lines[:20])); return 3
    if not (m_scripts and m_tests) or tests == 0:
        print("run_tests: INSTRUMENT FAIL no totals / nothing ran"); return 3
    if not a.file and not a.select:
        on_disk = len(list((ROOT / "test").rglob("test_*.gd")))
        if scripts < on_disk:
            print(f"run_tests: INSTRUMENT FAIL {on_disk} test files on disk, GUT ran {scripts} scripts"); return 3
    if failing or pending or code != 0:
        for l in out.splitlines():
            if "[Failed]" in l or "[Pending]" in l or "[Risky]" in l: print("  " + l.strip())
        print("run_tests: RED"); return 2
    print("run_tests: GREEN"); return 0

if __name__ == "__main__":
    sys.exit(main())
