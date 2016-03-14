//
//  NJViewController.h
//  n2sample
//
//  Copyright (c) 2014년 Neolab. All rights reserved.
//

#import <UIKit/UIKit.h>

@class NJPageCanvasController;
@interface NJViewController : UIViewController
@property (weak, nonatomic) IBOutlet UILabel *statusMessage;
@property (weak, nonatomic) IBOutlet UIButton *connectButton;
@property (nonatomic) BOOL canvasCloseBtnPressed;
@property (nonatomic, strong) NJPageCanvasController *pageCanvasController;

@end
