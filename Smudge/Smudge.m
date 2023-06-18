//
//  Smudge.m
//  Smudge
//
//  Created by Andy Finnell on 9/2/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "Smudge.h"
#import "Canvas.h"

@interface Smudge (Private)

- (NSPoint) canvasLocation:(NSEvent *)theEvent view:(NSView *)view;
- (void) stampStart:(NSPoint)startPoint end:(NSPoint)endPoint inView:(NSView *)view onCanvas:(Canvas *)canvas;

- (CGContextRef) createBitmapContext;
- (void) disposeBitmapContext:(CGContextRef)bitmapContext;
- (CGImageRef) createShapeImage;

@end

@implementation Smudge

- (id) init
{
	self = [super init];
	
	if ( self ) {
		// Set the size of the brush. A radius of 10 means a 20 pixel wide brush
		mRadius = 10.0;
		
		// Create the shape of the tip of the brush. Code currently assumes the bounding
		//	box of the shape is square (height == width)
		mShape = CGPathCreateMutable();
		CGPathAddEllipseInRect(mShape, nil, CGRectMake(0, 0, 2 * mRadius, 2 * mRadius));
		//CGPathAddRect(mShape, nil, CGRectMake(0, 0, 2 * mRadius, 2 * mRadius));

		// Set the initial smudge color, that starts out on the brush. May be nil, 
		//	if you don't want a smudge color.
#if 1
		mColor = nil;
#else
		CGColorSpaceRef colorspace = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);
		float components[] = { 0.0, 0.0, 1.0, 1.0 }; // I like blue
		mColor = CGColorCreate(colorspace, components);
		CGColorSpaceRelease(colorspace);
#endif
		
		// The "softness" of the brush edges
		mSoftness = 0.5;
		
		// The pressure at which to smudge. The more pressure, the more of a smudge
		//	will result.
		mPressure = 0.5;
		
		// Initialize variables that will be used during tracking
		mMask = nil;
		mLastPoint = NSZeroPoint;
		mLeftOverDistance = 0.0;
		mLastRenderPoint = NSZeroPoint;
	}
	
	return self;
}

- (void) dealloc
{
	// Clean up our shape and color
	CGPathRelease(mShape);
	CGColorRelease(mColor);
	
//	[super dealloc];
}

- (void) mouseDown:(NSEvent *)theEvent inView:(NSView *)view onCanvas:(Canvas *)canvas
{
	// Translate the event point location into a canvas point
	NSPoint currentPoint = [self canvasLocation:theEvent view:view];
	
	// Initialize all the tracking information. This includes creating an image
	//	of the brush tip
	mMask = [self createShapeImage];
	mLastPoint = currentPoint;
	mLeftOverDistance = 0.0;
	mLastRenderPoint = NSZeroPoint;

	// Since this is a mouse down, we want to stamp the brush's image not matter
	//	what.
	[canvas stamp:self at:currentPoint];
	
	// This isn't very efficient, but we need to tell the view to redraw. A better
	//	version would have the canvas itself to generate an invalidate for the view
	//	(since it knows exactly where the bits changed).
	[view setNeedsDisplay:YES];
}

- (void) mouseDragged:(NSEvent *)theEvent inView:(NSView *)view onCanvas:(Canvas *)canvas
{
	// Translate the event point location into a canvas point
	NSPoint currentPoint = [self canvasLocation:theEvent view:view];
	
	// Stamp the brush in a line, from the last mouse location to the current one
	[self stampStart:mLastPoint end:currentPoint inView:view onCanvas:canvas];
	
	// Remember the current point, so that next time we know where to start
	//	the line
	mLastPoint = currentPoint;
}

