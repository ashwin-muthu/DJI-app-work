//
//  JoystickTestViewController.m
//  DJISdkDemo
//
//  Created by Ares on 14-10-27.
//  Copyright (c) 2014年 DJI. All rights reserved.
//

#import "NavigationJoystickViewController.h"
#import "JoyStickView.h"
#import "VideoPreviewer.h"

#import <Foundation/Foundation.h>

#import "Communicator.h"


#define DeviceSystemVersion ([[[UIDevice currentDevice] systemVersion] floatValue])
#define iOS8System (DeviceSystemVersion >= 8.0)

#define SCREEN_WIDTH  (iOS8System ? [UIScreen mainScreen].bounds.size.width : [UIScreen mainScreen].bounds.size.height)
#define SCREEN_HEIGHT (iOS8System ? [UIScreen mainScreen].bounds.size.height : [UIScreen mainScreen].bounds.size.width)

@interface NavigationJoystickViewController ()

@property(nonatomic, assign) DJIDroneType droneType;

@property (nonatomic, retain) NSInputStream *inputStream;
@property (nonatomic, retain) NSOutputStream *outputStream;

@end

@implementation NavigationJoystickViewController
{
    float mThrottle;
    float mPitch;
    float mRoll;
    float mYaw;
}

-(id) initWithDroneType:(DJIDroneType)type
{
    self = [super init];
    if (self) {
        self.droneType = type;

    }
    
    return self;
}


- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    //    playerOrigin = player.frame.origin;
    
    if (self.connectedDrone) {
        _drone = self.connectedDrone;
    }
    else
    {
        _drone = [[DJIDrone alloc] initWithType:self.droneType];
    }
    
    _drone.delegate = self;
    _drone.camera.delegate = self;
    _drone.mainController.mcDelegate = self;
    
    //open up the connection to the server
    [self initNetworkCommunication];
    
    //Start the updates to get Attitude/Altitude/GPS location
    [_drone.mainController startUpdateMCSystemState];
    
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    [notificationCenter addObserver: self
                           selector: @selector (onStickChanged:)
                               name: @"StickChanged"
                             object: nil];
    


    self.videoPreviewView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)];
    [self.view addSubview:self.videoPreviewView];
    [self.view sendSubviewToBack:self.videoPreviewView];
    self.videoPreviewView.backgroundColor = [UIColor grayColor];
    [[VideoPreviewer instance] start];
}

-(void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    [self.navigationController setToolbarHidden:YES];
    [self.navigationController setNavigationBarHidden:YES];
    [[VideoPreviewer instance] setView:self.videoPreviewView];
    [[VideoPreviewer instance] setDecoderDataSource:[self dataSourceFromDroneType:_drone.droneType]];
    
    [_drone connectToDrone];
}

-(void) viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self.navigationController setNavigationBarHidden:NO];
    [[VideoPreviewer instance] setView:nil];
    [_drone disconnectToDrone];
}

-(IBAction) onBackButtonClicked:(id)sender
{
    [self.navigationController popViewControllerAnimated:YES];
}

-(IBAction) onEnterNavigationButtonClicked:(id)sender
{
    [_drone.mainController.navigationManager enterNavigationModeWithResult:^(DJIError *error) {
        ShowResult(@"Enter Navigation Mode:%@", error.errorDescription);
    }];
}

-(IBAction) onTakeoffButtonClicked:(id)sender
{
    [_drone.mainController startTakeoffWithResult:^(DJIError *error) {
        ShowResult(@"Takeoff:%@", error.errorDescription);
    }];
}

- (void)onStickChanged:(NSNotification*)notification
{
    NSDictionary *dict = [notification userInfo];
    NSValue *vdir = [dict valueForKey:@"dir"];
    CGPoint dir = [vdir CGPointValue];
    
    JoyStickView* joystick = (JoyStickView*)notification.object;
    if (joystick) {
        if (joystick == self.joystickLeft) {
            [self setThrottle:dir.y andYaw:dir.x];
        }
        else
        {
            [self setPitch:dir.y andRoll:dir.x];
        }
    }
}

-(void) setThrottle:(float)y andYaw:(float)x
{
    mThrottle = y * -2;
    mYaw = x * 30;
    
    [self updateJoystick];
}

-(void) setPitch:(float)y andRoll:(float)x
{
    mPitch = y * 15.0;
    mRoll  = x * 15.0;
    [self updateJoystick];
}

-(void) updateJoystick
{
    DJIFlightControlData ctrlData = {0};
    ctrlData.mPitch = mPitch;
    ctrlData.mRoll = mRoll;
    ctrlData.mYaw = mYaw;
    ctrlData.mThrottle =mThrottle;
//    _drone.mainController.navigationManager.flightControl.verticalControlMode = DJIVerticalControlPosition;
//    _drone.mainController.navigationManager.flightControl.verticalControlMode = DJIVerticalControlVelocity;
//    i (_drone.mainController.navigationManager.flightControl.verticalControlMode == DJIVerticalControlPosition) {
//        ctrlData.mThrottle = 20.0;
//    }
    
    //Log what is going on
    NSLog(@"Pitch: %f, Roll: %f, Yaw: %f, Throttle: %f \n",mPitch, mRoll, mYaw, mThrottle);
    
    
    
    //get real time data
//    DJIMCSystemState.attitude.yaw
//    float val = [_drone.mainControl]
//    
//    [_drone.mainController.compass]

//    [DJIMCSystemState ]
//
//
//    [_drone.mainController.navigationManager.flightControl sendFlightControlData:ctrlData withResult:nil];

}



