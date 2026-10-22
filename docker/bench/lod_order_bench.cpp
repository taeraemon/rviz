// Times level-of-detail orderings on a KITTI scan and on a large random chunk.
// build: g++ -O2 -std=c++17 lod_order_bench.cpp -o lod_order_bench
#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <numeric>
#include <random>
#include <vector>

struct P { float x, y, z; };

static uint32_t stride(uint32_t n)
{
  if (n < 3) return 1;
  auto s = static_cast<uint32_t>(n * 0.6180339887);
  while (std::gcd(s, n) != 1) ++s;
  return s;
}

static std::vector<uint32_t> byLevel(const std::vector<uint8_t> & level, int levels)
{
  const uint32_t n = level.size();
  std::vector<uint32_t> count(levels + 2, 0);
  for (auto l : level) ++count[l + 1];
  std::partial_sum(count.begin(), count.end(), count.begin());
  std::vector<uint32_t> by(n), next(count.begin(), count.end() - 1), order(n);
  for (uint32_t i = 0; i < n; ++i) by[next[level[i]]++] = i;
  for (int l = 0; l <= levels; ++l) {
    uint32_t b = count[l], sz = count[l + 1] - b, st = stride(sz), idx = 0;
    for (uint32_t k = 0; k < sz; ++k) { order[b + k] = by[b + idx]; idx += st; if (idx >= sz) idx -= sz; }
  }
  return order;
}

// Current implementation: one hash set pass per level.
static std::vector<uint32_t> hashOrder(const std::vector<P> & p)
{
  constexpr int L = 12;
  const uint32_t n = p.size();
  float mn[3] = {1e30f, 1e30f, 1e30f}, mx[3] = {-1e30f, -1e30f, -1e30f};
  for (auto & q : p) { const float c[3] = {q.x, q.y, q.z};
    for (int a = 0; a < 3; ++a) { mn[a] = std::min(mn[a], c[a]); mx[a] = std::max(mx[a], c[a]); } }
  const float ext = std::sqrt((mx[0]-mn[0])*(mx[0]-mn[0]) + (mx[1]-mn[1])*(mx[1]-mn[1]) + (mx[2]-mn[2])*(mx[2]-mn[2]));
  size_t cap = 16; while (cap < 2 * n) cap *= 2;
  std::vector<uint64_t> keys(cap); const size_t mask = cap - 1;
  auto insert = [&](uint64_t k) { size_t s = (k * 0x9E3779B97F4A7C15ull) >> 20 & mask;
    while (keys[s]) { if (keys[s] == k) return false; s = (s + 1) & mask; } keys[s] = k; return true; };
  std::vector<uint8_t> level(n, L);
  for (int l = 0; l < L; ++l) {
    const float inv = static_cast<float>(4 << l) / ext;
    auto key = [&](uint32_t i) { auto c = [](float v) { return (uint64_t) std::min(std::max(v, 0.f), 2097151.f); };
      return (c((p[i].x - mn[0]) * inv) << 42 | c((p[i].y - mn[1]) * inv) << 21 | c((p[i].z - mn[2]) * inv)) + 1; };
    std::fill(keys.begin(), keys.end(), 0);
    for (uint32_t i = 0; i < n; ++i) if (level[i] < l) insert(key(i));
    for (uint32_t i = 0; i < n; ++i) if (level[i] == L && insert(key(i))) level[i] = l;
  }
  return byLevel(level, L);
}

// Morton order: sort by interleaved voxel coordinates, the level of a point is where its code
// first differs from the previous one.
static std::vector<uint32_t> mortonOrder(const std::vector<P> & p)
{
  constexpr int L = 12, kBits = L + 1;  // bits per axis: level l uses its top l + 2 bits
  const uint32_t n = p.size();
  float mn[3] = {1e30f, 1e30f, 1e30f}, mx[3] = {-1e30f, -1e30f, -1e30f};
  for (auto & q : p) { const float c[3] = {q.x, q.y, q.z};
    for (int a = 0; a < 3; ++a) { mn[a] = std::min(mn[a], c[a]); mx[a] = std::max(mx[a], c[a]); } }
  const float ext = std::sqrt((mx[0]-mn[0])*(mx[0]-mn[0]) + (mx[1]-mn[1])*(mx[1]-mn[1]) + (mx[2]-mn[2])*(mx[2]-mn[2]));
  const float scale = (1 << kBits) / ext;
  auto spread = [](uint64_t v) { uint64_t r = 0; for (int b = 0; b < kBits; ++b) r |= ((v >> b) & 1ull) << (3 * b); return r; };
  std::vector<uint64_t> code(n);
  for (uint32_t i = 0; i < n; ++i) {
    auto q = [&](float v, float m) { return (uint64_t) std::min(std::max((v - m) * scale, 0.f), (float) ((1 << kBits) - 1)); };
    code[i] = (spread(q(p[i].x, mn[0])) << 2 | spread(q(p[i].y, mn[1])) << 1 | spread(q(p[i].z, mn[2]))) << 25 | i;
  }
  // LSD radix sort on bits 25..63
  std::vector<uint64_t> tmp(n);
  for (int shift = 25; shift < 64; shift += 8) {
    uint32_t cnt[257] = {0};
    for (auto c : code) ++cnt[((c >> shift) & 255) + 1];
    for (int b = 0; b < 256; ++b) cnt[b + 1] += cnt[b];
    for (auto c : code) tmp[cnt[(c >> shift) & 255]++] = c;
    code.swap(tmp);
  }
  std::vector<uint8_t> level(n, L);
  for (uint32_t k = 0; k < n; ++k) {
    const uint32_t i = code[k] & ((1u << 25) - 1);
    if (k == 0) { level[i] = 0; continue; }
    const uint64_t diff = (code[k] ^ code[k - 1]) >> 25;
    if (!diff) continue;                              // same finest voxel
    const int depth = kBits - 1 - (63 - __builtin_clzll(diff)) / 3;  // 0 = top bit of each axis
    level[i] = static_cast<uint8_t>(std::max(0, depth - 1));
  }
  return byLevel(level, L);
}

int main(int argc, char ** argv)
{
  std::vector<std::vector<P>> sets;
  if (argc > 1) {
    FILE * f = std::fopen(argv[1], "rb"); std::vector<float> d(4 * 200000);
    size_t m = std::fread(d.data(), 16, 200000, f) ; std::fclose(f);
    std::vector<P> s(m); for (size_t i = 0; i < m; ++i) s[i] = {d[4*i], d[4*i+1], d[4*i+2]};
    sets.push_back(s);
  }
  std::mt19937 g(1); std::uniform_real_distribution<float> u(-40, 40);
  std::vector<P> r(368640); for (auto & q : r) q = {u(g), u(g), u(g) * 0.1f}; sets.push_back(r);
  for (auto & s : sets) {
    for (auto fn : {hashOrder, mortonOrder}) {
      auto t0 = std::chrono::steady_clock::now();
      auto o = fn(s);
      double ms = std::chrono::duration<double, std::milli>(std::chrono::steady_clock::now() - t0).count();
      std::vector<uint32_t> c(o); std::sort(c.begin(), c.end());
      bool perm = true; for (uint32_t i = 0; i < c.size(); ++i) perm &= c[i] == i;
      std::printf("%s n=%zu %.1f ms permutation=%d\n", fn == hashOrder ? "hash  " : "morton", s.size(), ms, perm);
    }
  }
}
