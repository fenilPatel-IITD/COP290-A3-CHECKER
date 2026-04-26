
## Setup Instructions

1. From the `leveldb` project root, configure and build a static `libleveldb` (e.g. `cmake -B build -DLEVELDB_BUILD_TESTS=OFF && cmake --build build`).

2. Place this `COP290-A3-CHECKER` folder under `leveldb/`.

3. In `COP290-A3-CHECKER/`, the **Makefile** builds `sample` with `LINK_CXX`, which defaults to `CMAKE_CXX_COMPILER` from `../build/CMakeCache.txt` (so it matches your `libleveldb` ABI). Override if needed: `make COP290_CXX=/path/to/g++` or `make HOST_CXX=clang++`. The environment `CXX` (often `c++` → **clang**) is **not** used, because mixing clang and a g++-built `libleveldb` fails to link.

## Compaction stats logging (in `db_impl.cc`)

Implement this **before** you rely on `make strong`: the strong check reads `compaction_stats.txt` produced by `ForceFullCompaction`.

In `db_impl.cc`, after `ForceFullCompaction` has finished the manual
compaction work, take a snapshot of `stats_` *before* that work (e.g. copy
each `stats_[i]` into `start_stats[i]`) and, with the mutex held again,
build `CompactionStats totals` by **per-level deltas** and `Add` (or
equivalent), so the line reflects work done during this run only. Use the
**real** `CompactionStats` fields: `compactions_executed`, `input_files`, and
`output_files` (not `num_*` names).

Write **`compaction_stats.txt` in the process current working directory** (e.g. run
the checker with `cd COP290-A3-CHECKER/ && make run` so the file is created
beside `out.txt`). A path like `dbname_ + "/compaction_stats.txt"` only
creates a file *inside* the DB directory (e.g. `/tmp/testdb/...` when the DB
path is `/tmp/testdb`), not the `compaction_stats.txt` in this folder. One
line per successful `ForceFullCompaction`, five numbers, semicolon-separated:

```cpp
CompactionStats totals;
for (int i = 0; i < config::kNumLevels; i++) {
  CompactionStats d;
  d.micros = stats_[i].micros - start_stats[i].micros;
  d.bytes_read = stats_[i].bytes_read - start_stats[i].bytes_read;
  d.bytes_written = stats_[i].bytes_written - start_stats[i].bytes_written;
  d.compactions_executed =
      stats_[i].compactions_executed - start_stats[i].compactions_executed;
  d.input_files = stats_[i].input_files - start_stats[i].input_files;
  d.output_files = stats_[i].output_files - start_stats[i].output_files;
  totals.Add(d);
}

const char* stats_path = "compaction_stats.txt";
FILE* stats_file = std::fopen(stats_path, "a");
if (!stats_file) {
  std::fprintf(stderr, "Failed to open stats file: %s\n", stats_path);
  // If your code uses a manual-compaction flag and condition variables,
  // clear them and signal waiters before returning IOError.
  return Status::IOError("Failed to open stats file");
}
char line[128];
int len = std::snprintf(
    line, sizeof(line),
    "%lld; %lld; %lld; %llu; %llu\n",
    static_cast<long long>(totals.compactions_executed),
    static_cast<long long>(totals.input_files),
    static_cast<long long>(totals.output_files),
    static_cast<unsigned long long>(totals.bytes_read),
    static_cast<unsigned long long>(totals.bytes_written));
if (len > 0) {
  std::fwrite(line, 1, static_cast<size_t>(len), stats_file);
  std::fflush(stats_file);
}
std::fclose(stats_file);
```

You need `<cstdio>` (for `FILE`, `fopen`, `fprintf`, etc.); you do **not** need
`<iostream>` for this.

### Bytes vs. portable strong check

Byte read/write totals are still useful for debugging and for the handout, but they are **not portable** across machines and builds. The local checker’s golden `compaction_portable_ans.txt` stores only the first **three** fields per line (compactions, input files, output files). `make strong` still requires each line in `compaction_stats.txt` to have **five** numeric fields (as your `snprintf` writes), but it **diffs only the first three** against the golden.

Use `update_golden` if you **intentionally** change which compactions run or the file-count pattern.

**Do not** run the workload twice in a row without removing `compaction_stats.txt` — the
sample **appends** one line per successful `ForceFullCompaction`, so a second
run would double the lines. The Makefile’s `make run` / `update_golden` remove
that file first.

## Running the checker

4. **Basic check** (compiles `sample`, then compares `out.txt` to `ans.txt`; prints a **unified diff** on failure):

   ```bash
   cd COP290-A3-CHECKER/
   make       # builds ./sample
   make run
   ```

5. **Strong check** (everything in `make run`, plus validation of `compaction_stats.txt` as described above: five fields per line, then **structural** compare to `compaction_portable_ans.txt`). **Byte read / byte write are not compared** to the golden.

   ```bash
   make strong_run
   # or: make strong
   ```

6. **Regenerate golden files** (overwrites `ans.txt` and `compaction_portable_ans.txt`
   from one `./sample --write` run; the portable file stores **three** fields per line
   so byte noise is not in the reference):

   ```bash
   make update_golden
   ```

7. **Concurrent (race) check** — `make race` runs `./sample --race-only` only. Many threads call `Put` / `Get` / `Delete` / `Scan` / `DeleteRange` and **interleaved `ForceFullCompaction()`** on a **separate** database path (`COP290_RACE_DB` or default `/tmp/testdb_race`), so it does not affect `out.txt` or `compaction_stats.txt`. There is no golden: the process exits **0** if every `Status` is `ok` or `NotFound` (where expected). This matches the clarifications: exercise LevelDB’s existing thread safety and write-path serialization, not a custom threading model. Tune with `COP290_RACE_THREADS` (default 6) and `COP290_RACE_OPS` (default 2500 per thread). `make test` / `make check` run **run + strong + race** (single-threaded checks, then the concurrent stress).

8. Optional: `./sample --concurrent` runs the full single-threaded workload **then** the same race block in one invocation (handy for manual runs; `make test` uses `make race` so the ST path is not executed twice).

9. `sample` begins with a **deterministic** prefix (before the seeded random ops): **ReadOptions/snapshot** (`Scan` must match `Get` visibility per clarifications), **inverted key range** → empty `Scan`, `DeleteRange` on an empty range, and it **checks every `Status`** from `Put`/`Get`/`Delete`/`Scan`/`DeleteRange`/`ForceFullCompaction`. The first line of `out.txt` is `protocol=2 …` (bump if you change that prefix or the log format). Optional: `COP290_DB` env to choose the DB path (default `/tmp/testdb`, as in the handout section on cleaning the database directory).

   **Stricter `protocol=2` random path:** an in-memory `std::map` (same bytewise order as LevelDB’s default comparator) tracks the logical `key1`…`key10000` namespace. After every **`Put`**, a **`Get`** must return the new value. Every **`Get`** is checked against the model. After **`Delete`**, **`Get`** must be `NotFound` and the key is removed from the model. After **`DeleteRange`**, the model is updated the same way (half-open range), then **`Get`** on every key that was in range must be `NotFound`. **`Scan`** is compared in full to the model slice, keys must be strictly increasing and every `(k,v)` must match **`Get(k)`**. After **`ForceFullCompaction`**, three random **`Get`** checks compare against the model (compaction does not change logical state). The printed trace and golden **`ans.txt`** are unchanged for a **correct** implementation, except the `protocol=2` header line.
