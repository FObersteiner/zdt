//! errors

pub const ZdtError = FormatError || RangeError || TzError || WinTzError;

pub const FormatError = error{
    EmptyString,
    InvalidCharacter,
    InvalidDirective,
    InvalidFormat,
    InvalidFraction,
    OutOfMemory,
    Overflow,
    ParseIntError,
    Underflow,
    UnsupportedOS,
    WriterError,
};

pub const RangeError = error{
    YearOutOfRange,
    MonthOutOfRange,
    DayOutOfRange,
    HourOutOfRange,
    MinuteOutOfRange,
    SecondOutOfRange,
    NanosecondOutOfRange,
    UnixOutOfRange,
};

pub const TzError = error{
    AllTZRulesUndefined,
    InvalidOffset,
    InvalidPosixTz,
    BadTZifVersion,
    InvalidTz,
    InvalidIdentifier,
    AmbiguousDatetime,
    NonexistentDatetime,
    TzAlreadyDefined,
    TzUndefined,
    TZifUnreadable,
    CompareNaiveAware,
    NotImplemented,
};

pub const WinTzError = error{
    TzUtilFailed,
    ReadRegistryFailed,
    TzNotFound,
};
