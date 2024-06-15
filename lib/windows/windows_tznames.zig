//! A mapping of Windows time zone names to IANA db identifiers.
// This file is autogenerated by generate_wintz_mapping.py;
//
// --- Do not edit ---
//
// latest referesh: 2024-06-15T08:50:57+00:00
// windows_names are sorted alphabetically so we can do binary search (later)
pub const windows_names = [_][]const u8{
    "AUS Central Standard Time",
    "AUS Eastern Standard Time",
    "Afghanistan Standard Time",
    "Alaskan Standard Time",
    "Aleutian Standard Time",
    "Altai Standard Time",
    "Arab Standard Time",
    "Arabian Standard Time",
    "Arabic Standard Time",
    "Argentina Standard Time",
    "Astrakhan Standard Time",
    "Atlantic Standard Time",
    "Aus Central W. Standard Time",
    "Azerbaijan Standard Time",
    "Azores Standard Time",
    "Bahia Standard Time",
    "Bangladesh Standard Time",
    "Belarus Standard Time",
    "Bougainville Standard Time",
    "Canada Central Standard Time",
    "Cape Verde Standard Time",
    "Caucasus Standard Time",
    "Cen. Australia Standard Time",
    "Central America Standard Time",
    "Central Asia Standard Time",
    "Central Brazilian Standard Time",
    "Central Europe Standard Time",
    "Central European Standard Time",
    "Central Pacific Standard Time",
    "Central Standard Time",
    "Central Standard Time (Mexico)",
    "Chatham Islands Standard Time",
    "China Standard Time",
    "Cuba Standard Time",
    "Dateline Standard Time",
    "E. Africa Standard Time",
    "E. Australia Standard Time",
    "E. Europe Standard Time",
    "E. South America Standard Time",
    "Easter Island Standard Time",
    "Eastern Standard Time",
    "Eastern Standard Time (Mexico)",
    "Egypt Standard Time",
    "Ekaterinburg Standard Time",
    "FLE Standard Time",
    "Fiji Standard Time",
    "GMT Standard Time",
    "GTB Standard Time",
    "Georgian Standard Time",
    "Greenland Standard Time",
    "Greenwich Standard Time",
    "Haiti Standard Time",
    "Hawaiian Standard Time",
    "India Standard Time",
    "Iran Standard Time",
    "Israel Standard Time",
    "Jordan Standard Time",
    "Kaliningrad Standard Time",
    "Korea Standard Time",
    "Libya Standard Time",
    "Line Islands Standard Time",
    "Lord Howe Standard Time",
    "Magadan Standard Time",
    "Magallanes Standard Time",
    "Marquesas Standard Time",
    "Mauritius Standard Time",
    "Middle East Standard Time",
    "Montevideo Standard Time",
    "Morocco Standard Time",
    "Mountain Standard Time",
    "Mountain Standard Time (Mexico)",
    "Myanmar Standard Time",
    "N. Central Asia Standard Time",
    "Namibia Standard Time",
    "Nepal Standard Time",
    "New Zealand Standard Time",
    "Newfoundland Standard Time",
    "Norfolk Standard Time",
    "North Asia East Standard Time",
    "North Asia Standard Time",
    "North Korea Standard Time",
    "Omsk Standard Time",
    "Pacific SA Standard Time",
    "Pacific Standard Time",
    "Pacific Standard Time (Mexico)",
    "Pakistan Standard Time",
    "Paraguay Standard Time",
    "Qyzylorda Standard Time",
    "Romance Standard Time",
    "Russia Time Zone 10",
    "Russia Time Zone 11",
    "Russia Time Zone 3",
    "Russian Standard Time",
    "SA Eastern Standard Time",
    "SA Pacific Standard Time",
    "SA Western Standard Time",
    "SE Asia Standard Time",
    "Saint Pierre Standard Time",
    "Sakhalin Standard Time",
    "Samoa Standard Time",
    "Sao Tome Standard Time",
    "Saratov Standard Time",
    "Singapore Standard Time",
    "South Africa Standard Time",
    "South Sudan Standard Time",
    "Sri Lanka Standard Time",
    "Sudan Standard Time",
    "Syria Standard Time",
    "Taipei Standard Time",
    "Tasmania Standard Time",
    "Tocantins Standard Time",
    "Tokyo Standard Time",
    "Tomsk Standard Time",
    "Tonga Standard Time",
    "Transbaikal Standard Time",
    "Turkey Standard Time",
    "Turks And Caicos Standard Time",
    "US Eastern Standard Time",
    "US Mountain Standard Time",
    "UTC",
    "UTC+12",
    "UTC+13",
    "UTC-02",
    "UTC-08",
    "UTC-09",
    "UTC-11",
    "Ulaanbaatar Standard Time",
    "Venezuela Standard Time",
    "Vladivostok Standard Time",
    "Volgograd Standard Time",
    "W. Australia Standard Time",
    "W. Central Africa Standard Time",
    "W. Europe Standard Time",
    "W. Mongolia Standard Time",
    "West Asia Standard Time",
    "West Bank Standard Time",
    "West Pacific Standard Time",
    "Yakutsk Standard Time",
    "Yukon Standard Time",
};

