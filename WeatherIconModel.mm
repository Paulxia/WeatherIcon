/*
 *  WeatherView.mm
 *  
 *
 *  Created by David Ashman on 1/12/09.
 *  Copyright 2009 David Ashman. All rights reserved.
 *
 */

#import "WeatherIconModel.h"
#import <substrate.h>
#import <SpringBoard/SBIconModel.h>
#import <SpringBoard/SBApplicationIcon.h>
#import <SpringBoard/SleepProofTimer.h>
#import <UIKit/UIStringDrawing.h>
#import <UIKit/UIKit.h>
#import <Foundation/NSObjCRuntime.h>

static NSString* defaultTempStyle(@""
	"font-family: Helvetica; "
	"font-weight: bold; "
	"font-size: 13px; "
	"color: white; "
	"margin-top: 40px; "
	"margin-left: 3px; "
	"width: %dpx; "
	"text-align: center; "
	"text-shadow: rgba(0, 0, 0, 0.2) 1px 1px 0px; "
"");

static NSMutableDictionary* kweatherMapping;

static void initKweatherMapping()
{
	if (kweatherMapping)
		return;

	kweatherMapping = [[NSMutableDictionary alloc] initWithCapacity:50];
	[kweatherMapping setValue:@"tstorm3" forKey:@"0"];
	[kweatherMapping setValue:@"tstorm3" forKey:@"1"];
	[kweatherMapping setValue:@"tstorm3" forKey:@"2"];
	[kweatherMapping setValue:@"tstorm3" forKey:@"3"];
	[kweatherMapping setValue:@"tstorm2" forKey:@"4"];
	[kweatherMapping setValue:@"sleet" forKey:@"5"];
	[kweatherMapping setValue:@"sleet" forKey:@"6"];
	[kweatherMapping setValue:@"sleet" forKey:@"7"];
	[kweatherMapping setValue:@"hail" forKey:@"8"];
	[kweatherMapping setValue:@"light_rain" forKey:@"9"];
	[kweatherMapping setValue:@"hail" forKey:@"10"];
	[kweatherMapping setValue:@"shower2" forKey:@"11"];
	[kweatherMapping setValue:@"shower2" forKey:@"12"];
	[kweatherMapping setValue:@"snow1" forKey:@"13"];
	[kweatherMapping setValue:@"snow2" forKey:@"14"];
	[kweatherMapping setValue:@"snow3" forKey:@"15"];
	[kweatherMapping setValue:@"snow4" forKey:@"16"];
	[kweatherMapping setValue:@"hail" forKey:@"17"];
	[kweatherMapping setValue:@"sleet" forKey:@"18"];
	[kweatherMapping setValue:@"mist" forKey:@"19"];
	[kweatherMapping setValue:@"fog" forKey:@"20"];
	[kweatherMapping setValue:@"mist" forKey:@"21"];
	[kweatherMapping setValue:@"fog" forKey:@"22"];
	[kweatherMapping setValue:@"sunny" forKey:@"23"];
	[kweatherMapping setValue:@"fog" forKey:@"24"];
	[kweatherMapping setValue:@"cloudy5" forKey:@"25"];
	[kweatherMapping setValue:@"cloudy5" forKey:@"26"];
	[kweatherMapping setValue:@"cloudy4" forKey:@"27"];
	[kweatherMapping setValue:@"cloudy4" forKey:@"28"];
	[kweatherMapping setValue:@"cloudy2" forKey:@"29"];
	[kweatherMapping setValue:@"cloudy2" forKey:@"30"];
	[kweatherMapping setValue:@"sunny" forKey:@"31"];
	[kweatherMapping setValue:@"sunny" forKey:@"32"];
	[kweatherMapping setValue:@"cloudy1" forKey:@"33"];
	[kweatherMapping setValue:@"cloudy1" forKey:@"34"];
	[kweatherMapping setValue:@"hail" forKey:@"35"];
	[kweatherMapping setValue:@"sunny" forKey:@"36"];
	[kweatherMapping setValue:@"tstorm1" forKey:@"37"];
	[kweatherMapping setValue:@"tstorm2" forKey:@"38"];
	[kweatherMapping setValue:@"tstorm2" forKey:@"39"];
	[kweatherMapping setValue:@"shower1" forKey:@"40"];
	[kweatherMapping setValue:@"snow5" forKey:@"41"];
	[kweatherMapping setValue:@"snow3" forKey:@"42"];
	[kweatherMapping setValue:@"snow5" forKey:@"43"];
	[kweatherMapping setValue:@"cloudy2" forKey:@"44"];
	[kweatherMapping setValue:@"tstorm2" forKey:@"45"];
	[kweatherMapping setValue:@"snow3" forKey:@"46"];
	[kweatherMapping setValue:@"tstorm1" forKey:@"47"];
	[kweatherMapping setValue:@"dunno" forKey:@"3200"];
}

