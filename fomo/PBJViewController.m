//
//  PBJViewController.m
//  Vision
//
//  Created by Patrick Piemonte on 7/23/13.
//  Copyright (c) 2013 Patrick Piemonte. All rights reserved.
//

#import "PBJViewController.h"
#import "PBJStrobeView.h"
#import "PBJFocusView.h"

#import "PBJVision.h"
#import "PBJVisionUtilities.h"

#import <AssetsLibrary/AssetsLibrary.h>
#import <GLKit/GLKit.h>
#import "AFNetworking.h"
#import "Client.h"

@interface ExtendedHitButton : UIButton

+ (instancetype)extendedHitButton;

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event;

@end

@implementation ExtendedHitButton

+ (instancetype)extendedHitButton
{
    return (ExtendedHitButton *)[ExtendedHitButton buttonWithType:UIButtonTypeCustom];
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event
{
    CGRect relativeFrame = self.bounds;
    UIEdgeInsets hitTestEdgeInsets = UIEdgeInsetsMake(-35, -35, -35, -35);
    CGRect hitFrame = UIEdgeInsetsInsetRect(relativeFrame, hitTestEdgeInsets);
    return CGRectContainsPoint(hitFrame, point);
}

@end

@interface PBJViewController () <
    UIGestureRecognizerDelegate,
    PBJVisionDelegate,
    UIAlertViewDelegate>
{
    PBJStrobeView *_strobeView;
    UIButton *_doneButton;
    UIButton *_captureButton;
    UIButton *_flipButton;
    UIButton *_focusButton;
    UIButton *_onionButton;
    UIView *_captureDock;

    UIView *_previewView;
    AVCaptureVideoPreviewLayer *_previewLayer;
    PBJFocusView *_focusView;
    GLKViewController *_effectsViewController;
    
    UIView *_gestureView;
    UILongPressGestureRecognizer *_longPressGestureRecognizer;
    UITapGestureRecognizer *_tapGestureRecognizer;
    UITapGestureRecognizer *_tapCaptureGestureRecognizer;
    
    BOOL _recording;

    ALAssetsLibrary *_assetLibrary;
    __block NSDictionary *_currentPhoto;
    __block NSDictionary *_currentVideo;
}

@end

@implementation PBJViewController

#pragma mark - UIViewController

- (BOOL)prefersStatusBarHidden
{
    return YES;
}

#pragma mark - init

- (void)dealloc
{
    [UIApplication sharedApplication].idleTimerDisabled = NO;
    _longPressGestureRecognizer.delegate = nil;
}

#pragma mark - view lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.view.backgroundColor = [UIColor blackColor];
    self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

    _assetLibrary = [[ALAssetsLibrary alloc] init];
    
    CGFloat viewWidth = CGRectGetWidth(self.view.frame);
    CGFloat viewHeight = CGRectGetHeight(self.view.frame);

    // preview and AV layer
    _previewView = [[UIView alloc] initWithFrame:CGRectZero];
    _previewView.backgroundColor = [UIColor blackColor];
    CGRect previewFrame = self.view.frame;//CGRectMake(0, 60.0f, CGRectGetWidth(self.view.frame), CGRectGetWidth(self.view.frame));
    _previewView.frame = previewFrame;
    _previewLayer = [[PBJVision sharedInstance] previewLayer];
    _previewLayer.frame = _previewView.bounds;
    _previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    [_previewView.layer addSublayer:_previewLayer];
    
    // elapsed time and red dot
    _strobeView = [[PBJStrobeView alloc] initWithFrame:CGRectZero];
    CGRect strobeFrame = _strobeView.frame;
    strobeFrame.origin = CGPointMake(15.0f, 15.0f);
    _strobeView.frame = strobeFrame;
    [self.view addSubview:_strobeView];
    
    // done button
    _doneButton = [ExtendedHitButton extendedHitButton];
    _doneButton.frame = CGRectMake(viewWidth - 20.0f - 20.0f, 20.0f, 20.0f, 20.0f);
    UIImage *buttonImage = [UIImage imageNamed:@"capture_yep"];
    [_doneButton setImage:buttonImage forState:UIControlStateNormal];
    [_doneButton addTarget:self action:@selector(_handleDoneButton:) forControlEvents:UIControlEventTouchUpInside];
    [_previewView addSubview:_doneButton];
    
    // done button
    _captureButton = [ExtendedHitButton extendedHitButton];
    _captureButton.frame = CGRectMake(viewWidth/2 - 50.0f, viewHeight - 150.0f, 100.0f, 100.0f);
    UIImage *captureImage = [UIImage imageNamed:@"capture_rec_blink"];
    [_captureButton setImage:captureImage forState:UIControlStateNormal];
    [_captureButton addTarget:self action:@selector(_handleDoneButton:) forControlEvents:UIControlEventTouchUpInside];
    [_previewView addSubview:_captureButton];
    
    // onion skin
    _effectsViewController = [[GLKViewController alloc] init];
    _effectsViewController.preferredFramesPerSecond = 60;
    
    GLKView *view = (GLKView *)_effectsViewController.view;
    CGRect viewFrame = _previewView.bounds;
    view.frame = viewFrame;
    view.context = [[PBJVision sharedInstance] context];
    view.contentScaleFactor = [[UIScreen mainScreen] scale];
    view.alpha = 0.5f;
    view.hidden = YES;
    [[PBJVision sharedInstance] setPresentationFrame:_previewView.frame];
    [_previewView addSubview:_effectsViewController.view];

    // focus view
    _focusView = [[PBJFocusView alloc] initWithFrame:CGRectZero];
    
    // touch to record
    _longPressGestureRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(_handleLongPressGestureRecognizer:)];
    _longPressGestureRecognizer.delegate = self;
    _longPressGestureRecognizer.minimumPressDuration = 0.05f;
    _longPressGestureRecognizer.allowableMovement = 10.0f;
    
    // tap to focus
    _tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(_handleFocusTapGesterRecognizer:)];
    _tapGestureRecognizer.delegate = self;
    _tapGestureRecognizer.numberOfTapsRequired = 1;
    _tapGestureRecognizer.enabled = NO;
    [_previewView addGestureRecognizer:_tapGestureRecognizer];
    
    
    
    // tap to capture
    [_captureButton addTarget:self action:@selector(_handleCaptureButton:) forControlEvents:UIControlEventTouchUpInside];
    
    _tapCaptureGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(_handleCaptureTapGesterRecognizer:)];
    _tapCaptureGestureRecognizer.delegate = self;
    _tapCaptureGestureRecognizer.numberOfTapsRequired = 1;
    _tapCaptureGestureRecognizer.enabled = NO;
    [_captureButton addGestureRecognizer:_tapCaptureGestureRecognizer];
    [_captureButton addGestureRecognizer:_longPressGestureRecognizer];

    // bottom dock
    _captureDock = [[UIView alloc] initWithFrame:CGRectMake(0, CGRectGetHeight(self.view.bounds) - 60.0f, CGRectGetWidth(self.view.bounds), 60.0f)];
    _captureDock.backgroundColor = [UIColor clearColor];
    _captureDock.autoresizingMask = UIViewAutoresizingFlexibleTopMargin;
    [_previewView addSubview:_captureDock];
    
    // flip button
    _flipButton = [ExtendedHitButton extendedHitButton];
    UIImage *flipImage = [UIImage imageNamed:@"capture_flip"];
    [_flipButton setImage:flipImage forState:UIControlStateNormal];
    CGRect flipFrame = _flipButton.frame;
    flipFrame.origin = CGPointMake(20.0f, 16.0f);
    flipFrame.size = flipImage.size;
    _flipButton.frame = flipFrame;
    [_flipButton addTarget:self action:@selector(_handleFlipButton:) forControlEvents:UIControlEventTouchUpInside];
    [_captureDock addSubview:_flipButton];
    
    // focus mode button
    _focusButton = [ExtendedHitButton extendedHitButton];
    UIImage *focusImage = [UIImage imageNamed:@"capture_focus_button"];
    [_focusButton setImage:focusImage forState:UIControlStateNormal];
    [_focusButton setImage:[UIImage imageNamed:@"capture_focus_button_active"] forState:UIControlStateSelected];
    CGRect focusFrame = _focusButton.frame;
    focusFrame.origin = CGPointMake((CGRectGetWidth(self.view.bounds) * 0.5f) - (focusImage.size.width * 0.5f), 16.0f);
    focusFrame.size = focusImage.size;
    _focusButton.frame = focusFrame;
    
    [_focusButton addTarget:self action:@selector(_handleFocusButton:) forControlEvents:UIControlEventTouchUpInside];
    [_captureDock addSubview:_focusButton];
    
    // onion button
    _onionButton = [ExtendedHitButton extendedHitButton];
    UIImage *onionImage = [UIImage imageNamed:@"capture_onion"];
    [_onionButton setImage:onionImage forState:UIControlStateNormal];
    [_onionButton setImage:[UIImage imageNamed:@"capture_onion_selected"] forState:UIControlStateSelected];
    CGRect onionFrame = _onionButton.frame;
    onionFrame.origin = CGPointMake(CGRectGetWidth(self.view.bounds) - onionImage.size.width - 20.0f, 16.0f);
    onionFrame.size = onionImage.size;
    _onionButton.frame = onionFrame;
    _onionButton.imageView.frame = _onionButton.bounds;
    [_onionButton addTarget:self action:@selector(_handleOnionSkinningButton:) forControlEvents:UIControlEventTouchUpInside];
    [_captureDock addSubview:_onionButton];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    // iOS 6 support
    [[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationSlide];
    
    [self _resetCapture];
    [[PBJVision sharedInstance] startPreview];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    [[PBJVision sharedInstance] stopPreview];
    
    // iOS 6 support
    [[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationSlide];
}

#pragma mark - private start/stop helper methods

- (void)_startCapture
{
    [UIApplication sharedApplication].idleTimerDisabled = YES;

    [self _displayRecording:TRUE];
    [[PBJVision sharedInstance] setCameraMode:PBJCameraModeVideo];
    [[PBJVision sharedInstance] startVideoCapture];
}

- (void)_pauseCapture
{
    [self _displayRecording:FALSE];
    [[PBJVision sharedInstance] pauseVideoCapture];
    _effectsViewController.view.hidden = !_onionButton.selected;
}

- (void)_resumeCapture
{
    [UIView animateWithDuration:0.2f delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        _captureButton.alpha = 0;
        _captureButton.transform = CGAffineTransformMakeTranslation(0, 10.0f);
    } completion:^(BOOL finished) {
    }];
    
    [[PBJVision sharedInstance] resumeVideoCapture];
    _effectsViewController.view.hidden = YES;
}

