/*
 * Copyright 2010 Andrey Yastrebov
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import "Vkontakte.h"
#import "SBJSON.h"

@interface Vkontakte (Private)
- (void)storeSession;
- (BOOL)isSessionValid;
- (void)getCaptcha;
- (NSDictionary *)sendRequest:(NSString *)reqURl withCaptcha:(BOOL)captcha;
- (NSDictionary *)sendPOSTRequest:(NSString *)reqURl withImageData:(NSData *)imageData;
- (NSString *)URLEncodedString:(NSString *)str;
@end

@implementation Vkontakte (Private)

- (void)storeSession
{
    // Save authorization information
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:_accessToken forKey:@"VKAccessTokenKey"];
    [defaults setObject:_expirationDate forKey:@"VKExpirationDateKey"];
    [defaults setObject:_userId forKey:@"VKUserID"];
    [defaults setObject:_email forKey:@"VKUserEmail"];
    [defaults synchronize];
}

- (BOOL)isSessionValid 
{
    return (self.accessToken != nil && self.expirationDate != nil && self.userId != nil
            && NSOrderedDescending == [self.expirationDate compare:[NSDate date]]);
}

- (void)getCaptcha 
{
    NSString *captcha_img = [[NSUserDefaults standardUserDefaults] objectForKey:@"captcha_img"];
    UIAlertView *myAlertView = [[UIAlertView alloc] initWithTitle:@"Введите код:\n\n\n\n\n"
                                                          message:@"\n" delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"OK", nil];
    
    UIImageView *imageView = [[[UIImageView alloc] initWithFrame:CGRectMake(12.0, 45.0, 130.0, 50.0)] autorelease];
    imageView.image = [UIImage imageWithData:[NSData dataWithContentsOfURL:[NSURL URLWithString:captcha_img]]];
    [myAlertView addSubview:imageView];
    
    UITextField *myTextField = [[[UITextField alloc] initWithFrame:CGRectMake(12.0, 110.0, 260.0, 25.0)] autorelease];
    [myTextField setBackgroundColor:[UIColor whiteColor]];
    
    myTextField.autocorrectionType = UITextAutocorrectionTypeNo;
    myTextField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    myTextField.tag = 33;
    
    [myAlertView addSubview:myTextField];
    [myAlertView show];
    [myAlertView release];
}

- (void)alertView:(UIAlertView *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if(_isCaptcha && buttonIndex == 1)
    {
        _isCaptcha = NO;
        
        UITextField *myTextField = (UITextField *)[actionSheet viewWithTag:33];
        [[NSUserDefaults standardUserDefaults] setObject:myTextField.text forKey:@"captcha_user"];
        NSLog(@"Captcha entered: %@",myTextField.text);
        
        // Вспоминаем какой был последний запрос и делаем его еще раз
        NSString *request = [[NSUserDefaults standardUserDefaults] objectForKey:@"request"];
        
        NSDictionary *newRequestDict =[self sendRequest:request withCaptcha:YES];
        NSString *errorMsg = [[newRequestDict  objectForKey:@"error"] objectForKey:@"error_msg"];
        if(errorMsg) 
        {
            NSError *error = [NSError errorWithDomain:@"vk.com" 
                                                 code:[[[newRequestDict  objectForKey:@"error"] objectForKey:@"error_code"] intValue] 
                                             userInfo:[newRequestDict  objectForKey:@"error"]];
            if (_delegate && [_delegate respondsToSelector:@selector(vkontakteDidFailedWithError:)]) 
            {
                [_delegate vkontakteDidFailedWithError:error];
            }
            
        } 
        else 
        {
            if (_delegate && [_delegate respondsToSelector:@selector(vkontakteDidFinishPostingToWall:)]) 
            {
                [_delegate vkontakteDidFinishPostingToWall:newRequestDict];
            }
            
        }
    }
}

- (NSDictionary *)sendRequest:(NSString *)reqURl withCaptcha:(BOOL)captcha 
{
    if(captcha == YES)
    {
        NSString *captcha_sid = [[NSUserDefaults standardUserDefaults] objectForKey:@"captcha_sid"];
        NSString *captcha_user = [[NSUserDefaults standardUserDefaults] objectForKey:@"captcha_user"];
        reqURl = [reqURl stringByAppendingFormat:@"&captcha_sid=%@&captcha_key=%@", captcha_sid, [self URLEncodedString: captcha_user]];
    }
    NSLog(@"Sending request: %@", reqURl);
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:reqURl] 
                                                           cachePolicy:NSURLRequestReloadIgnoringLocalCacheData 
                                                       timeoutInterval:60.0]; 
    
    NSData *responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:nil];
    
    if(responseData)
    {
        NSString *responseString = [[NSString alloc] initWithData:responseData 
                                                         encoding:NSUTF8StringEncoding];
        SBJsonParser *parser = [[SBJsonParser alloc] init];
        NSDictionary *dict = [parser objectWithString:responseString];
        [parser release];
        [responseString release];
        
        NSString *errorMsg = [[dict objectForKey:@"error"] objectForKey:@"error_msg"];
        
        NSLog(@"Server response: %@ \nError: %@", dict, errorMsg);
        
        if([errorMsg isEqualToString:@"Captcha needed"])
        {
            _isCaptcha = YES;
            NSString *captcha_sid = [[dict objectForKey:@"error"] objectForKey:@"captcha_sid"];
            NSString *captcha_img = [[dict objectForKey:@"error"] objectForKey:@"captcha_img"];
            [[NSUserDefaults standardUserDefaults] setObject:captcha_img forKey:@"captcha_img"];
            [[NSUserDefaults standardUserDefaults] setObject:captcha_sid forKey:@"captcha_sid"];
            [[NSUserDefaults standardUserDefaults] setObject:reqURl forKey:@"request"];
            [[NSUserDefaults standardUserDefaults] synchronize];
            
            [self getCaptcha];
        }
        
        return dict;
    }
    return nil;
}

- (NSDictionary *)sendPOSTRequest:(NSString *)reqURl withImageData:(NSData *)imageData 
{
    NSLog(@"Sending request: %@", reqURl);
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:reqURl] 
                                                           cachePolicy:NSURLRequestReloadIgnoringLocalCacheData 
                                                       timeoutInterval:60.0]; 
    [request setHTTPMethod:@"POST"]; 
    
    [request addValue:@"8bit" forHTTPHeaderField:@"Content-Transfer-Encoding"];
    
    CFUUIDRef uuid = CFUUIDCreate(nil);
    NSString *uuidString = [(NSString*)CFUUIDCreateString(nil, uuid) autorelease];
    CFRelease(uuid);
    NSString *stringBoundary = [NSString stringWithFormat:@"0xKhTmLbOuNdArY-%@",uuidString];
    NSString *endItemBoundary = [NSString stringWithFormat:@"\r\n--%@\r\n",stringBoundary];
    
    NSString *contentType = [NSString stringWithFormat:@"multipart/form-data;  boundary=%@", stringBoundary];
    
    [request setValue:contentType forHTTPHeaderField:@"Content-Type"];
    
    NSMutableData *body = [NSMutableData data];
    
    [body appendData:[[NSString stringWithFormat:@"--%@\r\n",stringBoundary] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[[NSString stringWithString:@"Content-Disposition: form-data; name=\"photo\"; filename=\"photo.jpg\"\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[@"Content-Type: image/jpg\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:imageData];        
    [body appendData:[[NSString stringWithFormat:@"%@",endItemBoundary] dataUsingEncoding:NSUTF8StringEncoding]];
    
    [request setHTTPBody:body];
    
    NSData *responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:nil];
   
    NSDictionary *dict;
    if(responseData)
    {
        NSString *responseString = [[NSString alloc] initWithData:responseData 
                                                         encoding:NSUTF8StringEncoding];
        SBJsonParser *parser = [SBJsonParser new];
        dict = [parser objectWithString:responseString];
        [parser release];
        [responseString release];
        NSString *errorMsg = [[dict objectForKey:@"error"] objectForKey:@"error_msg"];
        
        NSLog(@"Server response: %@ \nError: %@", dict, errorMsg);
        
        return dict;
    }
    return nil;
}

- (NSString *)URLEncodedString:(NSString *)str
{
    NSString *result = (NSString *)CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault,
                                                                           (CFStringRef)str,
                                                                           NULL,
																		   CFSTR("!*'();:@&=+$,/?%#[]"),
                                                                           kCFStringEncodingUTF8);
    [result autorelease];
	return result;
}

@end

@implementation Vkontakte

NSString * const vkAppId = @"2849761";

@synthesize delegate = _delegate;
@synthesize accessToken = _accessToken;
@synthesize expirationDate = _expirationDate;
@synthesize userId = _userId;
@synthesize email = _email;

#pragma mark - Initialize

+ (id)sharedInstance
{
    static dispatch_once_t pred = 0;
    __strong static id _sharedObject = nil;
    dispatch_once(&pred, ^{
        _sharedObject = [[self alloc] init]; // or some other init method
    });
    return _sharedObject;
}

- (id)init
{
    self = [super init];
    if (self) 
    {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        if ([defaults objectForKey:@"VKAccessTokenKey"] 
            && [defaults objectForKey:@"VKExpirationDateKey"]
            && [defaults objectForKey:@"VKUserID"]
            && [defaults objectForKey:@"VKUserEmail"]) 
        {
            self.accessToken = [defaults objectForKey:@"VKAccessTokenKey"];
            self.expirationDate = [defaults objectForKey:@"VKExpirationDateKey"];
            self.userId = [defaults objectForKey:@"VKUserID"];
            self.email = [defaults objectForKey:@"VKUserEmail"];
        }
    }
    return self;
}

- (BOOL)isAuthorized
{    
    if (![self isSessionValid]) 
    {
        return NO;
    } 
    else 
    {
        return YES;
    }
}

- (void)authenticate
{
    NSString *authLink = [NSString stringWithFormat:@"http://api.vk.com/oauth/authorize?client_id=%@&scope=wall,photos&redirect_uri=http://api.vk.com/blank.html&display=touch&response_type=token", vkAppId];
    NSURL *url = [NSURL URLWithString:authLink];
    
    VkontakteViewController *vkontakteViewController = [[VkontakteViewController alloc] initWithAuthLink:url];
    vkontakteViewController.delegate = self;
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:vkontakteViewController];
    
    if (_delegate && [_delegate respondsToSelector:@selector(showVkontakteAuthController:)]) 
    {
        [_delegate showVkontakteAuthController:navController];
    }
    [vkontakteViewController release];
    [navController release];
}

- (void)logout
{
    NSString *logout = @"http://api.vk.com/oauth/logout";
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:logout] 
                                                           cachePolicy:NSURLRequestReloadIgnoringLocalCacheData 
                                                       timeoutInterval:60.0]; 
    NSData *responseData = [NSURLConnection sendSynchronousRequest:request 
                                                 returningResponse:nil 
                                                             error:nil];
    if(responseData)
    {
        NSString *responseString = [[NSString alloc] initWithData:responseData 
                                                         encoding:NSUTF8StringEncoding];
        SBJsonParser *parser = [[SBJsonParser alloc] init];
        NSDictionary *dict = [parser objectWithString:responseString];
        [parser release];
        [responseString release];
        NSLog(@"Logout: %@", dict);
        
        NSHTTPCookieStorage* cookies = [NSHTTPCookieStorage sharedHTTPCookieStorage];
        NSArray* vkCookies1 = [cookies cookiesForURL:
                               [NSURL URLWithString:@"http://api.vkontakte.ru"]];
        NSArray* vkCookies2 = [cookies cookiesForURL:
                               [NSURL URLWithString:@"http://vkontakte.ru"]];
        NSArray* vkCookies3 = [cookies cookiesForURL:
                               [NSURL URLWithString:@"http://login.vk.com"]];
        
        for (NSHTTPCookie* cookie in vkCookies1) 
        {
            [cookies deleteCookie:cookie];
        }
        for (NSHTTPCookie* cookie in vkCookies2) 
        {
            [cookies deleteCookie:cookie];
        }
        for (NSHTTPCookie* cookie in vkCookies3) 
        {
            [cookies deleteCookie:cookie];
        }
        
        // Remove saved authorization information if it exists and it is
        // ok to clear it (logout, session invalid, app unauthorized)
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        if ([defaults objectForKey:@"VKAccessTokenKey"]) 
        {
            [defaults removeObjectForKey:@"VKAccessTokenKey"];
            [defaults removeObjectForKey:@"VKExpirationDateKey"];
            [defaults removeObjectForKey:@"VKUserID"];
            [defaults synchronize];
            
            // Nil out the session variables to prevent
            // the app from thinking there is a valid session
            if (nil != [self accessToken]) 
            {
                self.accessToken = nil;
            }
            if (nil != [self expirationDate]) 
            {
                self.expirationDate = nil;
            }
        }
        
        if (self.delegate && [self.delegate respondsToSelector:@selector(vkontakteDidFinishLogOut:)]) 
        {
            [self.delegate vkontakteDidFinishLogOut:self];
        }
    }
}

- (void)getUserInfo
{    
    if (![self isAuthorized]) return;
    
    NSMutableString *requestString = [[NSMutableString alloc] init];
	[requestString appendFormat:@"%@/", @"https://api.vk.com/method"];
    [requestString appendFormat:@"%@?", @"getProfiles"];
    [requestString appendFormat:@"uid=%@&", self.userId];
    NSMutableString *fields = [[NSMutableString alloc] init];
    [fields appendString:@"sex,bdate,photo,photo_big"];
    [requestString appendFormat:@"fields=%@&", fields];
	[fields release];
    [requestString appendFormat:@"access_token=%@", self.accessToken];
    
	NSURL *url = [NSURL URLWithString:requestString];
	[requestString release];
	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
	
	NSData *response = [NSURLConnection sendSynchronousRequest:request 
											 returningResponse:nil 
														 error:nil];
	NSString *responseString = [[NSString alloc] initWithData:response 
                                                     encoding:NSUTF8StringEncoding];
	NSLog(@"%@",responseString);
	
	SBJsonParser *parser = [[SBJsonParser alloc] init];
	NSDictionary *parsedDictionary = [parser objectWithString:responseString];
	[parser release];
	[responseString release];
    
    NSArray *array = [parsedDictionary objectForKey:@"response"];
    
    if (array != nil) 
    {
        parsedDictionary = [array objectAtIndex:0];
        [parsedDictionary setValue:self.email forKey:@"email"];
        
        if ([self.delegate respondsToSelector:@selector(vkontakteDidFinishGettinUserInfo:)])
        {
            [self.delegate vkontakteDidFinishGettinUserInfo:parsedDictionary];
        }
    }
    else
    {        
        NSDictionary *errorDict = [parsedDictionary objectForKey:@"error"];
        
        if ([self.delegate respondsToSelector:@selector(vkontakteDidFailedWithError:)])
        {
            NSError *error = [NSError errorWithDomain:@"http://api.vk.com/method" 
                                                 code:[[errorDict objectForKey:@"error_code"] intValue]
                                             userInfo:errorDict];
            
            if (error.code == 5) 
            {
                [self logout];
            }
            
            [self.delegate vkontakteDidFailedWithError:error];
        }
    }
}

- (void)postMessageToWall:(NSString *)message
{
    if (![self isAuthorized]) return;
            
    NSString *sendTextMessage = [NSString stringWithFormat:@"https://api.vk.com/method/wall.post?owner_id=%@&access_token=%@&message=%@", 
                                 self.userId, 
                                 self.accessToken, 
                                 [self URLEncodedString:message]];
    NSLog(@"sendTextMessage: %@", sendTextMessage);
    
    NSDictionary *result = [self sendRequest:sendTextMessage withCaptcha:NO];
    // Если есть описание ошибки в ответе
    NSString *errorMsg = [[result objectForKey:@"error"] objectForKey:@"error_msg"];
    if(errorMsg) 
    {
        NSDictionary *errorDict = [result objectForKey:@"error"];
        
        if ([self.delegate respondsToSelector:@selector(vkontakteDidFailedWithError:)])
        {
            NSError *error = [NSError errorWithDomain:@"http://api.vk.com/method" 
                                                 code:[[errorDict objectForKey:@"error_code"] intValue]
                                             userInfo:errorDict];
            
            if (error.code == 5) 
            {
                [self logout];
            }
            
            [self.delegate vkontakteDidFailedWithError:error];
        }
    } 
    else 
    {
        if (_delegate && [_delegate respondsToSelector:@selector(vkontakteDidFinishPostingToWall:)]) 
        {
            [_delegate vkontakteDidFinishPostingToWall:result];
        }
    }
}

- (void)postMessageToWall:(NSString *)message link:(NSURL *)url
{
    if (![self isAuthorized]) return;
    
    NSString *link = [url absoluteString];
    
    NSString *sendTextAndLinkMessage = [NSString stringWithFormat:@"https://api.vk.com/method/wall.post?owner_id=%@&access_token=%@&message=%@&attachment=%@", 
                                        self.userId, 
                                        self.accessToken, 
                                        [self URLEncodedString:message], 
                                        link];
    
    NSLog(@"sendTextAndLinkMessage: %@", sendTextAndLinkMessage);
    
    // Если запрос более сложный мы можем работать дальше с полученным ответом
    NSDictionary *result = [self sendRequest:sendTextAndLinkMessage withCaptcha:NO];
    NSString *errorMsg = [[result objectForKey:@"error"] objectForKey:@"error_msg"];
    if(errorMsg) 
    {
        NSDictionary *errorDict = [result objectForKey:@"error"];
        
        if ([self.delegate respondsToSelector:@selector(vkontakteDidFailedWithError:)])
        {
            NSError *error = [NSError errorWithDomain:@"http://api.vk.com/method" 
                                                 code:[[errorDict objectForKey:@"error_code"] intValue]
                                             userInfo:errorDict];
            
            if (error.code == 5) 
            {
                [self logout];
            }
            
            [self.delegate vkontakteDidFailedWithError:error];
        }
    } 
    else 
    {
        if (_delegate && [_delegate respondsToSelector:@selector(vkontakteDidFinishPostingToWall:)]) 
        {
            [_delegate vkontakteDidFinishPostingToWall:result];
        }
    }
}

- (void)postImageToWall:(UIImage *)image text:(NSString *)message
{
    if (![self isAuthorized]) return;
    
    NSString *getWallUploadServer = [NSString stringWithFormat:@"https://api.vk.com/method/photos.getWallUploadServer?owner_id=%@&access_token=%@", self.userId, self.accessToken];
    
    NSDictionary *uploadServer = [self sendRequest:getWallUploadServer withCaptcha:NO];
    
    NSString *upload_url = [[uploadServer objectForKey:@"response"] objectForKey:@"upload_url"];
    
    NSData *imageData = UIImageJPEGRepresentation(image, 1.0f);
    
    NSDictionary *postDictionary = [self sendPOSTRequest:upload_url withImageData:imageData];
    
    NSString *hash = [postDictionary objectForKey:@"hash"];
    NSString *photo = [postDictionary objectForKey:@"photo"];
    NSString *server = [postDictionary objectForKey:@"server"];
    
    NSString *saveWallPhoto = [NSString stringWithFormat:@"https://api.vk.com/method/photos.saveWallPhoto?owner_id=%@&access_token=%@&server=%@&photo=%@&hash=%@", 
                               self.userId, 
                               self.accessToken,
                               server,
                               photo,
                               hash];
    
    saveWallPhoto = [saveWallPhoto stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    
    NSDictionary *saveWallPhotoDict = [self sendRequest:saveWallPhoto withCaptcha:NO];
    
    NSDictionary *photoDict = [[saveWallPhotoDict objectForKey:@"response"] lastObject];
    NSString *photoId = [photoDict objectForKey:@"id"];
    
    NSString *postToWallLink = [NSString stringWithFormat:@"https://api.vk.com/method/wall.post?owner_id=%@&access_token=%@&message=%@&attachment=%@", 
                                self.userId, 
                                self.accessToken, 
                                [self URLEncodedString:message], 
                                photoId];
    
    NSDictionary *postToWallDict = [self sendRequest:postToWallLink withCaptcha:NO];
    NSString *errorMsg = [[postToWallDict  objectForKey:@"error"] objectForKey:@"error_msg"];
    if(errorMsg) 
    {
        NSDictionary *errorDict = [postToWallDict objectForKey:@"error"];
        
        if ([self.delegate respondsToSelector:@selector(vkontakteDidFailedWithError:)])
        {
            NSError *error = [NSError errorWithDomain:@"http://api.vk.com/method" 
                                                 code:[[errorDict objectForKey:@"error_code"] intValue]
                                             userInfo:errorDict];
            
            if (error.code == 5) 
            {
                [self logout];
            }
            
            [self.delegate vkontakteDidFailedWithError:error];
        }
    } 
    else 
    {
        if (_delegate && [_delegate respondsToSelector:@selector(vkontakteDidFinishPostingToWall:)]) 
        {
            [_delegate vkontakteDidFinishPostingToWall:postToWallDict];
        }
    }
}

- (void)postImageToWall:(UIImage *)image
{
    if (![self isAuthorized]) return;
        
    [self postImageToWall:image text:@""];
}

#pragma mark - VkontakteViewControllerDelegate

- (void)authorizationDidSucceedWithToke:(NSString *)accessToken 
                                 userId:(NSString *)userId 
                                expDate:(NSDate *)expDate
                              userEmail:(NSString *)email

{
    self.accessToken = accessToken;
    self.userId = userId;
    self.expirationDate = expDate;
    self.email = email;
    
    [self storeSession];
    
    if (_delegate && [_delegate respondsToSelector:@selector(vkontakteDidFinishLogin:)]) 
    {
        [_delegate vkontakteDidFinishLogin:self];
    }
}

- (void)authorizationDidFailedWithError:(NSError *)error
{
    if (_delegate && [_delegate respondsToSelector:@selector(vkontakteDidFailedWithError:)]) 
    {
        [_delegate vkontakteDidFailedWithError:error];
    }
}

- (void)authorizationDidCanceled
{
    if (_delegate && [_delegate respondsToSelector:@selector(vkontakteAuthControllerDidCancelled)]) 
    {
        [_delegate vkontakteAuthControllerDidCancelled];
    }
}

- (void)didFinishGettingUserEmail:(NSString *)email
{
    self.email = email;
}

#pragma mark - Memory Management

- (void) dealloc 
{
    self.accessToken = nil;
    self.userId = nil;
    self.expirationDate = nil;
    self.email = nil;
    [super dealloc];
}

@end
