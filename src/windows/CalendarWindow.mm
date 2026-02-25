#import "CalendarWindow.h"

@interface CalendarGridView : NSView
@property(nonatomic, strong) NSDate *currentMonth;
@property(nonatomic, assign) NSInteger selectedDay;
@end

@implementation CalendarGridView

- (instancetype)initWithFrame:(NSRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    self.currentMonth = [NSDate date];
    self.selectedDay = -1;
  }
  return self;
}

- (void)drawRect:(NSRect)dirtyRect {
  [[NSColor whiteColor] setFill];
  NSRectFill(self.bounds);

  NSCalendar *calendar = [NSCalendar currentCalendar];
  NSDateComponents *components = [calendar
      components:(NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay)
        fromDate:self.currentMonth];

  // Get first day of month
  components.day = 1;
  NSDate *firstDay = [calendar dateFromComponents:components];
  NSInteger firstWeekday = [calendar component:NSCalendarUnitWeekday
                                      fromDate:firstDay];

  // Get number of days in month
  NSRange daysRange = [calendar rangeOfUnit:NSCalendarUnitDay
                                     inUnit:NSCalendarUnitMonth
                                    forDate:self.currentMonth];
  NSInteger daysInMonth = daysRange.length;

  // Get today
  NSDateComponents *todayComponents = [calendar
      components:(NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay)
        fromDate:[NSDate date]];
  BOOL isCurrentMonth = (components.year == todayComponents.year &&
                         components.month == todayComponents.month);
  NSInteger todayDay = todayComponents.day;

  // Draw day headers
  NSArray *dayNames =
      @[ @"Sun", @"Mon", @"Tue", @"Wed", @"Thu", @"Fri", @"Sat" ];
  CGFloat cellWidth = self.bounds.size.width / 7;
  CGFloat cellHeight = 35;
  CGFloat headerY = self.bounds.size.height - 25;

  NSDictionary *headerAttrs = @{
    NSFontAttributeName : [NSFont systemFontOfSize:11
                                            weight:NSFontWeightMedium],
    NSForegroundColorAttributeName : [NSColor grayColor]
  };

  for (NSInteger i = 0; i < 7; i++) {
    NSString *day = dayNames[i];
    NSSize size = [day sizeWithAttributes:headerAttrs];
    CGFloat x = i * cellWidth + (cellWidth - size.width) / 2;
    [day drawAtPoint:NSMakePoint(x, headerY) withAttributes:headerAttrs];
  }

  // Draw days
  NSInteger row = 0;
  NSInteger col = firstWeekday - 1;

  NSDictionary *dayAttrs = @{
    NSFontAttributeName : [NSFont systemFontOfSize:14],
    NSForegroundColorAttributeName : [NSColor blackColor]
  };

  NSDictionary *todayAttrs = @{
    NSFontAttributeName : [NSFont systemFontOfSize:14 weight:NSFontWeightBold],
    NSForegroundColorAttributeName : [NSColor whiteColor]
  };

  for (NSInteger day = 1; day <= daysInMonth; day++) {
    CGFloat x = col * cellWidth;
    CGFloat y = headerY - 30 - row * cellHeight;

    NSString *dayStr = [NSString stringWithFormat:@"%ld", (long)day];

    // Today highlight
    if (isCurrentMonth && day == todayDay) {
      CGFloat circleSize = 28;
      NSRect circleRect = NSMakeRect(x + (cellWidth - circleSize) / 2, y - 2,
                                     circleSize, circleSize);
      [[NSColor colorWithRed:1.0 green:0.3 blue:0.3 alpha:1.0] setFill];
      [[NSBezierPath bezierPathWithOvalInRect:circleRect] fill];

      NSSize size = [dayStr sizeWithAttributes:todayAttrs];
      [dayStr drawAtPoint:NSMakePoint(x + (cellWidth - size.width) / 2, y + 3)
           withAttributes:todayAttrs];
    } else {
      NSSize size = [dayStr sizeWithAttributes:dayAttrs];
      [dayStr drawAtPoint:NSMakePoint(x + (cellWidth - size.width) / 2, y + 3)
           withAttributes:dayAttrs];
    }

    col++;
    if (col > 6) {
      col = 0;
      row++;
    }
  }
}

@end

@interface CalendarWindow ()
@property(nonatomic, strong) NSWindow *calendarWindow;
@property(nonatomic, strong) CalendarGridView *calendarGrid;
@property(nonatomic, strong) NSTextField *monthLabel;
@property(nonatomic, strong) NSDate *currentMonth;
@end

@implementation CalendarWindow

+ (instancetype)sharedInstance {
  static CalendarWindow *instance = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    instance = [[CalendarWindow alloc] init];
  });
  return instance;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    self.currentMonth = [NSDate date];
  }
  return self;
}

