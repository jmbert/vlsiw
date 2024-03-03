
TOPMOD?=testBench
TOPFILE?=testBench
CXX=gcc

VERILATOR?=verilator
NPROC=$(shell nproc)
VFLAGS= -Wall -Wno-fatal --compiler $(CXX) --trace --assert --top $(TOPMOD) -j $(NPROC)


binary:
	$(VERILATOR) --binary $(TOPFILE) $(VFLAGS)
cc:
	$(VERILATOR) --cc $(TOPFILE) $(VFLAGS)
