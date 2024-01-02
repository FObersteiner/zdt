//! test timezone from a users's perspective (no internal functionality)
const std = @import("std");
const testing = std.testing;
const print = std.debug.print;

const datetime = @import("datetime.zig");
const Duration = @import("Duration.zig");
const tz = @import("timezone.zig");
const str = @import("stringIO.zig");

// if (true) return error.SkipZigTest;

test "utc" {
    const utc = tz.UTC;
    try std.testing.expect(utc.tzOffset.?.seconds_east == 0);
    try std.testing.expect(std.mem.eql(u8, utc.name, "UTC"));
}

test "offset tz never changes offset" {
    var tzinfo = tz.TZ{};
    try tzinfo.loadOffset(999, "hello world");
    try std.testing.expect(std.mem.eql(u8, tzinfo.name, "hello world"));

    tzinfo = try tzinfo.atUnixtime(0);
    try std.testing.expect(tzinfo.tzOffset.?.seconds_east == 999);
    tzinfo = try tzinfo.atUnixtime(@intCast(std.time.timestamp()));
    try std.testing.expect(tzinfo.tzOffset.?.seconds_east == 999);

    var err = tzinfo.loadOffset(-99999, "invalid");
    try std.testing.expectError(tz.TzError.InvalidOffset, err);
    err = tzinfo.loadOffset(99999, "invalid");
    try std.testing.expectError(tz.TzError.InvalidOffset, err);
}

test "offset manifests in Unix time" {
    var tzinfo = tz.TZ{};
    try tzinfo.loadOffset(3600, "UTC+1");
    // all fields zero, so Unix time has to be adjusted:
    const dt = try datetime.Datetime.fromFields(.{ .year = 1970, .tzinfo = tzinfo });
    try std.testing.expect(dt.__unix == -3600);
    try std.testing.expect(dt.hour == 0);
    // Unix time zero, so fields have to be adjusted
    const dt_unix = try datetime.Datetime.fromUnix(0, Duration.Resolution.second, tzinfo);
    try std.testing.expect(dt_unix.__unix == 0);
    try std.testing.expect(dt_unix.hour == 1);

    var s = std.ArrayList(u8).init(std.testing.allocator);
    defer s.deinit();
    const string = "1970-01-01T00:00:00+01:00";
    const directive = "%Y-%m-%dT%H:%M:%S%z";
    try str.formatDatetime(s.writer(), directive, dt);
    try std.testing.expectEqualStrings(string, s.items);
}

test "invalid tzfile name" {
    var err = tz.fromTzfile("this is not a tzname", std.testing.allocator);
    try std.testing.expectError(error.FileNotFound, err);
    err = tz.fromTzfile("../test", std.testing.allocator);
    try std.testing.expectError(error.FileNotFound, err);
    err = tz.fromTzfile("*=!?:.", std.testing.allocator);
    try std.testing.expectError(error.FileNotFound, err);
}

test "mem error" {
    const allocator = std.testing.failing_allocator;
    const err = tz.fromTzfile("UTC", allocator);
    try std.testing.expectError(error.OutOfMemory, err);
}

test "tzfile tz manifests in Unix time" {
    var tzinfo = try tz.fromTzfile("Europe/Berlin", std.testing.allocator);
    defer _ = tzinfo.deinit();

    const dt = try datetime.Datetime.fromFields(.{ .year = 1970, .nanosecond = 1, .tzinfo = tzinfo });
    try std.testing.expect(dt.__unix == -3600);
    try std.testing.expect(dt.hour == 0);
    try std.testing.expect(dt.nanosecond == 1); // don't forget the nanoseconds...
}

