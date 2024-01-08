//! zdt errors
pub const ZdtError = RangeError || TzError;

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
    AmbiguousDatetime,
    NonexistentDatetime,
    TzAlreadyDefined,
    TzUndefined,
    CompareNaiveAware,
    NotImplemented,
};
