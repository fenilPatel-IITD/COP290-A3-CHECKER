# Local harness. Build libleveldb first, from repo root:
#   cmake -B build -DLEVELDB_BUILD_TESTS=OFF -DLEVELDB_BUILD_BENCHMARKS=OFF -DLEVELDB_INSTALL=OFF
#   cmake --build build -j
# (If you have a full checkout with submodules, `cmake -B build && cmake --build build -j` is enough.)
# Compiler must match the library. Override: make COP290_CXX=...  or  HOST_CXX=...
BUILD_DIR       ?= ../build
LEVELDB_LIB_DIR ?= $(BUILD_DIR)
LEVELDB_INCLUDE ?= ../include
SAMPLE          ?= sample

CMAKE_CXX := $(shell [ -f $(BUILD_DIR)/CMakeCache.txt ] && sed -n 's/^CMAKE_CXX_COMPILER:[A-Z]*=//p' $(BUILD_DIR)/CMakeCache.txt | head -1)
# Priority: COP290_CXX > HOST_CXX > CMakeCache > g++
LINK_CXX  := $(if $(strip $(COP290_CXX)),$(COP290_CXX),$(if $(strip $(HOST_CXX)),$(HOST_CXX),$(or $(strip $(CMAKE_CXX)),g++)))

CXXFLAGS += -std=c++17 -fno-exceptions -fno-rtti -I$(LEVELDB_INCLUDE) -I$(BUILD_DIR)/include
LDFLAGS  += -L$(LEVELDB_LIB_DIR) -lleveldb -lpthread

.PHONY: all clean run race test check update_golden help

all: $(SAMPLE)

$(SAMPLE): sample.cpp $(LEVELDB_LIB_DIR)/libleveldb.a
	$(LINK_CXX) $(CXXFLAGS) sample.cpp -o $(SAMPLE) $(LDFLAGS)

help:
	@echo "all run race test(=check) update_golden clean  |  test = one sample --concurrent + diff; BUILD_DIR  COP290_CXX  HOST_CXX  COP290_DB  COP290_RACE_*  — see README"

clean:
	rm -f out.txt $(SAMPLE) sample.o

# Golden diff (see README for COP290_DB, protocol line, etc.)
run: $(SAMPLE) ans.txt
	rm -f out.txt
	@if [ -n "$$COP290_DB" ]; then rm -rf "$$COP290_DB"; else rm -rf /tmp/testdb; fi
	./$(SAMPLE)
	@diff -u ans.txt out.txt && echo "OK" || (echo "FAIL: diff above"; false)

# Concurrent stress; separate DB, no golden (COP290_RACE_DB, COP290_RACE_THREADS, COP290_RACE_OPS)
race: $(SAMPLE)
	@if [ -n "$$COP290_RACE_DB" ]; then rm -rf "$$COP290_RACE_DB"; else rm -rf /tmp/testdb_race; fi
	./$(SAMPLE) --race-only

# One process: ST (out.txt) + RACE; then golden diff. Ends with `ST: OK` / `RACE: OK`.
test: $(SAMPLE) ans.txt
	rm -f out.txt
	@if [ -n "$$COP290_DB" ]; then rm -rf "$$COP290_DB"; else rm -rf /tmp/testdb; fi
	@if [ -n "$$COP290_RACE_DB" ]; then rm -rf "$$COP290_RACE_DB"; else rm -rf /tmp/testdb_race; fi
	./$(SAMPLE) --concurrent
	@diff -u ans.txt out.txt && echo "OK" || (echo "FAIL: diff above"; false)
check: test

update_golden: $(SAMPLE)
	rm -f out.txt ans.txt
	@if [ -z "$$COP290_DB" ]; then rm -rf /tmp/testdb; else rm -rf "$$COP290_DB"; fi
	./$(SAMPLE) --write
	@echo "Wrote ans.txt"
