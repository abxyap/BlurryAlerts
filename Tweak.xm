// #include <libcolorpicker.h>
#include "UIHeaders.h"

#import <iostream>
#import <string>
#import <vector>

//#define LOGGING

#ifdef LOGGING
#define DBG(fmt, ...) NSLog(fmt, ##__VA_ARGS__)
#else
#define DBG(fmt, ...)
#endif

#define BG_BLUR_STYLE_LIGHT 0
#define BG_BLUR_STYLE_DARK 1
#define BG_BLUR_STYLE_ADAPTIVE 2
#define BG_BLUR_STYLE_GLASS 3

#define BUTTON_BLUR_STYLE_LIGHT 0
#define BUTTON_BLUR_STYLE_DARK 1
#define BUTTON_BLUR_STYLE_ADAPTIVE 2
#define BUTTON_BLUR_STYLE_NONE 3

static BOOL tweakEnabled = YES;
static BOOL displaySheetsAsAlerts = NO;
static BOOL dismissAnywhere = NO;
static BOOL removeCancelAction = NO;
static long backgroundBlurStyle = BG_BLUR_STYLE_GLASS;
static int backgroundBlurIntensity = 10;
static float backgroundBlurColorIntensity = 0.2;

static long buttonBlurStyle = BUTTON_BLUR_STYLE_NONE;
static float buttonBackgroundColorAlpha = 0.5;
static UIColor *buttonBackgroundColor;
static int buttonBlurIntensity = 10;
static float buttonBlurColorIntensity = 0.3;

static float buttonDestructiveColorAlpha = 1;
static UIColor *buttonDestructiveColor;

int convertFromHex(std::string hex) {
    int value = 0;

    int a = 0;
    int b = ((int)hex.length()) - 1;

    for (; b >= 0; a++, b--) {
        if (hex[b] >= '0' && hex[b] <= '9')
            value += (hex[b] - '0') * (1 << (a * 4));
        else {
            switch (hex[b]) {
                case 'A':
                case 'a':
                    value += 10 * (1 << (a * 4));
                    break;

                case 'B':
                case 'b':
                    value += 11 * (1 << (a * 4));
                    break;

                case 'C':
                case 'c':
                    value += 12 * (1 << (a * 4));
                    break;

                case 'D':
                case 'd':
                    value += 13 * (1 << (a * 4));
                    break;

                case 'E':
                case 'e':
                    value += 14 * (1 << (a * 4));
                    break;

                case 'F':
                case 'f':
                    value += 15 * (1 << (a * 4));
                    break;

                default:
                    NSLog(@"Error, invalid char '%d' in hex number", hex[a]);
                    break;
            }
        }
    }

    return value;
}

void hextodec(std::string hex, std::vector<unsigned char>& rgb) {
    // since there is no prefix attached to hex, use this code
    int prefix_len = 0;
    std::string redString = hex.substr(0 + prefix_len, 2);
    std::string greenString = hex.substr(2 + prefix_len, 2);
    std::string blueString = hex.substr(4 + prefix_len, 2);

    /*
        if the prefix # was attached to hex, use the following code
        string redString = hex.substr(1, 2);
        string greenString = hex.substr(3, 2);
        string blueString = hex.substr(5, 2);
     */

    unsigned char red = (unsigned char)(convertFromHex(redString));
    unsigned char green = (unsigned char)(convertFromHex(greenString));
    unsigned char blue = (unsigned char)(convertFromHex(blueString));

    rgb[0] = red;
    rgb[1] = green;
    rgb[2] = blue;
}

