//
//  NetAudio.m
//  NetAudio
//
//  Created by Kok Chen on 1/31/08.
//  Copyright 2008 Kok Chen, W7AY. All rights reserved.
//

#import "NetAudio.h"
#include <math.h>

#import "NetAudioStruct.h"
@implementation NetAudio

@synthesize timerThreadLock = _timerThreadLock;
@synthesize timerThread     = _timerThread;
@synthesize tickLock        = _tickLock;
@synthesize runTimer        = _runTimer;
@synthesize netAudioStruct  = _netAudioStruct;


- (id)init
{
	int i ;
	
	self = [ super init ] ;
	if ( self ) {
		_runTimer = nil ;
		_tickLock = [ [ NSLock alloc ] init ] ;
		serviceName = nil ;
	
		channels = 2 ;
		samplingRate = 44100.0 ;		
		[_netAudioStruct setDelegate:nil] ;
		[_netAudioStruct setRunState: kNetAudioIdle] ;
		
		for ( i = 0; i < 512; i++ ) _netAudioStruct.raisedCosine[i] = ( 1 - cos( i*3.1415926535/512.0 ) )*0.5 ;
		_timerThreadLock = [ [ NSConditionLock alloc ] initWithCondition:kWaitForCommand ] ;
		[ NSThread detachNewThreadSelector:@selector(timerThread:) toTarget:self withObject:self ] ;
	}
	return self ;
}

- (id)initWithService:(NSString*)service delegate:(id)inDelegate samplesPerBuffer:(int)size
{
	return nil ;
}

- (void)dealloc
{
	if ( _runTimer ) {
		_netAudioStruct.runState = kNetAudioIdle ;
	}
	[ self freeBuffers ] ;
	//[ super dealloc ] ;
}

//  return YES to quit thread
- (Boolean)runThread
{
	//  override in subclasses to do something.
	return YES ;
}

//  timer thread
- (void)timerThread:(id)ourself
{
	//NSAutoreleasePool *pool = [ [ NSAutoreleasePool alloc ] init ] ;
	
	[ [ NSRunLoop currentRunLoop ] run ] ;
	
	while ( 1 ) {
		[ _timerThreadLock lockWhenCondition:kCommandAvailable ] ;
		[ _timerThreadLock unlockWithCondition:kWaitForCommand ] ;
		if ( [ self runThread ] ) break ;
	}
	//[ pool release ] ;
}

//  set/reset buffer size
- (void)setBufferSize:(int)size
{
	int i, bufSize ;
	
	if ( _runTimer ) {
		//  first, stop any sampling process
		[ _runTimer invalidate ] ;
		_runTimer = nil ;
	}
	samplesPerBuffer = size ;
	bufSize = samplesPerBuffer*sizeof( float ) ;
	bufferList.mNumberBuffers = channels ;
		
	for ( i = 0; i < channels; i++ ) {
		if ( dataBuffer[i] ) free( dataBuffer[i] ) ;
		dataBuffer[i] = ( float* )malloc( bufSize ) ;		
		audioBuffer[i].mData = dataBuffer[i] ;
		audioBuffer[i].mNumberChannels = 1 ;
		audioBuffer[i].mDataByteSize = bufSize ;
		bufferList.mBuffers[i] = audioBuffer[i] ;
	}
}

- (void)freeBuffers
{
	int i ;	
	for ( i = 0; i < channels; i++ ) if ( dataBuffer[i] ) free( dataBuffer[i] ) ;
}

- (void)setDelegate:(id)inDelegate
{
	_netAudioStruct.delegate = inDelegate ;
}

- (id)delegate
{
	return _netAudioStruct.delegate ;
}

- (Boolean)setServiceName:(NSString*)name
{
	return NO ;
}

- (NSString*)serviceName
{
	return serviceName ;
}

- (Boolean)setPassword:(NSString*)password
{
	return NO ;
}

- (Boolean)isNetReceive
{
	return isReceive ;
}

@end
