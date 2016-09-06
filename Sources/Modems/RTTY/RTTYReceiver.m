//
//  RTTYReceiver.m
//  cocoaModem
//
//  Created by Kok Chen on 1/17/05.
#include "Copyright.h"
//

#import "RTTYReceiver.h"
#import "Application.h"
#import "ExchangeView.h"
#import "Modem.h"
#import "Module.h"
#import "RTTYAuralMonitor.h"
#import "RTTYDemodulator.h"
#import "RTTYSingleFilter.h"
#import "RTTYMPFilter.h"
#import "RTTYRxControl.h"
#import "cocoaModemParams.h"

#define notOLDDEMOD

@implementation RTTYReceiver

@synthesize clickBufferLock  = _clickBufferLock;
@synthesize n_newData        = _n_newData;
@synthesize bandwidthMatrix  = _bandwidthMatrix;
@synthesize demodulatorModeMatrix = _demodulatorModeMatrix;
@synthesize squelch          = _squelch;
@synthesize rttyAuralMonitor = _rttyAuralMonitor;
@synthesize clickBuffer      = _clickBuffer;





//  This is the cocoaModem wrapper around CoreModem's RTTYDemodulator.
//  It provides a bank of bandpass filters and a bank of match/ed filters.
//  Characters that are received from CMBaudotDecoder are displayed on a TextView.

- (id)initSuperReceiver:(int)index
{
	return [ super init ] ;
}

- (id)initReceiver:(int)index modem:(Modem*)modem
{
    NSLog(@"init RTTY Receiver");
	CMTonePair defaultTones = { 2125.0, 2295.0, 45.45 } ;
	
	self = [ super init ] ;
	if ( self ) {
        thisReceiveThread = FALSE;
		uniqueID = index ;
		app = [ modem application ] ;		//  v0.96d
		receiveView = nil ;
		_squelch = nil ;
		currentTonePair = defaultTones ;
		enabled = slashZero = sidebandState = NO ;
		_demodulatorModeMatrix = nil ;
		_bandwidthMatrix = nil ;
		appleScript = nil ;
		usos = YES ;
		clickBufferActive = NO ;							//  v0.88
		_clickBuffer = nil;
		//  local CMDataStream
		cmData.samplingRate = 11025.0 ;
		cmData.samples = 512 ;
		cmData.components = 1 ;
		cmData.channels = 1 ;
        self.data = &cmData;
		_n_newData = [ [ NSConditionLock alloc ] initWithCondition:kNoData ] ;
		//[ NSThread detachNewThreadSelector:@selector(receiveThread:) toTarget:self withObject:self ] ;
        [self receiveThread];
		_clickBufferLock = nil ;
		_rttyAuralMonitor = [ [ RTTYAuralMonitor alloc ] init ] ;
		
#ifdef OLDDEMOD
		demodulator = [ [ CMFSKDemodulator alloc ] initFromReceiver:self ] ;		// v0.32
#else
		demodulator = [ [ RTTYDemodulator alloc ] initFromReceiver:self ] ;			// v0.52, v0.68
#endif
		
		bandpassFilter = [ [ CMFilterBank alloc ] init ] ;
		matchedFilter = [ [ CMFilterBank alloc ] init ] ;
		
		// create bandpass filter bank
		bpf[0] = [ demodulator makeFilter:238.18 ] ;		//  v0.83, was 240
		bpf[1] = [ demodulator makeFilter:306.35 ] ;		//  was 340
		bpf[2] = [ demodulator makeFilter:442.70 ] ;		//  was 480
		bpf[3] = [ demodulator makeFilter:579.05 ] ;		//  was 580
		bpf[4] = [ demodulator makeFilter:1000.0 ] ;
		[ bandpassFilter installFilter:bpf[0] ] ;
		[ bandpassFilter installFilter:bpf[1] ] ;
		[ bandpassFilter installFilter:bpf[2] ] ;
		[ bandpassFilter installFilter:bpf[3] ] ;
		[ bandpassFilter installFilter:bpf[4] ] ;
		[ bandpassFilter selectFilter:1 ] ;
		[ demodulator useBandpassFilter:bandpassFilter ] ;
		
		//  create matched filter bank
		[ matchedFilter installFilter:[ [ RTTYSingleFilter alloc ] initTone:0 baud:45.45 ] ] ;					//  Mark-only
		[ matchedFilter installFilter:[ [ RTTYSingleFilter alloc ] initTone:1 baud:45.45 ] ] ;					//  Space-only
		[ matchedFilter installFilter:[ [ RTTYMPFilter alloc ] initBitWidth:0.35 baud:45.45 ] ] ;				//  MP+
		[ matchedFilter installFilter:[ [ RTTYMPFilter alloc ] initBitWidth:0.70 baud:45.45 ] ] ;				//  MP-
		[ matchedFilter installFilter:[ [ RTTYMatchedFilter alloc ] initDefaultFilterWithBaudRate:45.45 ] ] ;		//  MS		v0.32
        
		[ matchedFilter selectFilter:4 ] ;
		[ demodulator useMatchedFilter:matchedFilter ] ;
        
		return self ;
	}
	return nil ;
}

