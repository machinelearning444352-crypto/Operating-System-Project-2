#import "GlassmorphismHelper.h"

@implementation GlassmorphismHelper

+ (void)applyGlassEffectToView:(NSView *)view {
    [self applyGlassEffectToView:view withTint:[NSColor colorWithWhite:1.0 alpha:0.1]];
}

+ (void)applyGlassEffectToView:(NSView *)view withTint:(NSColor *)tint {
    [self applyGlassEffectToView:view withTint:tint cornerRadius:16];
}

+ (void)applyGlassEffectToView:(NSView *)view withTint:(NSColor *)tint cornerRadius:(CGFloat)radius {
    view.wantsLayer = YES;
    
    // Create visual effect view for blur
    NSVisualEffectView *blurView = [[NSVisualEffectView alloc] initWithFrame:view.bounds];
    blurView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    blurView.blendingMode = NSVisualEffectBlendingModeBehindWindow;
    blurView.material = NSVisualEffectMaterialHUDWindow;
    blurView.state = NSVisualEffectStateActive;
    blurView.wantsLayer = YES;
    blurView.layer.cornerRadius = radius;
    blurView.layer.masksToBounds = YES;
    
    // Add subtle gradient overlay
    CAGradientLayer *glassGradient = [CAGradientLayer layer];
    glassGradient.frame = view.bounds;
    glassGradient.colors = @[
        (id)[tint colorWithAlphaComponent:0.3].CGColor,
        (id)[tint colorWithAlphaComponent:0.1].CGColor,
        (id)[tint colorWithAlphaComponent:0.05].CGColor
    ];
    glassGradient.locations = @[@0.0, @0.5, @1.0];
    glassGradient.startPoint = CGPointMake(0, 0);
    glassGradient.endPoint = CGPointMake(1, 1);
    glassGradient.cornerRadius = radius;
    
    // Add inner glow/highlight at top
    CAGradientLayer *innerHighlight = [CAGradientLayer layer];
    innerHighlight.frame = CGRectMake(0, view.bounds.size.height - 2, view.bounds.size.width, 2);
    innerHighlight.colors = @[
        (id)[[NSColor whiteColor] colorWithAlphaComponent:0.4].CGColor,
        (id)[[NSColor whiteColor] colorWithAlphaComponent:0.0].CGColor
    ];
    innerHighlight.cornerRadius = radius;
    
    // Border glow
    view.layer.cornerRadius = radius;
    view.layer.borderWidth = 0.5;
    view.layer.borderColor = [[NSColor colorWithWhite:1.0 alpha:0.2] CGColor];
    view.layer.masksToBounds = YES;
    
    // Add shadow for depth
    view.layer.shadowColor = [[NSColor blackColor] CGColor];
    view.layer.shadowOffset = CGSizeMake(0, -10);
    view.layer.shadowRadius = 30;
    view.layer.shadowOpacity = 0.3;
    
    [view addSubview:blurView positioned:NSWindowBelow relativeTo:nil];
    [view.layer addSublayer:glassGradient];
    [view.layer addSublayer:innerHighlight];
}

+ (void)applyFrostedGlassToWindow:(NSWindow *)window {
    window.backgroundColor = [NSColor clearColor];
    window.opaque = NO;
    window.hasShadow = YES;
    
    NSView *contentView = window.contentView;
    contentView.wantsLayer = YES;
    
    // Create frosted effect
    NSVisualEffectView *frost = [[NSVisualEffectView alloc] initWithFrame:contentView.bounds];
    frost.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    frost.blendingMode = NSVisualEffectBlendingModeBehindWindow;
    frost.material = NSVisualEffectMaterialSidebar;
    frost.state = NSVisualEffectStateActive;
    frost.wantsLayer = YES;
    frost.layer.cornerRadius = 12;
    frost.layer.masksToBounds = YES;
    
    [contentView addSubview:frost positioned:NSWindowBelow relativeTo:nil];
    
    contentView.layer.cornerRadius = 12;
    contentView.layer.masksToBounds = YES;
}

