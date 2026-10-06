#!/usr/bin/env python
"""Multiprocess soak runner and probe harness for Foul Fowl."""
import argparse
import json
import os
import pathlib
import subprocess
import sys
import threading

ROOT = pathlib.Path(__file__).resolve().parent.parent.parent
GODOT = os.environ.get("GODOT_EXE", r"C:\Dev\InfiniteEmpire\GodotExe\Godot_v4.6.2-stable_win64_console.exe")
BUILD_SOAK = ROOT / "build" / "soak"

DESIGN_SEEDS = {
    "smoke20": 20,
    "standard100": 100,
    "long200": 200,
    "overnight1000": 1000,
}

def run_probes(only=None):
    probes_script = ROOT / "tools" / "soak" / "probes_main.gd"
    if not probes_script.exists():
        print(f"run_soak.py: probes runner not found at {probes_script}")
        return 1

    cmd = [GODOT, "--headless", "--path", str(ROOT), "-s", "tools/soak/probes_main.gd"]
    if only:
        cmd.extend(["--", f"--only={only}"])

    p = subprocess.run(cmd, cwd=ROOT, text=True, encoding="utf-8", errors="replace")
    return p.returncode

def main():
    parser = argparse.ArgumentParser(description="Foul Fowl Soak Runner")
    parser.add_argument("--design", default="smoke20", choices=["smoke20", "standard100", "long200", "overnight1000"])
    parser.add_argument("--procs", type=int, default=min(os.cpu_count() or 4, 8))
    parser.add_argument("--out", default=str(BUILD_SOAK / "report.json"))
    parser.add_argument("--probes", action="store_true", help="Run probes instead of soak")
    parser.add_argument("--only", default=None, help="Comma-separated probe IDs to run")
    args = parser.parse_args()

    if args.probes:
        return run_probes(args.only)

    total_seeds = DESIGN_SEEDS.get(args.design, 20)
    procs = max(1, min(args.procs, total_seeds))

    BUILD_SOAK.mkdir(parents=True, exist_ok=True)

    chunk_size = (total_seeds + procs - 1) // procs
    workers = []
    worker_outputs = []

    print(f"=== Starting Soak Run ({args.design}: {total_seeds} games across {procs} workers) ===")

    for i in range(procs):
        s_start = i * chunk_size
        s_end = min((i + 1) * chunk_size, total_seeds)
        if s_start >= total_seeds:
            break

        out_file = BUILD_SOAK / f"worker_{i}.json"
        worker_outputs.append(out_file)

        cmd = [
            GODOT,
            "--headless",
            "--path", str(ROOT),
            "-s", "tools/soak/soak_main.gd",
            "--",
            f"--seeds={s_start}:{s_end}",
            f"--design={args.design}",
            f"--out={out_file}"
        ]

        proc = subprocess.Popen(
            cmd,
            cwd=ROOT,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            encoding="utf-8",
            errors="replace",
            bufsize=1
        )
        workers.append((proc, i))

    # Stream stdout from all workers
    output_lock = threading.Lock()

    def stream_worker(proc, worker_idx):
        for line in proc.stdout:
            line_str = line.strip()
            if line_str.startswith("SOAK GAME") or "hard_failures" in line_str or "FAIL" in line_str:
                with output_lock:
                    print(f"[Worker {worker_idx}] {line_str}")

    threads = []
    for proc, idx in workers:
        t = threading.Thread(target=stream_worker, args=(proc, idx))
        t.daemon = True
        t.start()
        threads.append(t)

    exit_codes = []
    for proc, idx in workers:
        code = proc.wait()
        exit_codes.append(code)

    for t in threads:
        t.join(timeout=2.0)

    # Collect results
    all_games = []
    for out_file in worker_outputs:
        if out_file.exists():
            try:
                data = json.loads(out_file.read_text(encoding="utf-8"))
                if isinstance(data, list):
                    all_games.extend(data)
            except Exception as e:
                print(f"Error reading {out_file}: {e}")

    total_games = len(all_games)
    if total_games == 0:
        print("SOAK FAIL: No games completed.")
        return 1

    ended_before_cap = 0
    victory_mix = {}
    win_counts = {}
    turns_list = []
    max_turn_ms = 0.0
    all_hard_failures = []

    for g in all_games:
        turns = int(g.get("turn_count", 0))
        turns_list.append(turns)
        v_type = str(g.get("victory_type", "unknown"))
        victory_mix[v_type] = victory_mix.get(v_type, 0) + 1

        if v_type != "called_game" and turns < 200:
            ended_before_cap += 1

        winner = str(g.get("winner", "none"))
        win_counts[winner] = win_counts.get(winner, 0) + 1

        g_max_turn = float(g.get("max_turn_ms", 0.0))
        if g_max_turn > max_turn_ms:
            max_turn_ms = g_max_turn

        hfs = g.get("hard_failures", [])
        if hfs:
            all_hard_failures.extend(hfs)

    turns_list.sort()
    min_turns = turns_list[0] if turns_list else 0
    med_turns = turns_list[len(turns_list) // 2] if turns_list else 0
    avg_turns = sum(turns_list) / max(1, len(turns_list))
    max_turns = turns_list[-1] if turns_list else 0

    summary = {
        "design": args.design,
        "total_games": total_games,
        "ended_before_cap": ended_before_cap,
        "ended_before_cap_pct": (ended_before_cap / total_games) * 100.0,
        "victory_mix": victory_mix,
        "win_counts": win_counts,
        "turns": {
            "min": min_turns,
            "median": med_turns,
            "avg": round(avg_turns, 1),
            "max": max_turns
        },
        "max_turn_ms": round(max_turn_ms, 1),
        "hard_failures_count": len(all_hard_failures),
        "hard_failures": all_hard_failures,
        "games": all_games
    }

    report_path = pathlib.Path(args.out)
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(summary, indent=2), encoding="utf-8")
    (BUILD_SOAK / "soak_summary.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")

    md_report = f"""# Soak Report: {args.design}

- **Total Games**: {total_games}
- **Ended before cap**: {ended_before_cap}/{total_games} ({(ended_before_cap / total_games) * 100.0:.1f}%)
- **Victory Mix**: {json.dumps(victory_mix)}
- **Win Counts**: {json.dumps(win_counts)}
- **Turns**: Min={min_turns}, Median={med_turns}, Avg={avg_turns:.1f}, Max={max_turns}
- **Max Turn Time**: {max_turn_ms:.1f} ms (budget 300 ms native; max allowed 600 ms)
- **Hard Failures**: {len(all_hard_failures)}
"""
    if all_hard_failures:
        md_report += "\n## Hard Failures\n"
        for hf in all_hard_failures:
            md_report += f"- {hf}\n"

    (BUILD_SOAK / "report.md").write_text(md_report, encoding="utf-8")

    print("\n" + "=" * 50)
    print(f"=== SOAK REPORT ({args.design}) ===")
    print(f"Games: {total_games}")
    print(f"Ended before cap: {ended_before_cap}/{total_games} ({(ended_before_cap / total_games) * 100.0:.1f}%)")
    print(f"Victory mix: {victory_mix}")
    print(f"Win counts: {win_counts}")
    print(f"End turns: min={min_turns} med={med_turns} avg={avg_turns:.1f} max={max_turns}")
    print(f"Max turn ms: {max_turn_ms:.1f} ms")
    print(f"Hard failures: {len(all_hard_failures)}")
    print("=" * 50)

    if any(code != 0 for code in exit_codes) or len(all_hard_failures) > 0:
        print(f"SOAK FAIL: {len(all_hard_failures)} hard failures, exit codes={exit_codes}")
        return 1

    print("SOAK PASS: 0 hard failures")
    return 0

if __name__ == "__main__":
    sys.exit(main())
