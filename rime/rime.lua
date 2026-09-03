-- lightWubi86 Lua entrypoint.
--
-- Squirrel loads this file from the Rime user directory. Filters are registered
-- here so schema entries like lua_filter@charset_filter resolve predictably.

charset_filter = require("charset_filter")
code_hint_filter = require("code_hint_filter")
date_translator = require("date_translator")
status_hotkeys = require("status_hotkeys")
right_shift_switch = require("right_shift_switch")
runtime_editor = require("runtime_editor")
runtime_words = require("runtime_words")