+ (NSView *)createGlassPanelWithFrame:(NSRect)frame tint:(NSColor *)tint {
    NSView *panel = [[NSView alloc] initWithFrame:frame];
    panel.wantsLayer = YES;
    
    // Blur background
    NSVisualEffectView *blur = [[NSVisualEffectView alloc] initWithFrame:panel.bounds];
    blur.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    blur.blendingMode = NSVisualEffectBlendingModeWithinWindow;
    blur.material = NSVisualEffectMaterialPopover;
    blur.state = NSVisualEffectStateActive;
    blur.wantsLayer = YES;
    blur.layer.cornerRadius = 12;
    blur.layer.masksToBounds = YES;
    [panel addSubview:blur];
    
    // Tint overlay
    NSView *tintView = [[NSView alloc] initWithFrame:panel.bounds];
    tintView.wantsLayer = YES;
    tintView.layer.backgroundColor = [tint colorWithAlphaComponent:0.15].CGColor;
    tintView.layer.cornerRadius = 12;
    tintView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [panel addSubview:tintView];
    
    // Border
    panel.layer.cornerRadius = 12;
    panel.layer.borderWidth = 1;
    panel.layer.borderColor = [[NSColor colorWithWhite:1.0 alpha:0.15] CGColor];
    
    return panel;
}

+ (CAGradientLayer *)createAuroraGradient {
    CAGradientLayer *gradient = [CAGradientLayer layer];
    gradient.colors = @[
        (id)[NSColor colorWithRed:0.1 green:0.0 blue:0.2 alpha:1.0].CGColor,
        (id)[NSColor colorWithRed:0.0 green:0.3 blue:0.5 alpha:1.0].CGColor,
        (id)[NSColor colorWithRed:0.0 green:0.6 blue:0.4 alpha:1.0].CGColor,
        (id)[NSColor colorWithRed:0.2 green:0.8 blue:0.6 alpha:1.0].CGColor,
        (id)[NSColor colorWithRed:0.6 green:0.2 blue:0.8 alpha:1.0].CGColor
    ];
    gradient.locations = @[@0.0, @0.25, @0.5, @0.75, @1.0];
    gradient.startPoint = CGPointMake(0, 1);
    gradient.endPoint = CGPointMake(1, 0);
    return gradient;
}

+ (CAGradientLayer *)createSunsetGradient {
    CAGradientLayer *gradient = [CAGradientLayer layer];
    gradient.colors = @[
        (id)[NSColor colorWithRed:0.05 green:0.05 blue:0.15 alpha:1.0].CGColor,
        (id)[NSColor colorWithRed:0.3 green:0.1 blue:0.4 alpha:1.0].CGColor,
        (id)[NSColor colorWithRed:0.7 green:0.2 blue:0.4 alpha:1.0].CGColor,
        (id)[NSColor colorWithRed:1.0 green:0.5 blue:0.3 alpha:1.0].CGColor,
        (id)[NSColor colorWithRed:1.0 green:0.8 blue:0.4 alpha:1.0].CGColor
    ];
    gradient.locations = @[@0.0, @0.3, @0.5, @0.7, @1.0];
    gradient.startPoint = CGPointMake(0, 0);
    gradient.endPoint = CGPointMake(1, 1);
    return gradient;
}

+ (CAGradientLayer *)createOceanGradient {
    CAGradientLayer *gradient = [CAGradientLayer layer];
    gradient.colors = @[
        (id)[NSColor colorWithRed:0.0 green:0.1 blue:0.2 alpha:1.0].CGColor,
        (id)[NSColor colorWithRed:0.0 green:0.2 blue:0.4 alpha:1.0].CGColor,
        (id)[NSColor colorWithRed:0.0 green:0.4 blue:0.6 alpha:1.0].CGColor,
        (id)[NSColor colorWithRed:0.2 green:0.6 blue:0.8 alpha:1.0].CGColor,
        (id)[NSColor colorWithRed:0.4 green:0.8 blue:0.9 alpha:1.0].CGColor
    ];
    gradient.startPoint = CGPointMake(0, 1);
    gradient.endPoint = CGPointMake(1, 0);
    return gradient;
}