UIColor *colorFromHex(NSString *hexString) {
    if (hexString.length > 0) {
        if ([hexString hasPrefix:@"#"])
            hexString = [hexString substringFromIndex:1];

        std::string hexColor;

        std::vector<unsigned char> rgbColor(3);
        hexColor = hexString.UTF8String;

        if (hexColor.length() != 6) {
            std::string sixDigitHexColor = "";
            for (int i = 0; 6 > i; i++) {
                switch (i) {
                    case 0:
                        sixDigitHexColor.append(hexColor.substr(i, 1));
                        sixDigitHexColor.append(hexColor.substr(i, 1));
                        break;

                    case 1:
                        sixDigitHexColor.append(hexColor.substr(i, 1));
                        sixDigitHexColor.append(hexColor.substr(i, 1));
                        break;

                    case 2:
                        sixDigitHexColor.append(hexColor.substr(i, 1));
                        sixDigitHexColor.append(hexColor.substr(i, 1));
                        break;

                    default:
                        break;
                }
            }

            hexColor = sixDigitHexColor;
        }

        hextodec(hexColor, rgbColor);
        return [UIColor colorWithRed:int(rgbColor[0]) / 255.f
                               green:int(rgbColor[1]) / 255.f
                                blue:int(rgbColor[2]) / 255.f
                               alpha:1];
    } else { // Random
        CGFloat hue = ( arc4random() % 256 / 256.0 );  //  0.0 to 1.0
        CGFloat saturation = ( arc4random() % 128 / 256.0 ) + 0.5;  //  0.5 to 1.0, away from white
        CGFloat brightness = ( arc4random() % 128 / 256.0 ) + 0.5;  //  0.5 to 1.0, away from black
        return [UIColor colorWithHue:hue saturation:saturation brightness:brightness alpha:1];
    }
}

UIColor *LCPParseColorString(NSString *colorStringFromPrefs, NSString *colorStringFallback) {
    //fallback
    UIColor *fallbackColor = colorFromHex(colorStringFallback);
    CGFloat currentAlpha = 1.0f;

    if (colorStringFromPrefs && colorStringFromPrefs.length > 0) {
        NSString *value = colorStringFromPrefs;
        if (!value || value.length == 0)
            return fallbackColor;

        NSArray *colorAndOrAlpha = [value componentsSeparatedByString:@":"];
        if ([value rangeOfString:@":"].location != NSNotFound) {
            if ([colorAndOrAlpha objectAtIndex:1])
                currentAlpha = [colorAndOrAlpha[1] floatValue];
            else
                currentAlpha = 1.0f;
        }

        if (!value)
            return fallbackColor;

        NSString *color = colorAndOrAlpha[0];
        return [colorFromHex(color) colorWithAlphaComponent:currentAlpha];
    } else {
        return fallbackColor;
    }
}

%hook _UIAlertControllerActionView

%property (nonatomic, retain) UIVisualEffectView *baActionBackgroundBlurView;

// Workaround for sheets
-(void)tintColorDidChange {
	%orig;

	UIAlertController *controller = MSHookIvar<UIAlertController*>(self, "_alertController");
	if(controller.isBAEnabled) {
		[self applyButtonStyle:NO];
	}
}

-(void)setHighlighted:(BOOL)arg1 {
	%orig;

	UIAlertController *controller = MSHookIvar<UIAlertController*>(self, "_alertController");
	if(controller.isBAEnabled) {
		[self applyButtonStyle:arg1];
	}
}

