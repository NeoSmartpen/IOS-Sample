//
//  NJOfflineSyncViewController.m
//  n2sample
//
//  Copyright (c) 2014년 Neolab. All rights reserved.
//

#import "NJOfflineSyncViewController.h"
#import <NISDK/NISDK.h>
#import "NJPageCanvasController.h"

#define kViewTag			1
#define POINT_COUNT_MAX 1024

static NSString *kTitleKey = @"title";
static NSString *kViewKey = @"viewKey";
static NSString *kViewControllerKey = @"viewController";
static NSString *kSwitchCellId = @"SwitchCell";
static NSString *kControlCellId = @"ControlCell";
static NSString *kPauseCellId = @"PauseCell";

NSString * NJOfflineSyncNotebookCompleteNotification = @"NJOfflineSyncNotebookCompleteNotification";

typedef enum {
    OFFLINE_DOT_CHECK_NONE,
    OFFLINE_DOT_CHECK_FIRST,
    OFFLINE_DOT_CHECK_SECOND,
    OFFLINE_DOT_CHECK_THIRD,
    OFFLINE_DOT_CHECK_NORMAL
}OFFLINE_DOT_CHECK_STATE;

@interface NJOfflineSyncCustomTableViewCell : UITableViewCell
@end

@implementation NJOfflineSyncCustomTableViewCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    return [super initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:reuseIdentifier];
}

- (void) layoutSubviews {
    [super layoutSubviews];
    self.textLabel.frame = CGRectMake(30, 35, 320, 20);
}
@end

@interface NJOfflineSyncViewController () <NJOfflineDataDelegate>
{
    OffLineDataDotStruct offlineDotData0, offlineDotData1, offlineDotData2;
    OFFLINE_DOT_CHECK_STATE offlineDotCheckState;
}

@property (nonatomic,retain) UITableView *tableView;
@property (nonatomic, strong) NSMutableArray *menuList;
@property (nonatomic, strong) UITableViewController *tableViewController;
@property (nonatomic, strong) UIRefreshControl *refreshControl;
@property (nonatomic, strong) UILabel *dateLabel;
@property (nonatomic, strong) NSString *lastUpdated;
@property (nonatomic, strong) CALayer *layer;
@property (nonatomic) float progressValue;
@property (nonatomic, strong) UIProgressView *progressView;
@property (nonatomic) UInt32 ownerIdToRequest;
@property (nonatomic) UInt32 noteIdToRequest;
@property (nonatomic, strong) NSNumber *noteId;
@property (nonatomic) BOOL noteChange;
@property (nonatomic, strong) UIButton *pButton;
@property (nonatomic) BOOL pauseBtn;
@property (nonatomic, strong) NSMutableArray *offlineIdList;
@property (nonatomic, strong) NSMutableArray *noteIdList;
@property (nonatomic, strong) NSMutableDictionary *noteDict;
@property (nonatomic, strong) UIActivityIndicatorView *indicator;

@end

@implementation NJOfflineSyncViewController
{
    float *point_x_buff;
    float *point_y_buff;
    float *point_p_buff;
    int *time_diff_buff;
    int point_index;
}
@synthesize showOfflineFileList;


- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        
        // Custom initialization
        self.tableView = [[UITableView alloc] init];
        
        UIImageView *tempImageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"bg_settings.png"]];
        [tempImageView setFrame:self.tableView.frame];
        
        self.tableView.backgroundView = tempImageView;
        self.tableView.delegate = self;
        self.tableView.dataSource = self;
        
        [self.tableView setSeparatorStyle:UITableViewCellSeparatorStyleSingleLine];
        
        [self.tableView setSeparatorInset:UIEdgeInsetsZero];
        [self.tableView setSeparatorColor:[UIColor colorWithPatternImage:[UIImage imageNamed:@"line_navidrawer.png"]]];
        
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    
    
    self.navigationController.navigationBar.tintColor = [UIColor whiteColor];
    [self.navigationController.navigationBar setTitleTextAttributes:@{NSForegroundColorAttributeName : [UIColor whiteColor]}];
    
    [self.navigationController.navigationBar setBackgroundImage:[UIImage new] forBarMetrics:UIBarMetricsDefault];
    self.navigationController.navigationBar.shadowImage = [UIImage new];
    self.navigationController.navigationBar.translucent = YES;
    
    self.view.layer.cornerRadius = 5;
    self.view.layer.masksToBounds = YES;
    self.navigationController.navigationBar.layer.mask = [self roundedCornerNavigationBar];

    self.menuList = [NSMutableArray array];
    self.noteDict = [NSMutableDictionary dictionary];
    
    [self.tableView setSeparatorStyle:UITableViewCellSeparatorStyleSingleLine];
    
    [self.tableView setSeparatorInset:UIEdgeInsetsZero];
    [self.tableView setSeparatorColor:[UIColor colorWithPatternImage:[UIImage imageNamed:@"line_navidrawer.png"]]];
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    self.tableView.tableFooterView.backgroundColor = self.tableView.backgroundColor;
    
    [self.tableView registerClass:[NJOfflineSyncCustomTableViewCell class] forCellReuseIdentifier:kSwitchCellId];

    self.tableView.frame = self.view.bounds;
    [self.view addSubview:self.tableView];
    
}

