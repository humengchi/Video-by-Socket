//
//  CameraViewController.m
//  Coordinate
//
//  Created by hmc on 24/11/14.
//  Copyright (c) 2014年 Corrine Chan. All rights reserved.
//

#import "CameraViewController.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import <AVFoundation/AVFoundation.h>
#define PS 15
//#define REAL_IPHONE  //是否真机测试
#define HMC //打印log

static int tapNumber;
static int switchNumber;

static double upload;
static double download;
static int    sendNumber;
static int    sendNumber_t;
static int    uploadNumber;

static int    isFirstReceive;   //是否第一次接收数据 1:是 0:否

static int    sendNO;           //发送的图片的序号
static int    receiveNO;        //接收的图片的序号

static int seconds = 1;

static int xuhao = 1; //序号

static int lostPS = 1;//接收上一次的序号

static int allLostPS = 0;//丢失的全部帧数

@interface CameraViewController ()<UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIGestureRecognizerDelegate>
{
    UIImagePickerController *picker;
    NSDate *flagDate;
    int fps;
    
}
@property (nonatomic, strong) UIButton *overlayerBtn;

@property (nonatomic, strong) AVCaptureSession *session;

@end

@implementation CameraViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
        _receiveData = [[NSMutableData alloc] init];
        _allNumber = [[NSMutableData alloc] init];
        _everyNumber = [[NSMutableData alloc] init];
        _timeData = [[NSMutableData alloc] init];
        _tableArray = [[NSMutableArray alloc] init];
    }
    return self;
}

- (NSString *)getIPAddress
{
    NSString *address = @"error";
    struct ifaddrs *interfaces = NULL;
    struct ifaddrs *temp_addr = NULL;
    int success = 0;
    // retrieve the current interfaces - returns 0 on success
    success = getifaddrs(&interfaces);
    if (success == 0)
    {
        // Loop through linked list of interfaces
        temp_addr = interfaces;
        while(temp_addr != NULL)
        {
            if(temp_addr->ifa_addr->sa_family == AF_INET)
            {
                // Check if interface is en0 which is the wifi connection on the iPhone
                if([[NSString stringWithUTF8String:temp_addr->ifa_name] isEqualToString:@"en0"])
                {
                    // Get NSString from C String
                    address = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)temp_addr->ifa_addr)->sin_addr)];
                }
            }
            temp_addr = temp_addr->ifa_next;
        }
    }
    // Free memory
    freeifaddrs(interfaces);
    return address;
    
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];
    self.edgesForExtendedLayout = UIRectEdgeNone;
    
    NSLog(@"localIP:%@", [self getIPAddress]);
    
    [[UIApplication sharedApplication] setIdleTimerDisabled:YES];
    flagDate = [NSDate date];
    upload = download = 0;
    switchNumber = tapNumber = 1;
    sendNumber_t = 1;
    isFirstReceive = 1;
    sendNO = receiveNO = 0;
    fps = 0;
    
    NSString *ip_iphone = [self getIPAddress];
    self.myIP = ip_iphone;
    
    switchNumber = tapNumber = 1;
    UIView *keyWindow =  [[UIView alloc] initWithFrame:self.view.bounds];//[UIApplication sharedApplication].keyWindow;
    _otherImage = [[UIImageView alloc] initWithFrame:self.view.bounds];
    _otherImage.layer.borderColor = [UIColor grayColor].CGColor;
    [keyWindow addSubview:_otherImage];
    
    UIView *keyView = [[UIView alloc] initWithFrame:keyWindow.bounds];
    keyView.backgroundColor = [UIColor blackColor];
    keyView.alpha = 0.3;
    keyView.tag = 2002;
    [keyWindow addSubview:keyView];
    
    
    
    _myselfImage = [[UIImageView alloc] initWithFrame:CGRectMake(200, 370, 100, 150)];
    _myselfImage.layer.borderWidth = 0.5;
    _myselfImage.layer.borderColor = [UIColor grayColor].CGColor;
    [keyWindow addSubview:_myselfImage];
    
    CGRect frame = _myselfImage.frame;
    if(!DEVICE_IS_IPHONE5 && IOS7_OR_LATER){
        frame.origin.y -= 50;
        _myselfImage.frame = frame;
    }else if(!DEVICE_IS_IPHONE5 && !IOS7_OR_LATER){
        frame.origin.y -= 70;
        _myselfImage.frame = frame;
    }
    
    
    UIButton *switchBtn = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    switchBtn.frame = CGRectMake(200, 280, 80, 30);
    [switchBtn setTitle:@"Switch" forState:UIControlStateNormal];
    [switchBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [switchBtn addTarget:self action:@selector(switchDeviceCamera:) forControlEvents:UIControlEventTouchUpInside];
    [switchBtn setBackgroundColor:[UIColor lightGrayColor]];
//    [keyView addSubview:switchBtn];
    
    _speedLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 50, 280, 30)];
    _speedLabel.font = [UIFont boldSystemFontOfSize:15];
    _speedLabel.textAlignment = NSTextAlignmentCenter;
    _speedLabel.text = [NSString stringWithFormat:@"上传速度：10kb/s    下载速度：20kb/s"];
    _speedLabel.textColor = [UIColor whiteColor];
    [keyView addSubview:_speedLabel];
    keyView.alpha = 0;
    
    _psLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 90, 280, 30)];
    _psLabel.font = [UIFont boldSystemFontOfSize:15];
    _psLabel.textAlignment = NSTextAlignmentCenter;
    _psLabel.text = [NSString stringWithFormat:@"丢失的帧数：0FPS   时间：0s"];
    _psLabel.textColor = [UIColor whiteColor];
    [keyView addSubview:_psLabel];
    
    _myTableView = [[UITableView alloc] initWithFrame:CGRectMake(20, 130, 280, 100) style:UITableViewStylePlain];
    _myTableView.autoresizingMask = UIViewAutoresizingFlexibleHeight;
    _myTableView.backgroundView=nil;
    _myTableView.backgroundColor = [UIColor clearColor];
    _myTableView.dataSource=self;
    _myTableView.delegate=self;
    [_myTableView.layer setBorderWidth:1];
    [_myTableView.layer setBorderColor:[UIColor whiteColor].CGColor];
    _myTableView.separatorStyle=UITableViewCellSeparatorStyleNone;
