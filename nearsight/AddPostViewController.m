//
//  AddPostViewController.m
//  fomo
//
//  Created by Ebby Amir on 3/14/14.
//  Copyright (c) 2014 Ebby Amir. All rights reserved.
//

#import "AddPostViewController.h"
#import "PBJVideoPlayerController.h"
#import "UIERealTimeBlurView.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import "AFNetworking.h"
#import "Client.h"
#import "CheckinViewController.h"
#import "Place.h"
#import "Manager.h"
#import <LBBlurredImage/UIImageView+LBBlurredImage.h>
#import "UIExtensions.h"


@interface ColoredButton : UIButton

- (void)setColor:(UIColor *)color forState:(UIControlState)state;

@end

@implementation ColoredButton

- (void)setColor:(UIColor *)color forState:(UIControlState)state
{
    UIView *colorView = [[UIView alloc] initWithFrame:self.frame];
    colorView.backgroundColor = color;
    
    UIGraphicsBeginImageContext(colorView.bounds.size);
    [colorView.layer renderInContext:UIGraphicsGetCurrentContext()];
    
    UIImage *colorImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    [self setBackgroundImage:colorImage forState:state];
}

@end



@interface AddPostViewController () <PBJVideoPlayerControllerDelegate, UITextViewDelegate, CheckinViewControllerDelegate>
{
    PBJVideoPlayerController *_videoPlayerController;
    ExtendedHitButton *_backButton;
    ColoredButton *_emotionButton;
    UIButton *_postButton;
    UITextView *_captionInput;
    UIERealTimeBlurView *_blurredView;
    UITapGestureRecognizer *_tapRecognizer;
    ALAssetsLibrary *_assetLibrary;
    CheckinViewController *_checkinView;
    UIImageView *_blurredImageView;
    UIView *_shareOptions;
    UILabel *_shareLabel;
    UISwitch *_shareSwitch;
}


@property (nonatomic) Draft *draft;
@property (nonatomic) NSString *videoPath;
@property (nonatomic) AVAsset *asset;
@property (nonatomic) NSString *exportPath;
@property (nonatomic) NSArray *timeline;
@property (nonatomic) BOOL exported;
@property (nonatomic) NSString *caption;
@property (nonatomic) NSString *emotion;
@property (nonatomic) NSString *placeholder;
@property (nonatomic) Place *place;

@end

@implementation AddPostViewController

- (id)initWithVideoPath:(NSString *)videoPath
{
    self = [super init];
    if (self) {
        self.videoPath = videoPath;
    }
    return self;
}

- (id)initWithAsset:(AVAsset *)asset andExportPath:(NSString *)exportPath andTimeline:(NSArray *)timeline
{
    self = [super init];
    if (self) {
        self.asset = asset;
        self.exportPath = exportPath;
        self.timeline = timeline;
    }
    return self;
}

- (id)initWithAsset:(AVAsset *)asset andDraft:(Draft *)draft
{
    self = [super init];
    if (self) {
        self.asset = asset;
        self.draft = draft;
    }
    return self;
}


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
    
    CGFloat viewWidth = CGRectGetWidth(self.view.frame);
    CGFloat viewHeight = CGRectGetHeight(self.view.frame);
    
    _assetLibrary = [[ALAssetsLibrary alloc] init];
    
    if (self.videoPath || self.asset) {
        _videoPlayerController = [[PBJVideoPlayerController alloc] init];
        _videoPlayerController.delegate = self;
        _videoPlayerController.view.frame = self.view.bounds;
        
        [self addChildViewController:_videoPlayerController];
        [self.view addSubview:_videoPlayerController.view];
        [_videoPlayerController didMoveToParentViewController:self];

        if (self.videoPath) {
            [_videoPlayerController setVideoPath:self.videoPath];
        } else if (self.asset) {
            [_videoPlayerController setAsset:self.asset];
        }
        
        //_videoPlayerController.playbackLoops = YES;
        [_videoPlayerController playFromBeginning];
    }
    
    // Blurred view
