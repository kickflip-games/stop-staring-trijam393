# Repository cleanup

The active 2D arena remains in `stop_staring/experiments/pixel_pivot/` because
Home, gameplay, the scene builder and current tests all use it.

Removed 47 obsolete files:

- The standalone art patch, its unused socket SVG and old art-patch capture.
- The superseded composition test and duplicate global-cycle test alias.
- Earlier composition, six-alcove and global-cycle checkpoint folders.
- The original eye sheet/region list, replaced by the configured v2 sheet.
- The unused menu logo, four alternate wall clips and global-cycle audio cues.
- Associated import files and generator branches for the removed content.

The asset preview, atlas builders, current eye poses, gameplay tests, current
captures and promotional images remain. Credits and documentation reflect the
retained assets. Project settings no longer depend on an ignored local editor
plugin; the Music autoload is retained.

Validation: 98 literal resource references resolve; eight current headless
suites pass, totaling 2,988 counted assertions plus the menu music/warmup checks.
The arena builder passes its parser check, and regenerated launch/snap cues
match the retained WAVs byte-for-byte. A fresh isolated Web import/export passes
with credits included. Existing macOS certificate and teardown diagnostics in
some headless fixtures remain; they are separate from assertion failures.
