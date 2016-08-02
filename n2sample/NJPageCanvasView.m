//
//  NJPageCanvasView.m
//  n2sample
//
//  Copyright (c) 2014 Neolab. All rights reserved.
//

#import "NJPageCanvasView.h"
#import <NISDK/NISDK.h>

#define MAX_NODE 1024

extern NSString * NJPageChangedNotification;
@interface NJPageCanvasView ()
@property (nonatomic) int strokeRenderedIndex;
@property (strong, nonatomic) NJNotebookPaperInfo *paperInfo;
@end

@implementation NJPageCanvasView
{
    float mX[MAX_NODE], mY[MAX_NODE], mFP[MAX_NODE];
    int mN;
}
@synthesize location;
@synthesize nodes=_nodes;
@synthesize page = _page;

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self setMultipleTouchEnabled:NO];
        [self setBackgroundColor:[UIColor whiteColor]];
        self.tempPath = [UIBezierPath bezierPath];
        [self.tempPath setLineWidth:1.2];
        self.pageChanging = YES;
        self.dataUpdating = NO;
        self.scrollView = nil;
        self.paperInfo = [NJNotebookPaperInfo sharedInstance];
        self.screenScale = 1.0f;
    }
    return self;
}

- (void) setPage:(NJPage *)page
{
    _page = page;
    _page.bounds = self.bounds;
    self.strokeRenderedIndex = (int)[self.page.strokes count] - 1;
    // pass nil for bgimage. This will generate bg imgage from pdf
    if (!CGSizeEqualToSize(self.bounds.size,CGSizeZero)) {
        self.incrementalImage = [self.page drawPageWithImage:nil size:self.bounds drawBG:YES opaque:YES];
    }
    
    self.pageChanging = NO;
    [self.tempPath removeAllPoints];
    NSLog(@"canvas view page opened");
    [self setNeedsDisplay];
}

- (void) setScrollView:(UIScrollView *)scrollView
{
    _scrollView = scrollView;
    [self.scrollView scrollRectToVisible:CGRectMake(self.frame.origin.x, self.frame.origin.y,
                                                    self.scrollView.frame.size.width,
                                                    self.scrollView.frame.size.height)  animated:NO];
}
- (void) touchBeganX: (float)x_coordinate Y: (float)y_coordinate
{
    CGPoint currentLocation;
    currentLocation.x = x_coordinate * self.page.screenRatio;
    currentLocation.y = y_coordinate * self.page.screenRatio;
    [self.tempPath moveToPoint:currentLocation];
    
    if (self.scrollView != nil) {
        float start_x = (currentLocation.x * self.screenScale)- self.scrollView.frame.size.width/2.;
        if (start_x < 0.0f) start_x = 0.0f;
        float start_y = (currentLocation.y * self.screenScale) - self.scrollView.frame.size.height/2.;
        if (start_y < 0.0f) start_y = 0.0f;
        //NSLog(@"frame origin x %f, y %f", self.frame.origin.x, self.frame.origin.y);
        [self.scrollView scrollRectToVisible:CGRectMake(start_x + self.frame.origin.x, start_y + self.frame.origin.y,
                                                        self.scrollView.frame.size.width,
                                                        self.scrollView.frame.size.height)  animated:YES];
    }
}

- (void) touchMovedX:(float)x_coordinate Y:(float)y_coordinate{
    
    CGPoint currentLocation;
    currentLocation.x = x_coordinate * self.page.screenRatio;
    currentLocation.y = y_coordinate * self.page.screenRatio;
    
    [self.tempPath addLineToPoint:currentLocation];
    [self setNeedsDisplay];
}

- (void)drawRect: (CGRect)rect
{
    if (self.pageChanging || self.dataUpdating) {
        return;
    }
    
    if (self.penUIColor) {
        UIColor *strokeColor = self.penPenColor ? self.penPenColor:self.penUIColor;
        [strokeColor setStroke];
    }
    
    [self.incrementalImage drawInRect:rect];
    [self.tempPath stroke];
}

- (void) strokeUpdated
{
    int lastIndex = (int)[self.page.strokes count] - 1;
    if (self.strokeRenderedIndex >= lastIndex) {
        return;
    }
    for (int i = self.strokeRenderedIndex+1;i <= lastIndex; i++) {
        NJStroke *stroke = [[self.page strokes] objectAtIndex:i];
        if (stroke.type != MEDIA_STROKE) {
            continue;
        }
        self.incrementalImage = [self.page drawStroke:stroke withImage:self.incrementalImage
                                                  size:self.bounds scale:1.0 offsetX:0.0 offsetY:0.0 drawBG:YES opaque:YES];
        NSLog(@"self.incrementalImage:%d", self.incrementalImage? YES:NO);
    }
    self.strokeRenderedIndex = lastIndex;
    [self.tempPath removeAllPoints];
    [self setNeedsDisplay];
}

- (void) drawAllStroke
{
    self.strokeRenderedIndex = (int)[self.page.strokes count] - 1;
    
    UIImage *write_image = [self.page drawPageWithImage:nil size:self.bounds drawBG:YES opaque:YES];
    self.incrementalImage = write_image;
    
    self.pageChanging = NO;
    [self setNeedsDisplay];
}




@end