//    _blurredView = [[UIERealTimeBlurView alloc] initWithFrame:self.view.frame];
//    _blurredView.alpha = 0;
//    [self.view addSubview:_blurredView];
    
    _blurredImageView = [[UIImageView alloc] initWithFrame:self.view.frame];
    _blurredImageView.alpha = 0;
    [self.view addSubview:_blurredImageView];
    
    // Back button
    _backButton = [ExtendedHitButton extendedHitButton];
    _backButton.frame = CGRectMake(8.0f, 10.0f, 50.0f, 50.0f);
    _backButton.alpha = 0.8;
    UIImage *backButtonImage = [UIImage imageNamed:@"back"];
    [_backButton setImage:backButtonImage forState:UIControlStateNormal];
    [_backButton addTarget:self action:@selector(_handleBackButton:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_backButton];
    
    // Post Button
    _postButton = [[UIButton alloc] init];
    _postButton.frame = CGRectMake(viewWidth - 50.0f, 20.0f, 32.0f, 32.0f);
    _postButton.hidden = YES;
    _postButton.alpha = 0;
    UIImage *postButtonImage = [UIImage imageNamed:@"check"];
    [_postButton setImage:postButtonImage forState:UIControlStateNormal];
    [_postButton addTarget:self action:@selector(_handlePostButton:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_postButton];
    
    // Emotion Button
    _emotionButton = [[ColoredButton alloc] initWithFrame:CGRectMake(viewWidth/2 - 140.0f, viewHeight/2 - 20.0f, 280.0f, 40.0f)];
    _emotionButton.layer.cornerRadius = 6.0f;
    _emotionButton.clipsToBounds = YES;
    [_emotionButton.titleLabel setFont:[UIFont fontWithName:@"MrsEaves-Italic" size:24]];
    NSDictionary *underlineAttribute = @{NSUnderlineStyleAttributeName: @(NSUnderlineStyleSingle),
                                         NSForegroundColorAttributeName: [UIColor whiteColor]};
    
    if ([[Manager sharedClient].places count]) {
        Place *place = [Manager sharedClient].places[0];
        [_emotionButton setAttributedTitle:[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"Are you at %@?", place.name] attributes:underlineAttribute] forState:UIControlStateNormal];
    } else {
        [_emotionButton setAttributedTitle:[[NSAttributedString alloc] initWithString:@"Where are you?" attributes:underlineAttribute] forState:UIControlStateNormal];
    }
    
    [_emotionButton addTarget:self action:@selector(_handleEmotionButton:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_emotionButton];
    
    // Emotion holder
//    _emotionHolder = [[UITextView alloc] initWithFrame:CGRectMake(viewWidth/2 - 140.0f, viewHeight/2 - 20.0f, 280.0f, 40.0f)];
//    _emotionHolder.text = @"feeling";
//    _captionInput.textColor = [UIColor whiteColor];
//    _captionInput.alpha = 0.8f;
//    _captionInput.backgroundColor = [UIColor clearColor];
//    [self.view addSubview:_emotionButton];
    
    // Caption Input
    _captionInput = [[UITextView alloc] initWithFrame:CGRectMake(viewWidth/2 - 140.0f, viewHeight/2 - 20.0f, 280.0f, 36.0f)];
    _captionInput.layer.borderWidth = 1.0f;
    _captionInput.layer.borderColor = [[UIColor whiteColor] CGColor];
    _captionInput.layer.cornerRadius = 6.0f;
    _captionInput.editable = YES;
    [_captionInput setDelegate:self];
    _captionInput.textColor = [UIColor whiteColor];
    _captionInput.alpha = 0;
    _captionInput.backgroundColor = [UIColor clearColor];
    _captionInput.textAlignment = NSTextAlignmentCenter;
    [_captionInput setFont:_emotionButton.titleLabel.font];
    _captionInput.text = self.draft.caption ? self.draft.caption : @"How's this spot?";
    _captionInput.hidden = YES;
    [_captionInput setFont:[UIFont fontWithName:@"ProximaNovaCond-Regular" size:16]];
    [self.view addSubview:_captionInput];
    
    // Share options
    
//    _shareOptions = [[UIView alloc] initWithFrame:CGRectMake(0, viewHeight - 40.0f, viewWidth, 40.0f)];
//    _shareOptions.hidden = YES;
//    _shareOptions.alpha = 0;
//    
//    _shareLabel = [[UILabel alloc] initWithFrame:CGRectMake(viewWidth - 190.0f, 5.0f, viewWidth - 20.0f, 20.0f)];
//    _shareLabel.text = @"Share anonymously";
//    _shareLabel.textColor = [UIColor whiteColor];
//    _shareLabel.alpha = 0.8f;
//    _shareLabel.font = [UIFont boldSystemFontOfSize:14.0f];
//    [_shareOptions addSubview:_shareLabel];
//    
//    _shareSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(viewWidth - 60.0f, 0, 0, 0)];
//    _shareSwitch.on = YES;
//    _shareSwitch.transform = CGAffineTransformMakeScale(0.75, 0.75);
//    [_shareOptions addSubview:_shareSwitch];
//    
//    [self.view addSubview:_shareOptions];
//    
    // Emotion Menu
    // NSArray *images = //...
    NSMutableArray *placeNames = [[NSMutableArray alloc] init];
    for (Place *p in [Manager sharedClient].places) {
        [placeNames addObject:p.name];
    }
    _checkinView = [[CheckinViewController alloc] initWithPlaces:[Manager sharedClient].places];
    _checkinView.delegate = self;
    [self addChildViewController:_checkinView];
    [self.view addSubview:_checkinView.view];
    
    if (self.asset && self.draft.outputPath) {
        // Export the video
        [_videoPlayerController exportAssetWithPath:self.draft.outputPath andCallback:^(AVAssetExportSessionStatus status) {
            switch (status)
            {
                case AVAssetExportSessionStatusCompleted:
                    //                export complete
                    NSLog(@"Export Complete");
                    self.exported = YES;
                    self.videoPath = self.draft.outputPath;
                    break;
                case AVAssetExportSessionStatusFailed:
                    NSLog(@"Export Failed");
                    break;
                case AVAssetExportSessionStatusCancelled:
                    NSLog(@"Export Failed");
                    break;
            }
        }];
    }
    
    if (self.draft.place) {
        [self checkInViewPlaceSelected:self.draft.place];
    }
}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}

