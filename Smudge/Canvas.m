//
//  Canvas.m
//  Smudge
//
//  Created by Andy Finnell on 9/2/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "Canvas.h"
#import "Smudge.h"

@implementation Canvas

- (void) dealloc
{
	// Just free up our layer
	CGLayerRelease(mLayer);
}

- (void) setImage:(NSImage *)image view:(NSView *)view
{
	// First free up the previous layer, in case the new one is a new size
	CGLayerRelease(mLayer);
	mLayer = nil;
	
	// Next, create a new layer the size of the image. For performance reasons,
	//	we want to base our layer off of the window context.
	NSGraphicsContext* windowContext = [NSGraphicsContext graphicsContextWithWindow:[view window]];
	CGContextRef context = [windowContext graphicsPort];
	
	NSSize size = [image size];
	mLayer = CGLayerCreateWithContext(context, CGSizeMake(size.width, size.height), nil);
	
	// Pull out the NSGraphicsContext from the layer and focus it so we can
	//	use Cocoa class to draw into it.
	CGContextRef cgLayerContext = CGLayerGetContext(mLayer);
	NSGraphicsContext* layerContext = [NSGraphicsContext graphicsContextWithGraphicsPort:cgLayerContext flipped:YES];

	[NSGraphicsContext saveGraphicsState];
	[NSGraphicsContext setCurrentContext:layerContext];
	
	// Some images might have transparency, so fill the background with an opaque
	//	white. Real apps would probably do a checkerboard pattern.
	[[NSColor whiteColor] set];
	[NSBezierPath fillRect:NSMakeRect(0, 0, size.width, size.height)];
	
	// Draw the image, with no scaling
	[image drawAtPoint:NSMakePoint(0, 0) fromRect:NSMakeRect(0, 0, size.width, size.height) operation:NSCompositeSourceOver fraction:1.0];
	
	[NSGraphicsContext restoreGraphicsState];
}

- (void)drawRect:(NSRect)rect inContext:(NSGraphicsContext*)context
{	
	if ( mLayer == nil )
		return;
	
	// Very straight forward: just draw our layer in the given context at 0, 0
	CGContextRef cgContext = [context graphicsPort];
	CGContextDrawLayerAtPoint(cgContext, CGPointMake(0, 0), mLayer);
}

- (float)stamp:(Smudge *)brush from:(NSPoint)startPoint to:(NSPoint)endPoint leftOverDistance:(float)leftOverDistance
{
	// Set the spacing between the stamps. 
	float spacing = [brush spacing]; // Ask the brush
	
	// Anything less that half a pixel is overkill and could hurt performance.
	if ( spacing < 0.5 )
		spacing = 0.5;
	
	// Determine the delta of the x and y. This will determine the slope
	//	of the line we want to draw.
	float deltaX = endPoint.x - startPoint.x;
	float deltaY = endPoint.y - startPoint.y;
	
	// Normalize the delta vector we just computed, and that becomes our step increment
	//	for drawing our line, since the distance of a normalized vector is always 1
	float distance = sqrt( deltaX * deltaX + deltaY * deltaY );
	float stepX = 0.0;
	float stepY = 0.0;
	if ( distance > 0.0 ) {
		float invertDistance = 1.0 / distance;
		stepX = deltaX * invertDistance;
		stepY = deltaY * invertDistance;
	}
	
	float offsetX = 0.0;
	float offsetY = 0.0;
	
	// We're careful to only stamp at the specified interval, so its possible
	//	that we have the last part of the previous line left to draw. Be sure
	//	to add that into the total distance we have to draw.
	float totalDistance = leftOverDistance + distance;
	
	// While we still have distance to cover, stamp
	while ( totalDistance >= spacing ) {
		// Increment where we put the stamp
		if ( leftOverDistance > 0 ) {
			// If we're making up distance we didn't cover the last
			//	time we drew a line, take that into account when calculating
			//	the offset. leftOverDistance is always < spacing.
			offsetX += stepX * (spacing - leftOverDistance);
			offsetY += stepY * (spacing - leftOverDistance);
			
			leftOverDistance -= spacing;
		} else {
			// The normal case. The offset increment is the normalized vector
			//	times the spacing
			offsetX += stepX * spacing;
			offsetY += stepY * spacing;
		}
		
		// Calculate where to put the current stamp at.
		NSPoint stampAt = NSMakePoint(startPoint.x + offsetX, startPoint.y + offsetY);
		
		// Ka-chunk! Draw the image at the current location
		[self stamp:brush at: stampAt];
		
		// Remove the distance we just covered
		totalDistance -= spacing;
	}
	
	// Return the distance that we didn't get to cover when drawing the line.
	//	It is going to be less than spacing.
	return totalDistance;	
}

- (void)stamp:(Smudge *)brush at:(NSPoint)point
{
	// Just pass through to the brush to ask it to render. Give it the layer
	//	that backs the canvas, and the point to render at.
	[brush render:mLayer at:point];
}

@end
