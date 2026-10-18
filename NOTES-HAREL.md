# NOTES-HAREL.md — סיכום היכרות עם FilmCraft

> נכתב ב־2026-10-14 על ידי Claude (סשן קריאה בלבד, ללא בילד), עודכן ב־2026-10-16 (ראה §8). מטרת הקובץ: שבשיחה הבאה, על המק, נמשיך מכאן בלי לחקור הכול מחדש.
> הקובץ חי בברנץ' `harel-custom` בלבד. `main` של ה־fork נשאר נקי ומסונכרן עם `storytold/filmcraft`.

## 0. הקשר ומצב הריפו

- **מי אני (הראל):** עורך וידאו מקצועי לשעבר (Premiere / After Effects). היום עובד עם Claude Code על פרויקטים שלי.
- **המטרה:** להחליף את Premiere Pro לעריכות פשוטות: חיתוך קליפים, מעברים, כותרות/טקסט, מוזיקה, תיקון צבע בסיסי, ייצוא MP4 לרשתות חברתיות. בהמשך: התאמות אישיות לתוכנה.
- **המחשב:** MacBook Pro, Apple Silicon, 96 GB RAM.
- **הריפו:** `harelsalman1990-dotcom/filmcraft` הוא fork של `storytold/filmcraft`.
  - 2026-10-18: `main` של ה־fork סונכרן (fast-forward בלבד) ל־`main` של המקור, commit `48088e3` מ־18.10.2026. הוא כולל את גרסה **v0.9.0** (tag מ־17.10 בערב, שעון ארה"ב) ועוד ~25 PRs שמוזגו ב־18.10 אחריה. היסטוריה: ב־14.10 עמד על `cee1feb` (= v0.8.0 בלי העלאת גרסה), ב־16.10 על `c2f6587`.
  - ברנץ' עבודה שלי: `harel-custom` (עבר rebase על `main` העדכני ב־18.10). כל שינוי אישי הולך לכאן, לא ל־`main`.
  - כדי לסנכרן בעתיד: `git fetch https://github.com/storytold/filmcraft main && git checkout main && git merge --ff-only FETCH_HEAD && git push origin main`, ואז `git checkout harel-custom && git merge main`.
- **הפרויקט:** NLE בקוד פתוח (MIT OR Apache-2.0), Rust טהור, clean-room (בלי FFmpeg בתוך המוצר, הקודקים נכתבו מהתקנים). גרסה 0.9.0 (18.10.2026), שלב **alpha**. המתחזקים מעריכים "~56% מוכן לעבודה אמיתית" ו"~60% למשתמש essentials" (ייבוא, חיתוך, כותרת, מוזיקה, ייצוא). מאות issues פתוחים (506 נכון להיום), הפרויקט זז מהר מאוד (~75 PRs ביום בשיא).

## 1. מבנה הפרויקט בפשטות

Cargo workspace עם ~45 crates בשכבות (L0 למטה, L6 למעלה). חוק זהב: שכבה נמוכה לא תלויה בשכבה גבוהה, ושום דבר מתחת ל־UI לא מכיר egui/חלונות. `cargo xtask layers` בודק את זה.

### שכבות, מלמטה למעלה

| שכבה | crates | מה זה עושה |
|---|---|---|
| L0 קודקים ומכולות | `h264`, `h264enc`, `hevc`, `prores`, `aac`, `opus`, `vp8`, `vp9`, `av1`, `dnx`, `apv`, `dng`, `ac3`, `mpa`, `mpeg2v`; מכולות: `isobmff` (MP4/MOV), `matroska` (MKV/WebM), `avi`, `mxf`, `mpegts`, `ogg`, `cfb` | פענוח (וחלקם קידוד) של וידאו/אודיו ישירות מהביטים. כולם תלויים רק ב־`bitstream`. |
| L0 יסודות | `time`, `geom`, `color`, `bitstream`, `testkit` | `time::Tick` הוא היחידה לכל זמן (254,016,000,000 טיקים לשנייה, מתחלק בכל קצב פריימים ודגימה). אין שניות כ־f64 בחישובי עריכה. |
| L1 | `frame`, `media`, `project`, `audio-dsp`, `text` | `frame` = פריים וידאו/באפר אודיו. `media` = פתיחת מקורות ומטמון פריימים. **`project` = מודל הנתונים של הפרויקט** (ראה "איפה יושב ה־timeline"). `audio-dsp` = אפקטי אודיו ומדידת loudness. `text` = מנוע הטקסט לכותרות (ראה §4). |
| L2 | `edit`, `codecs`, `interchange`, `captions`, `speech`, `tts`, `tts-text` | `edit` = האלגברה הטהורה של עריכה (insert, overwrite, razor, ripple, roll, slip, slide…). `codecs` = הרכזת: demux + decode, חיפוש לפי GOP, רישום decoders. `interchange` = EDL / FCP7 XML / FCPXML / OTIO / AAF / OMF. |
| L3 | `render`, `gpu`, `export`, `scopes` | `render` = הקומפוזיטור ב־CPU (הרפרנס), אפקטים, מעברים, מיקס אודיו. `gpu` = קומפוזיטור wgpu (Metal במק). **`export` = צינור הייצוא** (render → encode → mux, presets, jobs). `scopes` = waveform/vectorscope. |
| L4 | `engine` | `Session`, **רישום הפקודות** (650+ פקודות), undo, jobs ברקע, media pool, autosave, הגדרות. |
| L5 | `ui-egui`, `automation`, `platform` | `ui-egui` = **כל ממשק המשתמש** (egui). `automation` = שרת MCP. `platform` = ה־crate היחיד עם `unsafe`: VideoToolbox (פענוח/קידוד חומרה במק), Media Foundation, VA-API, NVDEC/NVENC. |
| L6 | `apps/filmcraft`, `apps/filmcraft-cli`, `apps/filmcraft-web` | האפליקציה לדסקטופ (חלון, אודיו דרך cpal, תפריט macOS, שרת control על TCP), ה־CLI (כולל `mcp`), וגרסת הדפדפן (WASM). |

### עקרונות שחשוב להכיר לפני שנוגעים בקוד

1. **הכול פקודה.** כל פעולה (תפריט, כפתור, slider) היא `CommandSpec` עם id יציב (`sequence.addEdit`, `timeline.place`, `file.exportMedia`…), תווית, מיקום בתפריט, קיצור, פרמטרים, `enabled()` ו־`run()`. UI, CLI, control channel ו־MCP כולם מפעילים את אותן פקודות. הרשימה: `crates/engine/src/commands.rs`.
2. **Undo = snapshots.** הפרויקט הוא `Arc<Project>`; כל עריכה משכפלת (copy-on-write) ודוחפת את הישן למחסנית (200 צעדים).
3. **Never crash.** אסור `unwrap`/`expect`/`panic!` בקוד ייצור. כל מספר שמגיע מקובץ מדיה או פרמטר נחשב "עוין". `AGENTS.md` §0.
4. **אסור נכסים של Adobe** (אייקונים, LUTs, presets, פונטים) ואסור קוד GPL (FFmpeg וכו'). ffmpeg משמש רק כ־oracle בטסטים.
5. **פונטים** נוספים (יפנית/סינית/ערבית) חיים בריפו נפרד `storytold/craft-fonts`, לא כאן.

### איפה יושב ה־timeline

- **הנתונים:** `crates/project` — `Project` → `Sequence` → `Track` (video/audio) → `TrackItem` (קליפ: `item`, `start`, `source_in`, `duration`, `speed`, `effects`) → `EffectInstance` (פרמטרים/keyframes). `Transition` יושב ברשימת ה־track. `Sequence::check()` מאמת שאין חפיפות.
- **הלוגיקה:** `crates/edit` — פונקציות טהורות על `&mut Sequence` (razor, ripple, roll, slip, slide, nest, paste…), עם טסטי property.
- **הפקודות:** `crates/engine/src/commands.rs` — `timeline.*`, `sequence.*`, `clip.*`, `markers.*`, `edit.undo` וכו'.
- **הציור והאינטראקציה:** `crates/ui-egui/src/panels/timeline.rs` (+ `timeline_hit.rs`, `timeline_captions.rs`, `timeline_automation.rs`, `timeline_volume.rs`, `trim_monitor.rs`, `tools.rs`).

### איפה יושב הייצוא

- **הצינור:** `crates/export/src/pipeline.rs` (render → encode → mux), `job.rs` (עבודת רקע, progress, cancel), `settings.rs` (כל הגדרות הייצוא), `presets.rs` (24 presets מובנים, כולל `"YouTube 1080p Full HD"`, `"Vimeo…"`, ו־`"Social Vertical 1080×1920"` ל־9:16).
- **המקודדים:** `crates/h264enc` (H.264 שלנו: High/Main/Baseline, CABAC, B-frames, CRF/CBR/VBR/2-pass), `crates/aac` (AAC-LC), `crates/prores`, `crates/dnx`. המכולה: `crates/isobmff` (MP4/MOV).
- **קידוד חומרה במק:** `crates/platform/src/videotoolbox_encode.rs` — H.264 (opt-in, Export ▸ Hardware encoding) ו־H.265/HEVC 8-bit SDR (זה **המקודד ה־HEVC היחיד** במק; אין HEVC בתוכנה). HDR Main 10 ב־VideoToolbox עדיין לא.
- **הממשק:** `crates/ui-egui/src/panels/export_mode.rs`. פקודות: `file.exportMedia`, `export.queue.*`, `export.presets.*`. CLI: `filmcraft-cli --project p.fcproj export out.mp4`.

### איפה יושב ממשק המשתמש

- `crates/ui-egui/src/` — `dock.rs` (פאנלים ו־workspaces), `menus.rs` (תפריטים ופקודות UI-only), `theme.rs` (פונטים, צבעים), `state.rs` (מצב UI, serde כדי שסוכן יוכל לקרוא/לכתוב), `i18n/` (תרגומים: es, ja, zh-cn, fr, pt-br, id, it, ko, de, ru, uk — **אין עברית**), `rtl.rs` (ערבית/עברית, ראה §4), `icons.rs` (אייקונים מצוירים בקוד).
- `crates/ui-egui/src/panels/` — פאנל לכל דבר: `timeline.rs`, `monitor.rs`, `project.rs`, `effect_controls.rs`, `lumetri.rs`, `graphics.rs` (כלי הטקסט על המוניטור), `text.rs` (פאנל Text/Captions), `mixer.rs`, `export_mode.rs`, `settings.rs`…
- `apps/filmcraft/src/` — החלון עצמו (eframe/wgpu), אודיו (cpal), דיאלוגי קבצים (rfd), תפריט macOS native (muda), לוגים.

## 2. בנייה על macOS Apple Silicon

### דרישות

| מה | פרטים |
|---|---|
| Rust | stable **≥ 1.95** (edition 2024; egui 0.36 דורש). התקנה דרך rustup. `rustup component add rustfmt clippy`. |
| Xcode Command Line Tools | `xcode-select --install` (linker + headers של VideoToolbox/CoreAudio). |
| wasm target | רק ל־`cargo xtask wasm` / `cargo xtask ci`: `rustup target add wasm32-unknown-unknown`. לא נדרש להרצת האפליקציה. |
| ffmpeg + ffprobe | **אופציונלי**, רק לטסטי oracle ויצירת fixtures. `brew install ffmpeg`. הטסטים מחפשים ב־`/opt/homebrew/bin`. בלי זה הטסטים האלה פשוט נדלגים. |
| craft-fonts | **אופציונלי.** `git clone https://github.com/storytold/craft-fonts ../craft-fonts` ואז `CRAFT_FONTS_DIR="$PWD/../craft-fonts"`. מוסיף פונטים ליפנית/סינית/ערבית/תאית. **לעברית אין שם פונט** — העברית נלקחת מפונטי המערכת של macOS (SF Hebrew / Arial Hebrew), אז לא חובה בשבילי. |
| macOS | יעד מינימלי 11.0 (`MACOSX_DEPLOYMENT_TARGET`). יש דיווחים על קריסה ב־macOS 12 בגלל סימבול VideoToolbox (#468/#661); במק עדכני לא רלוונטי. |

### הורדה מוכנה (בלי בילד)

https://github.com/storytold/filmcraft/releases/latest — נכון ל־18.10 הגרסה היא **v0.9.0** (18.10.2026, שעון ישראל):

- `filmcraft-0.9.0-macos-universal.dmg` (70 MB): האפליקציה, חתומה ו־notarized. לפתוח ולגרור ל־Applications.
- `filmcraft-cli-0.9.0-macos-universal.zip` (58 MB): ה־CLI וה־MCP, נפרדים מה־.app. לפרוס ולהעתיק ל־`/usr/local/bin` (או כל תיקייה ב־PATH).
- `SHA256SUMS.txt`: לאימות, `shasum -a 256 -c SHA256SUMS.txt --ignore-missing` בתיקיית ההורדות.

ה־DMG מספיק כדי לנסות ולערוך. בילד מהקוד נדרש רק כדי לשנות את התוכנה, או כדי להריץ תיקונים שנכנסו ל־`main` ועוד לא יצאו ברלאז.

**עדכון לגרסה חדשה:** `scripts/update-filmcraft-mac.sh` (בברנץ' הזה) מוריד את הרלאז האחרון, מאמת SHA256, מחליף את `/Applications/FilmCraft.app` ומתקין את `filmcraft-cli` ב־`/usr/local/bin`. `--check` רק מדווח גרסאות, `--force` מתקין מחדש. הותקן ב־18.10 גם כ־`~/update-filmcraft.sh` על המק. אין עדכון אוטומטי בתוך האפליקציה. החלפת אפליקציה קיימת מהטרמינל דורשת ב־macOS 13+ הרשאת App Management לטרמינל (System Settings ▸ Privacy & Security ▸ App Management), אחרת מחליפים דרך Finder.

**גרסת דפדפן (ל־Claude for Chrome):** `scripts/serve-filmcraft-web.sh` מוריד את `filmcraft-web-<ver>.zip` מהרלאז, פורס ל־`~/FilmCraft-Web/` ומגיש על `http://localhost:8765/` עם `python3 -m http.server`, ופותח כרום. אותו מנוע ו־UI כמו הדסקטופ (WASM, WebGPU), אבל חד־תהליכי: בלי render previews / proxies, ייצוא יוצא כהורדה, מדיה דרך בורר קבצים או drag&drop, פענוח HEVC דרך WebCodecs של הדפדפן. יש `window.filmcraft` (API של control channel כ־promises, `docs/web.md`). לעבודת סוכן רצינית עדיף Claude Code + MCP על הדסקטופ.

### פקודות

```sh
# פיתוח / הרצה (release מומלץ: dev builds איטיים בפלייבק)
cargo run --release -p filmcraft                      # האפליקציה עם פרויקט דמו
cargo run --release -p filmcraft -- --empty           # בלי דמו
cargo run --release -p filmcraft -- --control 9876    # + שרת control (לסוכן)
cargo run --release -p filmcraft -- clip.mov music.wav

# CLI ו־MCP
cargo build --release -p filmcraft-cli -p filmcraft   # .mcp.json מצפה ל־target/release/filmcraft-cli
cargo run --release -p filmcraft-cli -- commands      # כל הפקודות
cargo run --release -p filmcraft-cli -- mcp --demo    # שרת MCP headless

# features אופציונליים
cargo build --release -p filmcraft --features whisper          # תמלול (speech-to-text) מקומי
cargo build --release -p filmcraft --features neural-voices    # TTS Kokoro

# שערי איכות לפני commit (אם אשנה קוד)
cargo fmt --check
cargo clippy --workspace --all-targets -- -D warnings
cargo test --workspace
cargo xtask layers && cargo xtask assets && cargo xtask wasm
cargo xtask ci        # הכול ביחד (clippy + tests ב־release)
```

### זמן בילד ראשון (הערכה, לא נמדד)

- גודל: ~400k שורות Rust בתוך ה־workspace, 707 חבילות ב־`Cargo.lock` (כולל egui, wgpu, rayon, candle רק אם מפעילים whisper).
- פרופיל release: `lto = "thin"`, `codegen-units = 1` — איטי יותר לקמפל, מהיר יותר לרוץ.
- **הערכה שלי** ל־MacBook Pro Apple Silicon (M-series Pro/Max): בילד release ראשון של `filmcraft` + `filmcraft-cli` בסביבות **10–25 דקות**; בילד dev (`cargo build`) כנראה **5–12 דקות**; `cargo test --workspace` מלא עוד **10–30 דקות** בפעם הראשונה (הרבה טסטי קודקים). בילדים חוזרים אחרי שינוי קטן: שניות עד 1–2 דקות. **כדאי למדוד בפעם הראשונה** (`time cargo build --release -p filmcraft`) ולעדכן כאן.
- טיפ מהתיעוד: לעבודה במקביל של כמה סוכנים משתמשים ב־git worktree נפרד ו־`CARGO_TARGET_DIR=target/agent-<name>`.
- לוגים: `~/Library/Application Support/FilmCraft/Logs/filmcraft.log` (Help ▸ Reveal Log Files).

## 3. Issues רלוונטיים לעריכה פשוטה על מק (סריקה 2026-10-14)

מקור: `github.com/storytold/filmcraft/issues` (506 פתוחים) + release notes של v0.5.0–v0.7.2 + `docs/gaps.md`. סטטוס נכון לתאריך הסריקה. "תוקן ב־main" = מוזג אחרי v0.7.2; **כל אלה כלולים ב־v0.8.0** שיצאה ב־14.10 (ראה §8).

### ייצוא (MP4 / H.264 / HEVC)

| # | מה | סטטוס |
|---|---|---|
| #1329 | **ייצוא H.264 נתקע ב־0% CPU במק** (deadlock ב־rayon), במקור עם קליפ מסובב (rotation tag, כמו וידאו אנכי מאייפון). | פתוח, אבל מדווח שעם PR #846 (כלול ב־**v0.8.0**) **כבר לא משתחזר**. PR #1334 לחלק של המרת הצבע עדיין לא מוזג (16.10). ב־`main` אחרי v0.8.0 נוסף תיקון deadlock נוסף בייצוא (`8309f21`). **לבדוק אצלי** עם קליפ אנכי מאייפון. |
| #1399 | ייצוא של 14 דקות לקח שעה (CPU encode). | פתוח. עם Hardware encoding + GPU rendering ירד ל־~6 דקות. **מסקנה:** להפעיל Export ▸ Hardware encoding (VideoToolbox) ו־GPU Rendering. Premiere עדיין מהיר פי ~4. |
| #371 | bitrate target לא מדויק (6.1 Mb/s כשביקשו 40). | פתוח (ב־gaps.md). |
| #1741 / #1616 / #1724 | GPU export נופל ל־CPU בשקט / פריימים כהים (Windows). | פתוחים, Windows. |
| #1544 | `file.exportMedia` עם `wait:false` לא ניתן למעקב דרך ה־bridge. | פתוח, רלוונטי לעבודה עם סוכן. |
| — | HEVC export במק: רק דרך VideoToolbox, 8-bit SDR בלבד (אין Main 10/HDR). AV1 export: אין. | מגבלה ידועה (gaps G13, #30). |
| v0.7.2 | Peak limiter לא פוגע ב־loudness; ייצוא עם מדיה offline מסרב בלי `--allow-offline`; **ייצוא לא נעצר לצמיתות עם קליפי HEVC מסובבים מאייפון** (rayon). | **תוקן**. |
| v0.6.0 | GPU export rendering מופעל כברירת מחדל. | **תוקן**. |

### HEVC ומדיה מאייפון

| # | מה | סטטוס |
|---|---|---|
| #1700 | **קליפים מטלפון עם זמני פריים מעוגלים למילישניות נקראים כ־30.303/58.824 fps** → New Sequence From Clip מפיל פריימים; גם proxies יוצאים עם מספר פריימים שגוי. | פתוח, PRs #1739/#1729 עדיין לא מוזגו (16.10). **חשוב לי** (iPhone מקליט VFR). |
| #1282 | פריים קודם מוצג כשחותמות הזמן מעט אחרי הגריד (צילום טלפון). | **נסגר** 13.10. |
| #987 | לזהות metadata של Apple Log ב־ProRes MOV מאייפון. | פתוח (רלוונטי רק אם מצלמים Log). |
| #1583 | תמונות סטילס מתעלמות מ־EXIF orientation (תמונות portrait מהטלפון נכנסות הפוכות). | פתוח. |
| #1483 | פענוח HEVC בחומרה נפל לתוכנה בגלל PPS שונה בבייט אפס. | **נסגר** 13.10. |
| #1039 | פענוח HEVC בתוכנה איטי פי 2.7–4 מ־ffmpeg. | פתוח; במק פחות קריטי כי VideoToolbox עושה את הפענוח. |
| v0.6.0 | HEVC cropping / clean aperture מ־MP4/MOV; צבע מהביטסטרים כשהמכולה לא מציינת. | **תוקן**. |
| v0.2.0 | rotation של המכולה (וידאו אנכי מטלפון מוצג ישר). | **תוקן**. |
| G3 | H.264 10-bit / 4:2:2 ו־HEVC 4:2:2 — במק עובדים דרך VideoToolbox (בשבבים שתומכים), אין fallback בתוכנה. | מגבלה; לא נוגעת באייפון רגיל (HEVC Main/Main 10 4:2:0 נתמך). |

### Timeline ועריכה

| # | מה | סטטוס |
|---|---|---|
| #1773 | **Cmd+V מדביק פעמיים במק** (התפריט ה־native צורך את הלחיצה ואז ה־release נקרא כהדבקה שנייה). | פתוח, PR #1807 (draft) מתקן; לא מוזג נכון ל־16.10. |
| #1622 | `playhead.set` מתעלם בזמן פלייבק אבל מדווח הצלחה; **47% dropped frames** על 1080p60 H.264 ב־M3 Max (רזולוציית ½, VideoToolbox פעיל). | פתוח, בלי תגובה. **לבדוק אצלי** עם `perf.stats`. |
| #1682 | FilmCraft תפס 150 GB RAM במק (פרויקט אינסטגרם מתמונות/וידאו, דרך Claude Code). | פתוח, לא טופל. **לשים לב** עם 96 GB. |
| #1535 | קליק ימני על ה־ruler פותח תפריט של קליפ. | פתוח (8 תגובות). |
| #1153 | zoom bar מתקרב סביב הקצה הלא נכון. | פתוח. |
| #1577 | 'D' לא בוחר רווחים (gaps). | פתוח. |
| #577 / #1810 | אין בקרות עריכה למעברים (transitions) ב־Effect Controls; הצעה לכתוב מחדש מעברים. | פתוח. |
| #1519 | ערכי effect presets לא נשמרים. | פתוח. |
| #1780 / #1424 | מתיחת קליפ / waveform מתכווץ. | פתוח. |
| #1333 | אי אפשר להסיר/לשנות קיצורי ברירת מחדל במק. | פתוח. |
| v0.7.2 | box selection חי, פלייהד זז מיד בלחיצה על ה־ruler, גרירה מעל הטראק העליון מוסיפה טראק, Esc מבטל גרירה, drop על timeline ריק יוצר sequence. | **תוקן**. |
| v0.6.0 | גרירת timecode לסקראב, תפריט edit point בקליק ימני, תצוגה מקדימה למעבר בגרירה, תיקוני trim. | **תוקן**. |

### כותרות / טקסט / כתוביות

| # | מה | סטטוס |
|---|---|---|
| #395 | **טקסט ערבי שבור בכותרות.** | פתוח. PR #1140 (מוזג) הוסיף פונטי fallback לערבית ועברית בממשק + כתוביות בסדר קריאה; ה־issue עצמו עדיין פתוח. ראה §4. |
| #1475 | ערבית כקוביות ריקות בשכבות גרפיקה (Windows). | פתוח, PR #1478 פתוח. |
| #40 | תווים לא־לטיניים (CJK) כ־NO GLYPH; אין fallback chain ואין בורר פונט בסרגל הכתוביות. | פתוח; חלקית טופל (CJK fallbacks). |
| #1464 | תצוגת פונטים בבורר. | פתוח. |
| #1663 | Color Picker במק. | פתוח. |
| #1791 | ייצוא כתוביות SCC/MCC — כתובית מופיעה שנייה מאוחר. | פתוח (רלוונטי רק לברודקאסט). |
| v0.7.2 | underline בטקסט אנכי, IME composition בשדות טקסט, Scale drag = undo אחד. | **תוקן**. |
| v0.6.0 | מילוי גרדיאנט לטקסט וצורות. | **תוקן**. |

### אודיו

| # | מה | סטטוס |
|---|---|---|
| #1265 | **רעש סטטי בפלייבק במק M3 Pro** (פרויקט הדמו; גם משתמש Windows שמע). | פתוח, סיבה לא זוהתה. **לבדוק אצלי.** |
| #1294 / #601 / #416 | ריבוי טראקי אודיו בייבוא. | תמיכה נחתה (#361, schema v13); המדווחים לא אישרו. |
| #1701 | 5.1 AC-3/E-AC-3 ב־MP4 נקרא כסטריאו. | פתוח. |
| #1746 | Normalize audio. | פתוח. |
| #1786 | Join Through Edits מאבד בחירת ערוץ. | פתוח. |
| #1699 | VST plugins. | פתוח; אין plugin hosting בכלל (gaps G11, 200–400 שעות). |
| v0.7.2 | stream אודיו מתאתחל כשההתקן נופל; AAC 8 ערוצים; Matroska codec delay מדויק; אודיו מקושר מתגלגל עם הכאט. | **תוקן**. |
| v0.6.0 | Parametric EQ מלא; Audio Gain מודד peak; אודיו בסקראב. | **תוקן**. |

### macOS ו־MCP כללי

| # | מה | סטטוס |
|---|---|---|
| #30 | Tracking: האצת חומרה (zero-copy, Lumetri curves/wheels על GPU, VideoToolbox Main 10). | פתוח, 13 תגובות, ה־epic המרכזי. |
| #882 | ה־.app ברלאז לא עובר `codesign --verify --deep --strict`. | פתוח (לא מפריע לבילד מקומי). |
| #1538 | **MCP bridge מפסיק להגיב אחרי פקודה איטית**; כל קריאה אחריה timeout. | PR #1548 **כלול ב־v0.8.0**. חשד נוסף: קורה כשהחלון מכוסה (#1584). |
| #1541 | `render_preview` מחזיר פריימים ישנים אחרי שינוי timeline. | פתוח. |
| #1545 | `command_list` מחזיר 188k תווים (יותר מדי לסוכן); `crop` לא מופיע ב־`effects.list`; פקודות מחזירות null. | פתוח; PR #1588 (draft) מוסיף `compact: true`. **טיפ:** תמיד להשתמש ב־`filter`. |
| #1669 | כותרת החלון "FilmCraft Demo" בהפעלה ראשונה מבלבלת. | פתוח. |

### מה אין בכלל (לא באג, פער)

- פתיחת `.prproj` של Premiere (G2, חוסם beta). מעבר דרך FCP7 XML / AAF / OTIO.
- Plugins (VST3/AU/OpenFX).
- HEVC בתוכנה, AV1 export, HDR HEVC במק.
- Lumetri curves/wheels/HSL ו־keys עדיין ב־CPU (Basic/Creative/Vignette על GPU).
- CI על PRs (G4): main נשבר מדי פעם; לבנות מ־tag יציב (v0.7.2) אם main אדום.

## 4. עברית ו־RTL

### מה המצב היום

**ממשק (UI, egui):**
- אין קטלוג תרגום לעברית (`crates/ui-egui/src/i18n/` כולל 11 שפות, לא `he`). הממשק **אף פעם לא מתהפך ל־RTL** (אין mirroring של פאנלים), וזה מתועד כפער (gaps G14, localization-parity: ערבית "40–70 שעות").
- יש **פונטי fallback** לעברית וערבית: `crates/ui-egui/src/rtl.rs` מוסיף לכל משפחת פונט UI את ה־face מ־craft-fonts (`Hebr`/`Arab`) ואם אין, face מותקן במערכת (לעברית: Noto Sans Hebrew, **SF Hebrew, Arial Hebrew**, Segoe UI…). ב־craft-fonts **אין פונט עברי** (יש Noto Sans Arabic), אז במק נשתמש בפונט המערכת — אמור להציג אותיות עבריות בשמות קבצים, שמות קליפים וכו'.
- **סדר מילים:** egui מעצב (shaping) כל ריצת פונט אבל מסדר ריצות משמאל לימין בלי bidi. לכן "מילה שנייה" יוצאת ראשונה בטקסט רב־מילים. התיקון קיים **רק לכתוביות** (`rtl::Lines`, בלוקים על ה־timeline ורשימת ה־Text panel, דרך `unicode-bidi` UAX #9). שדות אחרים (שמות קליפים, שדות קלט, תוויות) נשארים בסדר הלוגי של egui. שדה בעריכה (`TextEdit`) תמיד בסדר לוגי כי הסמן ממופה לפי אינדקס תו.

**כותרות (Titles / graphic clips):**
- מנוע הטקסט `crates/text` **כן תומך ב־bidi מלא**: `layout.rs` עושה font fallback לכל תו → רמות bidi (`unicode_bidi::BidiInfo`) → shaping עם harfrust (`Direction::RightToLeft`) → שבירת שורות → `visual_runs` לסידור ויזואלי → יישור. יש טסט `bidi_reorders_rtl_runs` עם אותיות עבריות (`\u{5d0}\u{5d1}\u{5d2}`) שבודק שהאות הראשונה הכי ימנית. `ParagraphStyle::rtl: Option<bool>` מאפשר לקבוע כיוון פסקה.
- כלי הטקסט על המוניטור (`crates/ui-egui/src/panels/graphics.rs`) משתמש ב־`layout.hit(x,y)` ו־`layout.caret(pos)` של אותו מנוע, אז מיקום הסמן אמור להיות נכון גם ב־RTL.
- הפונטים המובנים (Inter, JetBrains Mono, Noto Serif) **אין להם עברית**; `fallback_for` אמור למצוא פונט מערכת (SF Hebrew / Arial Hebrew במק). ב־Windows דווח שזה לא קורה לערבית (#1475), ו־#395 (ערבית בכותרות) עדיין פתוח — **כלומר "אמור לעבוד" ≠ "נבדק"**. לא ראיתי בדיקה או דיווח על עברית בכותרות במק.

### תוצאת בדיקה 2026-10-18, גרסת הדפדפן (v0.9.0 web, Chrome על המק)

כותרת `שלום עולם 2026` דרך ⌘T: **ה־bidi נכון** ("2026" משמאל, המילים העבריות מימינו), אבל כל אות עברית מצוירת כ־"NO GLYPH", גם במוניטור וגם בפאנל Layers (כל הממשק הוא canvas של egui). סיבה: ה־WASM לא סורק פונטי מערכת, הפונטים המוטמעים (Inter, Noto Serif) בלי עברית, וב־craft-fonts אין face עברי (יש Arab/Thai/CJK). **מסקנה:** בעיית פונט, לא בעיית כיווניות. תיקון אפשרי ומוגדר: Noto Sans Hebrew (OFL) ל־craft-fonts עם `Hebr` במניפסט, ובחירתו גם ל־web ב־`crates/text/build.rs`. הערה: אחרי ⌘T צריך דאבל־קליק על "New Text" כדי להקליד. **הבדיקה בדסקטופ עדיין לא בוצעה** (שם אמור להימצא SF Hebrew / Arial Hebrew מהמערכת).

### מה לבדוק ראשון (על המק)

1. כותרת עברית פשוטה (Type tool, `graphics.newText {"text":"שלום עולם"}`) — אותיות נכונות? סדר מילים נכון? יישור לימין (`align: Right`)? ניקוד?
2. כותרת מעורבת עברית + מספרים + אנגלית (bidi אמיתי).
3. שם קובץ עברי בפאנל Project ועל ה־timeline.
4. כתובית עברית (SRT) — אמור להיות הכי טוב, כי זה המקרה שתוקן ב־#1140.

### היקף עבודה משוער אם אני רוצה עברית "אמיתית"

| רובד | מה צריך | הערכה שלי |
|---|---|---|
| כותרות | אם בדיקה 1–2 עובדת: אולי רק UX (ברירת מחדל יישור ימין לטקסט RTL, כפתור כיוון פסקה ב־Properties, בדיקת ניקוד/תווים משולבים). אם לא: תיקון fallback במק. | 3–10 שעות |
| ממשק: שדות קלט ותוויות בסדר קריאה | להרחיב את `rtl::Lines` משדות כתוביות לשמות קליפים/קבצים/תוויות. שדות בעריכה נשארים לוגיים (מגבלת egui `TextEdit`). | 10–20 שעות |
| ממשק: קטלוג תרגום `he.tsv` | ~3,500 מחרוזות (כמו ספרדית). המתחזקים מעריכים 4–8 שעות לשפה ב־Opus, + בדיקת דובר שפה. ללא mirroring זה יוצא "עברית בממשק שמאלני" — כמו Premiere בעברית בעצם לא קיים. | 6–12 שעות + review |
| ממשק RTL מלא (mirroring) | egui לא תומך; המתחזקים: 40–70 שעות ולא בעדיפות. **לא שווה בשבילי.** | — |

**המלצה:** להתמקד בכותרות וכתוביות בעברית (זה מה שמופיע בסרטון), להשאיר את הממשק באנגלית.

## 5. MCP server ו־CLI: מה זה נותן לי

### הרעיון

כל פעולה בעורך היא פקודה עם id. ארבעה "לקוחות" מפעילים את אותן פקודות: ה־UI, ה־CLI (`filmcraft-cli`), ערוץ control (JSON lines על TCP `127.0.0.1:9876`), ושרת **MCP** (`filmcraft-cli mcp`). לכן Claude Code יכול לחתוך, לגרור, לצבוע, למקסס ולייצא בדיוק כמוני, ולראות את התוצאה (render של פריים או screenshot).

### שני מצבים

| מצב | פקודה | מה זה מפעיל |
|---|---|---|
| **Headless** | `filmcraft-cli mcp --project p.fcproj` (או `--demo` / ריק) | מנוע בתוך התהליך, בלי חלון. מתאים לאוטומציה: "קח את 40 הקליפים האלה, שים על timeline, הוסף כותרת, ייצא MP4". |
| **Bridge** | `filmcraft --control 9876` ואז `filmcraft-cli mcp --bridge 127.0.0.1:9876` | שולט באפליקציה הפתוחה: אני רואה בזמן אמת מה הסוכן עושה, הוא יכול ללחוץ/לגרור/להקליד לפי automation id ולצלם screenshot. |

`.mcp.json` בשורש הריפו כבר רושם את שניהם (`filmcraft` = bridge, `filmcraft-headless` = demo), אבל מצביע ל־`target/release/filmcraft-cli` — חייבים לבנות קודם: `cargo build --release -p filmcraft-cli -p filmcraft`. (זו הסיבה שבסשן הזה שרתי ה־MCP נכשלו: הבינארי לא קיים בקונטיינר.)

### הכלים (MCP tools)

- בשני המצבים: `command_list` (**תמיד עם `filter`**, אחרת 188k תווים), `command_run`, `command_batch`, `doc_inspect` / `project_inspect` / `sequence_inspect`, `media_import`, `render_frame` (PNG של פריים).
- Bridge בלבד: `ui_inspect`, `ui_elements`, `ui_click`, `ui_drag`, `ui_key`, `ui_type`, `ui_screenshot`, `ui_control`.
- ייצוא ארוך: `command_run {"id":"file.exportMedia","params":{…,"wait":true}}` חוסם עד הסוף עם progress/cancel דרך MCP; בלי `wait` מחזיר job ואפשר לעקוב ב־`jobs.list` (ב־bridge יש באג #1544).
- כל פקודה שעובדת על בחירה מקבלת גם `clips`/`items` מפורשים, אז סוכן לא צריך "לבחור" קודם.

### ה־CLI לבד (בלי MCP)

```sh
filmcraft-cli commands razor                         # חיפוש פקודות
filmcraft-cli describe timeline.razor
filmcraft-cli --project p.fcproj --save import a.mov b.wav
filmcraft-cli --project p.fcproj --save exec timeline.razor seconds=3.5
filmcraft-cli --project p.fcproj export out.mp4 --preset "YouTube 1080p Full HD"
filmcraft-cli --project p.fcproj export out.mp4 --preset "Social Vertical 1080×1920"
echo '{"id":"file.newBin","params":{"name":"Selects"}}' | filmcraft-cli --project p.fcproj --save run -
```

### איך זה משרת אותי

1. **עריכות סדרתיות** (למשל 20 Reels מאותם חומרים): סקריפט JSONL או Claude Code דרך MCP headless, ייצוא בלולאה, בלי לפתוח חלון.
2. **"עוזר עריכה"**: אני עורך ידנית, Claude Code מחובר ב־bridge, מבקש ממנו "תוסיף כותרת תחתונה לכל הקליפים ב־V1 עם שם הדובר" והוא עושה ואני רואה.
3. **פיתוח של FilmCraft עצמו**: כל תיקון UI נבדק ע"י הסוכן דרך control channel + screenshot (זה הפרוטוקול של הפרויקט, `docs/agents.md` §3).
4. **מכשולים ידועים:** bridge נתקע אחרי פקודה איטית ב־0.7.2 (תוקן ב־main), ולכאורה כשהחלון מכוסה (#1584); `render_preview` יכול להחזיר פריים ישן (#1541). לעבוד עם build מ־main עדכני.

## 6. צעדים מוצעים לשיחה הבאה (על המק)

1. להתקין את v0.9.0 מה־DMG (§2, "הורדה מוכנה") ולהתחיל לנסות מיד. במקביל להכין בילד: `rustup update && rustc --version` (≥ 1.95), `xcode-select --install`, `brew install ffmpeg` (אופציונלי).
2. `git checkout harel-custom`, ואז `time cargo build --release -p filmcraft -p filmcraft-cli` — **לרשום את הזמן כאן**.
3. להריץ `./target/release/filmcraft --control 9876`, לייבא קליפ HEVC אנכי מהאייפון + MP3, לחתוך, Cross Dissolve, כותרת עברית, Lumetri Basic, ייצוא עם preset `Social Vertical 1080×1920` **עם Hardware encoding ו־GPU Rendering מופעלים**. למדוד זמן ולבדוק ב־ffprobe.
4. לבדוק את הבאגים שסימנתי "לבדוק אצלי": #1329 (ייצוא קליפ מסובב), #1700 (fps של קליפ טלפון: `exec media.status` / Media File Properties), #1622 (dropped frames, `perf.stats`), #1265 (רעש בפלייבק), #1773 (Cmd+V כפול), #1682 (זיכרון).
5. בדיקת העברית לפי §4 ("מה לבדוק ראשון").
6. להחליט מה ההתאמה הראשונה שלי (מועמדים: preset ייצוא אישי ל־Reels/TikTok/YouTube Shorts; template כותרת עברית; ברירת יישור ימין לטקסט RTL; סקריפט MCP לעריכה סדרתית).
7. לקרוא לפני שנוגעים בקוד: `AGENTS.md` (חוקים מוחלטים), `CLAUDE.md`, `docs/contributing.md` §6 ("How to add… a command / effect / preset / panel").

## 7. דברים שלא בטוח בהם / לא נבדקו

- זמני בילד הם הערכה (אין מספר רשמי בתיעוד; ה־CI משתמש ב־workflow חיצוני של `craft-common-actions`).
- לא הרצתי כלום: לא בילד, לא טסטים. כל ה"תוקן" מבוסס על release notes ותגובות ב־issues, לא על בדיקה שלי.
- סריקת ה־issues כיסתה את העמוד הראשון של כל חיפוש (25 מתוך 100–500 תוצאות לכל מילת מפתח, ממוינות לפי תגובות/עדכון). יש בוודאי באגים רלוונטיים שפספסתי.
- עברית בכותרות: הקוד תומך ב־bidi, אבל לא מצאתי אף דיווח או טסט שמאשר שזה **נראה** נכון במק עם פונט מערכת. צריך לראות בעיניים.
- לא בדקתי לעומק את `docs/control-protocol.md` (רשימת כל המתודות) ואת `docs/project-files.md` (פורמט `.fcproj`, autosave, crash recovery).

## 8. עדכון 2026-10-16: מה השתנה מאז הסקירה

- **v0.8.0 יצאה ב־14.10.2026** (tag `f03e215`, "Release 0.8.0"). היא בדיוק הקוד שסקרתי ב־14.10 (`cee1feb`) + העלאת מספר גרסה. לכן כל מה שסימנתי למעלה "תוקן ב־main אחרי 0.7.2" **נמצא ב־DMG של 0.8.0**:
  - MCP bridge לא נתקע יותר אחרי פקודה איטית (#1538, PR #1548).
  - ייצוא עם קליפ מסובב (אייפון אנכי) לא נתקע (PR #846; קשור ל־#480 ו־#1329).
  - פונטי fallback לערבית ולעברית בממשק, וכתוביות RTL בסדר קריאה (PR #1140).
  - מה־release notes של 0.8.0 (לעומת 0.7.2): תפריט Ctrl+Click במק נפתח נכון; החלון נפתח במק אינטל עם Metal; Finder פותח `.fcproj`; ייצוא אודיו 32-bit int/float; קובץ כתוביות sidecar נחתך לטווח הייצוא; מעברי אודיו דרך handles; תיקוני timeline (Alt-marquee, nudge לקליפים מקושרים, גלילה בכפתור אמצעי, גרירת קליפ לא משאירה מעברים מאחור); תיקוני panic ב־MPEG-TS וב־H.264 parameter sets.
- **ב־`main` אחרי v0.8.0** (15.10, עדיין לא ברלאז): תיקון deadlock נוסף בייצוא (`fix(export): prevent nested renderer-pool deadlocks`, `8309f21`); שמות קבצים Unicode ברצפי תמונות (#1565); panic ב־URL עם Unicode בייבוא EDL (#1591); בחירת קליפים מקושרים ב־timeline; שינוי CI בלבד ל־FreeBSD.
- **עדיין לא מוזגו (16.10):** #1807 (Cmd+V כפול במק), #1739 / #1729 (fps של קליפי טלפון, #1700), #1334 (המרת צבע בייצוא), #1478 (ערבית ב־Windows), #1588 (`command_list` קומפקטי).
- **מה עשיתי בריפו ב־16.10:** `main` של ה־fork הועלה (fast-forward בלבד, בלי commits שלי) ל־`c2f6587`; `harel-custom` עבר rebase על זה והקובץ הזה עודכן.

## 9. עדכון 2026-10-18: v0.9.0 ו־main

- **v0.9.0 יצאה** (tag `4a69a03`, 17.10 בערב שעון ארה"ב). לעומת v0.8.0 היא קטנה: תיקון deadlock נוסף בייצוא (renderer pool, #861); שמות קבצים ו־URL עם עברית/Unicode לא מקריסים (#1565, #1591); בחירת קליפים מקושרים נשמרת במחיקה (#1639); נתיבי מדיה שמורים נפתחים רק במחשב הזה או בשיתוף של הפרויקט, ו־Edit Original פותח רק קבצי מדיה רגילים (#2304, בטיחות); CI.
- **ב־`main` אחרי v0.9.0** (כ־25 PRs ב־18.10, עדיין לא ברלאז), הרלוונטיים לי:
  - **ייצוא:** קבצי SDR מקבלים תיבת `colr` (#2142) — חשוב לצבעים נכונים ב־QuickTime/אינסטגרם; ייצוא שהתחיל בלי `wait` אומר איפה לעקוב אחריו (#1544, הבאג של ה־bridge); CLI `render` דוחה `--seconds`/`--scale` לא מספריים.
  - **כותרות/כתוביות:** outer stroke עם Fill כבוי מצייר רק את הטבעת (#1876); פאנל Properties עורך טקסט וזמני in/out של כתובית (#1846); חוזה של `captions.setStyle margin` (#1542); tick rate של TTML; פונטים בלי outlines לא מוצגים בבורר.
  - **מוניטור/timeline:** waveform ב־Source עוקב אחרי זום (#1782); Audio Clip Mixer נצמד לרוחב הפאנל (#1922); Basic 3D שומר פרספקטיבה (#1920); keyframe שנגרר בגרף נשאר במקום (#1918); מצבי enabled בתפריטים; סמני resize (#2263).
  - **ביצועים:** Lens Blur מחשב offsets פעם בפריים (#1871).
  - **robustness:** matroska/mxf/aaf saturating sums, CLI dotted keys depth, .3dl LUT עם mesh ענק נדחה.
- **עדיין לא מוזגו (18.10):** #1807 (Cmd+V כפול במק), #1739/#1729 (fps של קליפי טלפון), #1334, #1478, #1588. לא בדקתי מחדש issues חדשים.
- **מה עשיתי בריפו ב־18.10:** `main` של ה־fork הועלה (fast-forward) ל־`48088e3`; `harel-custom` עבר rebase; הקובץ הזה עודכן (סעיף 2 מצביע ל־v0.9.0).