%new
- (void)applyButtonStyle:(BOOL)isHighlighted {
	self.layer.cornerRadius = 5;
	self.layer.masksToBounds = true;

	UIAlertAction *action = MSHookIvar<UIAlertAction*>(self, "_action");
	UILabel *label = MSHookIvar<UILabel*>(self, "_label");
	UIFontDescriptor *fontBold = [label.font.fontDescriptor fontDescriptorWithSymbolicTraits:UIFontDescriptorTraitBold];

	if(self.baActionBackgroundBlurView) {
		[self.baActionBackgroundBlurView setHidden:isHighlighted];
	}

	if(isHighlighted) {
		label.tintColor = [UIColor blackColor];
		label.textColor = [UIColor blackColor];
		label.font = [UIFont fontWithDescriptor:fontBold size:0];

		self.backgroundColor = [UIColor whiteColor];
	} else {
		label.tintColor = [UIColor whiteColor];
		label.textColor = [UIColor whiteColor];

		if(action.style == UIAlertActionStyleDestructive) {
			self.backgroundColor = buttonDestructiveColor;
			label.font = [UIFont fontWithDescriptor:fontBold size:0];
		} else {
			if(buttonBlurStyle == BUTTON_BLUR_STYLE_NONE) {
				self.backgroundColor = buttonBackgroundColor;
			} else {
				NSLog(@"[BlurryAlerts] applyButtonStyle, buttonBlurStyle: %ld", buttonBlurStyle);
				switch(buttonBlurStyle) {
					case BUTTON_BLUR_STYLE_LIGHT:
						[self setBackgroundColor:[UIColor colorWithRed:1 green:1 blue:1 alpha:buttonBlurColorIntensity]];
						break;
					case BUTTON_BLUR_STYLE_DARK:
						// [self setBackgroundColor:[UIColor blackColor]];
						[self setBackgroundColor:[UIColor colorWithRed:0 green:0 blue:0 alpha:buttonBlurColorIntensity]];
						break;
					case BUTTON_BLUR_STYLE_ADAPTIVE: {
						if([[UITraitCollection currentTraitCollection] userInterfaceStyle] != UIUserInterfaceStyleDark) { // Inverted
							[self setBackgroundColor:[UIColor colorWithRed:0 green:0 blue:0 alpha:buttonBlurColorIntensity]];
						} else {
							[self setBackgroundColor:[UIColor colorWithRed:1 green:1 blue:1 alpha:buttonBlurColorIntensity]];
						}
						break;
					}
					default:
						break;
				}

				if(!self.baActionBackgroundBlurView) {
					UIBlurEffect *blurEffect = [UIBlurEffect effectWithBlurRadius:buttonBlurIntensity];
					UIVisualEffectView *visualEffectView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];

					visualEffectView.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight);
					visualEffectView.frame = self.bounds;
					self.autoresizesSubviews = YES;
					self.clipsToBounds = YES;
					
					[self addSubview:visualEffectView];
					[self sendSubviewToBack:visualEffectView];

					self.baActionBackgroundBlurView = visualEffectView;
				}
			}
		}
	}
}

%end

%hook _UIAlertControllerView

- (void)_configureActionGroupViewToAllowHorizontalLayout:(bool)arg1 {
	UIAlertController *controller = MSHookIvar<UIAlertController*>(self, "_alertController");

	if(!controller.isBAEnabled) {
		return %orig;
	}

	if(removeCancelAction && arg1) {
		%orig(false);
		return;
	}

	%orig;
}

%end

%hook UIAlertController

%property (nonatomic, assign) BOOL isBAEnabled;
%property (nonatomic, assign) BOOL isBAActionSheet;
%property (retain) UIInterfaceActionRepresentationView *baCancelActionView;

+ (id)alertControllerWithTitle:(id)title message:(id)message preferredStyle:(long long)style {
	UIAlertController *alertController = nil;
	if(displaySheetsAsAlerts) {
		alertController = %orig(title, message, UIAlertControllerStyleAlert);
	} else {
		alertController = %orig;
	}

	if(style == UIAlertControllerStyleActionSheet) {
		alertController.isBAActionSheet = YES;
	}

	alertController.isBAEnabled = NO;
	if(tweakEnabled && alertController.preferredStyle != UIAlertControllerStyleActionSheet) {
		alertController.isBAEnabled = YES;
	}

	return alertController;
}

- (id)init {
	UIAlertController *alertController = %orig;
	alertController.isBAEnabled = tweakEnabled && alertController.preferredStyle != UIAlertControllerStyleActionSheet;
	if(displaySheetsAsAlerts) {
		alertController.isBAEnabled = YES;
		[alertController setPreferredStyle:UIAlertControllerStyleAlert];
	}
	return alertController;
}

