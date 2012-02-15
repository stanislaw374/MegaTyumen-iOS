//
//  EventItem.m
//  MegaTyumen
//
//  Created by Stanislaw Lazienki on 19.12.11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "Event.h"

@interface Event()
@property (nonatomic, strong) SDWebImageDownloader *downloader;
@end

@implementation Event
//@synthesize image = _image;
@synthesize user = _user;
@synthesize text = _text;
@synthesize date = _date;
@synthesize downloader = _downloader;
@synthesize imageUrl = _imageUrl;

@end