- (void)_handleBackButton:(UIButton *)button
{
    [self.navigationController popViewControllerAnimated:NO];
}

- (void)_handlePostButton:(UIButton *)button
{
    if (_captionInput.text != self.placeholder) {
        self.draft.caption = _captionInput.text;
    }

    [self.draft upload];
    
    CATransition *transition = [CATransition animation];
    transition.duration = 0.35;
    transition.timingFunction =
    [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    transition.type = kCATransitionMoveIn;
    transition.subtype = kCATransitionFromTop;
    
    UIView *containerView = self.view.window;
    [containerView.layer addAnimation:transition forKey:nil];
    [self dismissViewControllerAnimated:NO completion:nil];
    [self.navigationController popViewControllerAnimated:NO];
}

-(void)_handleEmotionButton:(UIButton *)button
{
    _blurredImageView.alpha = 1;
    [_checkinView show];
}

-(void)_handleTapGestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
{

}
     
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    
    UITouch *touch = [[event allTouches] anyObject];
    if ([touch view] == _captionInput) {
        [_checkinView show];
        return;
    }
    if ([_captionInput isFirstResponder] && [touch view] != _captionInput) {
        [_captionInput resignFirstResponder];
        if ([_captionInput.text length] > 0) {
            self.draft.caption = _captionInput.text;
            [UIView animateWithDuration:0.3 animations:^(void) {
                _captionInput.frame = CGRectMake(self.view.frame.size.width/2 - 140.0f, self.view.frame.size.height/2 - 20.0f, 280.0f, 36.0f);
            }];
        } else {
            _captionInput.text = self.placeholder;
            [UIView animateWithDuration:0.3 animations:^(void) {
                _captionInput.frame = CGRectMake(self.view.frame.size.width/2 - 140.0f, self.view.frame.size.height/2 - 20.0f, 280.0f, 36.0f);
                _captionInput.textAlignment = NSTextAlignmentCenter;
            }];

        }

    }
    [super touchesBegan:touches withEvent:event];
}

#pragma mark - PBJVideoPlayerControllerDelegate

- (void)videoPlayerReady:(PBJVideoPlayerController *)videoPlayer
{
    [_blurredImageView setImageToBlur:videoPlayer.lastFrame blurRadius:1 completionBlock:nil];
}


- (void)videoPlayerPlaybackStateDidChange:(PBJVideoPlayerController *)videoPlayer
{
    if (videoPlayer.playbackState == PBJVideoPlayerPlaybackStatePlaying) {
        [UIView animateWithDuration:0.3f
                              delay:0
                            options:UIViewAnimationOptionCurveEaseOut animations:^{
                                _blurredImageView.alpha = 0.0f;
                            } completion:^(BOOL finished) {
                                _blurredImageView.hidden = YES;
                            }];
    } else if (videoPlayer.playbackState == PBJVideoPlayerPlaybackStatePaused
               || videoPlayer.playbackState == PBJVideoPlayerPlaybackStateStopped) {
        _blurredImageView.hidden = NO;
        _blurredImageView.backgroundColor = [UIColor blackColor];
        
        [UIView animateWithDuration:0.3f animations:^{
            _blurredImageView.alpha = 1.0f;
        } completion:^(BOOL finished) {
        }];
        
    }
}

- (void)videoPlayerPlaybackWillStartFromBeginning:(PBJVideoPlayerController *)videoPlayer
{
}

- (void)videoPlayerPlaybackDidEnd:(PBJVideoPlayerController *)videoPlayer
{
    _blurredImageView.hidden = NO;
    _blurredImageView.backgroundColor = [UIColor blackColor];
    
    [UIView animateWithDuration:0.3f animations:^{
        _blurredImageView.alpha = 1.0f;
    } completion:^(BOOL finished) {
    }];
}

#pragma mark - UITextViewDelegate