- (void)_endCapture
{
    [UIApplication sharedApplication].idleTimerDisabled = NO;
    [[PBJVision sharedInstance] endVideoCapture];
    _effectsViewController.view.hidden = YES;
}

- (void)_resetCapture
{
    [[Client sharedClient] getUploadUrl];
    [_strobeView stop];
    _longPressGestureRecognizer.enabled = YES;

    PBJVision *vision = [PBJVision sharedInstance];
    vision.delegate = self;

    if ([vision isCameraDeviceAvailable:PBJCameraDeviceBack]) {
        [vision setCameraDevice:PBJCameraDeviceBack];
        _flipButton.hidden = NO;
        _focusButton.hidden = NO;
    } else {
        [vision setCameraDevice:PBJCameraDeviceFront];
        _flipButton.hidden = YES;
        _focusButton.hidden = YES;
    }
    
    [vision setCameraMode:PBJCameraModePhoto];
    [vision setCameraOrientation:PBJCameraOrientationPortrait];
    [vision setFocusMode:PBJFocusModeContinuousAutoFocus];
    [vision setOutputFormat:PBJOutputFormatFullscreen];
    [vision setVideoRenderingEnabled:YES];
    
    
}

#pragma mark - UIButton

- (void)_handleFlipButton:(UIButton *)button
{
    PBJVision *vision = [PBJVision sharedInstance];
    if (vision.cameraDevice == PBJCameraDeviceBack) {
        _focusButton.hidden = YES;
        [vision setCameraDevice:PBJCameraDeviceFront];
    } else {
        _focusButton.hidden = NO;
        [vision setCameraDevice:PBJCameraDeviceBack];
    }
}