test "DST transitions" {
    var tzinfo = try tz.fromTzfile("Europe/Berlin", std.testing.allocator);
    defer _ = tzinfo.deinit();

    // DST off --> DST on (missing datetime), 2023-03-26
    var dt_std = try datetime.Datetime.fromUnix(1679792399, Duration.Resolution.second, tzinfo);
    var dt_dst = try datetime.Datetime.fromUnix(1679792400, Duration.Resolution.second, tzinfo);
    try std.testing.expect(dt_dst.tzinfo.?.is_dst);
    try std.testing.expect(!dt_std.tzinfo.?.is_dst);

    var s = std.ArrayList(u8).init(std.testing.allocator);
    try str.formatDatetime(s.writer(), "%Y-%m-%dT%H:%M:%S%z", dt_std);
    try std.testing.expectEqualStrings("2023-03-26T01:59:59+01:00", s.items);
    s.deinit();

    s = std.ArrayList(u8).init(std.testing.allocator);
    try str.formatDatetime(s.writer(), "%Y-%m-%dT%H:%M:%S%z", dt_dst);
    try std.testing.expectEqualStrings("2023-03-26T03:00:00+02:00", s.items);
    s.deinit();

    // DST on --> DST off (duplicate datetime), 2023-10-29
    dt_dst = try datetime.Datetime.fromUnix(1698541199, Duration.Resolution.second, tzinfo);
    dt_std = try datetime.Datetime.fromUnix(1698541200, Duration.Resolution.second, tzinfo);
    try std.testing.expect(dt_dst.tzinfo.?.is_dst);
    try std.testing.expect(!dt_std.tzinfo.?.is_dst);

    s = std.ArrayList(u8).init(std.testing.allocator);
    try str.formatDatetime(s.writer(), "%Y-%m-%dT%H:%M:%S%z", dt_dst);
    try std.testing.expectEqualStrings("2023-10-29T02:59:59+02:00", s.items);
    s.deinit();

    s = std.ArrayList(u8).init(std.testing.allocator);
    try str.formatDatetime(s.writer(), "%Y-%m-%dT%H:%M:%S%z", dt_std);
    try std.testing.expectEqualStrings("2023-10-29T02:00:00+01:00", s.items);
    s.deinit();
}

test "early LMT, late CET" {
    var tzinfo = try tz.fromTzfile("Europe/Berlin", std.testing.allocator);
    defer _ = tzinfo.deinit();

    var dt = try datetime.Datetime.fromFields(.{ .year = 1880, .tzinfo = tzinfo });
    var have = @as([]const u8, dt.tzinfo.?.abbreviation[0..3]);
    try std.testing.expectEqualStrings("LMT", have);

    dt = try datetime.Datetime.fromFields(.{ .year = 2039, .month = 8, .tzinfo = tzinfo });
    have = @as([]const u8, dt.tzinfo.?.abbreviation[0..3]);
    try std.testing.expectEqualStrings("CET", have);
}

test "non-existent datetime" {
    var tzinfo = try tz.fromTzfile("Europe/Berlin", std.testing.allocator);
    defer _ = tzinfo.deinit();

    var dt = datetime.Datetime.fromFields(.{ .year = 2023, .month = 3, .day = 26, .hour = 2, .tzinfo = tzinfo });
    try std.testing.expectError(datetime.ZdtError.NonexistentDatetime, dt);

    tzinfo.deinit();
    tzinfo = try tz.fromTzfile("America/Denver", std.testing.allocator);
    dt = datetime.Datetime.fromFields(.{ .year = 2023, .month = 3, .day = 12, .hour = 2, .minute = 59, .second = 59, .tzinfo = tzinfo });
    try std.testing.expectError(datetime.ZdtError.NonexistentDatetime, dt);
}

test "ambiguous datetime" {
    var tzinfo = try tz.fromTzfile("Europe/Berlin", std.testing.allocator);
    defer _ = tzinfo.deinit();

    var dt = datetime.Datetime.fromFields(.{ .year = 2023, .month = 10, .day = 29, .hour = 2, .tzinfo = tzinfo });
    try std.testing.expectError(datetime.ZdtError.AmbiguousDatetime, dt);

    tzinfo.deinit();
    tzinfo = try tz.fromTzfile("America/Denver", std.testing.allocator);
    dt = datetime.Datetime.fromFields(.{ .year = 2023, .month = 11, .day = 5, .hour = 1, .minute = 59, .second = 59, .tzinfo = tzinfo });
    try std.testing.expectError(datetime.ZdtError.AmbiguousDatetime, dt);
}

test "tz without transitions at UTC+9" {
    var tzinfo = try tz.fromTzfile("Asia/Tokyo", std.testing.allocator);
    defer _ = tzinfo.deinit();

    var dt = try datetime.Datetime.fromFields(.{ .year = 2023, .month = 3, .day = 26, .hour = 2, .tzinfo = tzinfo });
    try std.testing.expectEqual(@as(i20, 9 * 3600), dt.tzinfo.?.tzOffset.?.seconds_east);
    dt = try datetime.Datetime.fromFields(.{ .year = 2023, .month = 3, .day = 12, .hour = 2, .minute = 59, .second = 59, .tzinfo = tzinfo });
    try std.testing.expectEqual(@as(i20, 9 * 3600), dt.tzinfo.?.tzOffset.?.seconds_east);
    dt = try datetime.Datetime.fromFields(.{ .year = 2023, .month = 10, .day = 29, .hour = 2, .tzinfo = tzinfo });
    try std.testing.expectEqual(@as(i20, 9 * 3600), dt.tzinfo.?.tzOffset.?.seconds_east);
    dt = try datetime.Datetime.fromFields(.{ .year = 2023, .month = 11, .day = 5, .hour = 1, .minute = 59, .second = 59, .tzinfo = tzinfo });
    try std.testing.expectEqual(@as(i20, 9 * 3600), dt.tzinfo.?.tzOffset.?.seconds_east);
}

