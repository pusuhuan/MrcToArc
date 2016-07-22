//
//  AppDelegate.m
//  MrcToArc
//
//  Created by iceman on 16/7/20.
//  Copyright © 2016年 iceman. All rights reserved.
//

#import "AppDelegate.h"

#define PROJECTPATH @"/Users/iceman/Desktop/WeMusic_Beta_6"
#define TARGETNAME @"WeMusic"
#define IDLength 24



@interface AppDelegate ()

@property (weak) IBOutlet NSWindow *window;

@property (nonatomic,strong) NSFileManager *fileManager;

@property (nonatomic,strong) NSMutableArray *projectFileIdArray;

@property (nonatomic,strong) NSMutableArray *projectFileNameArray;

@property (nonatomic,strong) NSMutableArray *arcFileNameArray;

@property (nonatomic,strong) NSMutableArray *mrcFileNameArray;

@property (nonatomic,strong) NSMutableArray *deleteArcFlagFileArray;

@property (nonatomic,strong) NSMutableArray *addMrcFlagFileArray;

@property (nonatomic,copy) NSString *projectID;

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification{
    
    _fileManager = [NSFileManager defaultManager];
    _projectFileIdArray = [[NSMutableArray alloc] init];
    _projectFileNameArray = [[NSMutableArray alloc] init];
    _arcFileNameArray = [[NSMutableArray alloc] init];;
    _mrcFileNameArray = [[NSMutableArray alloc] init];;
    _deleteArcFlagFileArray = [[NSMutableArray alloc] init];
    _addMrcFlagFileArray = [[NSMutableArray alloc] init];
    
    //修改配置文件
    [self updateProjectFile];
    
    //修改代码文件
    [self traversePath:PROJECTPATH];
    
}

