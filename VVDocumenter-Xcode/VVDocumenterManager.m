//
//  VVDocumenterManager.m
//  VVDocumenter-Xcode
//
//  Created by 王 巍 on 13-7-16.
//  Copyright (c) 2013年 OneV's Den. All rights reserved.
//

#import "VVDocumenterManager.h"
#import "NSTextView+VVTextGetter.h"
#import "NSString+VVSyntax.h"
#import "VVDocumenter.h"
#import "VVKeyboardEventSender.h"
#import "VVDSettingPanelWindowController.h"
#import "VVDocumenterSetting.h"

#import "NSLineString.h"

typedef enum CopyDirection {
	CD_UP = 1, CD_DOWN
} CopyDirection;

@interface VVDocumenterManager()
@property (nonatomic, strong) id eventMonitor;
@property (nonatomic, assign) BOOL prefixTyped;
@property (nonatomic, strong) VVDSettingPanelWindowController *settingPanel;
@end

@implementation VVDocumenterManager
+(void)pluginDidLoad:(NSBundle *)plugin {
    VVLog(@"VVDocumenter: Plugin loaded successfully");
    [self shared];
}

+(id) shared {
    static dispatch_once_t once;
    static id instance = nil;
    dispatch_once(&once, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (id)init {
    if (self = [super init]) {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationDidFinishLaunching:)
                                                     name:NSApplicationDidFinishLaunchingNotification
                                                   object:nil];
    }
    return self;
}

- (void) applicationDidFinishLaunching: (NSNotification*) noti {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(textStorageDidChange:)
                                                 name:NSTextDidChangeNotification
                                               object:nil];
    [self addSettingMenu];
}

-(void) addSettingMenu
{
    NSMenuItem *windowMenuItem = [[NSApp mainMenu] itemWithTitle:@"Window"];
    if (windowMenuItem) {
        [[windowMenuItem submenu] addItem:[NSMenuItem separatorItem]];
        
        NSMenuItem *newMenuItem = [[NSMenuItem alloc] initWithTitle:@"VVDocumenter" action:@selector(showSettingPanel:) keyEquivalent:@""];
        
        [newMenuItem setTarget:self];
        [[windowMenuItem submenu] addItem:newMenuItem];
    }
    
    //add additional menu
    NSMenuItem *editMenuItem = [[NSApp mainMenu] itemWithTitle:@"Edit"];
    if (editMenuItem) {
        NSMenu *submenu = [[NSMenu alloc] init];
        NSMenuItem *item = nil;

        UniChar a;
        a		= 63232;
        item	= [[NSMenuItem alloc] initWithTitle:@"Copy line up" action:@selector(copyLineUp:) keyEquivalent:[NSString stringWithCharacters:&a length:1]];
        [item setKeyEquivalentModifierMask:(NSControlKeyMask | NSAlternateKeyMask)];
        [item setTarget:self];
        [submenu addItem:item];
        
        a		= 63233;
        item	= [[NSMenuItem alloc] initWithTitle:@"Copy line down" action:@selector(copyLineDown:) keyEquivalent:[NSString stringWithCharacters:&a length:1]];
        [item setKeyEquivalentModifierMask:(NSControlKeyMask | NSAlternateKeyMask)];
        [item setTarget:self];
        [submenu addItem:item];
        
        item = [[NSMenuItem alloc] initWithTitle:@"Delete line" action:@selector(deleteLine:) keyEquivalent:@"-"];
        [item setKeyEquivalentModifierMask:(NSCommandKeyMask)];
        [item setTarget:self];
        [submenu addItem:item];
        
        NSMenuItem *vvdocumentMenuItem = [[NSMenuItem alloc] initWithTitle:@"VVDocument" action:NULL keyEquivalent:@""];
        [vvdocumentMenuItem setSubmenu:submenu];
        
        [[editMenuItem submenu] addItem:[NSMenuItem separatorItem]];
        [[editMenuItem submenu] addItem:vvdocumentMenuItem];
    }
}

