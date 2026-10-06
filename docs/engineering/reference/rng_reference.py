"""Reference implementation of the Foul Fowl keyed RNG (format contract)."""
M = 0xFFFFFFFF
def fnv1a_bytes(data: bytes, h: int = 0x811C9DC5) -> int:
    for b in data:
        h ^= b
        h = (h * 0x01000193) & M
    return h
def hash_ints(values) -> int:
    h = 0x811C9DC5
    for v in values:
        h = fnv1a_bytes((v & 0xFFFFFFFFFFFFFFFF).to_bytes(8, "little"), h)
    return h
def seed_from_string(s: str) -> int:
    return fnv1a_bytes(s.encode("utf-8"))
def splitmix32(x):
    x = (x + 0x9E3779B9) & M
    z = x
    z = ((z ^ (z >> 16)) * 0x85EBCA6B) & M
    z = ((z ^ (z >> 13)) * 0xC2B2AE35) & M
    z = z ^ (z >> 16)
    return x, z
def rotl(x, k): return ((x << k) | (x >> (32 - k))) & M
class Rng:
    def __init__(self, seed32):
        x = seed32 & M
        self.s = []
        for _ in range(4):
            x, z = splitmix32(x)
            self.s.append(z)
        if self.s == [0, 0, 0, 0]:
            self.s[0] = 1
    @staticmethod
    def keyed(seed, turn, stream, a=0, b=0):
        return Rng(hash_ints([seed, turn, stream, a, b]))
    def next_u32(self):
        s0, s1, s2, s3 = self.s
        result = (rotl((s1 * 5) & M, 7) * 9) & M
        t = (s1 << 9) & M
        s2 ^= s0; s3 ^= s1; s1 ^= s2; s0 ^= s3; s2 ^= t; s3 = rotl(s3, 11)
        self.s = [s0, s1, s2, s3]
        return result
    def range_i(self, lo, hi):
        span = hi - lo + 1
        limit = (0x100000000 // span) * span
        while True:
            r = self.next_u32()
            if r < limit:
                return lo + r % span
    def chance_pct(self, p): return self.range_i(0, 99) < p
if __name__ == "__main__":
    print("seed_from_string('FOWL') =", seed_from_string("FOWL"))
    print("seed_from_string('') =", seed_from_string(""))
    print("hash_ints([1,2,3]) =", hash_ints([1, 2, 3]))
    print("hash_ints([-1]) =", hash_ints([-1]))
    r = Rng.keyed(12345, 1, 2, 0, 0)
    print("keyed(12345,1,2,0,0).next_u32 x5 =", [r.next_u32() for _ in range(5)])
    r = Rng.keyed(12345, 1, 2, 0, 0)
    print("keyed(12345,1,2,0,0).range_i(1,6) x10 =", [r.range_i(1, 6) for _ in range(10)])
    r = Rng(0)
    print("Rng(0).next_u32 x3 =", [r.next_u32() for _ in range(3)])
    r = Rng.keyed(seed_from_string("FOWL"), 0, 1, 7, -1)
    print("keyed(FOWL,0,1,7,-1).range_i(0,99) x8 =", [r.range_i(0, 99) for _ in range(8)])
