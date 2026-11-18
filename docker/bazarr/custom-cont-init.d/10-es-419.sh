#!/bin/sh
# Make Bazarr write/read Latin American Spanish subtitles as ".es-419" instead of ".es-MX".
# Jellyfin only recognises "es-419" (its language table has no es-MX); Bazarr only knows es-MX/es-la/lat/spl.
# Runs on every container start (linuxserver custom-cont-init.d), so it survives image updates.
B=/app/bazarr/bin

# 1) Latin American Spanish: write ".es-419" and recognise it (plus .forced / .hi / .cc / .sdh variants)
F=$B/bazarr/languages/custom_lang.py
if [ ! -f "$F" ]; then echo "[es-419] $F not found, skipping"
elif grep -q 'language = "es-419"' "$F"; then echo "[es-419] custom_lang already patched"
else
  sed -i '/^class LatinAmericanSpanish/,/^class /{
s/language = "es-MX"/language = "es-419"/
s/_extensions = (/_extensions = (".es-419", /
s/_extensions_forced = (/_extensions_forced = (".es-419.forced", /
s/_extensions_hi = (/_extensions_hi = (".es-419.hi", ".es-419.cc", ".es-419.sdh", /
}' "$F"
  grep -q 'language = "es-419"' "$F" && echo "[es-419] custom_lang patched" || echo "[es-419] custom_lang patch FAILED"
fi

# 2) Let the subtitle-to-video filename matcher accept numeric region codes (es-419), not only letters (es-MX)
L=$B/custom_libs/subzero/language.py
OLD='ENDSWITH_LANGUAGECODE_RE = re.compile(r"\.([^-.]{2,3})(?:-[A-Za-z]{2,})?$")'
NEW='ENDSWITH_LANGUAGECODE_RE = re.compile(r"\.([^-.]{2,3})(?:-[A-Za-z0-9]{2,})?$")'
if [ ! -f "$L" ]; then echo "[es-419] $L not found, skipping"
elif grep -qF "$NEW" "$L"; then echo "[es-419] matcher already patched"
elif grep -qF "$OLD" "$L"; then
  sed -i 's/(?:-\[A-Za-z\]{2,})?\$")/(?:-[A-Za-z0-9]{2,})?$")/' "$L"
  grep -qF "$NEW" "$L" && echo "[es-419] matcher patched" || echo "[es-419] matcher patch FAILED"
else echo "[es-419] matcher line changed upstream, not patching"
fi
