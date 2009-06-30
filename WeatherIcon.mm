/*
 *  WeatherIcon.mm
 *  
 *
 *  Created by David Ashman on 1/12/09.
 *  Copyright 2009 David Ashman. All rights reserved.
 *
 */

#include <substrate.h>
#import "WeatherIconController.h"
#import "WeatherIconSettings.h"
#import <SpringBoard/SBIcon.h>
#import <SpringBoard/SBIconList.h>
#import <SpringBoard/SBIconController.h>
#import <SpringBoard/SBUIController.h>
#import <SpringBoard/SBStatusBar.h>
#import <SpringBoard/SBStatusBarController.h>
#import <SpringBoard/SBStatusBarContentsView.h>
#import <SpringBoard/SBStatusBarContentView.h>
#import <SpringBoard/SBStatusBarIndicatorsView.h>
#import <SpringBoard/SBWidgetApplicationIcon.h>
#import <SpringBoard/SBInstalledApplicationIcon.h>
#import <SpringBoard/SBBookmarkIcon.h>
#import <SpringBoard/SBApplication.h>
#import <SpringBoard/SBAwayView.h>
#import <SpringBoard/SBAwayController.h>
#import <SpringBoard/SBIconModel.h>
#import <SpringBoard/SpringBoard.h>
#import <UIKit/UIKit.h>
 
@protocol WeatherIcon
- (id) wi_initWithApplication:(id) app;
- (id) wi_initWithWebClip:(id) clip;
- (void) wi_unscatter:(BOOL) b startTime:(double) time;
- (void) wi_deactivated;
- (void) wi_buildContentViews;
- (void) wi_reloadIndicators;
//- (void) wi__initializeIndicatorViewsWithNames:(id) names;
- (void) wi_indicatorsChanged;
- (void) wi_updateInterface;
- (NSString*) wi_pathForResource:(NSString*) name ofType:(NSString*) type;
@end

static Class $WIIconModel;
static Class $WIInstalledApplicationIcon;
static Class $WIApplicationIcon;
static Class $WIBookmarkIcon;
static Class $SBStatusBarContentsView;

static WeatherIconController* _controller;
static SBStatusBarContentView* _sb0;
static SBStatusBarContentView* _sb1;

static void $SBAwayView$updateInterface(SBAwayView<WeatherIcon> *self, SEL sel)
{
	[self wi_updateInterface];

	// refresh the weather model
	BOOL refresh = !self.dimmed;
	if (!refresh)
	{
		// check AC
		Class cls = objc_getClass("SBUIController");
		SBUIController* sbui = [cls sharedInstance];
		refresh = [sbui isOnAC];
	}

	if (refresh)
		[_controller refresh];
}

static void $SBIconController$unscatter$(SBIconController<WeatherIcon> *self, SEL sel, BOOL b, double time) 
{
	// refresh the weather model
	[_controller refresh];

	// do the unscatter
	[self wi_unscatter:b startTime:time];
}

static id weatherIcon(SBIcon *self, SEL sel) 
{
	NSLog(@"WI: Calling icon method for %@", self.displayIdentifier);
	return [_controller icon];
}

static void buildContentViews(SBStatusBarContentsView<WeatherIcon> *self, SEL sel) 
{
	NSArray* subviews = [self subviews];
	NSLog(@"WI: content views before: %@", subviews);
	[self wi_buildContentViews];
	NSLog(@"WI: content views after: %@", subviews);
}

static void addWeatherView(SBStatusBarContentsView* self)
{	
	SBStatusBar* sb = [self statusBar];
	int mode = [sb mode];

	if (UIImage* indicator = [_controller statusBarIndicator:mode])
	{
		SBStatusBarContentView* weatherView = (mode == 0 ? _sb0 : _sb1);
		if (weatherView == nil)
		{
			Class sbClass = objc_getClass("SBStatusBarContentView");
			weatherView = [[[sbClass alloc] initWithContentsView:self] autorelease];
			[weatherView setAlpha:[$SBStatusBarContentsView contentAlphaForMode:mode]];
			[weatherView setMode:mode];

			UIImageView* iv = [[[UIImageView alloc] initWithImage:indicator] autorelease];
			[weatherView addSubview:iv];

			if (mode == 0)
				_sb0 = [weatherView retain];
			else
				_sb1 = [weatherView retain];
		}

		SBStatusBarContentView* battery = MSHookIvar<NSMutableArray*>(self, "_batteryView");
		float x = battery.frame.origin.x;

		if ([self shouldDisplayBatteryPercentage])
		{
			SBStatusBarContentView* batteryPercent = MSHookIvar<NSMutableArray*>(self, "_batteryPercentageView");
			x = batteryPercent.frame.origin.x;
		}

		NSLog(@"WI: Moving weather view to %f", x - indicator.size.width - 3);	
		weatherView.frame = CGRectMake(x - indicator.size.width - 3, 0, indicator.size.width, indicator.size.height);	

		// clear the content view
		UIImageView* iv = [[weatherView subviews] objectAtIndex:0];
		if (iv.image != indicator)
		{
			iv.frame = CGRectMake(0, 0, indicator.size.width, indicator.size.height);
			iv.image = indicator;
		}

		if ([[self subviews] indexOfObject:weatherView] == NSNotFound)
		{
			NSLog(@"WI: Adding weather view");
			[self addSubview:weatherView];
		}
	}
}

