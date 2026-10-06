"""Reference implementation of the GDD §9.3 range rule (revision 4).

RangeTrack.step in GDScript must match `step` below exactly.
Run: python docs/engineering/reference/range_reference.py --fixture > test/fixtures/range_table.json
"""
import json
import sys


def _want(d, p, s):
    return max(-s, min(s, p - d))


def step(d, p_a, s_a, p_b, s_b):
    if p_a == p_b or s_a == 0 or s_b == 0:
        return max(0, min(12, d + _want(d, p_a, s_a) + _want(d, p_b, s_b)))
    (p_c, s_c), (p_o, s_o) = sorted([(p_a, s_a), (p_b, s_b)])
    if d > p_c:
        if d > p_o:
            gain = s_c + min(s_o, d - p_o)
        else:
            gain = max(1, s_c - min(s_o, 12 - d))
        return max(p_c, d - gain)
    if d == p_c:
        return min(12, d + max(0, min(s_o, p_o - d, 12 - d) - s_c))
    return min(p_c, d + s_c + min(s_o, max(0, p_o - d)))


def project(d0, p_own, s_own, s_enemy):
    """Worst case for the card: the enemy opens at full speed (P = 12)."""
    d, talon, beak = d0, None, None
    for rnd in range(0, 13):
        if talon is None and d <= 7:
            talon = rnd
        if beak is None and d <= 3:
            beak = rnd
        d = step(d, p_own, s_own, 12, s_enemy)
    return {"talon_round": talon if talon is not None else -1,
            "beak_round": beak if beak is not None else -1}


def fixture():
    rows = []
    for p_a in (0, 1, 5, 12):
        for p_b in (0, 1, 5, 12):
            for s_a in range(0, 6):
                for s_b in range(0, 6):
                    for d in range(0, 13):
                        rows.append([d, p_a, s_a, p_b, s_b, step(d, p_a, s_a, p_b, s_b)])
    return {"format": "d,p_a,s_a,p_b,s_b,expected", "rows": rows}


if __name__ == "__main__":
    if "--fixture" in sys.argv:
        print(json.dumps(fixture()))
    else:
        for s_c in range(1, 5):
            print(s_c, [(project(10, 0, s_c, s_o)) for s_o in range(0, 5)])