- (void)_handleFocusButton:(UIButton *)button
{
    _focusButton.selected = !_focusButton.selected;
    
    if (_focusButton.selected) {
        _tapGestureRecognizer.enabled = YES;
        _gestureView.hidden = YES;

    } else {
        if (_focusView && [_focusView superview]) {
            [_focusView stopAnimation];
        }
        _tapGestureRecognizer.enabled = NO;
        _gestureView.hidden = NO;
    }
    
    [UIView animateWithDuration:0.15f delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        _captureButton.alpha = 0;
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.15f delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            _captureButton.alpha = 1;
        } completion:^(BOOL finished1) {
        }];
    }];
}

- (void)_handleOnionSkinningButton:(UIButton *)button
{
    [_onionButton setSelected:!_onionButton.selected];
    if (_recording)
        _effectsViewController.view.hidden = !_onionButton.selected;
}

- (void)_handleDoneButton:(UIButton *)button
{
    // resets long press
    _longPressGestureRecognizer.enabled = NO;
    _longPressGestureRecognizer.enabled = YES;
    
    [self _endCapture];
}

- (void)_handleCaptureButton:(UIButton *)button
{
    NSLog(@"CAPTURE PICTURE");
    [[PBJVision sharedInstance] setCameraMode:PBJCameraModePhoto];
    [[PBJVision sharedInstance] capturePhoto];
    [NSTimer scheduledTimerWithTimeInterval:20.0 target:self selector:@selector(_displayRecording:) userInfo:nil repeats:NO];
    UIAlertView *message = [[UIAlertView alloc] initWithTitle:@"Photo Capture!"
                                                      message:@"Captured!."
                                                     delegate:nil
                                            cancelButtonTitle:@"OK"
                                            otherButtonTitles:nil];
}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    [self _resetCapture];
}

