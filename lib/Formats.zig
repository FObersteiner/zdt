//! common datetime formats,
//! <https://pkg.go.dev/time#pkg-constants>

pub const ANSIC = "%:a %:b %e %H:%M:%S %Y";
pub const UnixDate = "%:a %:b %e %H:%M:%S %Z %Y";
pub const RubyDate = "%:a %:b %e %H:%M:%S %z %Y";
pub const RFC822 = "%d %:b %y %H:%M %Z";
pub const RFC822Z = "%d %:b %y %H:%M %z";
pub const RFC850 = "%:A, %d-%:b-%y %H:%M:%S %Z";
pub const RFC1123 = "%:a, %d %:b %Y %H:%M:%S %Z";
pub const RFC1123Z = "%:a, %d %:b %Y %H:%M:%S %z";
pub const RFC3339 = "%Y-%m-%dT%H:%M:%S%:z";
pub const RFC3339nano = "%Y-%m-%dT%H:%M:%S.%f%:z";
pub const DateOnly = "%Y-%m-%d";
pub const TimeOnly = "%H:%M:%S";
pub const DateTime = "%Y-%m-%d %H:%M:%S";
pub const Stamp = "%:b %e %H:%M:%S";
pub const StampMilli = "%:b %e %H:%M:%S.%:f";
pub const StampMicro = "%:b %e %H:%M:%S.%::f";
pub const StampNano = "%:b %e %H:%M:%S.%f";
