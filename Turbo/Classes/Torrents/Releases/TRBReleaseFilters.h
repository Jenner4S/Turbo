/*
 The MIT License (MIT)

 Copyright (c) 2014 Mike Godenzi

 Permission is hereby granted, free of charge, to any person obtaining a copy of
 this software and associated documentation files (the "Software"), to deal in
 the Software without restriction, including without limitation the rights to
 use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
 the Software, and to permit persons to whom the Software is furnished to do so,
 subject to the following conditions:

 The above copyright notice and this permission notice shall be included in all
 copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
 FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
 COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
 IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
 CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

typedef NS_ENUM(NSUInteger, TRBReleaseType) {
	TRBReleaseTypeMovie = 1,
	TRBReleaseTypePC,
	TRBReleaseTypeTVShow,
	TRBReleaseTypeWii,
	TRBReleaseTypeXbox360,
	TRBReleaseTypePS3,

	TRBReleaseTypeCount = TRBReleaseTypePS3,
};

static NSString * const TRBReleaseTypes[TRBReleaseTypeCount] = {@"Movie", @"PC", @"TV Show", @"Wii", @"Xbox 360", @"PS3"};

typedef NS_ENUM(NSUInteger, TRBReleaseSubType) {
	TRBReleaseSubTypeP2P = 1,
	TRBReleaseSubTypeScene,

	TRBReleaseSubTypeCount = TRBReleaseSubTypeScene,
};

static NSString * const TRBReleaseSubTypes[TRBReleaseSubTypeCount] = {@"P2P", @"Scene"};

typedef NS_ENUM(NSUInteger, TRBReleaseVideoFormat) {
	TRBReleaseVideoFormatDVDR = 1,
	TRBReleaseVideoFormatX264,
	TRBReleaseVideoFormatXVId,
	TRBReleaseVideoFormatDLC,
	TRBReleaseVideoFormatISO,
	TRBReleaseVideoFormatVC,
	TRBReleaseVideoFormatWiiware,
	TRBReleaseVideoFormatXBLA,
	TRBReleaseVideoFormatLauncher,
	TRBReleaseVideoFormatUnlocker,
	TRBReleaseVideoFormatVCD,
	TRBReleaseVideoFormatSVCD,
	TRBReleaseVideoFormatVOB,
	TRBReleaseVideoFormatWMV,
	TRBReleaseVideoFormatJB,

	TRBReleaseVideoFormatCount = TRBReleaseVideoFormatJB,
};

static NSString * const TRBReleaseVideoFormats[TRBReleaseVideoFormatCount] = {@"DVDR", @"x264", @"Xvid", @"DLC", @"ISO", @"VC", @"Wiiware", @"XBLA", @"Launcher", @"Unlocker", @"VCD", @"SVCD", @"VOB", @"WMV", @"JB"};

typedef NS_ENUM(NSUInteger, TRBReleaseSource) {
	TRBReleaseSourceUnknown = 1,
	TRBReleaseSource1080p,
	TRBReleaseSource720p,
	TRBReleaseSourceBDRip,
	TRBReleaseSourceCable,
	TRBReleaseSourceCAM,
	TRBReleaseSourceDSR,
	TRBReleaseSourceDVD,
	TRBReleaseSourceDVDRip,
	TRBReleaseSourceDVDSCR,
	TRBReleaseSourceHDRip,
	TRBReleaseSourceHDTV,
	TRBReleaseSourceLaserDisc,
	TRBReleaseSourceNetwork,
	TRBReleaseSourceNTSC,
	TRBReleaseSourcePAL,
	TRBReleaseSourcePDTV,
	TRBReleaseSourcePDVD,
	TRBReleaseSourcePPV,
	TRBReleaseSourcePreair,
	TRBReleaseSourceR5,
	TRBReleaseSourceScreener,
	TRBReleaseSourceTelecine,
	TRBReleaseSourceTelesync,
	TRBReleaseSourceTVRip,
	TRBReleaseSourceVCDRip,
	TRBReleaseSourceVHSRip,
	TRBReleaseSourceWorkprint,
	TRBReleaseSourceRF,
	TRBReleaseSourceUSA,
	TRBReleaseSourceEUR,
	TRBReleaseSourceWebSCR,

	TRBReleaseSourceCount = TRBReleaseSourceWebSCR,
};

static NSString * const TRBReleaseSources[TRBReleaseSourceCount] = {@"Unknown", @"1080p", @"720p", @"BDRip", @"Cable", @"CAM", @"DSR", @"DVD", @"DVDRip", @"DVDSrc", @"HDRip", @"HDTV", @"LaserDisc", @"Network", @"NTSC", @"PAL", @"PDTV", @"PDVD", @"PPV", @"Preair", @"R5", @"Screener", @"Telecine", @"Telesync", @"TVRip", @"VCDRip", @"VHSRip", @"Workprint", @"RF", @"USA", @"EUR", @"WebScr"};

typedef NS_ENUM(NSUInteger, TRBReleaseGenre) {
	TRBReleaseGenreUnknown = 1,
	TRBReleaseGenreAction,
	TRBReleaseGenreComedy,
	TRBReleaseGenreThriller,
	TRBReleaseGenreHorror,
	TRBReleaseGenreAnimation,
	TRBReleaseGenreDrama,
	TRBReleaseGenreFantasy,
	TRBReleaseGenreDocumentary,
	TRBReleaseGenreCrime,
	TRBReleaseGenreFamily,
	TRBReleaseGenreGameShow,
	TRBReleaseGenreRealtyTV,
	TRBReleaseGenreBiography,
	TRBReleaseGenreAdventure,
	TRBReleaseGenreMystery,
	TRBReleaseGenreWestern,
	TRBReleaseGenreRomance,
	TRBReleaseGenreShort,
	TRBReleaseGenreFilmNoir,
	TRBReleaseGenreMusic,
	TRBReleaseGenreMusical,
	TRBReleaseGenreAdult,
	TRBReleaseGenreSciFi,
	TRBReleaseGenreWar,
	TRBReleaseGenreHistory,
	TRBReleaseGenreTalkShow,
	TRBReleaseGenreSport,
	TRBReleaseGenreNews,

	TRBReleaseGenreCount = TRBReleaseGenreNews,
};

static NSString * const TRBReleaseGenres[TRBReleaseGenreCount] = {@"Unknown", @"Action", @"Comedy", @"Thriller", @"Horror", @"Animation", @"Drama", @"Fantasy", @"Documentary", @"Crime", @"Family", @"GameShow", @"RealtyTV", @"Biography", @"Adventure", @"Mystery", @"Western", @"Romance", @"Short", @"FilmNoir", @"Music", @"Musical", @"Adult", @"SciFi", @"War", @"History", @"TalkShow", @"Sport", @"News"};

#define kTRBStaticFiltersCount 5
#define kTRBAllFiltersCount 6

static NSUInteger const TRBStaticFilterCounts[kTRBStaticFiltersCount] = {TRBReleaseTypeCount, TRBReleaseSubTypeCount, TRBReleaseVideoFormatCount, TRBReleaseSourceCount, TRBReleaseGenreCount};
static NSString * const TRBReleaseFilterTitles[kTRBAllFiltersCount] = {@"Type", @"Subtype", @"Video Format", @"Source", @"Genre", @"Year"};

static NSString * const * TRBReleaseStaticFilters[kTRBStaticFiltersCount] = {TRBReleaseTypes, TRBReleaseSubTypes, TRBReleaseVideoFormats, TRBReleaseSources, TRBReleaseGenres};

#define kTRBReleaseStartingYear 1980
