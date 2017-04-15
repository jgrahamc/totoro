SRCS := totoro.lua totoro-config.lua init.lua
PORT := /dev/cu.SLAB_USBtoUART 
LUATOOL := ./luatool/luatool.py --port $(PORT)
OBJ := ./obj

.PHONY: check
check: $(addprefix check-,$(SRCS))
check-%: % ; @lua $<

# Upload uploads all the Lua files in SRCS to the ESP8266.  Before
# uploading is strips all unnecessary whitespace and comments from the
# .lua files to save time. The stripped files are stored in the $(OBJ)
# directory and are only recreated as necessary.

.PHONY: upload
upload: $(addprefix $(OBJ)/,$(SRCS))
$(OBJ)/.f:
	@mkdir -p $(dir $@)
	@touch $@
$(OBJ)/%.lua: export LANG=en_US.iso88591
$(OBJ)/%.lua: $(OBJ)/.f %.lua
	@cat $*.lua | sed -e 's/^.*-- TEST_ONLY$$//g' | sed -e 's/^ *--.*$$//g' | sed '/^$$/d; /^\s*$$/d' > $@
	@$(LUATOOL) -f $@

# Used to connect a terminal to the ESP8266 for debugging.

.PHONY: connect
connect: ; miniterm.py

.PHONY: clean
clean: ; @rm -f $(addprefix $(OBJ)/,$(SRCS))