//
//  NJFWUpdateViewController.m
//  n2sample
//
//  Copyright (c) 2014년 Neolab. All rights reserved.
//

#import "NJFWUpdateViewController.h"
#import "NJAppDelegate.h"
#import <NISDK/NISDK.h>

@interface NJFWUpdateViewController () <UIAlertViewDelegate, NJFWUpdateDelegate>

@property (nonatomic, strong) NSString *penFWVersion;
@property (nonatomic) int counter;

@end

@implementation NJFWUpdateViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
        
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    [self initVC];
    [self updatePenFWVerision];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [self downloadNewFW];
}

- (void)viewWillDisappear:(BOOL)animated
{
    
    [super viewWillDisappear:animated];
    
    [self cancelTask];
}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)initVC
{
    _penFWVersion = nil;
    _progressView.alpha = 0.0f;
    _progressViewLabel.text = @"";
    [self animateProgressView:YES withString:@""];
    _progressBar.progress = 0.0f;
    [_indicator startAnimating];
    [[NJPenCommManager sharedInstance] setFWUpdateDelegate:self];
}

- (void)updatePenFWVerision
{
    
    NSString *internalFWVersion = [[NJPenCommManager sharedInstance] getFWVersion];
    NSArray * array = [internalFWVersion componentsSeparatedByString:@"."];
    _penFWVersion = [NSString stringWithFormat:@"%@.%@", array[0], array[1]];
    
    self.penVersionLabel.text = [NSString stringWithFormat:@"v.%@",_penFWVersion];

}

- (void)cancelTask
{
    [NJPenCommManager sharedInstance].cancelFWUpdate = YES;
    
    _progressBar.progress = 0.0f;

}



- (void)downloadNewFW
{
    NSString *updateFilePath = [[NSBundle mainBundle] pathForResource:@"NEO1" ofType:@"zip"];
    NSURL *filePath = [NSURL fileURLWithPath:updateFilePath];
    
    _progressBar.progress = 0.0f;
    
    [self animateProgressView:NO withString:@"Start updating pen firmware.."];
    
    _counter = 0;
    
    [[NJPenCommManager sharedInstance] sendUpdateFileInfoAtUrlToPen:filePath];
    [_indicator startAnimating];
   
}

- (void)fwUpdateDataReceiveStatus:(FW_UPDATE_DATA_STATUS)status percent:(float)percent
{
    if(status == FW_UPDATE_DATA_RECEIVE_END) {

        [_indicator stopAnimating];
        [self animateProgressView:YES withString:nil];

        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"FW Update", @"")
                                                        message:NSLocalizedString(@"Success", @"")
                                                       delegate:nil
                                              cancelButtonTitle:NSLocalizedString(@"OK", @"")
                                              otherButtonTitles:nil];
        
        [alert show];
        
    } else if(status == FW_UPDATE_DATA_RECEIVE_FAIL) {
        
        [self animateProgressView:YES withString:@""];
        [self cancelTask];
        [_indicator stopAnimating];
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"FW Update", @"")
                                                        message:NSLocalizedString(@"Failure", @"")
                                                       delegate:nil
                                              cancelButtonTitle:NSLocalizedString(@"OK", @"")
                                              otherButtonTitles:nil];
        
        [alert show];
        
    } else {
        _progressBar.progress = (percent/100.0f);
        
        if((_counter ++ % 10) == 5)
            _progressViewLabel.text = [NSString stringWithFormat:@"Updating pen firmware (%2d%%)",(int)percent];
    }
}


-(void)animateProgressView:(BOOL)hide withString:(NSString *)message
{
    if(!hide) {
        _progressViewLabel.text = message;
        
    }
    
    [UIView animateWithDuration:0.3f
                          delay:(0.1f)
                        options:UIViewAnimationOptionCurveLinear | UIViewAnimationOptionAllowUserInteraction
                     animations:^(void) {
                         
                         if(!hide)
                             _progressView.alpha = 1.0f;
                         else
                             _progressView.alpha = 0.0f;
                         
                     }
                     completion:^(BOOL finished) {
                         
                         
                     }
     ];
}

@end

