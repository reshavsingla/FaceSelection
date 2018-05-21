//
//  ViewController.m
//  FaceSelection
//
//  Created by Daniel Lau on 4/26/18.
//  Copyright © 2018 Curious Kiwi Co. All rights reserved.
//

#import "ViewController.h"
#import "AFNetworking.h"
#import "CustomButton.h"
#import <AVFoundation/AVFoundation.h>


@interface ViewController ()

@property (nonatomic, weak) IBOutlet UIImageView *imageView;
@property (nonatomic, weak) IBOutlet UIActivityIndicatorView *loadingIndicator;
@property (nonatomic, weak) IBOutlet UITextView *textView;
@property (nonatomic, copy) NSArray *jsonFaceData;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    self.loadingIndicator.hidden = NO;
    [self.loadingIndicator startAnimating];
    self.imageView.image = nil;
    self.textView.text = nil;
    
    // Image URL: https://s3-us-west-2.amazonaws.com/precious-interview/ios-face-selection/family.jpg
    // JSON URL: https://s3-us-west-2.amazonaws.com/precious-interview/ios-face-selection/family_faces.json
    // JSON contents documentation: https://westus.dev.cognitive.microsoft.com/docs/services/563879b61984550e40cbbe8d/operations/563879b61984550f30395236
    
    // TODO: Start your project here
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
    AFURLSessionManager *manager = [[AFURLSessionManager alloc] initWithSessionConfiguration:configuration];
    
    NSURL *documentsDirectoryURL = [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:NO error:nil];
    
    // Download the image and save it to the document folder
    NSURL *imageURL = [NSURL URLWithString:@"https://s3-us-west-2.amazonaws.com/precious-interview/ios-face-selection/family.jpg"];
    NSURLRequest *imageRequest = [NSURLRequest requestWithURL:imageURL];
    NSURLSessionDownloadTask *imageDownloadTask = [manager downloadTaskWithRequest:imageRequest progress:nil destination:^NSURL *(NSURL *targetPath, NSURLResponse *response) {
        return [documentsDirectoryURL URLByAppendingPathComponent:@"image.jpg"];
    } completionHandler:^(NSURLResponse *response, NSURL *filePath, NSError *error) {
        // After download completion show the image and add touch event to image view
        [self.loadingIndicator stopAnimating];
        self.loadingIndicator.hidden = YES;
        self.imageView.image = [UIImage imageWithContentsOfFile:filePath.path];
        UITapGestureRecognizer *tapRecognizer = [[UITapGestureRecognizer alloc]
                                                 initWithTarget:self action:@selector(buttonSelected:)];
        [tapRecognizer setNumberOfTouchesRequired:1];
        self.imageView.userInteractionEnabled = YES;
        [self.imageView addGestureRecognizer:tapRecognizer];
        
        // Download the Json file and save it to the document folder
        NSURL *URL = [NSURL URLWithString:@"https://s3-us-west-2.amazonaws.com/precious-interview/ios-face-selection/family_faces.json"];
        NSURLRequest *request = [NSURLRequest requestWithURL:URL];
        
        NSURLSessionDownloadTask *jsonDownloadTask = [manager downloadTaskWithRequest:request progress:nil destination:^NSURL *(NSURL *targetPath, NSURLResponse *response) {
            return [documentsDirectoryURL URLByAppendingPathComponent:@"face_metadata.json"];
        } completionHandler:^(NSURLResponse *response, NSURL *filePath, NSError *error) {
            NSError *e = nil;
            NSData *jsonData = [NSData dataWithContentsOfFile:filePath.path];
            // After download completion read the json file and draw bounding boxes
            self.jsonFaceData =  [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONReadingMutableContainers error:&e];
            if(self.jsonFaceData){
                [self setBoundingBoxes];
            }
        }];
        [jsonDownloadTask resume];
    }];
    [imageDownloadTask resume];
}

-(void)setBoundingBoxes{
    //Loop through json data and draw bounding boxes for each face
    for(NSDictionary *item in self.jsonFaceData) {
        NSLog(@"Item: %@", item);
        [self drawBoundingBox:item];
    }
}

- (void)drawBoundingBox:(NSDictionary *) item{
    //Create button and assign needed values
    CustomButton *button = [CustomButton buttonWithType:UIButtonTypeCustom];
    button.stringTag = [item valueForKey:@"faceId"];
    [button addTarget:self action:@selector(buttonSelected:) forControlEvents:UIControlEventTouchUpInside];
    NSString *gender = [item valueForKeyPath:@"faceAttributes.gender"];
    UIColor *color;
    if([gender isEqualToString:@"male"]){
        color = [UIColor blueColor];
    }else{
        color = [UIColor colorWithRed:255.0/255.0 green:192.0/255.0 blue:203.0/255.0 alpha:1.0];
    }
    button.layer.borderWidth =2.0f;
    button.layer.borderColor = color.CGColor;
    
    //Get the location of face in original image
    float faceX = [[item valueForKeyPath:@"faceRectangle.left"] floatValue];
    float faceY = [[item valueForKeyPath:@"faceRectangle.top"] floatValue];
    float faceHeight = [[item valueForKeyPath:@"faceRectangle.height"] floatValue];
    float faceWidth = [[item valueForKeyPath:@"faceRectangle.width"] floatValue];
    
    //Calculate the change in image size
    CGRect rect = AVMakeRectWithAspectRatioInsideRect(self.imageView.image.size,self.imageView.frame);
    float x = self.imageView.frame.origin.x + (self.imageView.frame.size.width - rect.size.width)/2;
    float y = self.imageView.frame.origin.y + (self.imageView.frame.size.height - rect.size.height)/2;
    float imageSizeRatio = rect.size.height/self.imageView.image.size.height;
    
    //Set the button size and location according to the image size
    button.frame = CGRectMake(x+ faceX * imageSizeRatio, y + faceY * imageSizeRatio, faceWidth * imageSizeRatio, faceHeight * imageSizeRatio);
    
    //add the button to the view
    [self.view addSubview:button];
}

