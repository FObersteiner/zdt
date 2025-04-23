# Roadmap

## 0.7.x

- revise Datetime struct: Would it be better to have it purely Unix time based, and calculate anything else on demand?

## unspecified

- experiment with comptime-generation of timezone database

- iso-caledar parsing / formatting with %G %V %u directives

- improve parser flagging

- Windows: DST disabled tz (#1)

- locale-specific parsing (%a, %A, %b, %B) on Windows

- parser: consider day name if supplied
  - check if a day-of-month or day-of-year is supplied as well
  - allow to create a date if a week-of-year is supplied as well

## see also

- [issues](https://github.com/FObersteiner/zdt/issues)