- (void)showWindow {
  if (self.calendarWindow) {
    [self.calendarWindow makeKeyAndOrderFront:nil];
    return;
  }

  NSRect frame = NSMakeRect(0, 0, 340, 380);
  self.calendarWindow = [[NSWindow alloc]
      initWithContentRect:frame
                styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                          NSWindowStyleMaskMiniaturizable
                  backing:NSBackingStoreBuffered
                    defer:NO];
  [self.calendarWindow setTitle:@"Calendar"];
  [self.calendarWindow center];

  NSView *contentView = [[NSView alloc] initWithFrame:frame];
  contentView.wantsLayer = YES;
  contentView.layer.backgroundColor = [[NSColor colorWithRed:0.11
                                                       green:0.11
                                                        blue:0.13
                                                       alpha:1.0] CGColor];
  [self.calendarWindow setContentView:contentView];

  // Header with month/year and navigation
  NSView *header =
      [[NSView alloc] initWithFrame:NSMakeRect(0, frame.size.height - 60,
                                               frame.size.width, 60)];
  header.wantsLayer = YES;
  header.layer.backgroundColor = [[NSColor colorWithRed:0.15
                                                  green:0.15
                                                   blue:0.18
                                                  alpha:1.0] CGColor];
  [contentView addSubview:header];

  // Previous month button
  NSButton *prevBtn =
      [[NSButton alloc] initWithFrame:NSMakeRect(10, 15, 30, 30)];
  prevBtn.title = @"◀";
  prevBtn.bezelStyle = NSBezelStyleTexturedRounded;
  prevBtn.target = self;
  prevBtn.action = @selector(previousMonth:);
  [header addSubview:prevBtn];

  // Next month button
  NSButton *nextBtn = [[NSButton alloc]
      initWithFrame:NSMakeRect(frame.size.width - 40, 15, 30, 30)];
  nextBtn.title = @"▶";
  nextBtn.bezelStyle = NSBezelStyleTexturedRounded;
  nextBtn.target = self;
  nextBtn.action = @selector(nextMonth:);
  [header addSubview:nextBtn];

  // Today button
  NSButton *todayBtn = [[NSButton alloc]
      initWithFrame:NSMakeRect(frame.size.width - 80, 15, 35, 30)];
  todayBtn.title = @"Today";
  todayBtn.bezelStyle = NSBezelStyleTexturedRounded;
  todayBtn.font = [NSFont systemFontOfSize:10];
  todayBtn.target = self;
  todayBtn.action = @selector(goToToday:);
  [header addSubview:todayBtn];

  // Month/Year label
  self.monthLabel =
      [[NSTextField alloc] initWithFrame:NSMakeRect(50, 18, 200, 25)];
  self.monthLabel.font = [NSFont systemFontOfSize:18
                                           weight:NSFontWeightSemibold];
  self.monthLabel.bezeled = NO;
  self.monthLabel.editable = NO;
  self.monthLabel.drawsBackground = NO;
  [header addSubview:self.monthLabel];

  [self updateMonthLabel];

  // Calendar grid
  self.calendarGrid = [[CalendarGridView alloc]
      initWithFrame:NSMakeRect(10, 10, frame.size.width - 20,
                               frame.size.height - 80)];
  self.calendarGrid.currentMonth = self.currentMonth;
  [contentView addSubview:self.calendarGrid];

  [self.calendarWindow makeKeyAndOrderFront:nil];
}

- (void)updateMonthLabel {
  NSDateFormatter *df = [[NSDateFormatter alloc] init];
  df.dateFormat = @"MMMM yyyy";
  self.monthLabel.stringValue = [df stringFromDate:self.currentMonth];
}

- (void)previousMonth:(id)sender {
  NSCalendar *calendar = [NSCalendar currentCalendar];
  self.currentMonth = [calendar dateByAddingUnit:NSCalendarUnitMonth
                                           value:-1
                                          toDate:self.currentMonth
                                         options:0];
  self.calendarGrid.currentMonth = self.currentMonth;
  [self updateMonthLabel];
  [self.calendarGrid setNeedsDisplay:YES];
}

- (void)nextMonth:(id)sender {
  NSCalendar *calendar = [NSCalendar currentCalendar];
  self.currentMonth = [calendar dateByAddingUnit:NSCalendarUnitMonth
                                           value:1
                                          toDate:self.currentMonth
                                         options:0];
  self.calendarGrid.currentMonth = self.currentMonth;
  [self updateMonthLabel];
  [self.calendarGrid setNeedsDisplay:YES];
}

- (void)goToToday:(id)sender {
  self.currentMonth = [NSDate date];
  self.calendarGrid.currentMonth = self.currentMonth;
  [self updateMonthLabel];
  [self.calendarGrid setNeedsDisplay:YES];
}

@end
