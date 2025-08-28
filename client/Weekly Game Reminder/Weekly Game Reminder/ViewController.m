//
//  ViewController.m
//  Weekly Game Reminder
//
//  Created by Scott Marks on 7/10/25.
//

#import "ViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    // Initialize the button

    self.view.backgroundColor = UIColor.systemBackgroundColor;

    self.sendMessageButton = [UIButton buttonWithType:UIButtonTypeSystem];
    
    // Set button title
    [self.sendMessageButton setTitle:@"Send Message" forState:UIControlStateNormal];
    
    // Set title color
    [self.sendMessageButton setTitleColor:[UIColor darkTextColor] forState:UIControlStateNormal];
    
    // Set a distinct background color for debugging
    self.sendMessageButton.backgroundColor = [UIColor tertiarySystemFillColor]; // Or any easily visible color
    
    // Add an action to the button
    [self.sendMessageButton addTarget:self
                               action:@selector(sendMessageButtonTapped:)
                     forControlEvents:UIControlEventTouchUpInside];

    // Disable autoresizing masks to use Auto Layout constraints
    self.sendMessageButton.translatesAutoresizingMaskIntoConstraints = NO;

    // Add the button to the view hierarchy
    [self.view addSubview:self.sendMessageButton];

    // Set up Auto Layout constraints for the button
    [NSLayoutConstraint activateConstraints:@[
        [self.sendMessageButton.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.sendMessageButton.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [self.sendMessageButton.widthAnchor constraintEqualToConstant:200], // Example width
        [self.sendMessageButton.heightAnchor constraintEqualToConstant:50]  // Example height
    ]];
}


// Call this function when you want to display the message compose view
- (IBAction)sendMessageButtonTapped:(UIButton *)sender {
    [self displayMessageComposeViewController:@[@"713-714-6660"]
                                             // Replace with actual recipient phone numbers from the player DB
                                             // You can add multiple recipients if needed:
                                             // messageComposeViewController.recipients = @[@"123-456-7890", @"987-654-3210"];
                                         body:@"Hello on Saturday from my iOS app one level up!"
                                            // Replace with the weekly message, from ... where?];
    ];
}

- (void) displayMessageComposeViewController: (NSArray<NSString *> *)recipients body:(NSString *)body  {
    // Check if the device can send text messages
    if ([MFMessageComposeViewController canSendText]) {
        MFMessageComposeViewController *messageComposeViewController = [[MFMessageComposeViewController alloc] init];
        messageComposeViewController.messageComposeDelegate = self; // Set the delegate

        // Configure the message recipients
        messageComposeViewController.recipients = recipients;

        // Set the message body
        messageComposeViewController.body = body;

        // Present the message compose view controller modally
//        dispatch_async(dispatch_get_main_queue(), ^{
//            [self presentViewController:messageComposeViewController animated:YES completion:nil];
//        });
         [self presentViewController:messageComposeViewController animated:YES completion:nil];
    } else {
        // Handle the case where the device cannot send text messages
        // This might happen on an iPad that doesn't have cellular capabilities for sending SMS
        NSLog(@"Device not configured to send messages.");
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Cannot Send Message"
                                                                        message:@"Your device is not configured to send messages."
                                                                 preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
        [alert addAction:okAction];
        [self presentViewController:alert animated:YES completion:nil];
    }
}

#pragma mark - MFMessageComposeViewControllerDelegate

- (void)messageComposeViewController:(MFMessageComposeViewController *)controller didFinishWithResult:(MessageComposeResult)result {
    // Dismiss the message compose view controller
    [controller dismissViewControllerAnimated:YES completion:nil];

    // Handle the message sending result
    switch (result) {
        case MessageComposeResultCancelled:
            NSLog(@"Message composition cancelled.");
            break;
        case MessageComposeResultSent:
            NSLog(@"Message sent successfully.");
            break;
        case MessageComposeResultFailed:
            NSLog(@"Message sending failed.");
            break;
        default:
            NSLog(@"Unknown message compose result.");
            break;
    }
}


@end