- (void)buttonSelected:(CustomButton *) boundingBox{
    //Clear all the text and subviews of last selection
    for (UIView* subview in self.view.subviews) {
        if ([subview isKindOfClass:[CustomButton class]]) {
            subview.layer.borderWidth = 2.0f;
        }
    }
    
    [[self.view.layer.sublayers copy] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        CALayer * subLayer = obj;
        if([subLayer.accessibilityValue isEqualToString:@"dot"]){
            [subLayer removeFromSuperlayer];
        }
        
    }];
    
    self.textView.text = nil;

    //If the touch is not from outside the bounding box
    if(boundingBox.class != [UITapGestureRecognizer class]){
        //Increase the border size
        boundingBox.layer.borderWidth = 5.0f;
        
        //Get the values from the json data for the corresponding box
        NSArray *filtered = [self.jsonFaceData filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"(faceId = %@)",boundingBox.stringTag]];
        NSDictionary *personData = filtered[0];
        NSString *gender = [personData valueForKeyPath:@"faceAttributes.gender"];
        NSString *age = [personData valueForKeyPath:@"faceAttributes.age"];
        NSDictionary *emotions = [personData valueForKeyPath:@"faceAttributes.emotion"];
        float height = [[personData valueForKeyPath:@"faceRectangle.height"] floatValue];
        float width = [[personData valueForKeyPath:@"faceRectangle.width"] floatValue];
        float percentageArea = (width*height *100)/(self.imageView.image.size.height * self.imageView.image.size.width);
        
        //Get the emotion with highest confidence value
        NSString *highestConfidenceEmotion = nil;
        float highestValue = 0;
        for (NSString *key in emotions)
        {
            int value = [emotions[key] floatValue];
            if (!highestConfidenceEmotion || highestValue < value)
            {
                highestConfidenceEmotion = key;
                highestValue = value;
            }
        }
        
        //Write to the textview
        self.textView.text = [NSString stringWithFormat:@"Gender:%@\nAge:%@\nEmotion:%@\nArea:%f",gender,age,highestConfidenceEmotion,percentageArea];
        
        //Draw green dots for the facial landmark
        NSDictionary *facialLandmarks = [personData valueForKey:@"faceLandmarks"];
        for (NSString *key in facialLandmarks){
            NSDictionary *landmarkLocation = facialLandmarks[key];
            float landmarkLocationX = [[landmarkLocation valueForKey:@"x"] floatValue];
            float landmarkLocationY = [[landmarkLocation valueForKey:@"y"] floatValue];
            CAShapeLayer *circleLayer = [CAShapeLayer layer];
            [circleLayer setAccessibilityValue:@"dot"];
            
            //Calculate the change in image size
            CGRect rect = AVMakeRectWithAspectRatioInsideRect(self.imageView.image.size,self.imageView.frame);
            float x = self.imageView.frame.origin.x + (self.imageView.frame.size.width - rect.size.width)/2;
            float y = self.imageView.frame.origin.y + (self.imageView.frame.size.height - rect.size.height)/2;
            float imageSizeRatio = rect.size.width/self.imageView.image.size.width;
            
            //Place the green dots according to the image size change
            [circleLayer setPath:[[UIBezierPath bezierPathWithOvalInRect:CGRectMake(x+landmarkLocationX*imageSizeRatio, y+landmarkLocationY*imageSizeRatio, 2, 2)] CGPath]];
            [circleLayer setStrokeColor:[[UIColor greenColor] CGColor]];
            [circleLayer setFillColor:[[UIColor greenColor] CGColor]];
            [[self.view layer] addSublayer:circleLayer];
        }
    }
}
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    //On rotation clear all the added bounding boxes and layers and draw them again
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context)
     {
         for (UIView* subview in self.view.subviews) {
             if ([subview isKindOfClass:[CustomButton class]]) {
                 [subview removeFromSuperview];
             }
         }
         
         [[self.view.layer.sublayers copy] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
             CALayer * subLayer = obj;
             if([subLayer.accessibilityValue isEqualToString:@"dot"]){
                 [subLayer removeFromSuperlayer];
             }
         }];
         self.textView.text = nil;
     } completion:^(id<UIViewControllerTransitionCoordinatorContext> context)
     {
         //reset bounding boxes after rotation
         [self setBoundingBoxes];
     }];
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
}

@end