+ (CAGradientLayer *)createNightGradient {
    CAGradientLayer *gradient = [CAGradientLayer layer];
    gradient.colors = @[
        (id)[NSColor colorWithRed:0.02 green:0.02 blue:0.08 alpha:1.0].CGColor,
        (id)[NSColor colorWithRed:0.05 green:0.05 blue:0.15 alpha:1.0].CGColor,
        (id)[NSColor colorWithRed:0.1 green:0.08 blue:0.25 alpha:1.0].CGColor,
        (id)[NSColor colorWithRed:0.15 green:0.1 blue:0.3 alpha:1.0].CGColor
    ];
    gradient.startPoint = CGPointMake(0.5, 0);
    gradient.endPoint = CGPointMake(0.5, 1);
    return gradient;
}

+ (void)addGlowToView:(NSView *)view color:(NSColor *)color {
    view.wantsLayer = YES;
    view.layer.shadowColor = color.CGColor;
    view.layer.shadowOffset = CGSizeMake(0, 0);
    view.layer.shadowRadius = 15;
    view.layer.shadowOpacity = 0.8;
}

+ (void)addPulsingGlowToView:(NSView *)view color:(NSColor *)color {
    view.wantsLayer = YES;
    view.layer.shadowColor = color.CGColor;
    view.layer.shadowOffset = CGSizeMake(0, 0);
    view.layer.shadowRadius = 15;
    view.layer.shadowOpacity = 0.6;
    
    CABasicAnimation *pulseAnim = [CABasicAnimation animationWithKeyPath:@"shadowOpacity"];
    pulseAnim.fromValue = @0.3;
    pulseAnim.toValue = @0.8;
    pulseAnim.duration = 1.5;
    pulseAnim.autoreverses = YES;
    pulseAnim.repeatCount = HUGE_VALF;
    pulseAnim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [view.layer addAnimation:pulseAnim forKey:@"pulseGlow"];
}

+ (void)styleGlassButton:(NSButton *)button {
    [self styleGlassButton:button withColor:[NSColor colorWithRed:0.3 green:0.5 blue:1.0 alpha:1.0]];
}

+ (void)styleGlassButton:(NSButton *)button withColor:(NSColor *)color {
    button.wantsLayer = YES;
    button.bordered = NO;
    
    // Glass gradient background
    CAGradientLayer *gradient = [CAGradientLayer layer];
    gradient.frame = button.bounds;
    gradient.colors = @[
        (id)[color colorWithAlphaComponent:0.8].CGColor,
        (id)[color colorWithAlphaComponent:0.5].CGColor
    ];
    gradient.startPoint = CGPointMake(0.5, 0);
    gradient.endPoint = CGPointMake(0.5, 1);
    gradient.cornerRadius = button.bounds.size.height / 2;
    
    // Inner highlight
    CAGradientLayer *highlight = [CAGradientLayer layer];
    highlight.frame = CGRectMake(1, 1, button.bounds.size.width - 2, button.bounds.size.height / 2);
    highlight.colors = @[
        (id)[[NSColor whiteColor] colorWithAlphaComponent:0.4].CGColor,
        (id)[[NSColor whiteColor] colorWithAlphaComponent:0.0].CGColor
    ];
    highlight.cornerRadius = (button.bounds.size.height / 2) - 1;
    
    button.layer.cornerRadius = button.bounds.size.height / 2;
    button.layer.borderWidth = 1;
    button.layer.borderColor = [[NSColor colorWithWhite:1.0 alpha:0.3] CGColor];
    
    [button.layer insertSublayer:gradient atIndex:0];
    [button.layer addSublayer:highlight];
    
    // Shadow
    button.layer.shadowColor = color.CGColor;
    button.layer.shadowOffset = CGSizeMake(0, 4);
    button.layer.shadowRadius = 8;
    button.layer.shadowOpacity = 0.4;
}

+ (void)styleGlassTextField:(NSTextField *)field {
    field.wantsLayer = YES;
    field.drawsBackground = NO;
    field.bezeled = NO;
    
    // Glass background
    field.layer.backgroundColor = [[NSColor colorWithWhite:1.0 alpha:0.1] CGColor];
    field.layer.cornerRadius = 8;
    field.layer.borderWidth = 1;
    field.layer.borderColor = [[NSColor colorWithWhite:1.0 alpha:0.2] CGColor];
}

@end