- (void)setPreferredStyle:(long long)style {
	if(!self.isBAEnabled) {
		%orig;
		return;
	}

	if(style == UIAlertControllerStyleActionSheet) {
		self.isBAActionSheet = YES;
	}

	if(displaySheetsAsAlerts) {
		%orig(UIAlertControllerStyleAlert);
	} else {
		%orig;
		self.isBAEnabled = self.preferredStyle != UIAlertControllerStyleActionSheet;
	}
}

-(void)setContentViewController:(id)arg1 {
	self.isBAEnabled = NO; // Disable here we can´t style every custom controller
	if(self.isBAActionSheet) {
		BOOL prevTmp = displaySheetsAsAlerts;
		displaySheetsAsAlerts = NO;
		[self setPreferredStyle:UIAlertControllerStyleActionSheet];
		displaySheetsAsAlerts = prevTmp;
	}
	
	%orig;
	DBG(@"[BlurryAlerts] Custom Controller: %@", arg1); 
}


- (void)viewDidLayoutSubviews {
	%orig;

	if(!self.isBAEnabled)
		return;

	// Remove background
	_UIAlertControllerView *view = MSHookIvar<_UIAlertControllerView*>(self, "_view");
	view.shouldHaveBackdropView = NO;

	_UIAlertControllerInterfaceActionGroupView *mainView = MSHookIvar<_UIAlertControllerInterfaceActionGroupView*>(view, "_mainInterfaceActionsGroupView");
	UIView *itemsView = MSHookIvar<UIView*>(mainView, "_topLevelItemsView");
	itemsView.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0];

	DBG(@"[BlurryAlerts] Top Level: %@", itemsView);

	UIView *bgView = MSHookIvar<UIView*>(mainView, "_backgroundView");
	if(bgView) {
		bgView.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0];
	}

	DBG(@"[BlurryAlerts] Background: %@", bgView);

	// Color Text
	[self colorAlertTextRecursive:view];

	// Get Buttons
	UIInterfaceActionGroup *actionGroup = MSHookIvar<UIInterfaceActionGroup*>(mainView, "_actionGroup");
	NSArray *actions = MSHookIvar<NSArray*>(actionGroup, "_actions");
	for(id actionInterface in actions) {
		DBG(@"[BlurryAlerts] Action: %@", actionInterface);

		if([actionInterface isKindOfClass:%c(_UIAlertControllerActionViewInterfaceAction)]) {
			_UIAlertControllerActionViewInterfaceAction *action = (_UIAlertControllerActionViewInterfaceAction*)actionInterface;
			_UIAlertControllerActionView *actionView = action.alertControllerActionView;

			UIAlertAction *actionTmp = MSHookIvar<UIAlertAction*>(actionView, "_action");
			if(actionTmp.style == UIAlertActionStyleCancel) {
				self.baCancelActionView = (UIInterfaceActionRepresentationView *)actionView.superview;

				if(removeCancelAction) {
					actionView.superview.hidden = YES;
				}
			}

			[actionView applyButtonStyle:NO];
		} else {
			DBG(@"[BlurryAlerts] Unknown action!");
		}
	}

	// Remove main seperators
	[self removeSeperatorViews:itemsView.subviews];

	// Get Stack View
	_UIInterfaceActionRepresentationsSequenceView *seqView = MSHookIvar<_UIInterfaceActionRepresentationsSequenceView*>(mainView, "_actionSequenceView");
	_UIInterfaceActionSeparatableSequenceView *sepView = MSHookIvar<_UIInterfaceActionSeparatableSequenceView*>(seqView, "_separatedContentSequenceView");
	UIStackView *stackView = MSHookIvar<UIStackView*>(sepView, "_stackView");

	DBG(@"[BlurryAlerts] StackView: %@ Views: %@", stackView, stackView.arrangedSubviews);

	// Remove seperators and add spacing
	[self removeSeperatorViews:stackView.arrangedSubviews];
	for(UIView *view in stackView.arrangedSubviews) {
		[stackView setCustomSpacing:5.0 afterView:view];
	}

	CGFloat scrollViewWidth = 0.0f;
	CGFloat scrollViewHeight = 0.0f;
	for (UIView* view in seqView.subviews) {
		scrollViewHeight += view.frame.size.height + 5;
		if(view.frame.size.width > scrollViewWidth) {
			scrollViewWidth = view.frame.size.width;
		}
	}

	[seqView setContentSize:(CGSizeMake(scrollViewWidth, scrollViewHeight))];

	for (NSLayoutConstraint *c in seqView.constraints) {
		DBG(@"[BlurryAlerts] Constraint: %@", c);
		if([[NSString stringWithFormat: @"%@", c] containsString:@"height =="]) {
			c.constant = scrollViewHeight;
		}
	}
}

