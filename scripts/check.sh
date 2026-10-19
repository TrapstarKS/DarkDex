#!/bin/sh
# Validates the sources: formatting, lint, types, offline tests and the bundle build.
set -e
cd "$(dirname "$0")/.."

ROBLOX_TYPES="${LUAU_ROBLOX_TYPES:-$HOME/Library/Application Support/Code/User/globalStorage/johnnymorganz.luau-lsp/globalTypes.RobloxScriptSecurity.d.luau}"

stylua --check src tests
selene src

if [ -f "$ROBLOX_TYPES" ]; then
	luau-lsp analyze --platform=roblox --no-strict-dm-types --formatter=plain \
		--definitions=@roblox="$ROBLOX_TYPES" \
		--definitions=@exploit=types/exploit.d.luau \
		--definitions=@darkdex=types/darkdex.d.luau \
		src
else
	echo "Skipping luau-lsp: Roblox type definitions not found (set LUAU_ROBLOX_TYPES)"
fi

for spec in tests/*.spec.luau; do
	lune run "$spec"
done

darklua process src/init.luau dist/DarkDex.lua --config darklua.json