- (void)updateProjectFile
{
//    NSString *path = @"/Users/iceman/Desktop/WeMusic_Beta_1/WeMusic.xcodeproj/project.pbxproj";
    NSString *path = [PROJECTPATH stringByAppendingFormat:@"/%@.xcodeproj/project.pbxproj",TARGETNAME];

    NSError *error;
    
    NSString *pbxprojString  = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
    
    NSMutableArray *pbxprojArray = [[NSMutableArray alloc] initWithArray:[pbxprojString componentsSeparatedByString:@"\n"]];
    
    int begin = -1;
    int end = -1;
    NSString *tempString;
    NSRange tempRange;
    
    for (int x = 0; x < pbxprojArray.count; x++) {
        tempString = pbxprojArray[x];
        if([tempString isEqualToString:@"/* Begin PBXNativeTarget section */"]){
            begin = x;
        }
        
        if([tempString isEqualToString:@"/* End PBXNativeTarget section */"]){
            end = x;
            break;
        }
    }
    

    
/*  查找工程id  */
    NSString *nameString = [NSString stringWithFormat:@" /* Build configuration list for PBXNativeTarget \"%@\" */",TARGETNAME];
    for (; begin < end; begin++) {
        tempString = pbxprojArray[begin];
        NSRange range = [tempString rangeOfString:nameString];
        if(range.length == nameString.length){
            
            begin += 2;
            if(begin < end){
                tempString = pbxprojArray[begin];
                NSRange beginRange = [tempString rangeOfString:@" /* Sources */,"];
               
                if(beginRange.length == @" /* Sources */,".length){
                    beginRange.location = beginRange.location - IDLength;
                    beginRange.length = IDLength;
                    self.projectID = [tempString substringWithRange:beginRange];
                    break;
                }
            }
        }
    }
    
    
    if(self.projectID.length <= 0){
        NSLog(@"找不到projectID");
        return;
    }
    
/*  查找需要修改的文件id array  */
    for (int x = 0; x < pbxprojArray.count; x++) {
        tempString = pbxprojArray[x];
        if([tempString containsString:@"/* Begin PBXSourcesBuildPhase section */"]){
            begin = x;
        }
        
        if([tempString containsString:@"/* End PBXSourcesBuildPhase section */"]){
            end = x;
            break;
        }
    }
    
    for (int x = begin; x < end; x++) {
        tempString = pbxprojArray[x];
        if([tempString containsString:self.projectID]){
            begin = x + 3;
        }
    }
    
    tempString = pbxprojArray[begin];
    NSRange endRange;
    
    if([tempString containsString:@"files"]){
        for (int x = begin+1;x < end;x++) {
            tempString = pbxprojArray[x];
            tempRange = [tempString rangeOfString:@" /* "];
            if(tempRange.length != 4)break;
            tempRange.location = tempRange.location - IDLength;
            tempRange.length = IDLength;
            
            endRange = [tempString rangeOfString:@" in Sources */,"];
            if (endRange.length != 15){
                NSLog(@"文件解析失败1");
                return;
            }
            endRange.length = endRange.location - (tempRange.location + IDLength + 4);
            endRange.location = endRange.location - endRange.length;
            
            
            [_projectFileIdArray addObject:[tempString substringWithRange:tempRange]];
            [_projectFileNameArray addObject:[tempString substringWithRange:endRange]];
            
        }
    }
    
    if (_projectFileIdArray.count != _projectFileNameArray.count){
        NSLog(@"文件解析失败 id 和 name 数量不等");
        return;
    }
    
    
    /*  查找需要修改的纪录位置  */
    for (int x = 0; x < pbxprojArray.count; x++) {
        tempString = pbxprojArray[x];
        if([tempString containsString:@"/* Begin PBXBuildFile section */"]){
            begin = x;
        }
        
        if([tempString containsString:@"/* End PBXBuildFile section */"]){
            end = x;
            break;
        }
    }
    

    
    int x = 0;
    
    int y = 0;
    
    NSString *tempID;
    
    
    NSMutableString *mutableString = [[NSMutableString alloc] init];
    for(int n = begin ; n < end ; n++){
        tempString = pbxprojArray[n];
        tempRange = [tempString rangeOfString:@" /*"];
        
        //相应位置有in sources 和 in Resources 两种，Resources 是图片等资源文件
        if(![tempString containsString:@"in Sources"]){
            continue;
        }
        
        
        if (tempRange.length == 3 && tempRange.location > IDLength) {
            //如果projectFileIdArray TARGETNAME 中的文件，要做处理，否则不予理会
            tempRange.location = tempRange.location - IDLength;
            tempRange.length = IDLength;
            tempID = [tempString substringWithRange:tempRange];
            
            for (int a = 0 ; a < self.projectFileIdArray.count ; a++){
                NSString *idString = self.projectFileIdArray[a];
                
                if([idString isEqualToString:tempID]){
                        x++;
                    if([tempString containsString:@"settings = {COMPILER_FLAGS = \"-fobjc-arc\"; };"]){
                        NSString *tempStringWithOutArcFlag = [tempString stringByReplacingOccurrencesOfString:@"settings = {COMPILER_FLAGS = \"-fobjc-arc\"; };" withString:@""];
                        pbxprojArray[n] = tempStringWithOutArcFlag;
                        [_arcFileNameArray addObject:_projectFileNameArray[a]];
                    }else{
                        y++;
                        [tempString stringByReplacingOccurrencesOfString:@"settings = {COMPILER_FLAGS = \"-fno-objc-arc\"; };" withString:@""];
                        
                        mutableString = [[NSMutableString alloc] initWithString:tempString];
                        
                        [mutableString insertString:@" settings = {COMPILER_FLAGS = \"-fno-objc-arc\"; };" atIndex:tempString.length - 3];
                        
                        pbxprojArray[n] = mutableString;
                        [_mrcFileNameArray addObject:_projectFileNameArray[a]];
                    }
                    break;
                }
            }
        }
    }
    
    [_fileManager removeItemAtPath:path error:nil];
    [_fileManager createFileAtPath:path contents:nil attributes:nil];
    NSFileHandle *filehandle = [NSFileHandle fileHandleForUpdatingAtPath:path];
    
    for (NSString *lineString in pbxprojArray) {
        [filehandle writeData:[[lineString stringByAppendingString:@"\n"] dataUsingEncoding:NSUTF8StringEncoding]];
    }
    [filehandle closeFile];
//    NSMutableArray *sourceArray = [[NSMutableArray alloc] init];
    
//    NSMutableArray *compilerArray = [[NSMutableArray alloc] init];
    
//    NSString *string;
//    for (int a = 0; a < array.count; a++) {
//        NSLog(@"a1 %d",a);
//        string = array[a];
//        @autoreleasepool {
//            if([string containsString:@"in Sources"]){
////                outString = [outString stringByAppendingFormat:@"%@\n",string];
//             
//                NSRange range;
//                range.length = 0;
//                range = [string rangeOfString:@"/* "];
//                if(range.length > 0)
//                {
//                    NSRange endRange = [string rangeOfString:@" in Sources"];
//                    
//                    range.location = range.length + range.location;
//                    
//                    range.length = endRange.location - range.location;
//                    NSLog(@"a2 %d",a);
//                    tempString = [string substringWithRange:range];
//                    
//                    for (int b = 0; b < sourceArray.count ; b++ ) {
//                        NSString *bString = sourceArray[b];
//                        if ([tempString isEqualToString:bString]) {
//                            
//                            NSRange aRange = [string rangeOfString:@" /*"];
//                            
//                            NSString *subString = [string substringFromIndex:aRange.length + aRange.location];
//                            [repeatArray addObject:subString];
//                            NSLog(@"b %d",b);
//                            for (int c = 0 ; c < a ; c++) {
//                                NSString *cString = array[c];
//                                if ([cString containsString:tempString]) {
//                                    aRange = [cString rangeOfString:@" /*"];
//                                    if(aRange.length == 3)
//                                    {
//                                        NSString *cSubString = [cString substringFromIndex:aRange.length + aRange.location];
//                                        NSLog(@"c %d",c);
////                                        if([subString isEqualToString:cSubString]){
//                                            [repeatArray addObject:cSubString];
////                                        }
//                                
//                                    }
//                                    break;
//                                }
//                            }
//                            
//                            break;
//                        }
//                    }
//                    
//                    [sourceArray addObject:tempString];
//                        
//                }
//                
//            }
//        }
//    }
//
//    for (NSString *string in array) {
//        @autoreleasepool {
//            if([string containsString:@"COMPILER_FLAGS"]){
////                outString = [outString stringByAppendingFormat:@"%@\n",string];
//                
//                NSRange range;
//                range.length = 0;
//                range = [string rangeOfString:@"/* "];
//                if(range.length > 0)
//                {
//                    NSRange endRange = [string rangeOfString:@" in Sources"];
//                    
//                    range.location = range.length + range.location;
//                    
//                    range.length = endRange.location - range.location;
//                    
//                    tempString = [string substringWithRange:range];
//                    
//                    for (NSString *aString in compilerArray) {
//                        if ([tempString isEqualToString:aString]) {
//                            [repeatArray addObject:string];
//                            for (NSString *bString in array) {
//                                if ([aString isEqualToString:bString]) {
//                                    [repeatArray addObject:bString];
//                                    break;
//                                }
//                            }
//                            
//                            break;
//                        }
//                    }
//                    
//                    [compilerArray addObject:tempString];
//                    
//                }
//            }
//        }
//    }
    
    
//    NSArray *sortedSourceArray = [sourceArray sortedArrayUsingSelector:@selector(compare:)];
//    NSArray *sortedCompoteArray = [compilerArray sortedArrayUsingSelector:@selector(compare:)];
}