@implementation WeatherIconModel

@synthesize applicationIcon;
@synthesize temp, windChill, code, tempStyle, tempStyleNight, imageScale, imageMarginTop, type;
@synthesize sunset, sunrise, night;
@synthesize weatherIcon;
@synthesize isCelsius, overrideLocation, showFeelsLike, location, refreshInterval;
@synthesize nextRefreshTime, lastUpdateTime;

+ (NSMutableDictionary*) preferences
{
	NSString* prefsPath = @"/var/mobile/Library/Preferences/com.ashman.WeatherIcon.plist";
	return [NSMutableDictionary dictionaryWithContentsOfFile:prefsPath];
}


- (void) _parsePreferences
{
	NSMutableDictionary* prefs = [WeatherIconModel preferences];
	if (prefs)
	{
		if (NSNumber* ol = [prefs objectForKey:@"OverrideLocation"])
			self.overrideLocation = [ol boolValue];
		NSLog(@"WI: Override Location: %d", self.overrideLocation);

		if (NSNumber* chill = [prefs objectForKey:@"ShowFeelsLike"])
			self.showFeelsLike = [chill boolValue];
		NSLog(@"WI: Show Feels Like: %d", self.showFeelsLike);

		if (self.overrideLocation)
		{
			if (NSString* loc = [prefs objectForKey:@"Location"])
				self.location = [NSString stringWithString:loc];

			if (NSNumber* celsius = [prefs objectForKey:@"Celsius"])
				self.isCelsius = [celsius boolValue];
		}
		else
		{
			[self _parseWeatherPreferences];
		}

		NSLog(@"WI: Location: %@", self.location);
		NSLog(@"WI: Celsius: %@", (self.isCelsius ? @"YES" : @"NO"));

		if (NSNumber* interval = [prefs objectForKey:@"RefreshInterval"])
			self.refreshInterval = ([interval intValue] * 60);
		NSLog(@"WI: Refresh Interval: %d seconds", self.refreshInterval);
	}
	else
	{
		prefs = [NSMutableDictionary dictionaryWithCapacity:4];
		[prefs setValue:[NSNumber numberWithBool:self.overrideLocation] forKey:@"OverrideLocation"];
		[prefs setValue:self.location forKey:@"Location"];
		[prefs setValue:[NSNumber numberWithBool:self.isCelsius] forKey:@"Celsius"];
		[prefs setValue:[NSNumber numberWithBool:self.showFeelsLike] forKey:@"ShowFeelsLike"];
		[prefs setValue:[NSNumber numberWithInt:(int)(self.refreshInterval / 60)] forKey:@"RefreshInterval"];
		[prefs setValue:@"com.apple.weather" forKey:@"WeatherBundleIdentifier"];

	        NSString* prefsPath = @"/var/mobile/Library/Preferences/com.ashman.WeatherIcon.plist";
		[prefs writeToFile:prefsPath atomically:YES];
	}

	NSBundle* bundle = [NSBundle mainBundle];
	NSString* themePrefs = [bundle pathForResource:@"com.ashman.WeatherIcon" ofType:@"plist"];
	if (themePrefs)
	{
		NSDictionary* dict = [NSDictionary dictionaryWithContentsOfFile:themePrefs];
		if (dict)
		{
			NSLog(@"Loading theme prefs: %@", themePrefs);

			if (NSString* type = [dict objectForKey:@"Type"])
			{
				self.type = [NSString stringWithString:type];
				initKweatherMapping();
			}

			if (NSString* style = [dict objectForKey:@"TempStyle"])
				self.tempStyle = [self.tempStyle stringByAppendingString:style];

			if (NSString* nstyle = [dict objectForKey:@"TempStyleNight"])
			        self.tempStyleNight = [self.tempStyle stringByAppendingString:nstyle];
			else
				self.tempStyleNight = self.tempStyle;

			if (NSNumber* scale = [dict objectForKey:@"ImageScale"])
				self.imageScale = [scale floatValue];

			if (NSNumber* top = [dict objectForKey:@"ImageMarginTop"])
				self.imageMarginTop = [top intValue];
		}
	}	
}

- (void) _parseWeatherPreferences
{
	NSString* prefsPath = @"/var/mobile/Library/Preferences/com.apple.weather.plist";
	NSDictionary* dict = [NSDictionary dictionaryWithContentsOfFile:prefsPath];

	if (dict)
	{
		self.isCelsius = [[dict objectForKey:@"Celsius"] boolValue];

//		NSNumber* activeCity = [dict objectForKey:@"ActiveCity"];
		NSArray* cities = [dict objectForKey:@"Cities"];
		if (cities.count > 0)
		{
			NSDictionary* city = [cities objectAtIndex:0];
			self.location = [[city objectForKey:@"Zip"] substringToIndex:8];
		}	
	}
}