//    [keyView addSubview:_myTableView];
    
    [self.view addSubview:keyWindow];
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tap)];
    tap.delegate = self;
    [keyWindow addGestureRecognizer:tap];
#ifdef REAL_IPHONE
    [self setupCaptureSession];
#endif
    [self openUDPServer];
    
    NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(showSpeed) userInfo:nil repeats:YES];
    [timer fire];
    
}

- (void)showSpeed
{
    _speedLabel.text = [NSString stringWithFormat:@"上传速度：%.0fkb/s    下载速度：%.0fkb/s", upload/1024, download/1024];
    seconds++;
    _psLabel.text = [NSString stringWithFormat:@"丢失的帧数：%dFPS   时间：%ds",fps, seconds];
    upload = download = 0;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark -
#pragma mark Methods
- (AVCaptureDevice *)cameraWithPosition:(AVCaptureDevicePosition)position
{
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for ( AVCaptureDevice *device in devices )
        if ( device.position == position )
            return device;
    return nil;
}

- (IBAction)switchDeviceCamera:(UIButton*)sender
{
    // Assume the session is already running
    NSArray *inputs = self.session.inputs;
    for ( AVCaptureDeviceInput *input in inputs ) {
        AVCaptureDevice *device = input.device;
        if ( [device hasMediaType:AVMediaTypeVideo] ) {
            AVCaptureDevicePosition position = device.position;
            AVCaptureDevice *newCamera = nil;
            AVCaptureDeviceInput *newInput = nil;
            
            if (position == AVCaptureDevicePositionFront)
                newCamera = [self cameraWithPosition:AVCaptureDevicePositionBack];
            else
                newCamera = [self cameraWithPosition:AVCaptureDevicePositionFront];
            newInput = [AVCaptureDeviceInput deviceInputWithDevice:newCamera error:nil];
            
            // beginConfiguration ensures that pending changes are not applied immediately
            [self.session beginConfiguration];
            
            [self.session removeInput:input];
            [self.session addInput:newInput];
            
            // Changes take effect once the outermost commitConfiguration is invoked.
            [self.session commitConfiguration];
            break;
        }
    }
    AVCaptureVideoPreviewLayer* preLayer = [AVCaptureVideoPreviewLayer layerWithSession: _session];
    preLayer = [AVCaptureVideoPreviewLayer layerWithSession:_session];
    preLayer.frame = _myselfImage.frame;
    preLayer.borderColor = [UIColor whiteColor].CGColor;
    preLayer.borderWidth = 3;
    
    preLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    [self.view.layer addSublayer:preLayer];
}

- (void)tap
{
    UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
    UIView *keyView = (UIView*)[keyWindow viewWithTag:2002];
    if(tapNumber){
        keyView.alpha = 0.2;
    }else{
        keyView.alpha = 0;
    }
    tapNumber = tapNumber?0:1;
}

#pragma mark-
#pragma mark AVCaptureSession
- (void)setupCaptureSession
{
    NSError *error = nil;
    _session = [[AVCaptureSession alloc] init];
    
//    192*144   480*360  640*480
    _session.sessionPreset = AVCaptureSessionPresetMedium;
    
    // Find a suitable AVCaptureDevice
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    //    NSArray *theArray = [AVCaptureDevice devices];
    
    // Create a device input with the device and add it to the session.
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
    if (!input) {
        // Handling the error appropriately.
    }
    [_session addInput:input];
    
    // Create a VideoDataOutput and add it to the session
    AVCaptureVideoDataOutput *output = [[AVCaptureVideoDataOutput alloc] init];
    [_session addOutput:output];
    
    // Configure your output.
    dispatch_queue_t queue = dispatch_queue_create("myQueue", NULL);
    [output setSampleBufferDelegate:self queue:queue];
    //    dispatch_release(queue);
    
    // Specify the pixel format
    output.videoSettings =
    [NSDictionary dictionaryWithObject:
     [NSNumber numberWithInt:kCVPixelFormatType_32BGRA]
                                forKey:(id)kCVPixelBufferPixelFormatTypeKey];
    
    // If you wish to cap the frame rate to a known value, such as 15 fps, set
    // minFrameDuration.
    output.minFrameDuration = CMTimeMake(1, PS);
    
    AVCaptureVideoPreviewLayer* preLayer = [AVCaptureVideoPreviewLayer layerWithSession: _session];
    preLayer = [AVCaptureVideoPreviewLayer layerWithSession:_session];
    preLayer.frame = _myselfImage.frame;
    preLayer.borderColor = [UIColor whiteColor].CGColor;
    preLayer.borderWidth = 1;
    preLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    [self.view.layer addSublayer:preLayer];
    
    // Start the session running to start the flow of data
    [_session startRunning];
}

#pragma mark -
#pragma mark AVCaptureVideoDataOutputSampleBufferDelegate
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    /*Lock the image buffer*/
    CVPixelBufferLockBaseAddress(imageBuffer,0);
    /*Get information about the image*/
    uint8_t *baseAddress = (uint8_t *)CVPixelBufferGetBaseAddress(imageBuffer);
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    
    /*We unlock the  image buffer*/
    CVPixelBufferUnlockBaseAddress(imageBuffer,0);
    
    /*Create a CGImageRef from the CVImageBufferRef*/
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef newContext = CGBitmapContextCreate(baseAddress, width, height, 8, bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    CGImageRef newImage = CGBitmapContextCreateImage(newContext);
    
    /*We release some components*/
    CGContextRelease(newContext);
    CGColorSpaceRelease(colorSpace);
    
    /*We display the result on the custom layer*/
    /*self.customLayer.contents = (id) newImage;*/
    
    /*We display the result on the image view (We need to change the orientation of the image so that the video is displayed correctly)*/
    UIImage *image= [UIImage imageWithCGImage:newImage scale:0.5 orientation:UIImageOrientationRight];
    //    NSLog(@"%@", image);
    //    self.myselfImage.image = image;
//    [self performSelectorOnMainThread:@selector(showImage:) withObject:image waitUntilDone:YES];
//    [self performSelectorInBackground:@selector(showImage:) withObject:image];
//    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self showImage:image];
//    });
    //    [NSThread sleepForTimeInterval:1];
    /*We relase the CGImageRef*/
    CGImageRelease(newImage);
}

- (void)showImage:(UIImage*)image
{
    __block NSData *thedata = UIImageJPEGRepresentation(image, 0.3);
//    NSLog(@"sender :%lu", (unsigned long)thedata.length/1024);
    uploadNumber = thedata.length;
//    upload += thedata.length;
//    NSDate* now = [NSDate date];
//    NSDateFormatter* fmt = [[NSDateFormatter alloc] init];
//    fmt.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"zh_CN"];
//    [fmt setDateFormat:@"秒：ss：毫秒：SSSS"];
//    NSString *sss = [fmt stringFromDate:now];
//    NSLog(@"%@", sss);
    dispatch_queue_t dispatch = dispatch_queue_create("com.anydata.hmc", NULL);
    dispatch_async(dispatch, ^{
//        sendNumber_t = 1;
        int n = thedata.length/MAXSEND;
        NSMutableArray *thearray = [[NSMutableArray alloc] init];
        for(int i = 0; i < n; i++){
            NSData *data = [thedata subdataWithRange:NSMakeRange(i*MAXSEND, MAXSEND)];
            [thearray addObject:data];
            
        }
        if(thedata.length%MAXSEND != 0){
            [thearray addObject:[thedata subdataWithRange:NSMakeRange(n*MAXSEND, thedata.length-n*MAXSEND)]];
            sendNumber = n+1;
        }else{
            sendNumber = n;
        }
        NSDate* now = [NSDate date];
        NSDateFormatter* fmt = [[NSDateFormatter alloc] init];
        fmt.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"zh_CN"];
        fmt.dateFormat = @"yyyyMMddHHmmss";
        NSString* dateString = [[fmt stringFromDate:now] stringByAppendingString:[NSString stringWithFormat:@"%d", sendNO++%9+1]];
        
        for(int i = 0; i < thearray.count; i++){
//            dispatch_queue_t dispatch = dispatch_queue_create("com.anydata.hmc.sendmessage", NULL);
//            dispatch_async(dispatch, ^{
                dispatch_async(dispatch_get_main_queue(), ^{
                    if(_sendData == nil){
                        _sendData = [[NSMutableData alloc] init];
                    }
                    
                    _timeData = (NSMutableData*)[dateString dataUsingEncoding:NSUTF8StringEncoding];
                    
                    _sendData = [thearray objectAtIndex:i];
                    _allNumber = (NSMutableData*)[[NSString stringWithFormat:@"%2d",sendNumber] dataUsingEncoding:NSUTF8StringEncoding];
                    _everyNumber = (NSMutableData*)[[NSString stringWithFormat:@"%2d",i] dataUsingEncoding:NSUTF8StringEncoding];
                    NSData *dataLength = [[NSString stringWithFormat:@"%5lu", (unsigned long)thedata.length] dataUsingEncoding:NSUTF8StringEncoding];
                    
                    [_everyNumber appendData:dataLength];
                    [_everyNumber appendData:_sendData];
                    [_allNumber appendData:_everyNumber];
                    [_timeData appendData:_allNumber];
                    [fmt setDateFormat:@"秒：ss：毫秒：SSSS"];
                    NSDate* nows = [NSDate date];
                    NSString *sss = [fmt stringFromDate:nows];
//                    NSLog(@"序号%4d:%@：帧序：%d：包数：%d：包号：%d", xuhao, sss, (sendNO-1)%9+1, sendNumber, i);
                    NSData *xuhaoData = [[NSString stringWithFormat:@"%4d", xuhao++] dataUsingEncoding:NSUTF8StringEncoding];
                    [_timeData appendData:xuhaoData];
                    [self sendMassage:_timeData];
                    upload += _timeData.length;
                });
//            });
        }

    });
}