// _dimmingView -> blurView
- (void)viewWillAppear:(BOOL)arg1 {
	NSLog(@"[BlurryAlerts] UIAlertController, viewWillAppear: %d", arg1);
	%orig;

	if(!self.isBAEnabled)
		return;

	// Add dismiss recognizer
	if(dismissAnywhere) {
		UITapGestureRecognizer *singleFingerTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleSingleTap:)];
		[self._dimmingView addGestureRecognizer:singleFingerTap];
	}

	// Apply blur
	NSLog(@"[BlurryAlerts] UIAlertController, viewWillAppear -> Apply blur");
	UIView *blurView = self._dimmingView;
	blurView.alpha = 1;

	UIView *bgView = nil;
	if(backgroundBlurStyle != BG_BLUR_STYLE_GLASS) {
		bgView = [[UIView alloc] init];
		bgView.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight);
		bgView.alpha = backgroundBlurColorIntensity;
	}

	NSLog(@"[BlurryAlerts] UIAlertController, viewWillAppear -> backgroundBlurStyle: %ld", backgroundBlurStyle);
	NSLog(@"[BlurryAlerts] UIAlertController, self: %@, blurView: %@, bgView: %@", self, blurView, bgView);
	switch(backgroundBlurStyle) {
		case BG_BLUR_STYLE_LIGHT:
			[bgView setBackgroundColor:[UIColor whiteColor]];
			break;
		case BG_BLUR_STYLE_DARK:
			[bgView setBackgroundColor:[UIColor blackColor]];
			break;
		case BG_BLUR_STYLE_ADAPTIVE: {
			if([[UITraitCollection currentTraitCollection] userInterfaceStyle] == UIUserInterfaceStyleDark) {
				[bgView setBackgroundColor:[UIColor blackColor]];
			} else {
				[bgView setBackgroundColor:[UIColor whiteColor]];
			}
			break;
		}
		default:
			break;
	}
	
	UIBlurEffect *blurEffect = [UIBlurEffect effectWithBlurRadius:backgroundBlurIntensity];
	UIVisualEffectView *visualEffectView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];

	[bgView setFrame: blurView.frame];
	[visualEffectView setFrame: blurView.frame];

	visualEffectView.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight);
	blurView.autoresizesSubviews = YES;
	blurView.clipsToBounds = YES;

	if(backgroundBlurStyle != BG_BLUR_STYLE_GLASS) {
		[blurView addSubview:bgView];
		[blurView insertSubview:visualEffectView aboveSubview:bgView];
	} else {
		[blurView addSubview:visualEffectView];
	}
}

%new
- (void)handleSingleTap:(UITapGestureRecognizer*)recognizer {
	DBG(@"[BlurryAlerts] Dismiss");

	[self.baCancelActionView invokeInterfaceAction];
}

%new
- (void)colorAlertTextRecursive:(UIView *)view {
    NSArray *subviews = [view subviews];
    if ([subviews count] == 0) return;

    for (UIView *subview in subviews) {
		if([subview isKindOfClass:%c(UILabel)]) {
			UILabel *label = (UILabel*)subview;
			label.tintColor = [UIColor whiteColor];
			label.textColor = [UIColor whiteColor];
		}
        [self colorAlertTextRecursive:subview];
    }
}