- (id) initWithIcon:(SBIcon*)icon
{
	self.applicationIcon = icon;
	self.temp = @"?";
	self.code = @"3200";
	self.tempStyle = [NSString stringWithFormat:defaultTempStyle, (int)icon.frame.size.width];
	self.tempStyleNight = self.tempStyle;
	self.imageScale = 1.0;
	self.imageMarginTop = 0;
	self.isCelsius = false;
	self.overrideLocation = false;
	self.showFeelsLike = false;
	self.refreshInterval = 900;

	[self _parsePreferences];

	self.nextRefreshTime = [NSDate date];
	[self _initWeatherIcon];

	return self;
}

- (void)parser:(NSXMLParser *)parser
didStartElement:(NSString *)elementName
namespaceURI:(NSString *)namespaceURI
qualifiedName:(NSString *)qName
   attributes:(NSDictionary *)attributeDict
{
	if ([elementName isEqualToString:@"yweather:astronomy"])
	{
		self.sunrise = [NSString stringWithString:[attributeDict objectForKey:@"sunrise"]];
		self.sunset = [NSString stringWithString:[attributeDict objectForKey:@"sunset"]];
		NSLog(@"WI: Sunrise: %@", self.sunrise);
		NSLog(@"WI: Sunset: %@", self.sunset);
	}
	else if ([elementName isEqualToString:@"yweather:wind"])
	{
		self.windChill = [NSString stringWithString:[attributeDict objectForKey:@"chill"]];
		NSLog(@"WI: Wind Chill: %@", self.windChill);
	}
	else if ([elementName isEqualToString:@"yweather:condition"])
	{
		self.temp = [NSString stringWithString:[attributeDict objectForKey:@"temp"]];
		NSLog(@"WI: Temp: %@", self.temp);
		self.code = [NSString stringWithString:[attributeDict objectForKey:@"code"]];
		NSLog(@"WI: Code: %@", self.code);

		self.lastUpdateTime = [NSDate date];
		NSLog(@"WI: Last Update Time: %@", self.lastUpdateTime);

		self.night = false;
		if (self.sunrise && self.sunset)
		{
			NSDateFormatter* format = [[[NSDateFormatter alloc] init] autorelease];
			[format setDateFormat:@"HH:mm"];
			NSString* now = [format stringFromDate:self.lastUpdateTime];
			NSLog(@"WI: Update Time: %@", now);

			//AM/PM
			NSString* srAM = [self.sunrise substringFromIndex:self.sunrise.length - 2];
			NSString* ssAM = [self.sunset substringFromIndex:self.sunset.length - 2];
			
			// Raw time	
			NSString* rsr = [self.sunrise substringToIndex:self.sunrise.length - 3];
			NSString* rss = [self.sunset substringToIndex:self.sunset.length - 3];

			// parts
			NSArray* na = [now componentsSeparatedByString:@":"];
			NSArray* sra = [rsr componentsSeparatedByString:@":"];
			NSArray* ssa = [rss componentsSeparatedByString:@":"];

			// check the hour
			int nh = [[na objectAtIndex:0] intValue];
			int srh = [[sra objectAtIndex:0] intValue];
			int ssh = [[ssa objectAtIndex:0] intValue];

			// account for AM/PM
			if ([srAM isEqualToString:@"pm"])
				srh += 12;

			if ([ssAM isEqualToString:@"pm"])
				ssh += 12;

			NSLog(@"WI: Hours: %d, %d, %d", nh, srh, ssh);

			int nm = [[na objectAtIndex:1] intValue] + (nh * 60);
			int srm = [[sra objectAtIndex:1] intValue] + (srh * 60);
			int ssm = [[ssa objectAtIndex:1] intValue] + (ssh * 60);

			NSLog(@"WI: Minutes: %d, %d, %d", nm, srm, ssm);

			self.night = (nm < srm || nm > ssm);
		}
		NSLog(@"WI: Night? %d", self.night);
	}
}

- (void)parser:(NSXMLParser *)parser
didEndElement:(NSString *)elementName
namespaceURI:(NSString *)namespaceURI
qualifiedName:(NSString *)qName
{
}


- (void)parser:(NSXMLParser *)parser
foundCharacters:(NSString *)string
{   
}

- (void) refresh
{
	NSDate* now = [NSDate date];
//	NSLog(@"WI: Checking refresh dates: %@ vs %@", now, self.nextRefreshTime);

	// are we ready for an update?
	if ([now compare:self.nextRefreshTime] == NSOrderedAscending)
	{
//		NSLog(@"WI: No refresh yet.");
		return;
	}

	[NSThread detachNewThreadSelector:@selector(_refreshInBackground) toTarget:self withObject:nil];
}