//建立基于UDP的Socket连接
-(void)openUDPServer{
	//初始化udp
	AsyncUdpSocket *tempSocket=[[AsyncUdpSocket alloc] initWithDelegate:self];
	self.udpSocket=tempSocket;
	//绑定端口
	NSError *error = nil;
	[self.udpSocket bindToPort:4333 error:&error];
    
    //发送广播设置
    [self.udpSocket enableBroadcast:YES error:&error];
    
    //加入群里，能接收到群里其他客户端的消息
    [self.udpSocket joinMulticastGroup:@"224.0.0.2" error:&error];
    
   	//启动接收线程
	[self.udpSocket receiveWithTimeout:-1 tag:0];
    
}

-(void)sendMassage:(NSData *)sendData
{
	//开始发送
	BOOL res = [self.udpSocket sendData:sendData
								 toHost:@"224.0.0.2"
								   port:4333
							withTimeout:-1
                                    tag:0];
    
   	if (!res) {
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"提示1"
														message:@"发送失败"
													   delegate:self
											  cancelButtonTitle:@"取消"
											  otherButtonTitles:nil];
		[alert show];
	}
}

#pragma mark -
#pragma mark UDP Delegate Methods
- (BOOL)onUdpSocket:(AsyncUdpSocket *)sock didReceiveData:(NSData *)data withTag:(long)tag fromHost:(NSString *)host port:(UInt16)port
{
    [self.udpSocket receiveWithTimeout:-1 tag:0];
    
    //收到自己发的广播时不显示出来
    NSMutableString *tempIP = [NSMutableString stringWithFormat:@"::ffff:%@",self.myIP];
//    NSLog(@"%@", self.myIP);
    if ([host isEqualToString:self.myIP]||[host isEqualToString:tempIP])
    {
        return YES;
    }
//    if(![host isEqual:@"192.168.0.103"]){
//        return YES;
//    }
    download += data.length;
    NSData *timeData = [data subdataWithRange:NSMakeRange(0, 14)];
    NSData *noData = [data subdataWithRange:NSMakeRange(14, 1)];
    NSData *firstData = [data subdataWithRange:NSMakeRange(15, 2)];
    NSData *secondData = [data subdataWithRange:NSMakeRange(17, 2)];
    NSData *dataLength = [data subdataWithRange:NSMakeRange(19, 5)];
    NSData *thirdData = [data subdataWithRange:NSMakeRange(24, data.length-24-4)];
    NSData *xuhaoData = [data subdataWithRange:NSMakeRange(data.length-4, 4)];
    
    
    int i = [[[NSString alloc] initWithData:secondData encoding:NSUTF8StringEncoding] intValue]+1;
    int all = [[[NSString alloc] initWithData:firstData encoding:NSUTF8StringEncoding] intValue];
    
    int no = [[[NSString alloc] initWithData:noData encoding:NSUTF8StringEncoding] intValue];
    
    int xuhaoInt = [[[NSString alloc] initWithData:xuhaoData encoding:NSUTF8StringEncoding] intValue];
    
    if(xuhaoInt > lostPS){
        if(xuhaoInt-lostPS != 1){
            allLostPS += xuhaoInt-lostPS-1;
            NSLog(@"当前丢失的包数-----------------------------------------------------：%d", xuhaoInt-lostPS-1);
        }
        lostPS = xuhaoInt;
    }
    
#ifndef HMC
    NSDate* now = [NSDate date];
    NSDateFormatter* fmt = [[NSDateFormatter alloc] init];
    fmt.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"zh_CN"];
    [fmt setDateFormat:@"秒：ss：毫秒：SSSS"];
    NSString *sss = [fmt stringFromDate:now];
    NSLog(@"序号：%4d：%@：帧序：%d：包数：%d：包号：%d：丢失的包数：%d", xuhaoInt, sss, no, all, i-1, allLostPS);