- (void) mouseUp:(NSEvent *)theEvent inView:(NSView *)view onCanvas:(Canvas *)canvas
{
	// Translate the event point location into a canvas point
	NSPoint currentPoint = [self canvasLocation:theEvent view:view];
	
	// Stamp the brush in a line, from the last mouse location to the current one
	[self stampStart:mLastPoint end:currentPoint inView:view onCanvas:canvas];
	
	// This is a mouse up, so we are done tracking. Use this opportunity to clean
	//	up all the tracking information, including the brush tip image.
	CGImageRelease(mMask);
	mMask = nil;
	mLastPoint = NSZeroPoint;
	mLeftOverDistance = 0.0;
	mLastRenderPoint = NSZeroPoint;
}

- (float) spacing
{
	// Smudge has to be spaced by 1 pixel or we get jaggies
	return 1.0;
}

- (void) render:(CGLayerRef)canvas at:(NSPoint)point
{
	// Grab the context for the canvas. No matter what, we're going to determine
	//	where the current brush stamp should go, then translate the context
	//	to that position.
	CGContextRef canvasContext = CGLayerGetContext(canvas);
	CGContextSaveGState(canvasContext);
	
	// So we can position the image correct, compute where the bottom left
	//	of the image should go, and modify the CTM so that 0, 0 is there.
	CGPoint bottomLeft = CGPointMake( point.x - CGImageGetWidth(mMask) * 0.5,
									  point.y - CGImageGetHeight(mMask) * 0.5 );
	CGContextTranslateCTM(canvasContext, bottomLeft.x, bottomLeft.y);
	
	// Our brush has a shape and soft edges. These are replicated by using our
	//	brush tip as a mask to clip to. No matter what we render after this,
	//	it will be in the proper shape of our brush.
	CGContextClipToMask(canvasContext, CGRectMake(0, 0, CGImageGetWidth(mMask), CGImageGetHeight(mMask)), mMask);

	// The pressure of the smudge is a one to one correspondance with the amount
	//	transparency of the brush stamp.
	CGContextSetAlpha(canvasContext, mPressure);
	
	// If this is our first stamp, then we normally don't want to lay down any
	//	ink. That's because if we're smudging with a clean brush, we don't have
	//	any ink on the brush to lay down. Only after the initial stamp will we
	//	have the ink from the canvas to lay down.
	if ( !NSEqualPoints(mLastRenderPoint, NSZeroPoint) ) {
		// Based on the last render point that we keep track of, determine the
		//	source bounds.
		CGPoint sourceBottomLeft = CGPointMake( mLastRenderPoint.x - CGImageGetWidth(mMask) * 0.5,
												mLastRenderPoint.y - CGImageGetHeight(mMask) * 0.5 );		
		
		// We pull straight from the canvas, and render directly onto the canvas. CGLayerRefs
		//	make this easy.
		CGContextDrawLayerAtPoint(canvasContext, CGPointMake(-sourceBottomLeft.x, -sourceBottomLeft.y), canvas);
	} else if ( mColor ) {
		// If this is our first stamp, and we have an initial color specified (i.e. the brush
		//	was dirty), we have to render the brush with that color only on the first
		//	stamp. The initial color might be carried to other pixels depending on
		//	how strong the pressure is.
		CGContextSetFillColorWithColor(canvasContext, mColor);
		CGContextFillRect(canvasContext, CGRectMake(0, 0, CGImageGetWidth(mMask), CGImageGetHeight(mMask)));
	}
	
	CGContextRestoreGState(canvasContext);

	// Remember our last render point, so we know where to pull from
	mLastRenderPoint = point;
}

@end

@implementation Smudge (Private)

- (NSPoint) canvasLocation:(NSEvent *)theEvent view:(NSView *)view
{
	// Currently we assume that the NSView here is a CanvasView, which means
	//	that the view is not scaled or offset. i.e. There is a one to one
	//	correlation between the view coordinates and the canvas coordinates.
	NSPoint eventLocation = [theEvent locationInWindow];
	return [view convertPoint:eventLocation fromView:nil];
}