#pragma mark - UIGestureRecognizer

- (void)_handleLongPressGestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
{
    switch (gestureRecognizer.state) {
      case UIGestureRecognizerStateBegan:
        {
            if (!_recording)
                [self _startCapture];
            else
                [self _resumeCapture];
            break;
        }
      case UIGestureRecognizerStateEnded:
      case UIGestureRecognizerStateCancelled:
      case UIGestureRecognizerStateFailed:
        {
            [self _pauseCapture];
            break;
        }
      default:
        break;
    }
}

- (void)_handleFocusTapGesterRecognizer:(UIGestureRecognizer *)gestureRecognizer
{
    CGPoint tapPoint = [gestureRecognizer locationInView:_previewView];

    // auto focus is occuring, display focus view
    CGPoint point = tapPoint;
    
    CGRect focusFrame = _focusView.frame;
#if defined(__LP64__) && __LP64__
    focusFrame.origin.x = rint(point.x - (focusFrame.size.width * 0.5));
    focusFrame.origin.y = rint(point.y - (focusFrame.size.height * 0.5));
#else
    focusFrame.origin.x = rintf(point.x - (focusFrame.size.width * 0.5f));
    focusFrame.origin.y = rintf(point.y - (focusFrame.size.height * 0.5f));
#endif
    [_focusView setFrame:focusFrame];
    
    [_previewView addSubview:_focusView];
    [_focusView startAnimation];

    CGPoint adjustPoint = [PBJVisionUtilities convertToPointOfInterestFromViewCoordinates:tapPoint inFrame:_previewView.frame];
    [[PBJVision sharedInstance] focusAtAdjustedPoint:adjustPoint];
}

