//
//  TweetbotForCouria.mm
//  TweetbotForCouria
//
//  Created by Qusic on 7/18/13.
//  Copyright (c) 2013 Qusic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Social/Social.h>
#import <Accounts/Accounts.h>
#import "Couria.h"

/*
 * This is an example project of Couria extension.
 * 
 * Generally, a Couria extension has these files:
 * 1. /Library/MobileSubstrate/DynamicLibraries/__$My_Couria_Extension_$__.dylib
 * 2. /Library/MobileSubstrate/DynamicLibraries/__$My_Couria_Extension_$__.plist
 * 3. /Library/Application Support/Couria/Extensions/__$Bundle_Identifier_Of_The_Application_Which_My_Extension_Is_For$__/Extension.plist
 *
 * The 3rd file listed above is optional and it is used to add extra preferences into Couria preferences.
 * Only simple PreferenceLoader plist is supported and you should create your own preference bundle if you need more control and flexibility.
 */

#pragma mark - Defines

#define TweetbotBundleIdentifier (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone ? @"com.tapbots.Tweetbot" : @"com.tapbots.TweetbotPad")

#pragma mark - Interfaces

@interface CouriaTweetbotMessage : NSObject <CouriaMessage> // Here a message is a mention or reply.
@property(retain) NSString *text; // Tweet content.
@property(retain) id media; // We only support image attachments here for simplicity.
@property(assign) BOOL outgoing;
@end

@interface CouriaTweetbotDataSource : NSObject <CouriaDataSource>
@end

@interface CouriaTweetbotDelegate : NSObject <CouriaDelegate>
@end

#pragma mark - Private APIs

@interface BBBulletin : NSObject
@property(retain, nonatomic) NSDictionary *context;
@end

@interface ACAccount (Private)
@property(readonly) NSDictionary *accountProperties;
@end

#pragma mark - Implementations

static NSString *Username; // Users can choose which account to use in extension preferences.
static NSMutableDictionary *Messages; // Messages usually are stored in the database of the messaging app. But Twitter is not a messaging service so here we use the infomation in push notifications as messages.

static void preferencesChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
    Username = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/me.qusic.tweetbotforcouria.plist"][@"Username"];
    if ([Username hasPrefix:@"@"]) {
        Username = [Username substringFromIndex:1];
    }
    Messages = [NSMutableDictionary dictionary];
}

static NSArray *getTwitterAccounts(void)
{
    static ACAccountStore *accountStore;
    if (accountStore == nil) {
        accountStore = [[ACAccountStore alloc]init];
    }
    ACAccountType *accountType = [accountStore accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierTwitter];
    NSArray *accounts = [accountStore accountsWithAccountType:accountType];
    return accounts;
}

static ACAccount *getTwitterAccountByUserID(NSString *userid)
{
    NSArray *accounts = getTwitterAccounts();
    for (ACAccount *account in accounts) {
        if ([account.accountProperties[@"user_id"] caseInsensitiveCompare:userid] == NSOrderedSame) {
            return account;
        }
    }
    return nil;
}

static ACAccount *getTwitterAccountByUsername(NSString *username)
{
    NSArray *accounts = getTwitterAccounts();
    for (ACAccount *account in accounts) {
        if ([account.username caseInsensitiveCompare:username] == NSOrderedSame) {
            return account;
        }
    }
    return nil;
}

@implementation CouriaTweetbotMessage
@end

@implementation CouriaTweetbotDataSource

- (NSString *)getUserIdentifier:(BBBulletin *)bulletin
{
    NSDictionary *userInfo = bulletin.context[@"userInfo"];
    if (![userInfo[@"e"] isEqualToString:@"m"]) { // Not a mention notification.
        return nil;
    }
    if ([getTwitterAccountByUserID([userInfo[@"a"]stringValue]).username caseInsensitiveCompare:Username] != NSOrderedSame) { // Not a notification from the designated account.
        return nil;
    }
    
    //Extract infomation from the bulletin. But this method is NOT recommended. You should directly read data from databases of the app, or simply ask the app by the way of interprocess communication.
    NSString *alert = userInfo[@"aps"][@"alert"];
    NSUInteger location = [alert rangeOfString:@":"].location;
    if (location == NSNotFound) { // What?
        return nil;
    }
    NSString *part1 = [alert substringToIndex:location];
    NSString *part2 = [alert substringFromIndex:location+2];
    NSString *username = [part1 substringWithRange:[[NSRegularExpression regularExpressionWithPattern:@"(?<=@).*?(?= )" options:NSRegularExpressionCaseInsensitive error:nil]firstMatchInString:part1 options:0 range:NSMakeRange(0, part1.length)].range];
    NSString *message = part2;
    Messages[username] = message; // Store this message summary in the push notification.
    
    return username;
}

- (NSString *)getNickname:(NSString *)userIdentifier
{
    // It's too expensive to get the name from Twitter API.
    return [NSString stringWithFormat:@"@%@", userIdentifier];
}

- (NSArray *)getMessages:(NSString *)userIdentifier
{
    NSString *summary = Messages[userIdentifier];
    if (summary != nil) {
        CouriaTweetbotMessage *message = [[CouriaTweetbotMessage alloc]init];
        message.text = summary;
        message.media = nil;
        message.outgoing = NO;
        return @[message];
    } else {
        return nil;
    }
}

- (NSArray *)getContacts:(NSString *)keyword
{
    // Just assume that the user are typing a username.
    NSString *username = keyword ? : @"";
    if ([username hasPrefix:@"@"]) {
        username = [username substringFromIndex:1];
    }
    return @[username];
}

@end

@implementation CouriaTweetbotDelegate

- (void)sendMessage:(id<CouriaMessage>)message toUser:(NSString *)userIdentifier
{
    NSString *status = [NSString stringWithFormat:@"@%@: %@", userIdentifier, message.text];
    UIImage *image = message.media;
    
    SLRequest *request = nil;
    if (image == nil) {
        request = [SLRequest requestForServiceType:SLServiceTypeTwitter requestMethod:SLRequestMethodPOST
                                               URL:[NSURL URLWithString:@"https://api.twitter.com/1.1/statuses/update.json"]
                                        parameters:@{@"status" : status}];
    } else {
        request = [SLRequest requestForServiceType:SLServiceTypeTwitter requestMethod:SLRequestMethodPOST
                                               URL:[NSURL URLWithString:@"https://api.twitter.com/1.1/statuses/update_with_media.json"]
                                        parameters:@{@"status" : status}];
        NSData *imageData = UIImageJPEGRepresentation(image, 1);
        [request addMultipartData:imageData withName:@"media[]" type:@"image/jpeg" filename:@"image.jpg"];

    }
    [request setAccount:getTwitterAccountByUsername(Username)];
    [request performRequestWithHandler:^(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error) {}];
}

- (BOOL)canSendPhoto
{
    return YES;
}

@end

#pragma mark - Constructor

__attribute__((constructor))
static void Constructor() // This will run on the loading of our dylib.
{
    @autoreleasepool {
        // Now Couria has been loaded into SpringBoard and we can register our data source and delegate.
        Couria *couria = [NSClassFromString(@"Couria") sharedInstance];
        [couria registerDataSource:[CouriaTweetbotDataSource new] delegate:[CouriaTweetbotDelegate new] forApplication:TweetbotBundleIdentifier];
        
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, preferencesChanged, CFSTR("me.qusic.tweetbotforcouria.preferencesChanged"), NULL, CFNotificationSuspensionBehaviorCoalesce);
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR("me.qusic.tweetbotforcouria.preferencesChanged"), NULL, NULL, TRUE);
    }
}