#pragma mark - UIViewController delegate

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    self.indicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    self.indicator.center = CGPointMake(160, 240);
    self.indicator.hidesWhenStopped = YES;
    [self.view addSubview:self.indicator];
    
    [[NJPenCommManager sharedInstance] setOfflineDataDelegate:self];
    
    NSIndexPath *tableSelection = [self.tableView indexPathForSelectedRow];
    [self.tableView deselectRowAtIndexPath:tableSelection animated:NO];
    
    // Register Listeners for pen notifications
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(nextOfflineNotebook:) name:NJOfflineSyncNotebookCompleteNotification object:nil];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [[NJPenCommManager sharedInstance] setOfflineDataDelegate:nil];
    
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc removeObserver:self name:NJOfflineSyncNotebookCompleteNotification object:nil];
    
    [super viewWillDisappear:animated];
    
}

- (CAShapeLayer *)roundedCornerNavigationBar
{
    
    UIBezierPath *maskPath = [UIBezierPath bezierPathWithRoundedRect:self.navigationController.navigationBar.bounds
                                                   byRoundingCorners:(UIRectCornerTopLeft | UIRectCornerTopRight)
                                                         cornerRadii:CGSizeMake(5.0, 5.0)];
    
    CAShapeLayer *maskLayer = [CAShapeLayer layer];
    maskLayer.frame = self.navigationController.navigationBar.bounds;
    maskLayer.path = maskPath.CGPath;
    
    return maskLayer;
}

-(void) nextOfflineNotebook:(NSNotification *)notification
{
    UInt32 noteIdToRequest = 0;
    UInt32 ownerIdToRequest = 0;
    
    [self.menuList removeObjectAtIndex:0];
    [self.noteDict removeObjectForKey:self.noteId];
    
    if (([self.menuList count] && (self.pauseBtn == NO))) {
        NSNumber *noteId = [self.menuList objectAtIndex:0];
        noteIdToRequest = (UInt32)[noteId unsignedIntegerValue];
        self.noteId = noteId;
        NSNumber *ownerId = [self.noteDict objectForKey:noteId];
        ownerIdToRequest = (UInt32)[ownerId unsignedIntegerValue];
        if(ownerIdToRequest != 0) {
            //from the second notebook
            [[NJPenCommManager sharedInstance] requestOfflineDataWithOwnerId:ownerIdToRequest noteId:noteIdToRequest];
            
        }
        
    }
    [self.tableView reloadData];
    
    if ([self.menuList count] == 0) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Offline Sync", @"")
                                                        message:NSLocalizedString(@"Offline Sync Completion", @"")
                                                       delegate:nil
                                              cancelButtonTitle:NSLocalizedString(@"OK", @"")
                                              otherButtonTitles:nil];
        
        [alert show];
        if ([self.noteDict count]) {
            [self.noteDict removeAllObjects];
        }

        [NJPenCommManager sharedInstance].penCommParser.shouldSendPageChangeNotification = YES;
        
        NJPageCanvasController *pageCanvasController = [[NJPageCanvasController alloc] initWithNibName:nil bundle:nil];
        pageCanvasController.offlineSyncViewController = self;
        pageCanvasController.parentController = self.parentController;
        pageCanvasController.canvasPage = self.oPage;
        [self presentViewController:pageCanvasController animated:YES completion:^{
        }];
    }
}