test "make datetime aware" {
    var tzinfo = try tz.fromTzfile("Europe/Berlin", std.testing.allocator);
    defer _ = tzinfo.deinit();

    const dt_naive = try datetime.Datetime.fromUnix(0, Duration.Resolution.second, null);
    try std.testing.expect(dt_naive.tzinfo == null);
    const dt_aware = try dt_naive.tzLocalize(tzinfo);
    try std.testing.expect(dt_aware.tzinfo != null);
    try std.testing.expect(dt_aware.__unix != dt_naive.__unix);
    try std.testing.expect(dt_aware.__unix == -3600);
    try std.testing.expect(dt_aware.year == dt_naive.year);
    try std.testing.expect(dt_aware.day == dt_naive.day);
    try std.testing.expect(dt_aware.hour == dt_naive.hour);

    const err = dt_aware.tzLocalize(tzinfo);
    try std.testing.expectError(datetime.ZdtError.TzAlreadyDefined, err);

    const naive_again = try dt_aware.tzLocalize(null);
    try std.testing.expect(std.meta.eql(dt_naive, naive_again));
}

test "convert time zone" {
    var tzinfo = try tz.fromTzfile("Europe/Berlin", std.testing.allocator);
    defer _ = tzinfo.deinit();

    const dt_naive = try datetime.Datetime.fromUnix(42, Duration.Resolution.nanosecond, null);
    const err = dt_naive.tzConvert(tzinfo);
    try std.testing.expectError(datetime.ZdtError.TzUndefined, err);

    const dt_Berlin = try datetime.Datetime.fromUnix(42, Duration.Resolution.nanosecond, tzinfo);

    tzinfo.deinit();
    _ = try tzinfo.loadTzfile("America/New_York", std.testing.allocator);
    const dt_NY = try dt_Berlin.tzConvert(tzinfo);

    try std.testing.expect(dt_Berlin.__unix == dt_NY.__unix);
    try std.testing.expect(dt_Berlin.nanosecond == dt_NY.nanosecond);
    try std.testing.expect(dt_Berlin.hour != dt_NY.hour);
}

test "make TZ with convenience func" {
    const off = try tz.fromOffset(42, "hello_world");
    try std.testing.expect(off.tzFile == null);
    try std.testing.expect(off.tzPosix == null);
    try std.testing.expect(off.tzOffset != null);

    var tzinfo = try tz.fromTzfile("Asia/Kolkata", std.testing.allocator);
    defer _ = tzinfo.deinit();
    try std.testing.expect(tzinfo.tzFile != null);
    try std.testing.expect(tzinfo.tzPosix == null);
    try std.testing.expect(tzinfo.tzOffset == null);
}

test "floor to date changes UTC offset" {
    var tzinfo = try tz.fromTzfile("Europe/Berlin", std.testing.allocator);
    defer _ = tzinfo.deinit();

    var dt = try datetime.Datetime.fromFields(.{ .year = 2023, .month = 10, .day = 29, .hour = 5, .tzinfo = tzinfo });
    var dt_floored = try dt.floorTo(Duration.Timespan.day);
    try std.testing.expectEqual(@as(u5, 0), dt_floored.hour);
    try std.testing.expectEqual(@as(u6, 0), dt_floored.minute);
    try std.testing.expectEqual(@as(u6, 0), dt_floored.second);
    try std.testing.expectEqual(@as(i20, 3600), dt.tzinfo.?.tzOffset.?.seconds_east);
    try std.testing.expectEqual(@as(i20, 7200), dt_floored.tzinfo.?.tzOffset.?.seconds_east);

    dt = try datetime.Datetime.fromFields(.{ .year = 2023, .month = 3, .day = 26, .hour = 3, .tzinfo = tzinfo });
    dt_floored = try dt.floorTo(Duration.Timespan.day);
    try std.testing.expectEqual(@as(u5, 0), dt_floored.hour);
    try std.testing.expectEqual(@as(u6, 0), dt_floored.minute);
    try std.testing.expectEqual(@as(u6, 0), dt_floored.second);
    try std.testing.expectEqual(@as(i20, 7200), dt.tzinfo.?.tzOffset.?.seconds_east);
    try std.testing.expectEqual(@as(i20, 3600), dt_floored.tzinfo.?.tzOffset.?.seconds_east);
}