#endif
    
//    NSLog(@"NO:%d--All:%d--i:%d", no, all, i);
    
    if(isFirstReceive == 1){
        isFirstReceive = 2;
        receiveNO = no;
        return YES;
    }else if(isFirstReceive == 2){
        if(receiveNO == no){
            return  YES;
        }else{
            receiveNO = no;
            isFirstReceive = 0;
            NSLog(@"this is first connection!!!!!!!!!");
        }
    }
    if(receiveNO == 0 ){
        receiveNO = no;
    }
    
    

//    if(no < receiveNextNO) return YES;
    if(no != receiveNO){
        [_tableArray addObject:[NSString stringWithFormat:@"receiveNO:%d--NO:%d--All:%d--i:%d", receiveNO, no, all, i]];
        [_myTableView reloadData];
        if(_tableArray.count > 5)
            [_myTableView setContentOffset:CGPointMake(0, 20*(_tableArray.count-5)) animated:YES];

        [_myTableView setContentSize:CGSizeMake(280, 20*_tableArray.count)];
        receiveNO = no;
        sendNumber_t = 1;
        _receiveData = nil;
        _receiveData = [[NSMutableData alloc] init];
        _receiveData1 = nil;
        _receiveData2 = nil;
        _receiveData3 = nil;
        _receiveData4 = nil;
        _receiveData5 = nil;
        _receiveData6 = nil;
        _receiveData7 = nil;
        ++fps;
//        _psLabel.text = [NSString stringWithFormat:@"丢失的帧数：%dFPS   时间：%ds",++fps, seconds];
#ifdef HMC
        NSLog(@"=======================================******************");
        NSLog(@" ");
        NSLog(@"receiveNO:%d--NO:%d--All:%d--i:%d", receiveNO, no, all, i);
#endif
//        return YES;
    }else{
#ifdef HMC
        NSLog(@"receiveNO:%d--NO:%d--All:%d--i:%d", receiveNO, no, all, i);
#endif
    }
    
    if(sendNumber_t > all){
        isFirstReceive = 1;
        sendNumber_t = 1;
        _receiveData = nil;
        _receiveData = [[NSMutableData alloc] init];
        _receiveData1 = nil;
        _receiveData2 = nil;
        _receiveData3 = nil;
        _receiveData4 = nil;
        _receiveData5 = nil;
        _receiveData6 = nil;
        _receiveData7 = nil;
        
        return YES;
    }
    if(i == 1){
        if(_receiveData1==nil)
            _receiveData1 = [[NSMutableData alloc] init];
        else{
            [self flush_dataDuplicate];
        }
        _receiveData1 = [thirdData copy];
    }else if (i == 2){
        if(_receiveData2==nil)
            _receiveData2 = [[NSMutableData alloc] init];
        else{
            [self flush_dataDuplicate];
        }
        _receiveData2 = [thirdData copy];
    }else if (i == 3){
        if(_receiveData3==nil)
            _receiveData3 = [[NSMutableData alloc] init];
        else{
            [self flush_dataDuplicate];
        }
        _receiveData3 = [thirdData copy];
    }else if (i == 4){
        if(_receiveData4==nil)
            _receiveData4 = [[NSMutableData alloc] init];
        else{
            [self flush_dataDuplicate];
        }
        _receiveData4 = [thirdData copy];
    }else if (i == 5){
        if(_receiveData5==nil)
            _receiveData5 = [[NSMutableData alloc] init];
        else{
            [self flush_dataDuplicate];
        }
        _receiveData5 = [thirdData copy];
    }else if (i == 6){
        if(_receiveData6==nil)
            _receiveData6 = [[NSMutableData alloc] init];
        else{
            [self flush_dataDuplicate];
        }
        _receiveData6 = [thirdData copy];
    }else if (i == 7){
        if(_receiveData7==nil)
            _receiveData7 = [[NSMutableData alloc] init];
        else{
            [self flush_dataDuplicate];
        }
        _receiveData7 = [thirdData copy];
    }