#pragma mark - NJOfflineDataDelegate
// NJOfflineDataDelegate sample implementation
- (void) offlineDataDidReceiveNoteList:(NSDictionary *)noteListDic
{
    BOOL needNext = YES;
    UInt32 ownerIdToRequest = 0;
    UInt32 noteIdToRequest = 0;
    NSEnumerator *enumerator = [noteListDic keyEnumerator];
    
    // Parse NoteListDictionary
    while (needNext) {
        NSNumber *ownerId = [enumerator nextObject];
        if (ownerId == nil) {
            NSLog(@"Offline data : no more owner ID left");
            break;
        }
        if (ownerIdToRequest == 0 || noteIdToRequest == 0) {
            ownerIdToRequest = (UInt32)[ownerId unsignedIntegerValue];
            
        }
        NSLog(@"** Owner Id : %@", ownerId);
        NSArray *noteList = [noteListDic objectForKey:ownerId];
        self.menuList = [noteList mutableCopy];
        for (NSNumber *noteId in noteList) {
            if (noteIdToRequest == 0) {
                noteIdToRequest = (UInt32)[noteId unsignedIntegerValue];
            }
            [self.noteDict setObject:ownerId forKey:noteId];
            NSLog(@"   - Note Id : %@", noteId);
        }
    }
    
    NSArray *keysArray = [self.noteDict allKeys];
    self.menuList = [keysArray mutableCopy];
    NSUInteger count = [self.menuList count];
    if (count) {
        NSNumber *noteId = [self.menuList objectAtIndex:0];
        noteIdToRequest = (UInt32)[noteId unsignedIntegerValue];
        self.noteId = noteId;
        NSNumber *ownerId = [self.noteDict objectForKey:noteId];
        ownerIdToRequest = (UInt32)[ownerId unsignedIntegerValue];
        
    }
    
    if ([self.menuList count]) {
        [self.tableView reloadData];
    }
    //for the only first notebook
    if((ownerIdToRequest != 0) && !showOfflineFileList) {
        [[NJPenCommManager sharedInstance] requestOfflineDataWithOwnerId:ownerIdToRequest noteId:noteIdToRequest];
    }
}

- (void) offlineDataReceiveStatus:(OFFLINE_DATA_STATUS)status percent:(float)percent
{
    NSLog(@"offlineDataReceiveStatus : status %d, percent %f", status, percent);

    [self.indicator startAnimating];
    
    if (status == OFFLINE_DATA_RECEIVE_END) {
        [self.indicator stopAnimating];
        if ([self.menuList count]) {
            [[NSNotificationCenter defaultCenter] postNotificationName:NJOfflineSyncNotebookCompleteNotification object:nil userInfo:nil];

        }
        
    }
}

- (void) offlineDataReceivePercent:(float)percent
{
    NSLog(@"offlineDataReceiveStatus : percent %f", percent);
    self.progressView.progress = percent/100.0f;
    
}

- (void)offlineDataDidReceiveNoteListCount:(int)noteCount ForSectionOwnerId:(UInt32)sectionOwnerId
{
    unsigned char section = (sectionOwnerId >> 24) & 0xFF;
    UInt32 ownerId = sectionOwnerId & 0x00FFFFFF;
    
    int offlineDataListNoteCount = noteCount;
    NSLog(@"offline Data Note List Count: %d for sectionId %d, ownerId %d", offlineDataListNoteCount, section, ownerId);
}

- (void)offlineDataPathBeforeParsed:(NSString *)path
{
    NSString *offlineDataPath = path;
    NSLog(@"offline raw data path: %@", offlineDataPath);
}

- (void) parseOfflineDots:(NSData *)penData startAt:(int)position withFileHeader:(OffLineDataFileHeaderStruct *)pFileHeader
          andStrokeHeader:(OffLineDataStrokeHeaderStruct *)pStrokeHeader
{
    OffLineDataDotStruct dot;
    NSRange range = {position, sizeof(OffLineDataDotStruct)};
    int dotCount = MIN(MAX_NODE_NUMBER, pStrokeHeader->nDotCount);
    point_x_buff = malloc(sizeof(float)* dotCount);
    point_y_buff = malloc(sizeof(float)* dotCount);
    point_p_buff = malloc(sizeof(float)* dotCount);
    time_diff_buff = malloc(sizeof(int)* dotCount);
    point_index = 0;
    
    offlineDotCheckState = OFFLINE_DOT_CHECK_FIRST;
    UInt64 startTime = pStrokeHeader->nStrokeStartTime;
    //    NSLog(@"offline time %llu", startTime);
    UInt32 color = pStrokeHeader->nLineColor;
    UInt32 offlinePenColor;
    if (/*(color & 0xFF000000) == 0x01000000 && */(color & 0x00FFFFFF) != 0x00FFFFFF && (color & 0x00FFFFFF) != 0x00000000) {
        offlinePenColor = color | 0xFF000000; // set Alpha to 255
    }
    else
        offlinePenColor = 0;
    NSLog(@"offlinePenColor 0x%x", (unsigned int)offlinePenColor);
    
    if (!self.oPage) {
        self.oPage = [[NJPage alloc] initWithNotebookId:pFileHeader->nNoteId andPageNumber:pFileHeader->nPageId];
    }
    
    for (int i =0; i < pStrokeHeader->nDotCount; i++) {
        [penData getBytes:&dot range:range];
        
        [self dotCheckerForOfflineSync:&dot];
        
        if(point_index >= MAX_NODE_NUMBER){
            [self offlineDotCheckerLast];
            
            NJStroke *stroke = [[NJStroke alloc] initWithRawDataX:point_x_buff Y:point_y_buff pressure:point_p_buff time_diff:time_diff_buff
                                                         penColor:offlinePenColor penThickness:1 startTime:startTime size:point_index
                                                       normalizer:self.oPage.inputScale];
            
            [self.oPage insertStrokeByTimestamp:stroke];
            point_index = 0;
        }
        position += sizeof(OffLineDataDotStruct);
        range.location = position;
    }
    [self offlineDotCheckerLast];
    
    NJStroke *stroke = [[NJStroke alloc] initWithRawDataX:point_x_buff Y:point_y_buff pressure:point_p_buff time_diff:time_diff_buff
                                                 penColor:offlinePenColor penThickness:1 startTime:startTime size:point_index
                                                 normalizer:self.oPage.inputScale];
    
    [self.oPage insertStrokeByTimestamp:stroke];
    point_index = 0;
    
    free(point_x_buff);
    free(point_y_buff);
    free(point_p_buff);
    free(time_diff_buff);
    
}