%new
- (void)removeSeperatorViews:(NSArray*)subviews {
	for(UIView *view in subviews) {
		if([view isKindOfClass:%c(_UIInterfaceActionVibrantSeparatorView)]) {
			DBG(@"[BlurryAlerts] View: Removed seperator!");
			[view setHidden:YES];
		}
	}
}

%end

static void loadPrefs() {
	NSMutableDictionary *prefs = [[NSMutableDictionary alloc] initWithContentsOfFile:@"/var/jb/var/mobile/Library/Preferences/com.slyfabi.blurryalerts.plist"];

	if([prefs objectForKey:@"isEnabled"] != nil)
		tweakEnabled = [[prefs objectForKey:@"isEnabled"] boolValue];

	if([prefs objectForKey:@"displaySheetsAsAlerts"] != nil)
		displaySheetsAsAlerts = [[prefs objectForKey:@"displaySheetsAsAlerts"] boolValue];

	if([prefs objectForKey:@"dismissAnywhere"] != nil)
		dismissAnywhere = [[prefs objectForKey:@"dismissAnywhere"] boolValue];

	if([prefs objectForKey:@"removeCancelAction"] != nil)
		removeCancelAction = [[prefs objectForKey:@"removeCancelAction"] boolValue];
	
	// Background Blur
	if([prefs objectForKey:@"backgroundBlurType"] != nil)
		backgroundBlurStyle = [[prefs objectForKey:@"backgroundBlurType"] intValue];
	
	if([prefs objectForKey:@"backgroundBlurIntensity"] != nil)
		backgroundBlurIntensity = [[prefs objectForKey:@"backgroundBlurIntensity"] intValue];

	if([prefs objectForKey:@"backgroundBlurColorIntensity"] != nil)
		backgroundBlurColorIntensity = [[prefs objectForKey:@"backgroundBlurColorIntensity"] floatValue];

	// Button Blur
	if([prefs objectForKey:@"buttonBlurType"] != nil)
		buttonBlurStyle = [[prefs objectForKey:@"buttonBlurType"] intValue];

	if([prefs objectForKey:@"buttonBlurIntensity"] != nil)
		buttonBlurIntensity = [[prefs objectForKey:@"buttonBlurIntensity"] intValue];

	if([prefs objectForKey:@"buttonBlurColorIntensity"] != nil)
		buttonBlurColorIntensity = [[prefs objectForKey:@"buttonBlurColorIntensity"] floatValue];

	if([prefs objectForKey:@"buttonBackgroundColorAlpha"] != nil)
		buttonBackgroundColorAlpha = [[prefs objectForKey:@"buttonBackgroundColorAlpha"] floatValue];

	buttonBackgroundColor = LCPParseColorString([prefs objectForKey:@"buttonBackgroundColor"], @"#333333");
	buttonBackgroundColor = [buttonBackgroundColor colorWithAlphaComponent:buttonBackgroundColorAlpha];

	// Button destructive color
	if([prefs objectForKey:@"buttonDestructiveColorAlpha"] != nil)
		buttonDestructiveColorAlpha = [[prefs objectForKey:@"buttonDestructiveColorAlpha"] floatValue];

	buttonDestructiveColor = LCPParseColorString([prefs objectForKey:@"buttonDestructiveColor"], @"#990000");
	buttonDestructiveColor = [buttonDestructiveColor colorWithAlphaComponent:buttonDestructiveColorAlpha];
}

%ctor {
	NSLog(@"[BlurryAlerts] Loaded");
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)loadPrefs, CFSTR("com.slyfabi.blurryalerts.settingschanged"), NULL, CFNotificationSuspensionBehaviorCoalesce);
	loadPrefs();
}