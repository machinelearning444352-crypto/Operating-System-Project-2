#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>

@interface GlassmorphismHelper : NSObject

// Apply stunning glassmorphism effect to a view
+ (void)applyGlassEffectToView:(NSView *)view;
+ (void)applyGlassEffectToView:(NSView *)view withTint:(NSColor *)tint;
+ (void)applyGlassEffectToView:(NSView *)view withTint:(NSColor *)tint cornerRadius:(CGFloat)radius;

// Apply frosted glass to window
+ (void)applyFrostedGlassToWindow:(NSWindow *)window;

// Create glass panel
+ (NSView *)createGlassPanelWithFrame:(NSRect)frame tint:(NSColor *)tint;

// Gradient backgrounds
+ (CAGradientLayer *)createAuroraGradient;
+ (CAGradientLayer *)createSunsetGradient;
+ (CAGradientLayer *)createOceanGradient;
+ (CAGradientLayer *)createNightGradient;

// Animated glow effect
+ (void)addGlowToView:(NSView *)view color:(NSColor *)color;
+ (void)addPulsingGlowToView:(NSView *)view color:(NSColor *)color;

// Glass button style
+ (void)styleGlassButton:(NSButton *)button;
+ (void)styleGlassButton:(NSButton *)button withColor:(NSColor *)color;

// Glass text field
+ (void)styleGlassTextField:(NSTextField *)field;

@end
