//
//  CanvasView.m
//  Smudge
//
//  Created by Andy Finnell on 9/2/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "CanvasView.h"
#import "Canvas.h"
#import "Smudge.h"


@implementation CanvasView

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        // Create both the canvas and the smudge tool. Create the canvas
		//	the same size as our initial size. Note that the canvas will not
		//	resize along with us.
		mCanvas = [[Canvas alloc] init];
		mSmudge = [[Smudge alloc] init];
    }
    return self;
}

- (void) setImage:(NSImage *)image
{
	// Give the canvas the image and view. This will cause the canvas to be
	//	resized and render the image.
	[mCanvas setImage:image view:self];
	
	// Resize this view so that we're the same as the image (and canvas)
	[self setFrameSize: [image size]];
	
	// We just changed what we the canvas draws, so invalidate the entire view
	[self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)rect {
	// Simply ask the canvas to draw into the current context, given the
	//	rectangle specified. A more sophisticated view might draw a border
	//	around the canvas, or a pasteboard in the case that the view was
	//	bigger than the canvas.
	NSGraphicsContext* context = [NSGraphicsContext currentContext];
	
	[mCanvas drawRect:rect inContext:context];	
}

- (void)mouseDown:(NSEvent *)theEvent
{
	// Simply pass the mouse event to the smudge tool. Also give it the canvas to
	//	work on, and a reference to ourselves, so it can translate the mouse
	//	locations.
	[mSmudge mouseDown:theEvent inView:self onCanvas:mCanvas];
}

- (void)mouseDragged:(NSEvent *)theEvent
{
	// Simply pass the mouse event to the smudge tool. Also give it the canvas to
	//	work on, and a reference to ourselves, so it can translate the mouse
	//	locations.	
	[mSmudge mouseDragged:theEvent inView:self onCanvas:mCanvas];
}

- (void)mouseUp:(NSEvent *)theEvent
{
	// Simply pass the mouse event to the smudge tool. Also give it the canvas to
	//	work on, and a reference to ourselves, so it can translate the mouse
	//	locations.	
	[mSmudge mouseUp:theEvent inView:self onCanvas:mCanvas];
}

@end