- (void) stampStart:(NSPoint)startPoint end:(NSPoint)endPoint inView:(NSView *)view onCanvas:(Canvas *)canvas
{
	// We need to ask the canvas to draw a line using the brush. Keep track
	//	of the distance left over that we didn't draw this time (so we draw
	//	it next time).
	mLeftOverDistance = [canvas stamp:self from:startPoint to:endPoint leftOverDistance:mLeftOverDistance];
	
	// This isn't very efficient, but we need to tell the view to redraw. A better
	//	version would have the canvas itself to generate an invalidate for the view
	//	(since it knows exactly where the bits changed).	
	[view setNeedsDisplay:YES];
}

- (CGContextRef) createBitmapContext
{
	// Create the offscreen bitmap context that we can draw the brush tip into.
	//	The context should be the size of the shape bounding box.
	CGRect boundingBox = CGPathGetBoundingBox(mShape);
	
	size_t width = CGRectGetWidth(boundingBox);
	size_t height = CGRectGetHeight(boundingBox);
	size_t bitsPerComponent = 8;
	size_t bytesPerRow = (width + 0x0000000F) & ~0x0000000F; // 16 byte aligned is good
	size_t dataSize = bytesPerRow * height;
	void* data = calloc(1, dataSize);
	CGColorSpaceRef colorspace = CGColorSpaceCreateWithName(kCGColorSpaceGenericGray);
	
	CGContextRef bitmapContext = CGBitmapContextCreate(data, width, height, bitsPerComponent,
													   bytesPerRow, colorspace, 
													   kCGImageAlphaNone);
	
	CGColorSpaceRelease(colorspace);
	
	CGContextSetGrayFillColor(bitmapContext, 0.0, 1.0);
	CGContextFillRect(bitmapContext, CGRectMake(0, 0, width, height));
	
	return bitmapContext;
}

- (void) disposeBitmapContext:(CGContextRef)bitmapContext
{
	// Free up the offscreen bitmap
	void * data = CGBitmapContextGetData(bitmapContext);
	CGContextRelease(bitmapContext);
	free(data);	
}

- (CGImageRef) createShapeImage
{
	// Create a bitmap context to hold our brush image
	CGContextRef bitmapContext = [self createBitmapContext];
	
	CGContextSetGrayFillColor(bitmapContext, 1.0, 1.0);
	
	// The way we acheive "softness" on the edges of the brush is to draw
	//	the shape full size with some transparency, then keep drawing the shape
	//	at smaller sizes with the same transparency level. Thus, the center
	//	builds up and is darker, while edges remain partially transparent.
	
	// First, based on the softness setting, determine the radius of the fully
	//	opaque pixels.
	int innerRadius = (int)ceil(mSoftness * (0.5 - mRadius) + mRadius);
	int outerRadius = (int)ceil(mRadius);
	int i = 0;
	
	// The alpha level is always proportial to the difference between the inner, opaque
	//	radius and the outer, transparent radius.
	float alphaStep = 1.0 / (outerRadius - innerRadius + 1);
	
	// Since we're drawing shape on top of shape, we only need to set the alpha once
	CGContextSetAlpha(bitmapContext, alphaStep);
	
	for (i = outerRadius; i >= innerRadius; --i) {
		CGContextSaveGState(bitmapContext);
		
		// First, center the shape onto the context.
		CGContextTranslateCTM(bitmapContext, outerRadius - i, outerRadius - i);
		
		// Second, scale the the brush shape, such that each successive iteration
		//	is two pixels smaller in width and height than the previous iteration.
		float scale = (2.0 * (float)i) / (2.0 * (float)outerRadius);
		CGContextScaleCTM(bitmapContext, scale, scale);
		
		// Finally, actually add the path and fill it
		CGContextAddPath(bitmapContext, mShape);
		CGContextEOFillPath(bitmapContext);
		
		CGContextRestoreGState(bitmapContext);
	}
	
	// Create the brush tip image from our bitmap context
	CGImageRef image = CGBitmapContextCreateImage(bitmapContext);
	
	// Free up the offscreen bitmap
	[self disposeBitmapContext:bitmapContext];
	
	return image;
}

@end
