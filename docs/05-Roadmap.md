# Roadmap

- extend range of datetimes that can be represented; 5-digit signed year

- host/run docs and CI on codeberg

- experiment with comptime-generation of timezone database

- iso-caledar parsing and formatting with %G %V %u directives

- improve parser flagging?

- Windows: handle tz with DST disabled

- locale-specific parsing (%a, %A, %b, %B) on Windows

- parser: consider day name if supplied
  - check if a day-of-month or day-of-year is supplied as well
  - allow to create a date if a week-of-year is supplied as well
