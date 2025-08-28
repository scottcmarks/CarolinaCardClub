//
//  ViewController.h
//  Weekly Game Reminder
//
//  Created by Scott Marks on 7/10/25.
//

#import <UIKit/UIKit.h>
#import <MessageUI/MessageUI.h> // Import the MessageUI framework

@interface ViewController : UIViewController <MFMessageComposeViewControllerDelegate>

- (IBAction)sendMessageButtonTapped:(UIButton *)sender;

@property (nonatomic, strong) UIButton *sendMessageButton; // Declare the button as a property

@end

