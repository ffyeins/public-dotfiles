# IntelliJ IDEA 2026.1 — Islands Dark

## Terminal & Editor Color Scheme Reference

*Extracted from Islands Dark.icls (parent: Darcula) and verified against live terminal output.*

---

## Terminal ANSI Color Palette

The 16 standard ANSI colors as rendered by the Islands Dark scheme. Background (BG) values are the stored palette colors. Foreground (FG) values are what the terminal renders for text, adjusted by the contrast ratio setting (default 4.5:1 against the terminal background).

| ANSI | Name           | BG Hex    | FG Hex    |
|------|----------------|-----------|-----------|
| 0    | Black          | `#1E1F22` | `#000000` |
| 1    | Red            | `#AC484E` | `#E27B83` |
| 2    | Green          | `#468531` | `#83CA6F` |
| 3    | Yellow         | `#9D6C23` | `#DDCF7D` |
| 4    | Blue           | `#254DB8` | `#6492F3` |
| 5    | Magenta        | `#7B3ED8` | `#B994F4` |
| 6    | Cyan           | `#3A8376` | `#6FC9BD` |
| 7    | White          | `#CED0D5` | `#CED0D5` |
| 8    | Bright Black   | `#4F5156` | `#8C8E93` |
| 9    | Bright Red     | `#EB565F` | `#ED747D` |
| 10   | Bright Green   | `#79E257` | `#92FC71` |
| 11   | Bright Yellow  | `#F5C242` | `#FCED53` |
| 12   | Bright Blue    | `#52ACF8` | `#5297F8` |
| 13   | Bright Magenta | `#A85EF6` | `#CB76F8` |
| 14   | Bright Cyan    | `#6DE2CF` | `#81FBE9` |
| 15   | Bright White   | `#FFFFFF` | `#FFFFFF` |

## Console Output Colors

Colors for console I/O streams, defined in the Islands Dark .icls file.

| Element              | Hex       |
|----------------------|-----------|
| Console Background   | `#191A1C` |
| Console Normal Output| `#BCBEC4` |
| Console System Output| `#BCBEC4` |
| Console Error Output | `#F75464` |
| Console User Input   | `#6AAB73` |

## Editor Base Colors

Foundational editor colors for text, background, caret, and gutter.

| Element            | Hex       |
|--------------------|-----------|
| Text Foreground    | `#BCBEC4` |
| Text Background    | `#191A1C` |
| Caret              | `#CED0D6` |
| Caret Row          | `#1F2024` |
| Line Numbers       | `#4B5059` |
| Active Line Number | `#A1A3AB` |

## Syntax Highlighting

Token colors for code highlighting in the editor.

| Token              | Hex       |
|--------------------|-----------|
| Keyword            | `#CF8E6D` |
| String             | `#6AAB73` |
| Number             | `#2AACB8` |
| Comment            | `#7A7E85` |
| Doc Comment        | `#5F826B` |
| Function Declaration | `#56A8F5` |
| Instance Method    | `#57AAF7` |
| Static Method      | `#C77DBA` |
| Instance Field     | `#C77DBB` |
| Constant           | `#C77DBB` |
| Metadata/Annotation| `#B3AE60` |
| Identifier         | `#BCBEC4` |
| Type Parameter     | `#16BAAC` |
| Template Variable  | `#B189F5` |
| Valid String Escape | `#CF8E6D` |
| HTML/XML Tag       | `#D5B778` |
| Custom Tag         | `#2FBAA3` |

## Diagnostics & Errors

Colors used for error/warning indicators, underlines, and error stripes.

| Element          | Hex       |
|------------------|-----------|
| Error Underline  | `#FA6675` |
| Error Stripe     | `#D64D5B` |
| Warning Underline| `#F2C55C` |
| Warning Stripe   | `#C29E4A` |
| Typo             | `#7EC482` |
| Bad Character    | `#F75464` |

## Version Control

Gutter and file status colors for version control integration.

| Element        | Hex       |
|----------------|-----------|
| Added Lines    | `#549159` |
| Modified Lines | `#375FAD` |
| Deleted Lines  | `#868A91` |
| File Added     | `#73BD79` |
| File Modified  | `#70AEFF` |
| File Deleted   | `#6F737A` |
| File Conflict  | `#DE6A66` |
| File Unknown   | `#E88F89` |
| File Ignored   | `#D69A6B` |
| File Merged    | `#CF84CF` |

## Notes

- **Scheme file:** `Islands Dark.icls` (parent_scheme="Darcula", version 142)
- **IDE version:** IntelliJ IDEA 2026.1 (ideVersion 2025.3.0.0)
- **Terminal engine:** Reworked 2025 with contrast adjustment enabled (ratio 4.5:1)
- **ANSI palette source:** The ANSI colors are NOT inherited from Darcula. Islands Dark defines its own palette, hardcoded in the IntelliJ platform JAR. Values were extracted from a live terminal screenshot.
- **Contrast adjustment:** When ANSI colors are used as foreground text, the terminal engine automatically lightens them to maintain a 4.5:1 contrast ratio against the `#191A1C` background. This is why foreground and background hex values differ for the same ANSI slot. Disabling contrast adjustment (setting ratio to 1) would make foreground values match the background values.
