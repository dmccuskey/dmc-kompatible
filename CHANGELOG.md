# Changelog

## 1.2.0 (2026-09-30)

The source is now the version DMC-Corona-Library 2.x shipped (1.1.0, for the current boot loader), not the older 1.0.0 this repository held, with these changes.

### Changed

- Gray with alpha works: `( 51, 102 )` is a gray of 51 at alpha 102. The alpha became the green and blue.
- Gradients are translated as a copy, so the same table can be used again (its second use was near black), and their alpha is 0-255 like the other colors; it was passed on untranslated.
- A color name, a malformed color or a wrong argument raises an error at the caller's line, `dmc_kompatible: invalid color ...`. Names printed `ERROR dmc_kolor` and gave white (the named colors were never defined); other mistakes printed an error and failed inside the module.
- Hex strings (`'#RRGGBB'`) and other paints (image, composite) are accepted.
- `setReferencePoint()` accepts Solar2D's own reference point constants, and a number left out keeps its current value; both set the anchor to `nil`. Anything else raises an error.
- Native text fields and boxes get a 0-255 `setTextColor()`; they got a `setFillColor()` that called a method they don't have. Web views get no color method.
- `display.newPolygon()` gets the 0-255 `setFillColor()`; it got only `setStrokeColor()`, and only when `ACTIVATE_FILLCOLOR` was on. `display.newText()`'s `setTextColor()` and `setFillColor()` are the same 0-255 method.
- Lines get a 0-255 `setStrokeColor()`, and Graphics 1.0's `line:setColor()` is the same method. `setColor()` called `setFillColor()`, which lines don't have; and Solar2D ignores setting a line's color methods the usual way, so the module now stores them with `rawset()`.
- A constructor that returns `nil`, such as `display.newImage()` for a missing file, returns `nil`; it raised `attempt to index nil`.
- The `newLine()` warning is printed once, not for every line.
- Config values work without `:BOOL`: `ACTIVATE_REFERENCE = false` was the string `'false'`, which counted as on.
- The module is a callable table with `VERSION`, `display` and `native`; calling it returns the two tables, as before.
- Rebuilt with dmc-corona-boot 1.6.0, with a `Snakefile` and `dmc_corona.cfg`.

### Added

- Unit tests, and `tests/run_unit.sh` to run them with plain Lua 5.1.
- A README with a Quick Start, the API, the settings and how to build.

### Removed

- `native.newText()`: Solar2D has none, so it raised an error.
- The copy of `extend()`, which leaked the global `_extend`, and the other leaked globals (`translateRGBToHDR`, `addSetAnchor`, `addSetFillColor`, `addSetStrokeColor`, `createClosure`, `Display`, `Native`, `t`).

## 1.1.0 (2014)

The version in DMC-Corona-Library 2.x.