//  v0.68
- (void)setPrintControl:(Boolean)state
{
	[ (RTTYDemodulator*)demodulator setPrintControl:state ] ;
}

//  0.78
//- (RTTYAuralMonitor*)rttyAuralMonitor
//{
//	return rttyAuralMonitor ;
//}

//  update views when receiver is moved inside the window
- (void)updateInterface
{
}

- (CMTappedPipe*)baudotPipe
{
	return (CMTappedPipe*)[ demodulator baudotWaveform ] ;
}

- (CMTappedPipe*)atcPipe
{
	return (CMTappedPipe*)[ demodulator atcWaveform ] ;
}

- (CMTappedPipe*)demodBufferPipe
{
	return (CMTappedPipe*)demodulator ;
}

- (CMTappedPipe*)bpfBufferPipe
{
	return (CMTappedPipe*)bandpassFilter ;
}

- (void)registerModule:(Module*)module
{
	appleScript = module ;
}

- (CMFSKDemodulator*)demodulator
{
	return demodulator ;
}

//  set up filter cutoffs given current mark and space frequencies
- (void)setFilterCutoffs:(CMTonePair*)tonepair
{
	float low, high, bw ;
	
	if ( tonepair->space < tonepair->mark ) {
		low = tonepair->space ;
		high = tonepair->mark ;
	}
	else {
		low = tonepair->mark ;
		high = tonepair->space ;
	}
	bw = tonepair->baud/45.45 ;		// bandwidth relative to 45.5 baud receiver
	
	[ bpf[0] updateLowCutoff:low-(1.5*45.45/2)*bw highCutoff:high+(1.5*45.45/2)*bw ] ;	//  v0.83 changed from 35
	[ bpf[1] updateLowCutoff:low-(3*45.45/2)*bw highCutoff:high+(3*45.45/2)*bw ] ;		//  v0.83 changed from 85.5
	[ bpf[2] updateLowCutoff:low-(6*45.45/2)*bw highCutoff:high+(6*45.45/2)*bw ] ;		//  v0.83 changed from 155
	[ bpf[3] updateLowCutoff:low-(9*45.45/2)*bw highCutoff:high+(9*45.45/2)*bw ] ;		//  v0.83 changed from 205
}

- (void)setupReceiverChain:(ModemConfig*)config
{
	[ demodulator setConfig:config ] ;						//  v0.88d
	[ demodulator setupDemodulatorChain ] ;
	[ demodulator useBandpassFilter:bandpassFilter ] ;
	[ demodulator useMatchedFilter:matchedFilter ] ;
	[ demodulator setDelegate:self ] ;						//  demodulator calls back to receivedCharacter: delegate
}

- (void)createClickBuffer
{
	int i ;
	
	clickBufferProducer = clickBufferConsumer = 0 ;		//  buffer number (512 samples per buffer)
	_clickBufferLock = [ [ NSLock alloc ] init ] ;
    
    _clickBuffer = (float**)malloc(512*sizeof(float*));
	for ( i = 0; i < 512; i++ ) {
		// 1 MB buffer, for 262,144 floating point samples (23.77 seconds)
		_clickBuffer[i] = (float*)malloc( 512*sizeof( float ) ) ;
	}
}