pub const iana_names = [_][]const u8{
    "Australia/Darwin",
    "Australia/Sydney",
    "Asia/Kabul",
    "America/Anchorage",
    "America/Adak",
    "Asia/Barnaul",
    "Asia/Riyadh",
    "Asia/Dubai",
    "Asia/Baghdad",
    "America/Buenos_Aires",
    "Europe/Astrakhan",
    "America/Halifax",
    "Australia/Eucla",
    "Asia/Baku",
    "Atlantic/Azores",
    "America/Bahia",
    "Asia/Dhaka",
    "Europe/Minsk",
    "Pacific/Bougainville",
    "America/Regina",
    "Atlantic/Cape_Verde",
    "Asia/Yerevan",
    "Australia/Adelaide",
    "America/Guatemala",
    "Asia/Bishkek",
    "America/Cuiaba",
    "Europe/Budapest",
    "Europe/Warsaw",
    "Pacific/Guadalcanal",
    "America/Chicago",
    "America/Mexico_City",
    "Pacific/Chatham",
    "Asia/Shanghai",
    "America/Havana",
    "Etc/GMT+12",
    "Africa/Nairobi",
    "Australia/Brisbane",
    "Europe/Chisinau",
    "America/Sao_Paulo",
    "Pacific/Easter",
    "America/New_York",
    "America/Cancun",
    "Africa/Cairo",
    "Asia/Yekaterinburg",
    "Europe/Kiev",
    "Pacific/Fiji",
    "Europe/London",
    "Europe/Bucharest",
    "Asia/Tbilisi",
    "America/Godthab",
    "Atlantic/Reykjavik",
    "America/Port-au-Prince",
    "Pacific/Honolulu",
    "Asia/Calcutta",
    "Asia/Tehran",
    "Asia/Jerusalem",
    "Asia/Amman",
    "Europe/Kaliningrad",
    "Asia/Seoul",
    "Africa/Tripoli",
    "Pacific/Kiritimati",
    "Australia/Lord_Howe",
    "Asia/Magadan",
    "America/Punta_Arenas",
    "Pacific/Marquesas",
    "Indian/Mauritius",
    "Asia/Beirut",
    "America/Montevideo",
    "Africa/Casablanca",
    "America/Denver",
    "America/Mazatlan",
    "Asia/Rangoon",
    "Asia/Novosibirsk",
    "Africa/Windhoek",
    "Asia/Katmandu",
    "Pacific/Auckland",
    "America/St_Johns",
    "Pacific/Norfolk",
    "Asia/Irkutsk",
    "Asia/Krasnoyarsk",
    "Asia/Pyongyang",
    "Asia/Omsk",
    "America/Santiago",
    "America/Los_Angeles",
    "America/Tijuana",
    "Asia/Karachi",
    "America/Asuncion",
    "Asia/Qyzylorda",
    "Europe/Paris",
    "Asia/Srednekolymsk",
    "Asia/Kamchatka",
    "Europe/Samara",
    "Europe/Moscow",
    "America/Cayenne",
    "America/Bogota",
    "America/La_Paz",
    "Asia/Bangkok",
    "America/Miquelon",
    "Asia/Sakhalin",
    "Pacific/Apia",
    "Africa/Sao_Tome",
    "Europe/Saratov",
    "Asia/Singapore",
    "Africa/Johannesburg",
    "Africa/Juba",
    "Asia/Colombo",
    "Africa/Khartoum",
    "Asia/Damascus",
    "Asia/Taipei",
    "Australia/Hobart",
    "America/Araguaina",
    "Asia/Tokyo",
    "Asia/Tomsk",
    "Pacific/Tongatapu",
    "Asia/Chita",
    "Europe/Istanbul",
    "America/Grand_Turk",
    "America/Indianapolis",
    "America/Phoenix",
    "Etc/UTC",
    "Etc/GMT-12",
    "Etc/GMT-13",
    "Etc/GMT+2",
    "Etc/GMT+8",
    "Etc/GMT+9",
    "Etc/GMT+11",
    "Asia/Ulaanbaatar",
    "America/Caracas",
    "Asia/Vladivostok",
    "Europe/Volgograd",
    "Australia/Perth",
    "Africa/Lagos",
    "Europe/Berlin",
    "Asia/Hovd",
    "Asia/Tashkent",
    "Asia/Hebron",
    "Pacific/Port_Moresby",
    "Asia/Yakutsk",
    "America/Whitehorse",
};