#pragma mark - Copy line
- (void)copyLine:(CopyDirection)direction
{
	NSWindow	*nsKeyWindow	= [[NSApplication sharedApplication] keyWindow];
	NSResponder *responder		= [nsKeyWindow firstResponder];
	NSString	*resname		= [[responder class] description];
    
	if (![resname isEqualToString:@"DVTSourceTextView"]) {
		return;
	}
    
	NSTextView		*tv		= (NSTextView *)responder;
	NSRange			range	= tv.selectedRange;
	NSLineString	*ls		= [NSLineString lineStringWith:[[tv textStorage] string]];
	NSUInteger		cline	= [ls lineOfLocation:range.location];
    
	NSString	*ltext;
	NSRange		srg;
    
	if (range.length > 0) {
		if ('\n' == [ls.targetStr characterAtIndex:range.location + range.length - 1]) {
			range.length -= 1;
		}
        
		NSRange srange	= [ls rangeOfLineNumber:[ls lineOfLocation:range.location]];
		NSRange erange	= [ls rangeOfLineNumber:[ls lineOfLocation:(range.location + range.length)]];
		range	= NSMakeRange(srange.location, erange.location + erange.length + 1 - srange.location);
		ltext	= [ls.targetStr substringWithRange:range];
        
		if (direction == CD_UP) {
			srg = range;
		} else {
			srg = NSMakeRange(range.length + range.location, ltext.length);
		}
        
		range = NSMakeRange(range.length + range.location, 0);
	} else {
		ltext			= [[ls stringOfLineNumber:cline] stringByAppendingString:@"\n"];
		range			= [ls rangeOfLineNumber:cline];
		range.location	= range.location + range.length + 1;
		range.length	= 0;
        
		if (direction == CD_UP) {
			srg = tv.selectedRange;
		} else {
			srg = NSMakeRange(range.length + range.location + ltext.length - 1, 0);
		}
	}
    
	[tv insertText:ltext replacementRange:range];
	tv.selectedRange = srg;
}

- (void)copyLineUp:(id)sender
{
	@synchronized(self) {
		@try {
			[self copyLine:CD_UP];
		}
		@catch(NSException *exception) {
			NSLog(@"copy line up error:%@", [exception debugDescription]);
		}
	}
}

- (void)copyLineDown:(id)sender
{
	@synchronized(self) {
		@try {
			[self copyLine:CD_DOWN];
		}
		@catch(NSException *exception) {
			NSLog(@"copy line up error:%@", [exception debugDescription]);
		}
	}
}

#pragma mark - Delete line
- (void)deleteLine:(id)sender
{
	NSWindow	*nsKeyWindow	= [[NSApplication sharedApplication] keyWindow];
	NSResponder *responder		= [nsKeyWindow firstResponder];
	NSString	*resname		= [[responder class] description];
    
	if (![resname isEqualToString:@"DVTSourceTextView"]) {
		return;
	}
    
	NSTextView		*tv		= (NSTextView *)responder;
	NSRange			range	= tv.selectedRange;
	NSLineString	*ls		= [NSLineString lineStringWith:[[tv textStorage] string]];
	NSUInteger		cline	= [ls lineOfLocation:range.location];
    
	if (range.length > 0) {
		if ('\n' == [ls.targetStr characterAtIndex:range.location + range.length - 1]) {
			range.length -= 1;
		}
        
		NSRange srange	= [ls rangeOfLineNumber:[ls lineOfLocation:range.location]];
		NSRange erange	= [ls rangeOfLineNumber:[ls lineOfLocation:(range.location + range.length)]];
		range = NSMakeRange(srange.location, erange.location + erange.length + 1 - srange.location);
	} else {
		range = [ls rangeOfLineNumber:cline];
		range.length++;
	}
    
	[tv insertText:@"" replacementRange:range];
}


-(void) showSettingPanel:(NSNotification *)noti {
    self.settingPanel = [[VVDSettingPanelWindowController alloc] initWithWindowNibName:@"VVDSettingPanelWindowController"];
    [self.settingPanel showWindow:self.settingPanel];
}

