#import <Cocoa/Cocoa.h>

@protocol DockViewDelegate <NSObject>
- (void)dockItemClicked:(NSString *)appName;
@end

@interface DockView : NSView

@property (nonatomic, strong) NSArray *dockItems;
@property (nonatomic, assign) NSInteger hoveredItem;
@property (nonatomic, assign) NSInteger selectedItem;
@property (nonatomic, weak) id<DockViewDelegate> delegate;

- (void)selectItemAtIndex:(NSInteger)index;
- (void)deselectAllItems;
- (void)bounceItemAtIndex:(NSInteger)index;

@end