MSHook(void, _arrangeIconsByPriority, SBStatusBarContentsView* self, SEL sel, float left, float right)
{	
	NSLog(@"WI: Enter arrangeIconsByPriority");
	__arrangeIconsByPriority(self, sel, left, right);
	addWeatherView(self);
	NSLog(@"WI: Exit arrangeIconsByPriority");
}

MSHook(void, indicatorSetFrame, SBStatusBarContentView* self, SEL sel, CGRect rect) 
{
	int mode = [self effectiveModeForImages];
	UIImage* indicator = [_controller statusBarIndicator:mode];
	float offset = (indicator == nil ? 0 : indicator.size.width + 2);
	_indicatorSetFrame(self, sel, CGRectMake(rect.origin.x - offset, rect.origin.y, rect.size.width, rect.size.height));
}

static void $SBStatusBarIndicatorsView$reloadIndicators(SBStatusBarIndicatorsView<WeatherIcon> *self, SEL sel) 
{
	[self wi_reloadIndicators];

	int mode = [self effectiveModeForImages];
	UIImage* indicator = [_controller statusBarIndicator:mode];

	NSLog(@"WI: Reloading indicators");
	if (indicator)
	{
		UIImageView* weatherView = [[UIImageView alloc] initWithImage:indicator];
		NSArray* views = [self subviews];
		if (views.count > 0)
		{
			// if there are already indicators, move the weather view
			UIView* last = [views objectAtIndex:views.count - 1];
			weatherView.frame = CGRectMake(last.frame.origin.x + last.frame.size.width + 6, 0, weatherView.frame.size.width, weatherView.frame.size.height);
		}

		[self addSubview:weatherView];
		self.frame = CGRectMake(0, 0, weatherView.frame.origin.x + weatherView.frame.size.width, 20);

		NSLog(@"WI: weatherView: %f, %f, %f, %f", weatherView.frame.origin.x, weatherView.frame.origin.y, weatherView.frame.size.width, weatherView.frame.size.height); 
		NSLog(@"WI: indicators: %f, %f, %f, %f", self.frame.origin.x, self.frame.origin.y, self.frame.size.width, self.frame.size.height); 
	}
}

static void $SBApplication$deactivated(SBApplication<WeatherIcon> *self, SEL sel) 
{
	if ([self.displayIdentifier isEqualToString:@"com.apple.weather"] ||
	    [_controller isWeatherIcon:self.displayIdentifier])
	{
		// refresh the weather model
		[_controller refreshNow];
	}

	if ([self.displayIdentifier isEqualToString:@"com.apple.Preferences"])
	{
		[_controller checkPreferences];
	}

	[self wi_deactivated];
}

static NSString* pathForResource(NSBundle<WeatherIcon> *self, SEL sel, NSString* name, NSString* type) 
{
	if ([name isEqualToString:@"FSO_WeatherIcon"] || [name isEqualToString:@"Default_WeatherIcon"])
	{
		NSLog(@"WI: Loading weather icon SB image");
		return [NSString stringWithFormat:@"~/Library/WeatherIcon/%@.%@", name, type];
	}
	
	return [self wi_pathForResource:name ofType:type];
}

static id $SBApplicationIcon$initWithApplication$(SBApplicationIcon<WeatherIcon> *self, SEL sel, id app) 
{
	self = [self wi_initWithApplication:app];

	if ([_controller isWeatherIcon:self.displayIdentifier])
	{
		NSLog(@"WI: Replacing icon for %@.", self.displayIdentifier);
		if ([self class] == objc_getClass("SBInstalledApplicationIcon"))
			object_setClass(self, $WIInstalledApplicationIcon);
		else
			object_setClass(self, $WIApplicationIcon);
	}

	return self;
}

static id $SBBookmarkIcon$initWithWebClip$(SBBookmarkIcon<WeatherIcon> *self, SEL sel, id clip) 
{
	self = [self wi_initWithWebClip:clip];

	if ([_controller isWeatherIcon:self.displayIdentifier])
	{
		NSLog(@"WI: Replacing icon for %@.", self.displayIdentifier);
		object_setClass(self, $WIBookmarkIcon);
	}

	return self;
}