//	v0.89
- (void)clearClickBuffer
{
	if ( _clickBuffer != nil  && _clickBufferLock != nil) {
        [ _clickBufferLock lock ];
        clickBufferProducer = clickBufferConsumer = 0 ;
        if ( clickBufferActive == YES ) {
            clickBufferActive = NO ;
            [ _rttyAuralMonitor clickBufferCleared ] ;
        }
        [ _clickBufferLock unlock ] ;
    }
}

- (void)receiveThread
{
	//NSAutoreleasePool *pool = [ [ NSAutoreleasePool alloc ] init ] ;
	//int i ;
    
	//[ NSThread setThreadPriority:[ NSThread threadPriority ]*0.95 ] ;			//  lower thread priority of demodulator
	
    if(thisReceiveThread)return;
    
    
    if(_RTTYreceiveQueue == nil) _RTTYreceiveQueue = dispatch_queue_create("com.owlhousetoys.RTTYReceiveQueue", DISPATCH_QUEUE_CONCURRENT);
    dispatch_async(_RTTYreceiveQueue, [ ^(void) {
        
        @autoreleasepool {
            
            thisReceiveThread = TRUE;
            
            
            while ( 1 ) {
                // block here waiting for data
                [ _n_newData lockWhenCondition:kHasData ] ;
                if ( enabled ) {
                    //  copy the stream info but use the buffered data, and set the pointer to the click buffer
                    //  process 8 click buffers as fast as possible until the stream has caught up
                    for (int i = 0; i < 8; i++ ) {
                        if ( clickBufferConsumer == clickBufferProducer ) {
                            //  mute auralMonitor while click buffer is active
                            if ( clickBufferActive == YES ) {
                                clickBufferActive = NO ;
                                [ _rttyAuralMonitor setClickBufferActive: NO ] ;
                            }
                            break ;
                        }
                        //  push out unprocessed data
                        cmData.array = _clickBuffer[clickBufferConsumer] ;
                        //if(cmData.array[54] == 0.0) NSLog(@"empty cmData");
                        clickBufferConsumer = ( clickBufferConsumer+1 ) & 0x1ff ; // wrap around 512 buffer pointers
                        [ _rttyAuralMonitor setClickBufferResampling: ( clickBufferActive && ( i == 0 ) ) ] ;
                        
                        if(demodulator != nil)[ demodulator importData:self ] ;
                    }
                    
                }
                usleep(10000);
                [ _n_newData unlockWithCondition:kNoData ] ;
            }
            
            
            thisReceiveThread = FALSE;
        }
    } copy]);
	//[ pool release ] ;
}

- (void)setIgnoreNewline:(Boolean)state
{
	[ receiveView setIgnoreNewline:state ] ;
}

- (void)importData:(CMPipe*)pipe
{
	CMDataStream *stream ;
    float *array, *buf ;
    
    
    //   dispatch_async(_RTTYreceiveQueue,  ^(void) {
    //  check if we have a click buffer by looking to see if a lock exists
    //  some sub classes of RTTYReceiver don't have click buffers
	if ( _clickBufferLock != nil ) {
		if ( [ _clickBufferLock tryLock ] ) {
			[ _n_newData lockWhenCondition:kNoData ] ;
			//  copy data into tail of clickBuffer
			stream = [ pipe stream ] ;
			array = stream->array ;
			//  copy another 512 samples into the click buffer (memcpy has problems with auto release pools?)
			buf = _clickBuffer[clickBufferProducer] ;
			clickBufferProducer = ( clickBufferProducer+1 ) & 0x1ff ; // 512 click buffers
			memcpy( buf, array, 512*sizeof( float ) ) ;
			//  run the receive thread
			cmData.userData = stream->userData ;
			cmData.sourceID = stream->sourceID ;
			// signal receiveThread of new block of data that new data has arrived
			[ _n_newData unlockWithCondition:kHasData ] ;
			[ _clickBufferLock unlock ] ;
		}
	}
	else {
		//  no click buffer -- simply use input stream
		[ demodulator importData:pipe ] ;
	}
}


