## Setup Instructions

1. From the `leveldb` project root, configure and build a static `libleveldb` (e.g. `cmake -B build -DLEVELDB_BUILD_TESTS=OFF && cmake --build build`).

2. Place this `COP290-A3-CHECKER` folder under `leveldb/`.

3. In `COP290-A3-CHECKER/`, the **Makefile** builds `sample` with `LINK_CXX`, which defaults to `CMAKE_CXX_COMPILER` from `../build/CMakeCache.txt` (so it matches your `libleveldb` ABI). Override if needed: `make COP290_CXX=/path/to/g++` or `make HOST_CXX=clang++`. The environment `CXX` (often `c++` → **clang**) is **not** used, because mixing clang and a g++-built `libleveldb` fails to link.

4. `sample` links against `../build/libleveldb.a`. The Makefile lists that archive as a dependency, so after you **rebuild** the library in the repo root, a normal `make` in this directory will **relink** `sample`. If you ever build `sample` by hand, relink after changing `libleveldb`.

## Make targets (quick)

| Command | What it does |
|--------|----------------|
| `make` / `make all` | Build `./sample` |
| `make run` | Single-threaded workload; `diff` `out.txt` to `ans.txt` |
| **`make race`** | **Concurrent stress** — `./sample --race-only` (separate DB; no golden; see below) |
| `make test` or `make check` | **One** `./sample --concurrent` (ST trace, then race, then compaction-overlap test) + `diff` to `ans.txt`; on success, last stdout lines: `ST: OK`, `RACE: OK` (compaction stage is pass/fail only) |
| `make update_golden` | Regenerate `ans.txt` (after intentional trace changes) |
| `make clean` | Remove `sample`, `out.txt` |

## Running the checker

The harness combines a **single-threaded** golden run with **concurrent** stress tests (no golden for those). `make run` covers only the first; `make race` covers only the threaded race; `make test` runs the **full** `--concurrent` sequence (slower than `make run` or `make race` alone).

1. **Single-threaded** — compiles `sample`, runs it, and compares `out.txt` to `ans.txt` (unified diff on failure):

   ```bash
   cd COP290-A3-CHECKER/
   make
   make run
   ```

2. **Concurrent (race) check** — `make race` runs `./sample --race-only`. Many threads call `Put` / `Get` / `Delete` / `Scan` / `DeleteRange` and interleaved `ForceFullCompaction()` on a **separate** database path (`COP290_RACE_DB` or default `/tmp/testdb_race`), so it does not affect `out.txt`. There is no golden: the process exits **0** if every `Status` is `ok` or `NotFound` (where expected). Tune with `COP290_RACE_THREADS` (default 6) and `COP290_RACE_OPS` (default 2500 per thread).

3. **Full check (`make test`)** — `make test` (or `make check`) runs **one** `./sample --concurrent` in order: (1) same single-threaded trace to `out.txt` as `make run`; (2) the race stress on `COP290_RACE_DB` or `/tmp/testdb_race` (same as `make race`); (3) a **compaction-overlap** stress: one thread calls `ForceFullCompaction` while other threads do `Put` / `Get` / `Delete` / `Scan` / `DeleteRange` on `COP290_COMPACTION_DB` or `/tmp/testdb_compaction`. Then `diff out.txt` to `ans.txt`. On success, stdout ends with `ST: OK` and `RACE: OK` (the compaction stage does not add a third line; it fails the process on error). Expect this target to take **much longer** than `make run` or `make race` by itself. Tune the overlap test with `COP290_COMPACTION_PREFILL` (default 30000), `COP290_COMPACTION_WORKERS` (default 4), and `COP290_COMPACTION_OPS` (default 5000 per worker).

4. **Regenerate `ans.txt`** (after you intentionally change trace format or fix behavior):

   ```bash
   make update_golden
   ```

5. `make run` and `make race` run the **single-threaded** and **race** steps **separately** (handy for debugging). `make test` is one `--concurrent` run (ST + race + compaction-overlap) plus the golden diff, so the ST workload is not executed twice.

6. `sample` begins with a **deterministic** prefix: ReadOptions/snapshot, inverted key range → empty `Scan`, `DeleteRange` on an empty range, and it checks every `Status`. The first line of `out.txt` is `protocol=4 …` (bump if you change that prefix, RNG mapping, or the log format). The single-threaded workload uses a portable int sampler (`std::mt19937` plus one `uint32_t` remainder per draw, not `std::uniform_int_distribution`, so `ans.txt` can match across libstdc++ and libc++). The random path uses an in-memory `std::map`; each `Scan` is logged with every `key=>value` in range (not just a size), and after `ForceFullCompaction` every `key1`…`key10000` is checked against the model. Optional: `COP290_DB` for the DB path (default `/tmp/testdb`).