test "load a lot of zones" {
    var tz_a = tz.TZ{};
    defer tz_a.deinit();
    var dt_a = datetime.Datetime{};
    const zones = [_][]const u8{
        "America/La_Paz",
        "Pacific/Saipan",
        "Asia/Muscat",
        "Pacific/Gambier",
        "Asia/Kolkata",
        "Asia/Anadyr",
        "Asia/Baku",
        "Africa/Maseru",
        "Europe/Brussels",
        "Indian/Mahe",
        "Africa/Abidjan",
        "Etc/GMT-1",
        "America/Guyana",
        "Mexico/BajaNorte",
        "Antarctica/Davis",
        "Europe/Malta",
        "Africa/Libreville",
        "Singapore",
        "America/Aruba",
        "Australia/Broken_Hill",
        "Asia/Yekaterinburg",
        "Europe/Sarajevo",
        "Europe/Warsaw",
        "Antarctica/Mawson",
        "Europe/Zurich",
        "Atlantic/Reykjavik",
        "Africa/Porto-Novo",
        "Asia/Vientiane",
        "America/Argentina/San_Juan",
        "Etc/GMT+3",
        "America/Maceio",
        "America/Manaus",
        "Poland",
        "US/Central",
        "Pacific/Auckland",
        "GMT0",
        "Asia/Kashgar",
        "Asia/Barnaul",
        "Etc/GMT-10",
        "Asia/Phnom_Penh",
        "America/Metlakatla",
        "America/Nome",
        "America/Anguilla",
        "Iceland",
        "America/Whitehorse",
        "Asia/Kuwait",
        "Asia/Almaty",
        "America/Indiana/Winamac",
        "America/Eirunepe",
        "Africa/Asmara",
        "Etc/GMT0",
        "Asia/Ujung_Pandang",
        "Jamaica",
        "Asia/Famagusta",
        "Asia/Jerusalem",
        "Australia/Yancowinna",
        "Brazil/DeNoronha",
        "America/St_Thomas",
        "EST",
        "America/Jujuy",
        "Pacific/Tongatapu",
        "America/Araguaina",
        "Australia/Queensland",
        "Pacific/Marquesas",
        "Europe/Mariehamn",
        "Europe/Belfast",
        "Africa/Malabo",
        "Europe/London",
        "Asia/Dacca",
        "America/Rainy_River",
        "US/Arizona",
        "America/Jamaica",
        "Asia/Pontianak",
        "Canada/Mountain",
        "America/Cordoba",
        "CST6CDT",
        "America/Tegucigalpa",
        "America/Pangnirtung",
        "GMT",
        "Atlantic/Canary",
        "America/Panama",
        "Africa/Mbabane",
        "Europe/Zagreb",
        "America/Coral_Harbour",
        "Australia/South",
        "Eire",
        "America/Chihuahua",
        "Africa/Johannesburg",
        "Asia/Aden",
        "Asia/Aqtobe",
        "America/St_Vincent",
        "Australia/Hobart",
        "Australia/Melbourne",
        "Asia/Saigon",
        "Europe/Copenhagen",
        "GMT+0",
        "America/Montserrat",
        "America/Fort_Wayne",
        "America/North_Dakota/Center",
        "America/Cuiaba",
        "Asia/Chita",
        "Europe/Simferopol",
        "Pacific/Wake",
        "Asia/Aqtau",
        "America/Recife",
        "Africa/Banjul",
        "Africa/Nairobi",
        "Asia/Yangon",
        "Asia/Novokuznetsk",
        "Asia/Ashgabat",
        "America/Belem",
        "PRC",
        "America/Cayenne",
        "Africa/Harare",
        "Asia/Magadan",
        "Atlantic/Faroe",
        "America/Atikokan",
        "Africa/Timbuktu",
        "Australia/Lord_Howe",
        "Europe/Rome",
        "Europe/Bucharest",
        "Africa/Tripoli",
        "Pacific/Honolulu",
        "America/Thule",
        "America/Merida",
        "Asia/Krasnoyarsk",
        "Atlantic/St_Helena",
        "America/Guayaquil",
        "Etc/GMT+9",
        "Asia/Irkutsk",
        "US/Hawaii",
        "America/Argentina/Ushuaia",
        "Europe/Kirov",
        "Asia/Kathmandu",
        "Europe/Luxembourg",
        "Africa/Ouagadougou",
        "America/Argentina/Catamarca",
        "Africa/Cairo",
        "America/Porto_Acre",
        "Europe/San_Marino",
        "Asia/Ho_Chi_Minh",
        "America/Cambridge_Bay",
        "Chile/Continental",
        "Pacific/Pago_Pago",
        "America/Fortaleza",
        "America/Port-au-Prince",
        "Africa/Gaborone",
        "Africa/Freetown",
        "America/Kralendijk",
        "America/Argentina/ComodRivadavia",
        "Atlantic/South_Georgia",
        "Europe/Bratislava",
        "Cuba",
        "Australia/Victoria",
        "Pacific/Apia",
        "NZ",
        "Pacific/Pohnpei",
        "America/North_Dakota/Beulah",
        "Australia/North",
        "US/Eastern",
        "NZ-CHAT",
        "Indian/Kerguelen",
        "America/Rankin_Inlet",
        "America/Creston",
        "Asia/Tbilisi",
        "America/Marigot",
        "Etc/GMT-2",
        "America/Winnipeg",
        "Europe/Oslo",
        "America/Tijuana",
        "Chile/EasterIsland",
        "America/Sitka",
        "America/Curacao",
        "Asia/Tokyo",
        "Brazil/East",
        "Asia/Dubai",
        "Africa/Juba",
        "Asia/Tehran",
        "America/Halifax",
        "Australia/Lindeman",
        "America/Blanc-Sablon",
        "Europe/Budapest",
        "Asia/Jayapura",
        "Pacific/Palau",
        "Hongkong",
        "America/Atka",
        "Asia/Atyrau",
        "Africa/Djibouti",
        "Atlantic/Stanley",
        "America/Santarem",
        "Antarctica/Casey",
        "America/Dominica",
        "Africa/Bangui",
        "Asia/Novosibirsk",
        "Europe/Guernsey",
        "Pacific/Yap",
        "Australia/Tasmania",
        "Africa/Lagos",
        "Etc/GMT-13",
        "Etc/GMT-9",
        "Canada/Central",
        "America/Ojinaga",
        "America/Costa_Rica",
        "Asia/Dhaka",
        "Asia/Amman",
        "Africa/Monrovia",
        "Asia/Qyzylorda",
        "Europe/Skopje",
        "Asia/Nicosia",
        "America/Ciudad_Juarez",
        "Israel",
        "Etc/GMT+5",
        "Africa/Kampala",
        "Asia/Calcutta",
        "Europe/Volgograd",
        "Asia/Beirut",
        "Australia/Perth",
        "America/Guatemala",
        "America/Indiana/Petersburg",
        "America/Paramaribo",
        "Asia/Baghdad",
        "Australia/Currie",
        "Pacific/Truk",
        "America/Porto_Velho",
        "Indian/Comoro",
        "Pacific/Midway",
        "Pacific/Easter",
        "Canada/Yukon",
        "America/Indiana/Vincennes",
        "Etc/GMT-5",
        "America/Punta_Arenas",
        "Mexico/BajaSur",
        "America/Ensenada",
        "America/Inuvik",
        "Australia/ACT",
        "EET",
        "America/Los_Angeles",
        "Asia/Srednekolymsk",
        "Zulu",
        "Europe/Jersey",
        "Europe/Zaporozhye",
        "America/Cancun",
        "Pacific/Tahiti",
        "Europe/Istanbul",
        "Africa/Maputo",
        "Asia/Kabul",
        "Europe/Busingen",
        "America/Detroit",
        "America/Argentina/Tucuman",
        "Asia/Qatar",
        "Europe/Saratov",
        "Europe/Belgrade",
        "America/Dawson",
        "Asia/Ulan_Bator",
        "Indian/Christmas",
        "Europe/Ulyanovsk",
        "Pacific/Guadalcanal",
        "Canada/Atlantic",
        "Africa/Ceuta",
        "Etc/GMT-4",
        "America/Antigua",
        "Antarctica/Vostok",
        "America/Mazatlan",
        "US/Michigan",
        "Australia/Eucla",
        "Africa/Addis_Ababa",
        "Africa/Lubumbashi",
        "Asia/Thimphu",
        "Antarctica/Syowa",
        "Europe/Ljubljana",
        "Asia/Urumqi",
        "America/St_Johns",
        "America/Godthab",
        "Europe/Riga",
        "Asia/Katmandu",
        "Pacific/Funafuti",
        "America/Moncton",
        "ROK",
        "Pacific/Chuuk",
        "Factory",
        "America/Swift_Current",
        "America/Goose_Bay",
        "Europe/Vatican",
        "America/Tortola",
        "America/Argentina/Cordoba",
        "America/Boa_Vista",
        "Africa/Sao_Tome",
        "Pacific/Nauru",
        "America/Argentina/Buenos_Aires",
        "Canada/Newfoundland",
        "Antarctica/McMurdo",
        "PST8PDT",
        "Australia/Brisbane",
        "Europe/Paris",
        "Africa/Khartoum",
        "Etc/GMT-3",
        "America/Catamarca",
        "Europe/Uzhgorod",
        "Pacific/Bougainville",
        "America/Noronha",
        "America/Guadeloupe",
        "Europe/Lisbon",
        "America/Kentucky/Monticello",
        "Asia/Harbin",
        "Europe/Kiev",
        "America/Cayman",
        "Pacific/Kanton",
        "America/Martinique",
        "America/Santa_Isabel",
        "America/Lower_Princes",
        "Pacific/Port_Moresby",
        "America/Thunder_Bay",
        "Asia/Dili",
        "Iran",
        "America/Hermosillo",
        "Europe/Samara",
        "America/Matamoros",
        "America/Bogota",
        "Europe/Tiraspol",
        "Atlantic/Jan_Mayen",
        "Africa/Accra",
        "America/Boise",
        "Libya",
        "Africa/Bissau",
        "WET",
        "Asia/Bangkok",
        "America/Puerto_Rico",
        "Asia/Pyongyang",
        "Etc/GMT-0",
        "Africa/Dar_es_Salaam",
        "America/Argentina/Salta",
        "Etc/GMT-6",
        "America/Shiprock",
        "America/Anchorage",
        "Atlantic/Azores",
        "America/St_Lucia",
        "America/Grenada",
        "Asia/Tomsk",
        "Asia/Colombo",
        "Europe/Athens",
        "America/Rosario",
        "Australia/Sydney",
        "Europe/Tallinn",
        "Asia/Singapore",
        "Europe/Astrakhan",
        "Africa/Windhoek",
        "Europe/Podgorica",
        "Africa/Douala",
        "Asia/Gaza",
        "Canada/Pacific",
        "Pacific/Rarotonga",
        "America/Rio_Branco",
        "Asia/Bahrain",
        "Pacific/Norfolk",
        "Pacific/Noumea",
        "Europe/Kaliningrad",
        "Greenwich",
        "US/Samoa",
        "Africa/Bujumbura",
        "America/Dawson_Creek",
        "Pacific/Niue",
        "America/Argentina/La_Rioja",
        "America/Glace_Bay",
        "Atlantic/Bermuda",
        "Asia/Hovd",
        "America/Campo_Grande",
        "Asia/Istanbul",
        "Asia/Tel_Aviv",
        "Australia/Adelaide",
        "America/Danmarkshavn",
        "Asia/Ulaanbaatar",
        "Pacific/Pitcairn",
        "Pacific/Guam",
        "Pacific/Samoa",
        "Asia/Qostanay",
        "America/Nipigon",
        "Africa/Nouakchott",
        "Asia/Bishkek",
        "GB",
        "Etc/GMT-7",
        "America/Yellowknife",
        "Indian/Antananarivo",
        "America/Belize",
        "Asia/Karachi",
        "Asia/Taipei",
        "Africa/Brazzaville",
        "Asia/Choibalsan",
        "GB-Eire",
        "Etc/GMT+0",
        "Asia/Sakhalin",
        "America/Mendoza",
        "Africa/Lusaka",
        "Canada/Saskatchewan",
        "America/St_Kitts",
        "Indian/Mayotte",
        "Europe/Isle_of_Man",
        "Indian/Cocos",
        "America/Grand_Turk",
        "W-SU",
        "America/Kentucky/Louisville",
        "Africa/Kigali",
        "America/Vancouver",
        "Europe/Prague",
        "Etc/GMT+6",
        "Africa/Blantyre",
        "Asia/Chungking",
        "Asia/Oral",
        "Pacific/Fiji",
        "Indian/Maldives",
        "Australia/LHI",
        "Australia/NSW",
        "US/Mountain",
        "Pacific/Chatham",
        "Africa/Kinshasa",
        "America/North_Dakota/New_Salem",
        "Europe/Nicosia",
        "Asia/Riyadh",
        "Pacific/Enderbury",
        "Africa/Casablanca",
        "Etc/UCT",
        "US/Indiana-Starke",
        "Universal",
        "Pacific/Wallis",
        "MST7MDT",
        "Asia/Khandyga",
        "Europe/Dublin",
        "America/Adak",
        "America/Monterrey",
        "Asia/Chongqing",
        "Europe/Minsk",
        "Antarctica/Macquarie",
        "Asia/Omsk",
        "America/Bahia",
        "Asia/Rangoon",
        "US/Aleutian",
        "Etc/GMT+12",
        "America/Indiana/Marengo",
        "Africa/Tunis",
        "Europe/Vaduz",
        "Portugal",
        "HST",
        "America/Santo_Domingo",
        "Pacific/Kosrae",
        "Etc/GMT+7",
        "Etc/GMT-12",
        "Asia/Dushanbe",
        "America/Indiana/Knox",
        "Pacific/Kiritimati",
        "America/Louisville",
        "America/Argentina/Mendoza",
        "Europe/Chisinau",
        "Etc/GMT+1",
        "Africa/Algiers",
        "Asia/Kuala_Lumpur",
        "Asia/Hebron",
        "America/Phoenix",
        "America/Caracas",
        "Asia/Manila",
        "Asia/Jakarta",
        "America/Edmonton",
        "Africa/Bamako",
        "Pacific/Tarawa",
        "America/Fort_Nelson",
        "America/St_Barthelemy",
        "Australia/Darwin",
        "Asia/Yerevan",
        "Asia/Yakutsk",
        "Europe/Tirane",
        "Navajo",
        "Etc/GMT+4",
        "Africa/Niamey",
        "Europe/Sofia",
        "Pacific/Fakaofo",
        "Antarctica/Palmer",
        "Asia/Thimbu",
        "Europe/Madrid",
        "US/East-Indiana",
        "Africa/Dakar",
        "Etc/Zulu",
        "Pacific/Kwajalein",
        "America/Argentina/Rio_Gallegos",
        "Etc/GMT-8",
        "GMT-0",
        "America/Nassau",
        "Europe/Berlin",
        "Europe/Vilnius",
        "Brazil/West",
        "Etc/GMT+11",
        "America/Menominee",
        "Etc/UTC",
        "America/Scoresbysund",
        "Pacific/Johnston",
        "America/Sao_Paulo",
        "America/Port_of_Spain",
        "Kwajalein",
        "America/Buenos_Aires",
        "Indian/Reunion",
        "Asia/Makassar",
        "America/Toronto",
        "Antarctica/DumontDUrville",
        "America/Indianapolis",
        "Asia/Brunei",
        "Asia/Kamchatka",
        "Etc/GMT+10",
        "CET",
        "Atlantic/Faeroe",
        "Atlantic/Cape_Verde",
        "Pacific/Galapagos",
        "US/Alaska",
        "Pacific/Ponape",
        "America/Resolute",
        "Turkey",
        "Europe/Moscow",
        "America/El_Salvador",
        "Antarctica/South_Pole",
        "Asia/Vladivostok",
        "America/Asuncion",
        "Asia/Samarkand",
        "Indian/Chagos",
        "Atlantic/Madeira",
        "Europe/Kyiv",
        "Asia/Macao",
        "MET",
        "EST5EDT",
        "Europe/Stockholm",
        "Africa/Asmera",
        "Japan",
        "America/Bahia_Banderas",
        "Asia/Damascus",
        "Europe/Helsinki",
        "America/Denver",
        "America/Iqaluit",
        "America/Managua",
        "Pacific/Majuro",
        "Etc/GMT+8",
        "America/Indiana/Tell_City",
        "America/Lima",
        "America/Nuuk",
        "Etc/GMT-14",
        "Africa/El_Aaiun",
        "America/Miquelon",
        "Africa/Ndjamena",
        "America/Indiana/Vevay",
        "Etc/GMT-11",
        "US/Pacific",
        "Asia/Seoul",
        "America/Barbados",
        "America/Regina",
        "UTC",
        "Etc/GMT+2",
        "Africa/Luanda",
        "America/Montreal",
        "Africa/Mogadishu",
        "America/Chicago",
        "Antarctica/Troll",
        "Egypt",
        "Asia/Ust-Nera",
        "ROC",
        "Pacific/Efate",
        "Asia/Macau",
        "Asia/Shanghai",
        "America/Mexico_City",
        "Etc/Greenwich",
        "America/Yakutat",
        "America/Virgin",
        "Africa/Conakry",
        "Etc/Universal",
        "localtime",
        "Australia/Canberra",
        "MST",
        "Asia/Kuching",
        "America/Montevideo",
        "America/Indiana/Indianapolis",
        "Asia/Tashkent",
        "America/Havana",
        "Canada/Eastern",
        "Europe/Andorra",
        "America/Argentina/San_Luis",
        "Europe/Gibraltar",
        "Europe/Amsterdam",
        "Etc/GMT",
        "Europe/Monaco",
        "America/Knox_IN",
        "America/New_York",
        "Indian/Mauritius",
        "America/Juneau",
        "UCT",
        "Asia/Hong_Kong",
        "America/Santiago",
        "Europe/Vienna",
        "Brazil/Acre",
        "Mexico/General",
        "Australia/West",
        "America/Argentina/Jujuy",
        "Africa/Lome",
        "Antarctica/Rothera",
        "Asia/Ashkhabad",
        "Arctic/Longyearbyen",
    };

    for (zones) |zone| {
        tz_a = try tz.fromTzfile(zone, std.testing.allocator);
        dt_a = try datetime.Datetime.fromUnix(1, Duration.Resolution.second, tz_a);
        tz_a.deinit();
    }
}