- (void) _refresh
{
	// reparse the preferences
	if (!self.overrideLocation)
		[self _parseWeatherPreferences];

	if (!self.location)
	{
		NSLog(@"WI: No location set.");
		return;
	}

	NSLog(@"WI: Refreshing weather for %@...", self.location);
	NSString* urlStr = [NSString stringWithFormat:@"http://weather.yahooapis.com/forecastrss?p=%@&u=%@", self.location, (self.isCelsius ? @"c" : @"f")];
	NSURL* url = [NSURL URLWithString:urlStr];
	NSXMLParser* parser = [[NSXMLParser alloc] initWithContentsOfURL:url];
	[parser setDelegate:self];
	[parser parse];
	[parser release];

//	NSLog(@"WI: Did the update succeed? %@ vs %@", self.lastUpdateTime, self.nextRefreshTime);
	if (!self.lastUpdateTime || [self.lastUpdateTime compare:self.nextRefreshTime] == NSOrderedAscending)
	{
		NSLog(@"WI: Update failed.");
		return;
	}

	if (!self.temp)
		self.temp = @"?";

	if (!self.code)
		self.code = @"3200";

	self.nextRefreshTime = [NSDate dateWithTimeIntervalSinceNow:self.refreshInterval];
	NSLog(@"WI: Next refresh time: %@", self.nextRefreshTime);

}

- (void) _refreshInBackground
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	[self _refresh];
	[pool release];

	// update the weather info
	[self performSelectorOnMainThread:@selector(_updateWeatherIcon) withObject:nil waitUntilDone:NO];
}

- (void) _initWeatherIcon
{
	[self _refresh];
	[self _updateWeatherIcon];
}

- (UIImage*) findWeatherImage:(NSBundle*) bundle prefix:(NSString*) prefix code:(NSString*) code suffix:(NSString*) suffix
{
	NSString* name = [[prefix stringByAppendingString:code] stringByAppendingString:suffix];
	NSString* path = [bundle pathForResource:name ofType:@"png"];
	UIImage* image = (path ? [UIImage imageWithContentsOfFile:path] : nil);
	if (image)
	{
		NSLog(@"WI: Found %@ Image: %@", prefix, path);
		return image;
	}

	return nil;
}

- (UIImage*) findWeatherImage:(BOOL) background
{
	NSString* blank = @"";
	NSString* prefix = (background ? @"weatherbg" : @"weather");
	NSString* code = self.code;

	if (!background && [self.type isEqualToString:@"kweather"])
	{
		code = [kweatherMapping objectForKey:self.code];
		NSLog(@"WI: Mapping %@ to %@", self.code, code);
		prefix = blank;
	}

	NSLog(@"WI: Find image for %@", code);
        NSBundle* bundle = [NSBundle mainBundle];
	NSString* suffix = (self.night ? @"_night" : @"_day");	

	if (UIImage* img = [self findWeatherImage:bundle prefix:prefix code:code suffix:suffix])
		return img;

	if (UIImage* img = [self findWeatherImage:bundle prefix:prefix code:blank suffix:suffix])
		return img;

	if (UIImage* img = [self findWeatherImage:bundle prefix:prefix code:code suffix:blank])
		return img;

	if (UIImage* img = [self findWeatherImage:bundle prefix:prefix code:blank suffix:blank])
		return img;

	return nil;
}

- (void) _updateWeatherIcon
{
	UIImage* bgIcon = [self findWeatherImage:YES];
	UIGraphicsBeginImageContext(bgIcon.size);

//	NSLog(@"WI: Drawing Background");
	[bgIcon drawAtPoint:CGPointMake(0, 0)];	

//	NSLog(@"WI: Drawing Weather Image");
	UIImage* weatherImage = [self findWeatherImage:NO];
	float width = weatherImage.size.width * self.imageScale;
	float height = weatherImage.size.height * self.imageScale;
        CGRect iconRect = CGRectMake((self.applicationIcon.frame.size.width - width) / 2, self.imageMarginTop, width, height);
	[weatherImage drawInRect:iconRect];

//	NSLog(@"WI: Drawing Temperature");
	NSString* t =[(self.showFeelsLike ? self.windChill : self.temp) stringByAppendingString: @"\u00B0"];
       	[t drawAtPoint:CGPointMake(0, 0) withStyle:(self.night ? self.tempStyleNight : self.tempStyle)];

	self.weatherIcon = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();

	NSArray* views = self.applicationIcon.subviews;
	for (int i = 0; i < views.count; i++)
		[[views objectAtIndex:i] setNeedsDisplay];
}

- (UIImage*) icon
{
	return self.weatherIcon;
}

- (void) dealloc
{
	[self.applicationIcon release];
	[self.temp release];
	[self.tempStyle release];
	[self.code release];
	[self.location release];
	[self.lastUpdateTime release];
	[self.nextRefreshTime release];
	[super dealloc];
}
@end