//  each audio stream is 512 samples in size
//  there are 512 of these buffers in the click buffer, or 23.77 seconds worth
- (void)clicked:(float)history
{
	if ( !_clickBuffer ) return ;
	
	if ( history < 0.1 ) history = 0.1 ;
	if ( history > 20.0 ) history = 20.0 ;
    
	
    [_clickBufferLock lock];
    clickBufferConsumer = clickBufferProducer + ( 512 - (int)( 21.5*history ) ) ;
    
    //  v0.88 mute aural monitor
    clickBufferActive = YES ;
    [ _rttyAuralMonitor setClickBufferActive: YES ] ;
    
    clickBufferConsumer = clickBufferConsumer & 0x1ff ; // wrap around a 256K sample (512*512 samples) floating point buffer
    [ _clickBufferLock unlock ] ;
    
}

- (void)enableReceiver:(Boolean)state
{
	enabled = state ;
}

- (void)setSlashZero:(Boolean)state
{
	slashZero = state ;
}

- (void)setUSOS:(Boolean)state
{
	usos = state ;
	[ demodulator setUSOS:state ] ;
}

- (void)setBell:(Boolean)state
{
	[ demodulator setBell:state ] ;
}

//- (void)setBandwidthMatrix:(NSMatrix*)matrix
//{
//	_bandwidthMatrix = matrix ;
//}
//
//- (void)setDemodulatorModeMatrix:(NSMatrix*)matrix
//{
//	_demodulatorModeMatrix = matrix ;
//}

- (void)setReceiveView:(ExchangeView*)view
{
	receiveView = view ;
}

//  select a Demodulator as the client of the Mixer
- (void)selectDemodulator:(int)index
{
	if ( _demodulatorModeMatrix ) {
		[ _demodulatorModeMatrix deselectAllCells ] ;
		[ _demodulatorModeMatrix selectCellAtRow:0 column:index ] ;
		if ( index < 0 || index > 4 ) index = 4 ;
	}
	else index = 4 ;  //  mask space demodulator
	
	[ matchedFilter selectFilter:index ] ;
	
	//  send equalizer parameters
	switch ( index ) {
        case 2:
            [ demodulator setEqualizer:2 ] ;
            break ;
        case 3:
            [ demodulator setEqualizer:1 ] ;
            break ;
        default:
            [ demodulator setEqualizer:0 ] ;
            break ;
	}
}

//  select an input BPF
- (void)selectBandwidth:(int)index
{
	if ( _bandwidthMatrix ) {
		[ _bandwidthMatrix deselectAllCells ] ;
		[ _bandwidthMatrix selectCellAtRow:0 column:index ] ;
		if ( index < 0 || index > 4 ) index = 1 ;
		[ bandpassFilter selectFilter:index ] ;
		return ;
	}
	[ bandpassFilter selectFilter:1 ] ;	// "normal" filter
}

//  --- squelch -----
//- (void)setSquelch:(NSSlider*)slider
//{
//	squelch = slider ;
//}

- (void)setSquelchValue:(float)value
{
	if ( _squelch ) {
		[ _squelch setFloatValue:value ] ;
		[ demodulator setSquelch:value ] ;
	}
}

- (void)newSquelchValue:(float)value
{
	[ demodulator setSquelch:value ] ;
}

- (float)squelchValue
{
	float value = 0.1 ;
    
	if ( _squelch ) value = [ _squelch floatValue ] ;
	return value ;
}

- (void)makeReceiverActive:(Boolean)state
{
	[ demodulator makeDemodulatorActive:state ] ;
}

- (void)rxTonePairChanged:(RTTYRxControl*)control
{
	CMTonePair tonePair ;
	
	tonePair = [ control rxTonePair ] ;
	//  set mixer tones
	[ demodulator setTonePair:&tonePair ] ;
	[ self setFilterCutoffs:&tonePair ] ;
}

- (void)forceLTRS
{
	[ demodulator setLTRS:YES ] ;
}

- (Boolean)enabled
{
	return enabled ;
}

//  delegate to CMFSKDemodulator
//  character received from CMBaudotDecoder.
//  Switch zero to a slashed zero if it is requested.
- (void)receivedCharacter:(int)c
{
	char buffer[2] ;
	
	if ( appleScript ) [ appleScript insertBuffer:c ] ;
	if ( c == '0' && slashZero ) c = Phi ;
	
	buffer[0] = c ;
	buffer[1] = 0 ;
	if ( receiveView ) {
		[ receiveView append:buffer ] ;
		[ app addToVoice:c channel:uniqueID+1 ] ;		//  v0.96d	voice synthesizer
	}
}

@end
