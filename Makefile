ERTS_INCLUDE_DIR ?= $(shell erl -noshell -eval 'io:format("~s", [code:lib_dir(erts, include)]), halt().')
PRIV_DIR := $(MIX_APP_PATH)/priv
PRIV_SO  := $(PRIV_DIR)/stow_nif.so
SRC      := native/zig/stow_nif.zig

all: $(PRIV_SO)
$(PRIV_SO): $(SRC)
	@mkdir -p $(PRIV_DIR)
	zig build-lib -O ReleaseFast -dynamic -fallow-shlib-undefined -lc -femit-bin=$(PRIV_SO) -I $(ERTS_INCLUDE_DIR) -Mroot=$(SRC)
.PHONY: all