#define Hook(cls, sel, imp) \
        _ ## imp = MSHookMessage($ ## cls, @selector(sel), &$ ## imp)

extern "C" void TweakInit() {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	if (objc_getClass("SpringBoard") == nil)
		return;

	$WIApplicationIcon = objc_allocateClassPair(objc_getClass("SBApplicationIcon"), "WIApplicationIcon", 0);
	class_replaceMethod($WIApplicationIcon, @selector(icon), (IMP)&weatherIcon, "@@:");
	objc_registerClassPair($WIApplicationIcon);

	$WIInstalledApplicationIcon = objc_allocateClassPair(objc_getClass("SBInstalledApplicationIcon"), "WIInstalledApplicationIcon", 0);
	class_replaceMethod($WIInstalledApplicationIcon, @selector(icon), (IMP)&weatherIcon, "@@:");
	objc_registerClassPair($WIInstalledApplicationIcon);

	$WIBookmarkIcon = objc_allocateClassPair(objc_getClass("SBBookmarkIcon"), "WIBookmarkIcon", 0);
	class_replaceMethod($WIBookmarkIcon, @selector(icon), (IMP)&weatherIcon, "@@:");
	objc_registerClassPair($WIBookmarkIcon);

	Class $NSBundle = objc_getClass("NSBundle");
	Class $SBAwayView = objc_getClass("SBAwayView");
	Class $SBIconController = objc_getClass("SBIconController");
	Class $SBBookmarkIcon = objc_getClass("SBBookmarkIcon");
	Class $SBApplicationIcon = objc_getClass("SBApplicationIcon");
	Class $SBApplication = objc_getClass("SBApplication");
	Class $SBIconModel = objc_getClass("SBIconModel");
	Class $SBStatusBarController = objc_getClass("SBStatusBarController");
	Class $SBStatusBarIndicatorView = objc_getClass("SBStatusBarIndicatorView");
	Class $SBStatusBarIndicatorsView = objc_getClass("SBStatusBarIndicatorsView");
	$SBStatusBarContentsView = objc_getClass("SBStatusBarContentsView");
	
	// MSHookMessage is what we use to redirect the methods to our own
//	MSHookMessage($NSBundle, @selector(pathForResource:ofType:), (IMP) &pathForResource, "wi_");
	MSHookMessage($SBIconController, @selector(unscatter:startTime:), (IMP) &$SBIconController$unscatter$, "wi_");
	MSHookMessage($SBApplication, @selector(deactivated), (IMP) &$SBApplication$deactivated, "wi_");
	MSHookMessage($SBApplicationIcon, @selector(initWithApplication:), (IMP) &$SBApplicationIcon$initWithApplication$, "wi_");
	MSHookMessage($SBBookmarkIcon, @selector(initWithWebClip:), (IMP) &$SBBookmarkIcon$initWithWebClip$, "wi_");
	MSHookMessage($SBStatusBarIndicatorsView, @selector(reloadIndicators), (IMP) &$SBStatusBarIndicatorsView$reloadIndicators, "wi_");
//	MSHookMessage($SBStatusBarContentsView, @selector(_initializeIndicatorViewsWithNames:), (IMP) &_initializeIndicatorViewsWithNames, "wi_");
//	MSHookMessage($SBStatusBarContentsView, @selector(buildContentViews), (IMP) &buildContentViews, "wi_");
//	MSHookMessage($SBStatusBarContentsView, @selector(indicatorsChanged), (IMP) &indicatorsChanged, "wi_");
	MSHookMessage($SBAwayView, @selector(updateInterface), (IMP) &$SBAwayView$updateInterface, "wi_");
	Hook(SBStatusBarIndicatorView, setFrame:, indicatorSetFrame);
	Hook(SBStatusBarContentsView, _arrangeIconsByPriorityWithLeftWidth:rightWidth:, _arrangeIconsByPriority);
//	Hook(SBStatusBarContentsView, reflowContentViewsNow, reflowContentViewsNow);
//	Hook(SBStatusBarContentsView, reflowContentViews, reflowContentViews);
//	Hook(SBStatusBarContentsView, reflowContentViews:, reflowContentViewsWithBool);
//	Hook(SBStatusBarContentsView, _initializeIndicatorViewsWithNames:, _initializeIndicatorViewsWithNames);
//	Hook(SBStatusBarContentsView, indicatorsChanged, indicatorsChanged);
//	Hook(SBStatusBarContentsView, _addObjectSortedByPriority:toArray:, _addObjectSortedByPriority);
//	Hook(SBStatusBarContentsView, _capacityAfterAddingView:onSide:, _capacityAfterAddingView);
	
	NSLog(@"WI: Init weather controller.");
	_controller = [WeatherIconController sharedInstance];

	[pool release];
}
