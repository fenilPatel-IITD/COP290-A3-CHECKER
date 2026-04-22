.PHONY: build app run strong_run clean

BUILD_DIR = ../build
SRC = sample.cpp
OUT = $(BUILD_DIR)/app

CXX = g++-15
CC = gcc-15
CXXFLAGS = -std=c++17 -I../include
LDFLAGS = -L$(BUILD_DIR) -lleveldb -lpthread

build:
	mkdir -p $(BUILD_DIR)
	rm -rf $(BUILD_DIR)/CMakeCache.txt $(BUILD_DIR)/CMakeFiles
	cd $(BUILD_DIR) && cmake -DCMAKE_BUILD_TYPE=Release -DLEVELDB_BUILD_TESTS=OFF -DLEVELDB_BUILD_BENCHMARKS=OFF -DCMAKE_C_STANDARD=17 -DCMAKE_CXX_STANDARD=17 -DCMAKE_C_COMPILER=$(CC) -DCMAKE_CXX_COMPILER=$(CXX) ..
	cd $(BUILD_DIR) && cmake --build . -j

app: build
	$(CXX) $(CXXFLAGS) $(SRC) $(LDFLAGS) -o $(OUT)

run: app
	rm -rf /tmp/testdb
	rm -f compaction_stats.txt
	./$(OUT) out.txt
	@if diff -q ans.txt out.txt >/dev/null; then \
		echo "All tests passed (out.txt matches ans.txt)"; \
	else \
		echo "Wrong answer: out.txt and ans.txt differ"; \
	fi

strong_run: app
	rm -rf /tmp/testdb
	rm -f compaction_stats.txt
	./$(OUT) out.txt
	@ok=1; \
	if diff -q ans.txt out.txt >/dev/null; then \
		echo "Output check passed (out.txt matches ans.txt)"; \
	else \
		echo "Output check failed: out.txt and ans.txt differ"; \
		ok=0; \
	fi; \
	if diff -q compaction_stats_ans.txt compaction_stats.txt >/dev/null; then \
		echo "Compaction stats check passed (compaction_stats.txt matches compaction_stats_ans.txt)"; \
	else \
		echo "Compaction stats check failed: compaction_stats.txt and compaction_stats_ans.txt differ"; \
		ok=0; \
	fi; \
	if [ "$$ok" -eq 1 ]; then \
		echo "All strong tests passed"; \
	else \
		exit 1; \
	fi

clean:
	rm -rf $(BUILD_DIR)