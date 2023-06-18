//
//  CanvasView.h
//  Smudge
//
//  Created by Andy Finnell on 9/2/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class Canvas;
@class Smudge;

@interface CanvasView : NSView {
	// The canvas we will render to the screen
	Canvas		*mCanvas;
	// The smudge tool we will pass mouse events to
	Smudge		*mSmudge;	
}

- (void) setImage:(NSImage *)image;

@end
