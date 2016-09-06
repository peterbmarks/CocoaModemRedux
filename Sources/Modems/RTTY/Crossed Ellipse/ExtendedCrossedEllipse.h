//
//  ExtendedCrossedEllipse.h
//  cocoaModem
//
//  Created by Kok Chen on 8/20/05.
//

#ifndef _EXTENDEDCROSSEDELLIPSE_H_
	#define _EXTENDEDCROSSEDELLIPSE_H_

	#import <Cocoa/Cocoa.h>
	#include "CrossedEllipse.h"



	@interface ExtendedCrossedEllipse : CrossedEllipse {
		CMFFT *spectrum ;
	//	NSColor *fskColor ;
	//	NSBezierPath *fsk ;
		
		float freq[2048], avgfreq[128] ;
		UInt32 intensity[256], intensityFade[256] ;
       // dispatch_source_t g_timer1,g_timer2;
       // bool  okToDraw;
        //GraphBlock gBlock;
	}

    @property (retain)  NSColor *fskColor;
    @property (retain)  NSBezierPath *fsk;
    @property (retain)  NSLock *lock;
	@end

#endif