- (void) dotCheckerForOfflineSync:(OffLineDataDotStruct *)aDot
{
    if (offlineDotCheckState == OFFLINE_DOT_CHECK_NORMAL) {
        if ([self offlineDotCheckerForMiddle:aDot]) {
            [self offlineDotAppend:&offlineDotData2];
            offlineDotData0 = offlineDotData1;
            offlineDotData1 = offlineDotData2;
        }
        else {
            NSLog(@"offlineDotChecker error : middle");
        }
        offlineDotData2 = *aDot;
    }
    else if(offlineDotCheckState == OFFLINE_DOT_CHECK_FIRST) {
        offlineDotData0 = *aDot;
        offlineDotData1 = *aDot;
        offlineDotData2 = *aDot;
        offlineDotCheckState = OFFLINE_DOT_CHECK_SECOND;
    }
    else if(offlineDotCheckState == OFFLINE_DOT_CHECK_SECOND) {
        offlineDotData2 = *aDot;
        offlineDotCheckState = OFFLINE_DOT_CHECK_THIRD;
    }
    else if(offlineDotCheckState == OFFLINE_DOT_CHECK_THIRD) {
        if ([self offlineDotCheckerForStart:aDot]) {
            [self offlineDotAppend:&offlineDotData1];
            if ([self offlineDotCheckerForMiddle:aDot]) {
                [self offlineDotAppend:&offlineDotData2];
                offlineDotData0 = offlineDotData1;
                offlineDotData1 = offlineDotData2;
            }
            else {
                NSLog(@"offlineDotChecker error : middle2");
            }
        }
        else {
            offlineDotData1 = offlineDotData2;
            NSLog(@"offlineDotChecker error : start");
        }
        offlineDotData2 = *aDot;
        offlineDotCheckState = OFFLINE_DOT_CHECK_NORMAL;
    }
}

- (void) offlineDotAppend:(OffLineDataDotStruct *)dot
{
    float pressure, x, y;
    
    float startX = [[NJPenCommManager sharedInstance] startX];
    float startY = [[NJPenCommManager sharedInstance] startY];
    
    x = (float)dot->x + (float)dot->fx * 0.01f;
    y = (float)dot->y + (float)dot->fy * 0.01f;
    pressure = [[NJPenCommManager sharedInstance] processPressure:(float)dot->force];
    point_x_buff[point_index] = x - startX;
    point_y_buff[point_index] = y - startY;
    point_p_buff[point_index] = pressure;
    time_diff_buff[point_index] = dot->nTimeDelta;
    point_index++;
}