//改.m .mm文件,只更改compile source 里有纪录的
- (void)traversePath:(NSString *)path
{
    BOOL flag = NO;
    BOOL inArcFlag = NO;
    NSArray *folder = [_fileManager contentsOfDirectoryAtPath:path error:nil];
    NSString *current = nil;
    for (NSString *name in folder){
        flag = NO;
        current = [path stringByAppendingPathComponent:name];
        if ([_fileManager fileExistsAtPath:current isDirectory:&flag]){
            inArcFlag = NO;
            if (!flag) {
                for (NSString *fileNameString in _arcFileNameArray) {
                    //只有在_arcFileNameArray 中有此文件名才做处理
                    if([fileNameString isEqualToString:name])
                    {
                        inArcFlag = YES;
                        //                        if ([current hasSuffix:@".m"] || [current hasSuffix:@".mm"] || [current hasSuffix:@".c"] || [current hasSuffix:@".cpp"]){
                        
                        NSData *fileData = [NSData dataWithContentsOfFile:current];
                        NSData *crlfData = [@"#if ! __has_feature(objc_arc)\n#error This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).\n#endif" dataUsingEncoding:NSASCIIStringEncoding];
                        
                        NSRange range;
                        range.length = fileData.length;
                        range.location = 0;
                        range = [fileData rangeOfData:crlfData options:NSDataSearchBackwards range:range];
                        
                        if(range.length > 0){
                            NSRange beginRange;
                            beginRange.location = 0;
                            beginRange.length = range.location;
                            NSMutableData *mData = [[NSMutableData alloc] initWithData:[fileData subdataWithRange:beginRange]];
                            
                            beginRange.location = range.length + range.location;
                            beginRange.length = fileData.length - beginRange.location;
                            [mData appendData:[fileData subdataWithRange:beginRange]];
                            
                            [_fileManager removeItemAtPath:current error:nil];
                            [_fileManager createFileAtPath:current contents:nil attributes:nil];
                            NSFileHandle *filehandle = [NSFileHandle fileHandleForUpdatingAtPath:current];
                            [filehandle writeData:mData];
                            [_deleteArcFlagFileArray addObject:fileNameString];
                        }
                        
                        break;
                    }
                }
                
                if(!inArcFlag)
                for (NSString *fileNameString in _mrcFileNameArray){
                    
                    if([fileNameString isEqualToString:name])
                    {
                        NSString *fileString  = [NSString stringWithContentsOfFile:current encoding:NSUTF8StringEncoding error:nil];
                        NSString *insertString = @"#if __has_feature(objc_arc)\n#error This file must be compiled with MRC. Use \"-fobjc-arc\" flag.\n#endif\n";
                        
                        NSMutableArray *mArray = [[NSMutableArray alloc] initWithArray:[fileString componentsSeparatedByString:@"\n"]];
                        
                        NSString *tempString;
                        for (int x = 0; x < mArray.count ;x++){
                            tempString = mArray[x];
                            if ([tempString containsString:@"#import"]) {
                                NSRange tempRange = [tempString rangeOfString:@"#import"];
                                //防止是注释里面的import
                                if (tempRange.length == 7 && tempRange.location < 2) {
                                    [mArray insertObject:insertString atIndex:x];
                                    [_fileManager removeItemAtPath:current error:nil];
                                    [_fileManager createFileAtPath:current contents:nil attributes:nil];
                                    NSFileHandle *filehandle = [NSFileHandle fileHandleForUpdatingAtPath:current];
                                    for (NSString *writeString in mArray) {
                                        [filehandle writeData:[[writeString stringByAppendingString:@"\n"] dataUsingEncoding:NSUTF8StringEncoding]];
                                    }
                                    [filehandle closeFile];
                                }
                                break;
                            }
                        }
                    }
                }
            }
            else {
                [self traversePath:current];
            }
        }
    }
}
@end
