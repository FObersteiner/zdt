//! errors

pub const ZdtError = RangeError || TzError || WinTzError;

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
    BadTZifVersion,
    InvalidTz,
    InvalidIdentifier,
    AmbiguousDatetime,
    NonexistentDatetime,
    TzAlreadyDefined,
    TzUndefined,
    CompareNaiveAware,
    NotImplemented,
};

pub const WinTzError = error{
    TzUtilFailed,
    ReadRegistryFailed,
    TzNotFound,
};
