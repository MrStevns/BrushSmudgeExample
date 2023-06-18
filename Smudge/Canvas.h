//
//  Canvas.h
//  Smudge
//
//  Created by Andy Finnell on 9/2/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class Smudge;

@interface Canvas : NSObject {	
	// Because we want to be able to both draw into the canvas as well as use 
	//	it as a brush, back the canvas as a CGLayerRef. Also, CGLayeRef's
	//	give better performance when stamping.
	CGLayerRef			mLayer;
}

	// Resize the canvas to the size of the image and render the image onto the canvas
- (void) setImage:(NSImage *)image view:(NSView *)view;

	// Draws the contents of the canvas into the specified context. Handy for views
	//	that host a canvas.
- (void)drawRect:(NSRect)rect inContext:(NSGraphicsContext*)context;

	// Graphics privimites for the canvas. The first draws a line given the brush
	//	and the second draws a point given the brush.
- (float)stamp:(Smudge *)brush from:(NSPoint)startPoint to:(NSPoint)endPoint leftOverDistance:(float)leftOverDistance;
- (void)stamp:(Smudge *)brush at:(NSPoint)point;

@end