- (void) textStorageDidChange:(NSNotification *)noti {

    if ([[noti object] isKindOfClass:[NSTextView class]]) {
        NSTextView *textView = (NSTextView *)[noti object];
        VVTextResult *currentLineResult = [textView textResultOfCurrentLine];
        if (currentLineResult) {

            //Check if there is a "//" already typed in. We do this to solve the undo issue
            //Otherwise when you press Cmd+Z, "///" will be recognized and trigger the doc inserting, so you can not perform an undo.
            NSString *triggerString = [[VVDocumenterSetting defaultSetting] triggerString];
            
            if (triggerString.length > 1) {
                NSString *preTypeString = [triggerString substringToIndex:triggerString.length - 2];
                self.prefixTyped = [currentLineResult.string vv_matchesPatternRegexPattern:[NSString stringWithFormat:@"^\\s*%@$",[NSRegularExpression escapedPatternForString:preTypeString]]] | self.prefixTyped;
            } else {
                self.prefixTyped = YES;
            }
            
            if ([currentLineResult.string vv_matchesPatternRegexPattern:[NSString stringWithFormat:@"^\\s*%@$",[NSRegularExpression escapedPatternForString:triggerString]]] && self.prefixTyped) {
                VVTextResult *previousLineResult = [textView textResultOfPreviousLine];

                // Previous line is a documentation comment, so ignore this
                if ([previousLineResult.string vv_matchesPatternRegexPattern:@"^\\s*///"]) {
                    return;
                }

                VVTextResult *nextLineResult = [textView textResultOfNextLine];

                // Next line is a documentation comment, so ignore this
                if ([nextLineResult.string vv_matchesPatternRegexPattern:@"^\\s*///"]) {
                    return;
                }
                
                //Get a @"///" (triggerString) typed in by user. Do work!
                self.prefixTyped = NO;

                __block BOOL shouldReplace = NO;
                
                //Decide which is closer to the cursor. A semicolon or a half brace.
                //We just want to document the next valid line.
                VVTextResult *resultUntilSemiColon = [textView textResultUntilNextString:@";"];
                VVTextResult *resultUntilBrace = [textView textResultUntilNextString:@"{"];
                
                VVTextResult *resultToDocument = nil;
                
                if (resultUntilSemiColon && resultUntilBrace) {
                    resultToDocument = (resultUntilSemiColon.range.length < resultUntilBrace.range.length) ? resultUntilSemiColon : resultUntilBrace;
                } else if (resultUntilBrace) {
                    resultToDocument = resultUntilBrace;
                } else {
                    resultToDocument = resultUntilSemiColon;
                }
                
                //We always write document until semicolon for enum. (Maybe struct later)
                if ([resultToDocument.string vv_isEnum]) {
                    resultToDocument = resultUntilSemiColon;
                    shouldReplace = YES;
                }
                
                VVDocumenter *doc = [[VVDocumenter alloc] initWithCode:resultToDocument.string];

                //Now we are using a simulation of keyboard event to insert the docs, instead of using the IDE's private method.
                //See more at https://github.com/onevcat/VVDocumenter-Xcode/issues/3

                //Save current content in paste board
                NSPasteboard *pasteBoard = [NSPasteboard generalPasteboard];
                NSString *originPBString = [pasteBoard stringForType:NSPasteboardTypeString];

                //Set the doc comments in it
                [pasteBoard declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:nil];
                [pasteBoard setString:[doc document] forType:NSStringPboardType];
                
                //Begin to simulate keyborad pressing
                VVKeyboardEventSender *kes = [[VVKeyboardEventSender alloc] init];
                [kes beginKeyBoradEvents];
                //Cmd+delete Delete current line
                [kes sendKeyCode:kVK_Delete withModifierCommand:YES alt:NO shift:NO control:NO];
                //if (shouldReplace) [textView setSelectedRange:resultToDocument.range];
                //Cmd+V, paste (If it is Dvorak layout, use '.', which is corresponding the key 'V' in a QWERTY layout)
                NSInteger kKeyVCode = [[VVDocumenterSetting defaultSetting] useDvorakLayout] ? kVK_ANSI_Period : kVK_ANSI_V;
                [kes sendKeyCode:kKeyVCode withModifierCommand:YES alt:NO shift:NO control:NO];
                
                //The key down is just a defined finish signal by me. When we receive this key, we know operation above is finished.
                [kes sendKeyCode:kVK_F20];

                self.eventMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:NSKeyDownMask handler:^NSEvent *(NSEvent *incomingEvent) {
                    if ([incomingEvent type] == NSKeyDown && [incomingEvent keyCode] == kVK_F20) {
                        //Finish signal arrived, no need to observe the event
                        [NSEvent removeMonitor:self.eventMonitor];
                        self.eventMonitor = nil;
                        
                        //Restore previois patse board content
                        [pasteBoard setString:originPBString forType:NSStringPboardType];
                        
                        //Set cursor before the inserted documentation. So we can use tab to begin edit.
                        int baseIndentationLength = (int)[doc baseIndentation].length;
                        [textView setSelectedRange:NSMakeRange(currentLineResult.range.location + baseIndentationLength, 0)];
                        
                        //Send a 'tab' after insert the doc. For our lazy programmers. :)
                        [kes sendKeyCode:kVK_Tab];
                        [kes endKeyBoradEvents];
                        
                        shouldReplace = NO;
                        
                        //Invalidate the finish signal, in case you set it to do some other thing.
                        return nil;
                    } else if ([incomingEvent type] == NSKeyDown && [incomingEvent keyCode] == kKeyVCode && shouldReplace == YES) {
                        //Select input line and the define code block.
                        NSRange r = [textView textResultUntilNextString:@";"].range;
                        
                        //NSRange r begins from the starting of enum(struct) line. Select 1 character before to include the trigger input line.
                        [textView setSelectedRange:NSMakeRange(r.location - 1, r.length + 1)];
                        return incomingEvent;
                    } else {
                        return incomingEvent;
                    }
                }];
            }
        }
    }
}

@end