// test "conversion between random time zones" {
//     var tz_a = tz.TZ{};
//     var tz_b = tz.TZ{};
//     defer tz_a.deinit();
//     defer tz_b.deinit();
//     var dt_a = datetime.Datetime{};
//     var dt_b = datetime.Datetime{};
//     var dt_c = datetime.Datetime{};
//
//     tz_a = try tz.fromTzfile("Asia/Kolkata", std.testing.allocator);
//     tz_b = try tz.fromTzfile("Asia/Tokyo", std.testing.allocator);
//     dt_a = try datetime.Datetime.fromUnix(0, Duration.Resolution.second, tz_a);
//     dt_b = try datetime.Datetime.fromUnix(0, Duration.Resolution.second, tz_b);
//     dt_c = try dt_a.tzConvert(tz_b);
//     print("\na: {s}", .{dt_a});
//     print("\nb: {s}", .{dt_b});
//     print("\nc: {s}", .{dt_c});
//     print("\ndiff: {s}", .{dt_c.diff(dt_a)});
//     print("\ndiff: {s}", .{try dt_c.diffWall(dt_a)});
//     try testing.expect(std.meta.eql(dt_b, dt_c));
// }

// test "conversion between random time zones" {
//     var tz_a = tz.TZ{};
//     var tz_b = tz.TZ{};
//     defer tz_a.deinit();
//     defer tz_b.deinit();
//     var dt_a = datetime.Datetime{};
//     var dt_b = datetime.Datetime{};
//     var dt_a_str = std.ArrayList(u8).init(testing.allocator);
//     var dt_b_str = std.ArrayList(u8).init(testing.allocator);
//     defer dt_a_str.deinit();
//     defer dt_b_str.deinit();
//
//     tz_a = try tz.fromTzfile("Etc/GMT+6", std.testing.allocator);
//     tz_b = try tz.fromTzfile("Asia/Macau", std.testing.allocator);
//     dt_a = try datetime.Datetime.fromUnix(-1667178601, Duration.Resolution.second, tz_a);
//     dt_b = try datetime.Datetime.fromUnix(-1391111626, Duration.Resolution.second, tz_b);
//
//     // print("\n{s}", .{dt_a});
//     print("\n{s}", .{dt_b});
//     // try str.formatDatetime(dt_a_str.writer(), "%Y-%m-%dT%H:%M:%S%z", dt_a);
//     // print("\n{s}", .{dt_a_str.items});
//     try str.formatDatetime(dt_b_str.writer(), "%Y-%m-%dT%H:%M:%S%z", dt_b);
//     print("\n{s}", .{dt_b_str.items});
//
//     tz_a.deinit();
//     tz_b.deinit();
//
//     tz_a = try tz.fromTzfile("Atlantic/Madeira", std.testing.allocator);
//     tz_b = try tz.fromTzfile("Asia/Dacca", std.testing.allocator);
//     dt_a = try datetime.Datetime.fromUnix(-1139903279, Duration.Resolution.second, tz_a);
//     dt_b = try datetime.Datetime.fromUnix(-422363402, Duration.Resolution.second, tz_b);
//     tz_a.deinit();
//     tz_b.deinit();
//
//     tz_a = try tz.fromTzfile("Europe/Tiraspol", std.testing.allocator);
//     tz_b = try tz.fromTzfile("Pacific/Johnston", std.testing.allocator);
//     dt_a = try datetime.Datetime.fromUnix(202463633, Duration.Resolution.second, tz_a);
//     dt_b = try datetime.Datetime.fromUnix(1669207832, Duration.Resolution.second, tz_b);
//     tz_a.deinit();
//     tz_b.deinit();
// }