//    NSLog(@"all:%d----i:%d----sendNumber_t:%d", all, i, sendNumber_t);
    if(all == sendNumber_t++){
        if(all == 1){
            [_receiveData appendData:_receiveData1];
        }else if (all == 2){
            [_receiveData appendData:_receiveData1];
            [_receiveData appendData:_receiveData2];
        }else if (all == 3){
            [_receiveData appendData:_receiveData1];
            [_receiveData appendData:_receiveData2];
            [_receiveData appendData:_receiveData3];
        }else if (all == 4){
            [_receiveData appendData:_receiveData1];
            [_receiveData appendData:_receiveData2];
            [_receiveData appendData:_receiveData3];
            [_receiveData appendData:_receiveData4];
            
        }else if (all == 5){
            [_receiveData appendData:_receiveData1];
            [_receiveData appendData:_receiveData2];
            [_receiveData appendData:_receiveData3];
            [_receiveData appendData:_receiveData4];
            [_receiveData appendData:_receiveData5];
        }else if (all == 6){
            [_receiveData appendData:_receiveData1];
            [_receiveData appendData:_receiveData2];
            [_receiveData appendData:_receiveData3];
            [_receiveData appendData:_receiveData4];
            [_receiveData appendData:_receiveData5];
            [_receiveData appendData:_receiveData6];
        }else if (all == 7){
            [_receiveData appendData:_receiveData1];
            [_receiveData appendData:_receiveData2];
            [_receiveData appendData:_receiveData3];
            [_receiveData appendData:_receiveData4];
            [_receiveData appendData:_receiveData5];
            [_receiveData appendData:_receiveData6];
            [_receiveData appendData:_receiveData7];
        }
        
        _otherImage.image = [UIImage imageWithData:_receiveData];
//        download += _receiveData.length;
        _receiveData = nil;
        _receiveData = [[NSMutableData alloc] init];
        _receiveData1 = nil;
        _receiveData2 = nil;
        _receiveData3 = nil;
        _receiveData4 = nil;
        _receiveData5 = nil;
        _receiveData6 = nil;
        _receiveData7 = nil;
#ifdef HMC
        NSLog(@"=======================================");
        NSLog(@" ");
#endif
        sendNumber_t = 1;
        receiveNO = 0;
    }
    
	//已经处理完毕
	return YES;
}

