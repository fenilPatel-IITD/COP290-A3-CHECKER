
## Setup Instructions

1. Clone this repository inside the `leveldb` directory.
2. Navigate to the project folder:

   ```bash
   cd COP290-A3-CHECKER/
   ```

3. Build and run basic check (compares only `out.txt` with `ans.txt`):

   ```bash
   make run
   ```

4. Build and run strong check (compares both `out.txt` vs `ans.txt`, and
   `compaction_stats.txt` vs `compaction_stats_ans.txt`):

   ```bash
   make strong_run
   ```

## Compaction Stats Logging

In `db_impl.cc`, you can create a variable `totals` that contains the
aggregate compaction stats (for example by summing per-level stats). After
that, append the following code to write one stats line into
`compaction_stats.txt`:

```cpp
//Say s is status
FILE* stats_file = std::fopen("compaction_stats.txt", "a");
if (!stats_file) return s;
char line[128];
int len = std::snprintf(
    line, sizeof(line),
    "%d; %d; %d; %llu; %llu\n",
    static_cast<int>(totals.num_compactions),
    static_cast<int>(totals.num_input_files),
    static_cast<int>(totals.num_output_files),
    static_cast<unsigned long long>(totals.bytes_read),
    static_cast<unsigned long long>(totals.bytes_written)
);

if (len > 0) {
    std::fwrite(line, 1, static_cast<size_t>(len), stats_file);
    std::fflush(stats_file);
}

std::fclose(stats_file);
```

