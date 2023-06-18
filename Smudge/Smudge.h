//
//  Smudge.h
//  Smudge
//
//  Created by Andy Finnell on 9/2/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class Canvas;

@interface Smudge : NSObject {
	// Information about the brush that's always used
	float				mRadius;
	CGMutablePathRef	mShape;
	float				mSoftness; // 0.0 - 1.0, 0.0 being hard, 1.0 be all soft
	float				mPressure; // 0.0 - 1.0, 0.0 being not smudging at all, 1.0 smudges a lot
	CGColorRef			mColor;	// The initial color on the brush. Can be nil, if you don't want a color
	
	// Cached information that's only used when actually tracking/drawing
	CGImageRef			mMask;
	NSPoint				mLastPoint;
	float				mLeftOverDistance;
	NSPoint				mLastRenderPoint; // The last point we rendered at, so we know where to pull pixels from.
}

// Mouse events to respond to
- (void) mouseDown:(NSEvent *)theEvent inView:(NSView *)view onCanvas:(Canvas *)canvas;
- (void) mouseDragged:(NSEvent *)theEvent inView:(NSView *)view onCanvas:(Canvas *)canvas;
- (void) mouseUp:(NSEvent *)theEvent inView:(NSView *)view onCanvas:(Canvas *)canvas;

// Callbacks from Canvas to know how to render lines
- (float) spacing;
- (void) render:(CGLayerRef)canvas at:(NSPoint)point;

@end