- (void)flush_dataDuplicate //当帧的序号相同时，但是不是用一张图片
{
    sendNumber_t = 1;
    _receiveData = nil;
    _receiveData = [[NSMutableData alloc] init];
    _receiveData1 = nil;
    _receiveData2 = nil;
    _receiveData3 = nil;
    _receiveData4 = nil;
    _receiveData5 = nil;
    _receiveData6 = nil;
    _receiveData7 = nil;
    [_tableArray addObject:@"数据重复"];
    [_myTableView reloadData];
    if(_tableArray.count > 5)
        [_myTableView setContentOffset:CGPointMake(0, 20*(_tableArray.count-5)) animated:YES];
    [_myTableView setContentSize:CGSizeMake(280, 20*_tableArray.count)];
}

- (void)onUdpSocket:(AsyncUdpSocket *)sock didNotSendDataWithTag:(long)tag dueToError:(NSError *)error
{
	//无法发送时,返回的异常提示信息
    NSLog(@"发送失败!%@", [error description]);
    //	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"提示2"
    //													message:[error description]
    //												   delegate:self
    //										  cancelButtonTitle:@"取消"
    //										  otherButtonTitles:nil];
    //	[alert show];
}
- (void)onUdpSocket:(AsyncUdpSocket *)sock didNotReceiveDataWithTag:(long)tag dueToError:(NSError *)error
{
	//无法接收时，返回异常提示信息
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"提示3"
													message:[error description]
												   delegate:self
										  cancelButtonTitle:@"取消"
										  otherButtonTitles:nil];
	[alert show];
}

#pragma mark
#pragma mark -UITableViewDelegate
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return _tableArray.count;
}

- (double)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 20;
}

- (UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
    }
    cell.selectionStyle = UITableViewCellSelectionStyleBlue;
    cell.textLabel.text = [_tableArray objectAtIndex:indexPath.row];
    cell.textLabel.textColor = [UIColor whiteColor];
    cell.textLabel.font = [UIFont systemFontOfSize:12.0f];
    cell.textLabel.textAlignment = NSTextAlignmentCenter;
    
    if(_tableArray.count-1 == indexPath.row){
        cell.backgroundColor = [UIColor blueColor];
    }else{
        cell.backgroundColor = [UIColor clearColor];
    }
    return cell;
}

@end