- (BOOL) offlineDotCheckerForStart:(OffLineDataDotStruct *)aDot
{
    static const float delta = 2.0f;
    if (offlineDotData1.x > 150 || offlineDotData1.x < 1) return NO;
    if (offlineDotData1.y > 150 || offlineDotData1.y < 1) return NO;
    if ((aDot->x - offlineDotData1.x) * (offlineDotData2.x - offlineDotData1.x) > 0
        && ABS(aDot->x - offlineDotData1.x) > delta && ABS(offlineDotData1.x - offlineDotData2.x) > delta)
    {
        return NO;
    }
    if ((aDot->y - offlineDotData1.y) * (offlineDotData2.y - offlineDotData1.y) > 0
        && ABS(aDot->y - offlineDotData1.y) > delta && ABS(offlineDotData1.y - offlineDotData2.y) > delta)
    {
        return NO;
    }
    return YES;
}
- (BOOL) offlineDotCheckerForMiddle:(OffLineDataDotStruct *)aDot
{
    static const float delta = 2.0f;
    if (offlineDotData2.x > 150 || offlineDotData2.x < 1) return NO;
    if (offlineDotData2.y > 150 || offlineDotData2.y < 1) return NO;
    if ((offlineDotData1.x - offlineDotData2.x) * (aDot->x - offlineDotData2.x) > 0
        && ABS(offlineDotData1.x - offlineDotData2.x) > delta && ABS(aDot->x - offlineDotData2.x) > delta)
    {
        return NO;
    }
    if ((offlineDotData1.y - offlineDotData2.y) * (aDot->y - offlineDotData2.y) > 0
        && ABS(offlineDotData1.y - offlineDotData2.y) > delta && ABS(aDot->y - offlineDotData2.y) > delta)
    {
        return NO;
    }
    
    return YES;
}
- (BOOL) offlineDotCheckerForEnd
{
    static const float delta = 2.0f;
    if (offlineDotData2.x > 150 || offlineDotData2.x < 1) return NO;
    if (offlineDotData2.y > 150 || offlineDotData2.y < 1) return NO;
    if ((offlineDotData2.x - offlineDotData0.x) * (offlineDotData2.x - offlineDotData1.x) > 0
        && ABS(offlineDotData2.x - offlineDotData0.x) > delta && ABS(offlineDotData2.x - offlineDotData1.x) > delta)
    {
        return NO;
    }
    if ((offlineDotData2.y - offlineDotData0.y) * (offlineDotData2.y - offlineDotData1.y) > 0
        && ABS(offlineDotData2.y - offlineDotData0.y) > delta && ABS(offlineDotData2.y - offlineDotData1.y) > delta)
    {
        return NO;
    }
    return YES;
}

- (void) offlineDotCheckerLast
{
    if ([self offlineDotCheckerForEnd]) {
        [self offlineDotAppend:&offlineDotData2];
        offlineDotData2.x = 0.0f;
        offlineDotData2.y = 0.0f;
    }
    else {
        NSLog(@"offlineDotChecker error : end");
    }
    offlineDotCheckState = OFFLINE_DOT_CHECK_NONE;
}

#pragma mark - UITableViewDelegate

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.menuList.count;
}

- (NJOfflineSyncCustomTableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NJOfflineSyncCustomTableViewCell *cell = nil;
    
    cell = [tableView dequeueReusableCellWithIdentifier:kSwitchCellId forIndexPath:indexPath];
    
    NSUInteger noteId = [[self.menuList objectAtIndex:indexPath.row] integerValue];
    cell.textLabel.text = [self noteTitle:noteId];
    cell.textLabel.textColor = [UIColor whiteColor];
    cell.backgroundColor = [UIColor clearColor];
    
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    
    cell.textLabel.opaque = NO;
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 55.0;
}

- (UIView*)tableView:(UITableView*)tableView viewForHeaderInSection:(NSInteger)section {
    
    NSString* sectionHeader = NSLocalizedString(@"Offline File List", @"");
    
    UIView* view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 24)];
    
    UILabel* label = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 320, 24)];
    
    label.backgroundColor = [UIColor clearColor];
    label.textColor = [UIColor whiteColor];
    label.text = sectionHeader;
    label.textAlignment = NSTextAlignmentCenter;
    label.font = [label.font fontWithSize:21.0f];
    
    UIView* separatorLowerLineView = [[UIView alloc] initWithFrame:CGRectMake(0, 40, 320, 0.5)];
    separatorLowerLineView.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"line_navidrawer.png"]];
    
    [view addSubview:separatorLowerLineView];
    [view addSubview:label];
    
    return view;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return 40;
}

- (void)startStopAdvertizing:(id)sender
{
    
}

- (NSString *) noteTitle:(NSInteger)type
{
    NSString *notebookTitle;
    
    switch (type) {
        case 601:
            notebookTitle = @"Pocket Note";
            break;
        case 602:
            notebookTitle = @"Memo Note";
            break;
        case 603:
            notebookTitle = @"Spring Note";
            break;
        case 605:
            notebookTitle = @"FP Memo Pad";
            break;
        default:
            notebookTitle = @"Unknown Note";
            break;
    }
    return notebookTitle;
}


@end

