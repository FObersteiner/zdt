<!-- -*- coding: utf-8 -*- -->

# Advanced

## Ambiguous and Non-Existent Datetime: folds and gaps

A datetime is ambiguous if it appears multiple times on a wall clock. Example:
- DST transition fold: wall clock moved backwards when daylight saving time goes from active to inactive (offset from UTC is reduced)

A datetime is non-existent if it does not appear on a wall clock. Example:
- DST transition gap: wall clock moved forwards when daylight saving time goes from inactive to active (offset from UTC is increased)
