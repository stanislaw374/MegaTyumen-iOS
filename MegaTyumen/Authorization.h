//
//  Authorization.h
//  MegaTyumen
//
//  Created by Yazhenskikh Stanislaw on 23.11.11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ASIHTTPRequestDelegate.h"
#import "ASIHTTPRequest.h"

#define kNOTIFICATION_DID_AUTHORIZE @"megatyumen.didAuthorize"
#define kNOTIFICATION_DID_PASS_AUTHORIZATION @"megatyumen.didPassAuthorization"
#define kNOTIFICATION_DID_REGISTER @"megatyumen.didRegister"
#define kNOTIFICATION_DID_PASS_REGISTRATION @"megatyumen.didPassRegistration"
#define kNOTIFICATION_DID_GET_USER_AGREEMENT @"megatyumen.didGetUserAgreement"
#define kNOTIFICATION_DID_RESTORE_PASSWORD @"megatyumen.didRestorePassword"

@protocol AuthorizationDelegate;

@interface Authorization : NSObject <ASIHTTPRequestDelegate>

@property (nonatomic, readonly) BOOL isAuthorized;
@property (nonatomic, copy, readonly) NSString *token;
@property (nonatomic, readonly) BOOL result;
@property (nonatomic, copy, readonly) NSString *error;
@property (nonatomic, copy, readonly) NSString *userAgreement;

// Синглетон авторизации
+ (Authorization *)sharedAuthorization; 

// Авторизация
- (void)authorizeWithLogin:(NSString *)login andPassword:(NSString *)password;

// Регистрация
- (void)registerWithLogin:(NSString *)login Password:(NSString *)password andName:(NSString *)name;

// Пользовательское соглашение
- (void)getUserAgreement;

// Восстановление пароля
- (void)restorePasswordWithEmail:(NSString *)email;

@end
