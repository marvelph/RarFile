//
//  RarFile.m
//  RarFile
//
//  Created by Kenji Nishishiro <marvel@programmershigh.org> on 2013/08/29.
//  Copyright 2013 Kenji Nishishiro. All rights reserved.
//

#import "RarFile.h"

#include "rar.hpp"
#include "dll.hpp"

@implementation RarFile

- (id)initWithFileAtPath:(NSString *)path {
    NSAssert(path, @"path");
    
	if (self = [super init]) {
        _path = [path retain];
    }
    return self;
}

- (void)dealloc {
    [_path release];
    [super dealloc];
}

- (BOOL)open {
    return YES;
}

- (void)close {
}

int CALLBACK CallbackProc(UINT msg, LPARAM UserData, LPARAM P1, LPARAM P2)
{
    switch (msg) {
        case UCM_PROCESSDATA: {
            NSMutableData *data = (NSMutableData *)UserData;
            [data appendBytes:(void *)P1 length:P2];
            return 1;
        }
        default:
            return 0;
    }
}

- (NSData *)readWithFileName:(NSString *)fileName maxLength:(NSUInteger)maxLength
{
	NSAssert(fileName, @"fileName");
    
    NSMutableData *data = [NSMutableData data];
    
    RAROpenArchiveDataEx openArchiveData;
    memset(&openArchiveData, 0, sizeof openArchiveData);
    openArchiveData.ArcName = (char *)[_path UTF8String];
    openArchiveData.OpenMode = RAR_OM_EXTRACT;
    openArchiveData.Callback = CallbackProc;
    openArchiveData.UserData = (LPARAM)data;
    HANDLE unrarFile = RAROpenArchiveEx(&openArchiveData);
    if (openArchiveData.OpenResult) {
        return nil;
    }
    
    int error;
    RARHeaderDataEx headerData;
    while (!(error = RARReadHeaderEx(unrarFile, &headerData))) {
        if ([fileName isEqual:[NSString stringWithUTF8String:headerData.FileName]]) {
            break;
        }
        if ((error = RARProcessFile(unrarFile, RAR_SKIP, NULL, NULL))) {
            break;
        }
    }
    if (error != ERAR_SUCCESS) {
        RARCloseArchive(unrarFile);
        return nil;
    }
    
    error = RARProcessFile(unrarFile, RAR_TEST, NULL, NULL);
    
    RARCloseArchive(unrarFile);
    if (error == ERAR_SUCCESS) {
        return data;
    }
    else {
        return nil;
    }
}

- (NSArray *)fileNames
{
    RAROpenArchiveDataEx openArchiveData;
    memset(&openArchiveData, 0, sizeof openArchiveData);
    openArchiveData.ArcName = (char *)[_path UTF8String];
    openArchiveData.OpenMode = RAR_OM_LIST;
    openArchiveData.Callback = CallbackProc;
    HANDLE unrarFile = RAROpenArchiveEx(&openArchiveData);
    if (openArchiveData.OpenResult) {
        return nil;
    }
    
    NSMutableArray *results = [NSMutableArray array];
    int error;
    RARHeaderDataEx headerData;
    while (!(error = RARReadHeaderEx(unrarFile, &headerData))) {
        [results addObject:[NSString stringWithUTF8String:headerData.FileName]];
        if ((error = RARProcessFile(unrarFile, RAR_SKIP, NULL, NULL))) {
            break;
        }
    }
    
    RARCloseArchive(unrarFile);
    if (error == ERAR_END_ARCHIVE) {
        return results;
    }
    else {
        return nil;
    }
}

@end