- (void)_displayRecording:(BOOL)recording
{
    if (recording) {
        [UIView animateWithDuration:0.2f delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            _captureButton.alpha = 0;
            _captureButton.transform = CGAffineTransformMakeTranslation(0, 10.0f);
        } completion:^(BOOL finished) {
        }];
    } else {
        [UIView animateWithDuration:0.2f delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            _captureButton.alpha = 1;
            _captureButton.transform = CGAffineTransformIdentity;
        } completion:^(BOOL finished) {
        }];
    }
}


#pragma mark - PBJVisionDelegate

- (void)visionSessionWillStart:(PBJVision *)vision
{
}

- (void)visionSessionDidStart:(PBJVision *)vision
{
    if (![_previewView superview]) {
        [self.view addSubview:_previewView];
        [self.view bringSubviewToFront:_gestureView];
    }
}

- (void)visionSessionDidStop:(PBJVision *)vision
{
    [_previewView removeFromSuperview];
}

- (void)visionModeWillChange:(PBJVision *)vision
{
}

- (void)visionModeDidChange:(PBJVision *)vision
{
}

- (void)vision:(PBJVision *)vision didChangeCleanAperture:(CGRect)cleanAperture
{
}

- (void)visionWillStartFocus:(PBJVision *)vision
{
}

- (void)visionDidStopFocus:(PBJVision *)vision
{
    if (_focusView && [_focusView superview]) {
        [_focusView stopAnimation];
    }
}

// photo

- (void)visionWillCapturePhoto:(PBJVision *)vision
{
}

- (void)visionDidCapturePhoto:(PBJVision *)vision
{
}

- (void)vision:(PBJVision *)vision capturedPhoto:(NSDictionary *)photoDict error:(NSError *)error
{
    if (error)
        return;
    
    _currentPhoto = photoDict;
    
    NSData *photoData = [_currentPhoto objectForKey:PBJVisionPhotoJPEGKey];
    NSDictionary *metadata = [_currentPhoto objectForKey:PBJVisionPhotoMetadataKey];
    
    // ALAssetsLibrary
    [_assetLibrary writeImageDataToSavedPhotosAlbum:photoData metadata:metadata completionBlock:nil];
}

// video capture

- (void)visionDidStartVideoCapture:(PBJVision *)vision
{
    [_strobeView start];
    _recording = YES;
}

- (void)visionDidPauseVideoCapture:(PBJVision *)vision
{
    [_strobeView stop];
}

- (void)visionDidResumeVideoCapture:(PBJVision *)vision
{
    [_strobeView start];
}

- (void)vision:(PBJVision *)vision capturedVideo:(NSDictionary *)videoDict error:(NSError *)error
{
    _recording = NO;

    if (error) {
        NSLog(@"encounted an error in video capture (%@)", error);
        return;
    }

    _currentVideo = videoDict;
    
    NSString *videoPath = [_currentVideo  objectForKey:PBJVisionVideoPathKey];
    [_assetLibrary writeVideoAtPathToSavedPhotosAlbum:[NSURL URLWithString:videoPath] completionBlock:^(NSURL *assetURL, NSError *error1) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle: @"Saved!" message: @"Saved to the camera roll."
                                                       delegate:self
                                              cancelButtonTitle:nil
                                              otherButtonTitles:@"OK", nil];
        [alert show];
    }];
    
    AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
    NSDictionary *parameters = @{@"foo": @"bar"};
    NSURL *filePath = [NSURL fileURLWithPath:videoPath];
    [manager POST:[Client sharedClient].uploadUrl parameters:parameters constructingBodyWithBlock:^(id<AFMultipartFormData> formData) {
        [formData appendPartWithFileURL:filePath name:@"video" error:nil];
    } success:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSLog(@"Success: %@", responseObject);
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"Error: %@", error);
    }];
    
}

// progress

- (void)visionDidCaptureAudioSample:(PBJVision *)vision
{
//    NSLog(@"captured audio (%f) seconds", vision.capturedAudioSeconds);
}

- (void)visionDidCaptureVideoSample:(PBJVision *)vision
{
//    NSLog(@"captured video (%f) seconds", vision.capturedVideoSeconds);
}

@end