#pragma mark - Delegate

-(void) droneOnConnectionStatusChanged:(DJIConnectionStatus)status
{
    if (status == ConnectionSucceeded) {
        NSLog(@"Connection Successed!");
    }
    else
    {
        NSLog(@"Connection Broken!");
    }
}

-(void) camera:(DJICamera*)camera didReceivedVideoData:(uint8_t*)videoBuffer length:(int)length
{
    uint8_t* pBuffer = (uint8_t*)malloc(length);
    memcpy(pBuffer, videoBuffer, length);
    [[[VideoPreviewer instance] dataQueue] push:pBuffer length:length];
}

-(void) camera:(DJICamera*)camera didUpdateSystemState:(DJICameraSystemState*)systemState
{
    
}

-(void) mainController:(DJIMainController*)mc didUpdateSystemState:(DJIMCSystemState*)state
{
    float pitch = state.attitude.pitch;
    float yaw = state.attitude.yaw;
    float roll = state.attitude.roll;

    float vx = state.velocityX;
    float vy = state.velocityY;
    float vz = state.velocityZ;
    
    float altitude = state.altitude;
    
    CLLocationCoordinate2D droneCoords = state.droneLocation;
    float droneLongitude = droneCoords.longitude;
    float droneLatitude = droneCoords.latitude;
    
    CLLocationCoordinate2D homeCoords = state.homeLocation;
    float homeLongitude = homeCoords.longitude;
    float homeLatitude = homeCoords.latitude;
    
    NSLog(@"UPDATING STATE:: %f %f %f",pitch, roll, yaw);
}

- (void) initNetworkCommunication {
    
    CFReadStreamRef readStream;
    CFWriteStreamRef writeStream;
    CFStreamCreatePairWithSocketToHost(NULL, (CFStringRef)@"127.0.0.1", 8888, &readStream, &writeStream);
    
    self.inputStream = (__bridge NSInputStream *)readStream;
    self.outputStream = (__bridge NSOutputStream *)writeStream;
    [self.inputStream setDelegate:self];
    [self.outputStream setDelegate:self];
    [self.inputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [self.outputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [self.inputStream open];
    [self.outputStream open];
    
}

- (void)stream:(NSStream *)theStream handleEvent:(NSStreamEvent)streamEvent {
    
//    NSLog(@"stream event %i", streamEvent);
    
    switch (streamEvent) {
            
        case NSStreamEventOpenCompleted:
            NSLog(@"Stream opened");
            break;
        case NSStreamEventHasBytesAvailable:
            
            if (theStream == _inputStream) {
                
                uint8_t buffer[24];
                int len;
                
                while ([_inputStream hasBytesAvailable]) {
                    len = (int) [_inputStream read:buffer maxLength:sizeof(buffer)];
                    NSLog(@"Received %d bytes", len);
                    NSData *data = [[NSData alloc] initWithBytes:buffer length:sizeof(buffer)];
                    if (len > 0) {
                        uint8_t command = (uint8_t) buffer[0];

                        uint8_t version = (uint8_t) buffer[1];
                        
                        uint8_t size = (uint8_t) buffer[2];

                        uint8_t flags = (uint8_t) buffer[3];
                        
                        uint32_t tempword;
                        [data getBytes:&tempword range:NSMakeRange(4, 4)];
                        uint32_t seqno = ntohl(tempword);
                        
                        [data getBytes:&tempword range:NSMakeRange(8, 4)];
                        tempword = ntohl(tempword);
                        float pitch = *((float*) &tempword);
                        
                        [data getBytes:&tempword range:NSMakeRange(12, 4)];
                        tempword = ntohl(tempword);
                        float roll = *((float*) &tempword);
                        
                        [data getBytes:&tempword range:NSMakeRange(16, 4)];
                        tempword = ntohl(tempword);
                        float yaw = *((float*) &tempword);
                        
                        [data getBytes:&tempword range:NSMakeRange(20, 4)];
                        tempword = ntohl(tempword);
                        float throttle = *((float*) &tempword);
                       
                        NSLog(@"command %u, version %u, size %u, flag %u, sequenceNum %u", command, version, size, flags, seqno);
                        NSLog(@"pitch %0.3f, roll %0.3f, yaw %0.3f, throttle %0.3f", pitch, roll, yaw, throttle);
                        
                    }
                }
            }
            break;
            
            
        case NSStreamEventErrorOccurred:
            
            NSLog(@"Can not connect to the host!");
            break;
            
        case NSStreamEventEndEncountered:
            
            [theStream close];
            [theStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
            
            theStream = nil;
            
            break;
        default:
            NSLog(@"Unknown event");
    }
    
}
float counter = 0;



@end