-(void)textViewDidBeginEditing:(UITextView *)textView
{
    if ([self.draft.caption length] == 0) {
        textView.text = @"";
    }
    [UIView animateWithDuration:0.3 animations:^(void) {
        _blurredView.alpha = 1;
        textView.frame = CGRectMake(self.view.frame.size.width/2 - 140.0f, 65, 280.0f, 40.0f);
        textView.textAlignment = NSTextAlignmentLeft;
    }];
}

-(void)textViewDidChange:(UITextView *)textView {
    float height = textView.contentSize.height;
    CGRect frame = textView.frame;
    frame.size.height = height; //Give it some padding
    textView.frame = frame;
    [UIView animateWithDuration:0.5 animations:^{
        textView.frame = frame;
    }];
}

-(void)textViewDidChangeSelection:(UITextView *)textView {
    
}

-(void)textViewDidEndEditing:(UITextView *)textView {

    
}

-(void)textFieldDidBeginEditing:(UITextField *)textField
{
    
}

-(void)textFieldDidEndEditing:(UITextField *)textField
{
    [UIView animateWithDuration:0.3 animations:^(void) {
        _blurredView.alpha = 0;
    }];
}

#pragma mark - CheckinViewControllerDelegate

-(void)checkInViewPlaceSelected:(Place *)place
{
    CGFloat viewWidth = CGRectGetWidth(self.view.frame);
    CGFloat viewHeight = CGRectGetHeight(self.view.frame);
    self.draft.place = place;
    CGSize stringsize = [place.name sizeWithAttributes:@{NSFontAttributeName:_emotionButton.titleLabel.font}];
    float newWidth = stringsize.width + 10;
    float newHeight = stringsize.height + 10;
    [_emotionButton setTitle:place.name forState:UIControlStateNormal];
    NSDictionary *underlineAttribute = @{NSUnderlineStyleAttributeName: @(NSUnderlineStyleSingle),
                                         NSForegroundColorAttributeName: [UIColor whiteColor]};
    [_emotionButton setAttributedTitle:[[NSAttributedString alloc] initWithString:place.name attributes:underlineAttribute] forState:UIControlStateNormal];

     _emotionButton.frame=CGRectMake(viewWidth/2 - newWidth/2, viewHeight/2 - newHeight/2, newWidth, newHeight);

    NSLog(@"Caption input: %@", self.draft.caption);
    self.placeholder = self.draft.caption ? self.draft.caption : [NSString stringWithFormat:@"Thoughts on %@?", self.draft.place.name];
    _captionInput.text = self.placeholder;
    _captionInput.hidden = NO;
    _shareOptions.hidden = NO;
    _postButton.hidden = NO;
    [UIView animateWithDuration:0.5 animations:^{
        _emotionButton.frame=CGRectMake(viewWidth/2 - newWidth/2, 25, newWidth, newHeight);
        _shareOptions.alpha = 0.8f;
        _captionInput.alpha = 0.8f;
        _postButton.alpha = 0.8f;
    }];
}

//# pragma mark - RNGridMenuDelegate
//
//- (void)gridMenu:(RNGridMenu *)gridMenu willDismissWithSelectedItem:(RNGridMenuItem *)item atIndex:(NSInteger)itemIndex
//{
//    CGFloat viewWidth = CGRectGetWidth(self.view.frame);
//    CGFloat viewHeight = CGRectGetHeight(self.view.frame);
//    
//    self.emotion = item.title;
//
//    CGSize stringsize = [self.emotion sizeWithAttributes:@{NSFontAttributeName:_emotionButton.titleLabel.font}];
//    float newWidth = stringsize.width + 10;
//    float newHeight = stringsize.height + 10;
//    [_emotionButton setColor:[UIColor colorWithRed:231.0/255 green:76.0/255 blue:60.0/255 alpha:1] forState:UIControlStateNormal];
//    [_emotionButton setTitle:[self.emotion lowercaseString] forState:UIControlStateNormal];
//     _emotionButton.frame=CGRectMake(viewWidth/2 - newWidth/2, viewHeight/2 - newHeight/2,newWidth, newHeight);
//    
//    self.placeholder = [NSString stringWithFormat:@"Thoughts on %@?", self.emotion];
//    _captionInput.text = self.placeholder;
//    _captionInput.hidden = NO;
//    _shareOptions.hidden = NO;
//    _postButton.hidden = NO;
//    [UIView animateWithDuration:0.5 animations:^{
//        _emotionButton.frame=CGRectMake(viewWidth/2 - newWidth/2, viewHeight/2 - newHeight/2 - 50.0f, newWidth, newHeight);
//        _shareOptions.alpha = 0.8f;
//        _captionInput.alpha = 0.8f;
//        _postButton.alpha = 0.8f;
//    }];
//}
//
//- (void)gridMenuWillDismiss:(RNGridMenu *)gridMenu
//{
//    
//}

@end
