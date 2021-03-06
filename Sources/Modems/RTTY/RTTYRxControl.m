//
//  RTTYRxControl.m
//  cocoaModem
//
//  Created by Kok Chen on 1/24/05.
	#include "Copyright.h"
//

#import "RTTYRxControl.h"
#import "Application.h"
#import "ASCIIReceiver.h"
#import "AuralMonitor.h"
#import "CoreModemTypes.h"
#import "CrossedEllipse.h"
#import "Modem.h"
#import "RTTY.h"
#import "RTTYAuralMonitor.h"
#import "RTTYConfig.h"
#import "RTTYModulator.h"
#import "RTTYMonitor.h"
#import "RTTYTxConfig.h"
#import "RTTYWaterfall.h"
#import "Spectrum.h"
#import "SubDictionary.h"
#import "TextEncoding.h"


@implementation RTTYRxControl

//	RTTY Aural Monitor sub dictionary keys
#define	kRxMonitorEnable			@"Receive Enable"
#define	kRxMonitorAttenuator		@"Receive Attenuator"
#define	kRxMonitorFixSelect			@"Receive Fix Select"
#define	kRxMonitorFrequency			@"Receive Frequency"
#define	kRxClickVolume				@"Click Buffer click volume"
#define	kRxClickPitch				@"Click Buffer click pitch"
#define	kRxSoftLimit				@"Receive Soft Limiting"
#define	kTxMonitorEnable			@"Transmit Enable"
#define	kTxMonitorAttenuator		@"Transmit Attenuator"
#define	kTxMonitorFixSelect			@"Transmit Fix Select"
#define	kTxMonitorFrequency			@"Transmit Frequency"
#define	kWideMonitorEnable			@"Wideband Enable"
#define	kWideMonitorAttenuator		@"Wideband Attenuator"
#define	kMonitorMute				@"Mute"
#define	kMonitorVolume				@"Volume"

@synthesize waterfall  = _waterfall;
@synthesize spectrumView = _spectrumView;
@synthesize client    = _client;
@synthesize config    = _config;
@synthesize receiver  = _receiver;
@synthesize monitor   = _monitor;
@synthesize auralMonitorPlist = _auralMonitorPlist;




//  Client is DualRTTY or RTTY

- (id)initIntoView:(NSView*)view client:(Modem*)modem index:(int)index
{
	self = [ super init ] ;
	if ( self ) {
//        if(_waterfall == nil)      _waterfall = [[RTTYWaterfall alloc] init];
//        if(_spectrumView == nil)_spectrumView = [[Spectrum alloc] init];
//        if(_monitor == nil)          _monitor = [[RTTYMonitor alloc] init];

		_auralMonitorPlist = nil ;
		if ( [ [NSBundle mainBundle] loadNibNamed:@"RTTYRxControl" owner:self topLevelObjects:nil] ) {
			// loadNib should have set up controlView connection
			if ( view && controlView ) {
				[ view addSubview:controlView ] ;
				if ( auxWindow ) [ auxWindow setTitle: (index == 0) ? NSLocalizedString( @"Main Receiver", nil ) : NSLocalizedString( @"Sub Receiver", nil ) ] ;
				[ self setupWithClient:modem index:index ] ;
				if ( activeIndicator ) [ activeIndicator setBackgroundColor:[ NSColor grayColor ] ] ;
				return self ;
			}
		}
	}
	return nil ;
}

- (void)setInterface:(NSControl*)object to:(SEL)selector
{
	[ object setAction:selector ] ;
	[ object setTarget:self ] ;
}

- (void)awakeFromNib
{
//	spectrumView = nil ;
//	waterfall = nil ;
//	monitor = nil ;
	tonePair.mark = 2125 ;
	tonePair.space = 2295 ;
	tonePair.baud = 45.45 ;
	transmitTonePair = tonePair ;			// v0.67
	sideband = 0 ;
	rxPolarity = txPolarity = 0 ;
	activeTransmitter = NO ;
	vfoOffset = ritOffset = 0 ;
	txLocked = NO ;
	
//    if(_waterfall == nil)      _waterfall = [[RTTYWaterfall alloc] init];
//    if(_spectrumView == nil)_spectrumView = [[Spectrum alloc] init];
//    if(_monitor == nil)          _monitor = [[RTTYMonitor alloc] init];
    
	[ self setInterface:txPolarityButton to:@selector(txPolarityChanged) ] ;
	[ self setInterface:bandwidthMatrix to:@selector(bandwidthChanged) ] ;
	[ self setInterface:demodulatorModeMatrix to:@selector(demodulatorModeChanged) ] ;
	[ self setInterface:squelchSlider to:@selector(squelchChanged) ] ;
	
	[ self setInterface:rxPolarityButton to:@selector(rxPolarityChanged) ] ;
	[ self setInterface:markFreq to:@selector(tonePairChanged) ] ;
	[ self setInterface:shiftField to:@selector(shiftChanged) ] ;
	[ self setInterface:baudRateBox to:@selector(baudRateChanged) ] ;

	[ self setInterface:memorySelectMenu to:@selector(tonePairSelected) ] ;
	[ self setInterface:inputAttenuator to:@selector(inputAttenuatorChanged) ] ;
	
	//  0.68 print controls
	[ self setInterface:printControlCheckbox to:@selector(printControlChanged:) ] ;
	
	//  0.78 aural monitor
	[ self setInterface:auralLevelSlider to:@selector(auralVolumeChanged:) ] ;
	[ self setInterface:auralMonitorMute to:@selector(auralMuteChanged:) ] ;
	[ self setInterface:rxMonitorCheckbox to:@selector(rxMonitorChanged:) ] ;
	[ self setInterface:rxMonitorAttenuationField to:@selector(rxAttenuatorChanged:) ] ;
	[ self setInterface:rxMonitorFrequencyField to:@selector(rxFrequencyChanged:) ] ;
	[ self setInterface:rxFixedRadioButton to:@selector(rxFixedRadioButtonChanged:) ] ;
	//  v0.88c
	[ self setInterface:rxMonitorClickVolumeSlider to:@selector(rxMonitorClickVolumeSliderChanged:) ] ;
	[ self setInterface:rxMonitorClickPitchSlider to:@selector(rxMonitorClickPitchSliderChanged:) ] ;
	[ self setInterface:rxMonitorSoftLimitCheckbox to:@selector(rxMonitorSoftLimitCheckboxChanged:) ] ;

	[ self setInterface:txMonitorCheckbox to:@selector(txMonitorChanged:) ] ;
	[ self setInterface:txMonitorAttenuationField to:@selector(txAttenuatorChanged:) ] ;
	[ self setInterface:txMonitorFrequencyField to:@selector(txFrequencyChanged:) ] ;
	[ self setInterface:txFixedRadioButton to:@selector(txFixedRadioButtonChanged:) ] ;

	[ self setInterface:rxMonitorBackgroundCheckbox to:@selector(rxWideMonitorChanged:) ] ;
}

- (void)printControlChanged:(id)sender
{
	[ _receiver setPrintControl:( [ sender state ] == NSOnState ) ] ;
}

- (void)auralVolumeChanged:(id)sender
{
	[ [ _receiver rttyAuralMonitor ] setGain:[ sender floatValue ] source:AURALMASTER ] ;
}

- (void)auralMuteChanged:(id)sender
{
	[ [ _receiver rttyAuralMonitor ] setState:( [ sender state ] != NSOnState ) source:AURALMASTER ] ;
}

- (void)rxMonitorChanged:(id)sender
{
	[ [ _receiver rttyAuralMonitor ] setState:( [ sender state ] == NSOnState ) source:AURALRECEIVE ] ;
}

- (void)rxFrequencyChanged:(id)sender
{
	[ [ _receiver rttyAuralMonitor ] setOutputFrequency:[ sender floatValue ] source:AURALRECEIVE ] ;
}

- (void)rxAttenuatorChanged:(id)sender
{
	[ [ _receiver rttyAuralMonitor ] setAttenuation:[ sender intValue ] source:AURALRECEIVE ] ;
}

- (void)rxFixedRadioButtonChanged:(id)sender
{
	[ [ _receiver rttyAuralMonitor ] setFloatingTone:( [ sender selectedRow ] == 0 ) source:AURALRECEIVE ] ;
}

//  v0.88c
- (void)rxMonitorClickVolumeSliderChanged:(id)sender
{
	[ [ _receiver rttyAuralMonitor ] setClickVolume:[ sender floatValue ] ] ;
	[ [ _receiver rttyAuralMonitor ] emitBeep ] ;
}

//  v0.88c
- (void)rxMonitorClickPitchSliderChanged:(id)sender
{
	[ [ _receiver rttyAuralMonitor ] setClickPitch:[ sender floatValue ] ] ;
	[ [ _receiver rttyAuralMonitor ] emitBeep ] ;
}

//  v0.88c
- (void)rxMonitorSoftLimitCheckboxChanged:(id)sender
{
	[ [ _receiver rttyAuralMonitor ] setSoftLimit:( [ sender state ] == NSOnState ) ] ;
}

- (void)txMonitorChanged:(id)sender
{
	[ [ _receiver rttyAuralMonitor ] setState:( [ sender state ] == NSOnState ) source:AURALTRANSMIT ] ;
}

- (void)txFrequencyChanged:(id)sender
{
	[ [ _receiver rttyAuralMonitor ] setOutputFrequency:[ sender floatValue ] source:AURALTRANSMIT ] ;
}

- (void)txAttenuatorChanged:(id)sender
{
	[ [ _receiver rttyAuralMonitor ] setAttenuation:[ sender intValue ] source:AURALTRANSMIT ] ;
}

- (void)txFixedRadioButtonChanged:(id)sender
{
	[ [ _receiver rttyAuralMonitor ] setFloatingTone:( [ sender selectedRow ] == 0 ) source:AURALTRANSMIT ] ;
}

- (void)rxWideMonitorChanged:(id)sender
{
	[ [ _receiver rttyAuralMonitor ] setState:( [ sender state ] == NSOnState ) source:AURALBACKGROUND ] ;
}

- (void)rxWideAttenuatorChanged:(id)sender
{
	[ [ _receiver rttyAuralMonitor ] setAttenuation:[ sender intValue ] source:AURALBACKGROUND ] ;
}

- (void)transmitterTonePairChangedTo:(CMTonePair*)pair
{
	[ [ _receiver rttyAuralMonitor ] setTransmitTonePair:pair ] ;
}

- (void)setTransmitLock:(Boolean)state
{
	txLocked = state ;
}

static CMTonePair adjustTone( CMTonePair *base, int usb, int reverse, float delta )
{
	CMTonePair adjusted ;
	float t ;
	
	adjusted = *base ;
	adjusted.mark += delta ;		// RIT
	adjusted.space += delta ;
	
	if ( usb ^ reverse ) {
		t = adjusted.mark ;
		adjusted.mark = adjusted.space ;
		adjusted.space = t ;
	}
	return adjusted ;
}

- (void)useAsTransmitTonePair:(Boolean)state
{
	if ( activeIndicator ) [ activeIndicator setBackgroundColor:(state) ? [ NSColor yellowColor ] : [ NSColor grayColor ] ] ;
	activeTransmitter = state ;
}

- (void)setupRTTYReceiver
{
	[ _receiver setupReceiverChain:_config ] ;
	[ _config setClient:self ] ;

	// connect up scope taps to the various audio pipes
	if ( _monitor ) {
		[ _monitor connect:4 to:[_receiver baudotPipe ] title:@"Baudot" baudotMarkers:YES timebase:8 ] ;
		[ _monitor connect:3 to:[_receiver atcPipe ] title:@"ATC" baudotMarkers:NO timebase:2 ] ;
		[ _monitor connect:2 to:[_receiver demodBufferPipe ] title:@"MFilter" baudotMarkers:NO timebase:4 ] ;
		[ _monitor connect:1 to:[_receiver bpfBufferPipe ] title:@"BPF" baudotMarkers:NO timebase:1 ] ;
		[ _monitor connect:0 to:(CMTappedPipe*)_config title:@"Input" baudotMarkers:NO timebase:1 ] ;
	}
}

//  audio source starts at config and is routed here first
//	the data is sent to the receiver and the tuning and any spectrum
- (void)importData:(CMPipe*)pipe
{
	if ( !_receiver || ![ _receiver enabled ] ) return ;
	
	//  send data through the processing chain
	if ( _receiver ) [ _receiver importData:pipe ] ;
	//  send data to crossed ellipse display
	if ( tuningView ) [ tuningView importData:pipe ] ;
	//  send data to a spectrum display if needed
	if ( _spectrumView ) [ _spectrumView addData:[ pipe stream ] ] ;
	if ( _waterfall ) [ _waterfall importData:pipe ] ;
}

- (void)setEllipseFatness:(float)value
{
	if ( tuningView ) [ tuningView setFatness:value ] ;
}

- (void)setTheSpectrumView:(Spectrum*)view
{
	CMTonePair localTonePair ;
	
	_spectrumView = view ;
	if ( _spectrumView ) {
		localTonePair = [ self baseTonePair ] ;
		[ _spectrumView setTonePairMarker:&localTonePair ] ;
	}
}


- (void)setTheWaterfall:(RTTYWaterfall*)view
{
	CMTonePair localTonePair ;
	
	_waterfall = view ;
	if ( _waterfall ) {
		localTonePair = [ self baseTonePair ] ;
		[ _waterfall setSideband:sideband ] ;
		[ _waterfall setTonePairMarker:&localTonePair index:uniqueID ] ;
		[ _waterfall setWaterfallID:uniqueID ] ;
		[ _waterfall setActive:YES index:uniqueID ] ;
		[ _waterfall useVFOOffset:vfoOffset ] ;
	}
}

//-(RTTYWaterfall*)waterfall {
//    return waterfall;
//}

- (void)setWaterfallOffset:(float)offset
{
	vfoOffset = offset ;
	if ( _waterfall ) [ _waterfall useVFOOffset:offset ] ;
}

- (void)setPlotColor:(NSColor*)color
{
	if ( _monitor ) [ _monitor setPlotColor:color ] ;
	if ( tuningView ) [ tuningView setPlotColor:color ] ;
}

- (void)setupDefaultFilters
{
	CMTonePair defaultpair = { 2125.0, 2295.0, 45.45 } ;
	CMTonePair asciipair = { 2125.0, 2295.0, 110.0 } ;
	float baud ;
	
	//  v0.83	ASCII baud rates
	if ( [ (RTTYInterface*)_client isASCIIModem ] == NO ) {
		tonePair = defaultpair ;
		baud = 45.45 ;
	}
	else {
		tonePair = asciipair ;
		baud = 110.0 ;
	}
	
	memory[0].mark = 2125 ;  memory[0].space = 2295 ;  memory[0].baud = baud ;
	memory[1].mark = 2110 ;  memory[1].space = 2310 ;  memory[1].baud = baud ;
	memory[2].mark = 1415 ;  memory[2].space = 1585 ;  memory[2].baud = baud ;
	memory[3].mark = 1275 ;  memory[3].space = 1445 ;  memory[3].baud = baud ;
	selectedTone = 0 ;
	
	[ self setTuningIndicatorState:YES ] ;
	//  receive views
	receiveTextAttribute = [ exchangeView newAttribute ] ;
	[ exchangeView setDelegate:_client ] ;
}

- (void)setupWithClient:(Modem*)modem index:(int)index
{
	uniqueID = index ;
	_client = (RTTY*)modem ;
	[ self setupDefaultFilters ] ;
	
	if ( [ (RTTYInterface*)modem isASCIIModem ] == NO ) {
		_receiver = [ [ RTTYReceiver alloc ] initReceiver:index modem:_client ] ;
		//  set up receiver connections
		_monitor = [ [ RTTYMonitor alloc ] init ] ;
		[ _monitor setTitle:@"RTTY Monitor" ] ;
	}
	else {
		//  v0.83
		_receiver = [ [ ASCIIReceiver alloc ] initReceiver:index modem:_client ] ;
		_monitor = [ [ RTTYMonitor alloc ] init ] ;
		[ _monitor setTitle:@"ASCII Monitor" ] ;
	}
	[ _receiver setSquelch:squelchSlider ] ;
	[ _receiver setReceiveView:exchangeView ] ;
	[ _receiver setDemodulatorModeMatrix:demodulatorModeMatrix ] ;
	[ _receiver setBandwidthMatrix:bandwidthMatrix ] ;
}

//- (RTTYReceiver*)receiver
//{
//	return _receiver ;
//}

- (ExchangeView*)view
{
	return exchangeView ;
}

- (NSSlider*)inputAttenuator
{
	return inputAttenuator ;
}

- (VUMeter*)vuMeter
{
	return vuMeter ;
}

- (int)uniqueID
{
	return uniqueID ;
}

- (void)setTuningIndicatorState:(Boolean)active
{
	if ( tuningView ) {
		if ( active ) [ tuningView enableIndicator:_client ] ; else [ tuningView clearIndicator ] ;
	}
}

- (void)turnOnMarkers:(Boolean)active
{
	if ( _waterfall ) {
		[ _waterfall setActive:active index:uniqueID ] ;
	}
}

- (TextAttribute*)textAttribute
{
	return receiveTextAttribute ;
}

- (void)setName:(NSString*)name
{
	[ receiverName setStringValue:name ] ;
}

- (CMTonePair)baseTonePair
{
	return adjustTone( &tonePair, sideband, rxPolarity, 0.0 ) ;
}

- (CMTonePair)rxTonePair
{
	return adjustTone( &tonePair, sideband, rxPolarity, ritOffset ) ;
}

//  v0.67
- (CMTonePair)txTonePair
{
	return adjustTone( &transmitTonePair, sideband, txPolarity, 0.0 ) ;
}


//  CW mode uses the mark tone of an RTTY Tone pair
- (float)cwTone
{
	return tonePair.mark ;
}

//  get tx tone pair from text fields
- (CMTonePair)lockedTxTonePair
{
	CMTonePair locked ;
	
	locked = tonePair ;
	locked.mark = [ markFreq intValue ] ;
	locked.space = locked.mark + [ shiftField intValue ] ;
	return adjustTone( &locked, sideband, txPolarity, 0.0 ) ;
}

- (int)sideband
{
	return sideband ;
}

// v0.67 -- separate rx and tx tone pairs
- (void)setTonePair:(const CMTonePair*)tonepair mask:(int)mask
{
	CMTonePair rxTonepair, txTonepair ;
	
	switch ( mask ) {
	case 1:
	case 3:
		// receive or both
		tonePair = *tonepair ;
		if ( mask == 3 ) {
			transmitTonePair = tonePair ;
			if ( activeTransmitter ) [ (RTTYConfig*)_config txTonePairChanged:self ] ;	//  update the transmit tone pair
			[ _waterfall setTransmitTonePairMarker:&transmitTonePair index:uniqueID ] ;
		}
		//  send frequencies to receiver
		if ( _receiver ) [ _receiver rxTonePairChanged:self ] ;
		//  and to config if we are the selected transmitter
		if ( activeTransmitter && ( mask&2 ) == 2 ) [ (RTTYConfig*)_config txTonePairChanged:self ] ;

		//  set cross ellipse filters
		if ( tuningView ) {
			rxTonepair = [ self rxTonePair ] ;
			[ tuningView setTonePair:&rxTonepair ] ;
		}
		//  dual RTTY spectrum
		if ( _spectrumView ) [ _spectrumView setTonePairMarker:tonepair ] ;
		if ( _waterfall ) {
			[ _waterfall setSideband:sideband ] ;
			[ _waterfall setTonePairMarker:tonepair index:uniqueID ] ;
			[ _waterfall setRITOffset:ritOffset ] ;
			if ( txLocked ) {
				txTonepair = [ self lockedTxTonePair ] ;
				[ _waterfall setTransmitTonePairMarker:&txTonepair index:uniqueID ] ;
			}
		}
		//  set RTTY Monitor's markers
		if ( _monitor ) [ _monitor setTonePairMarker:tonepair ] ;
		if ( _config ) [ (RTTYConfig*)_config setTonePairMarker:tonepair ] ;
		break ;
	case 2:
		//  transmit case
		if ( txLocked == NO ) {
			transmitTonePair = *tonepair ;			//  change the transmit tone pair
			if ( activeTransmitter ) [ (RTTYConfig*)_config txTonePairChanged:self ] ;	//  update the transmit tone pair
			[ _waterfall setTransmitTonePairMarker:&transmitTonePair index:uniqueID ] ;
		}
		//  tell tx side tones have changed
		[ (RTTYConfig*)_config txTonePairChanged:self ] ;
	}
}

//  v0.67
- (void)setTonePair:(const CMTonePair*)tonepair
{
	[ self setTonePair:tonepair mask:3 ] ;
}

- (void)setRIT:(float)offset
{
	CMTonePair rxTonepair ;
	
	ritOffset = offset ;
	rxTonepair = [ self rxTonePair ] ;
	
	if ( _receiver ) [ _receiver rxTonePairChanged:self ] ;
	if ( tuningView ) [ tuningView setTonePair:&rxTonepair ] ;
	if ( _waterfall ) [ _waterfall setRITOffset:ritOffset ] ;
}

- (void)fetchTonePairFromMemory
{
	// update tone pair and baud rate
	tonePair.mark = [ markFreq intValue ] ;
	tonePair.space = tonePair.mark + [ shiftField intValue ] ;
	tonePair.baud = [ baudRateBox floatValue ] ;
	
	//  v0.83 -- should not fix anything other than for 45 -> 45.45
	if ( tonePair.baud > 44.99 && tonePair.baud < 45.46 ) {
		tonePair.baud = 1000.0/22 ;
	}
	transmitTonePair = tonePair ;		//  v0.68
}

//  v0.67
- (void)updateTonePairInformationForMask:(int)mask
{
	int previous ;
	
	if ( ( mask & 1 ) == 1 ) {
		// update rx polarity
		if ( ( [ rxPolarityButton state ] == NSOnState ) ) {
			[ rxPolarityButton setTitle:NSLocalizedString( @"Reversed", nil ) ] ; 
			rxPolarity = 1 ;
		}
		else {
			[ rxPolarityButton setTitle:NSLocalizedString( @"Normal", nil ) ] ; 
			rxPolarity = 0 ; 
		}
	}
	if ( ( mask & 2 ) == 2 ) {
		// update tx polarity
		if ( ( [ txPolarityButton state ] == NSOnState ) ) {
			[ txPolarityButton setTitle:NSLocalizedString( @"Reversed", nil ) ] ; 
			txPolarity = 1 ;
		}
		else {
			[ txPolarityButton setTitle:NSLocalizedString( @"Normal", nil ) ] ; 
			txPolarity = 0 ; 
		}
	}

	//  sideband
	previous = sideband ;
	sideband =(int) [ sidebandMenu indexOfSelectedItem ] ;
	
	if ( mask & 1 ) {
		[ self setTonePair:&tonePair mask:1 ] ;
	}
	

	if ( mask & 2 ) {
	
		transmitTonePair.baud = tonePair.baud ;

		CMTonePair flippedPair = transmitTonePair ;
		if ( flippedPair.mark < 5.1 ) flippedPair = tonePair ;

		if ( ( sideband == 1 && txPolarity == 0 ) || ( sideband == 0 && txPolarity == 1 ) ) {			//  v0.67  flip mark/space
			flippedPair.mark = tonePair.space ;
			flippedPair.space = tonePair.mark ;
		}
		[ self setTonePair:&transmitTonePair mask:2 ] ;
	}
		
	//  update waterfall sideband
	if ( sideband != previous && _waterfall ) {
		CMTonePair pair = [ self baseTonePair ] ;
		[ _waterfall setSideband:sideband ] ;
		[ _waterfall setTonePairMarker:&pair index:uniqueID ] ;
	}
}

- (void)updateTonePairInformation
{
	[ self updateTonePairInformationForMask:3 ] ;
}

- (float)markFrequency 
{
	return tonePair.mark ;
}

- (void)setMarkFrequency:(float)f
{
	tonePair.mark = f ;
	[ self updateTonePairInformation ] ;
}

- (float)spaceFrequency
{
	return tonePair.space ;
}

- (void)setSpaceFrequency:(float)f
{
	tonePair.space = f ;
	[ self updateTonePairInformation ] ;
}

//  v0.67
//  mask = 1 > receiver
//	mask = 2 > transmitter
- (float)markFrequencyForMask:(int)mask
{
	if ( mask == 2 ) return transmitTonePair.mark ;
	//return tonePair.mark ;
	return [ self rxTonePair ].mark ;				//  v0.68
}

//  v0.67
//  mask = 1 > receiver
//	mask = 2 > transmitter
- (void)setMarkFrequency:(float)f mask:(int)mask
{
	switch ( mask ) {
	case 1:
	case 3:
		tonePair.mark = f ;
		[ self updateTonePairInformationForMask:mask ] ;
		break ;
	case 2:
		if ( transmitTonePair.mark < 5 ) transmitTonePair = tonePair ;
		transmitTonePair.mark = f ;
		[ self updateTonePairInformationForMask:2 ] ;
		break ;
	}
}

//  v0.67
//  mask = 1 > receiver
//	mask = 2 > transmitter
- (float)spaceFrequencyForMask:(int)mask
{
	if ( mask == 2 ) return transmitTonePair.space ;
	//return tonePair.space ;
	return [ self rxTonePair ].space ;				//  v0.68
}

//  v0.67
//  mask = 1 > receiver
//	mask = 2 > transmitter
- (void)setSpaceFrequency:(float)f mask:(int)mask
{
	switch ( mask ) {
	case 1:
	case 3:
		tonePair.space = f ;
		[ self updateTonePairInformationForMask:mask ] ;
		break ;
	case 2:
		if ( transmitTonePair.mark < 5 ) transmitTonePair = tonePair ;
		transmitTonePair.space = f ;
		[ self updateTonePairInformationForMask:2 ] ;
		break ;
	}
}

//  returns 45.45 for 45 (used by AFSK)
- (float)baudRate
{
	return tonePair.baud ;
}

//  returns what is in the baud rate box v0.50
- (float)actualBaudRate
{
	return [ baudRateBox floatValue ] ;
} 

- (void)setBaudRateField:(float)rate 
{
	int v ;
	
	v = rate ;
	if ( ( rate - v ) < .01 ) {
		[ baudRateBox setIntValue:v ] ;
		return ;
	}
	[ baudRateBox setStringValue:[ NSString stringWithFormat:@"%.2f", rate ] ] ;
}

- (void)setBaudRate:(float)rate
{
	tonePair.baud = rate ;
	[ self updateTonePairInformation ] ;
}

- (Boolean)invertStateForReceiver
{
	return ( [ rxPolarityButton state ] == NSOnState ) ;
}

- (void)setInvertStateForReceiver:(Boolean)state
{
	[ rxPolarityButton setState: (state) ? NSOnState : NSOffState ] ;
	[ self updateTonePairInformation ] ;
}

- (Boolean)invertStateForTransmitter
{
	return ( [ txPolarityButton state ] == NSOnState ) ;
}

- (void)setInvertStateForTransmitter:(Boolean)state
{
	[ txPolarityButton setState: (state) ? NSOnState : NSOffState ] ;
	[ self updateTonePairInformation ] ;
}

- (Boolean)breakinStateForTransmitter
{
	return NO ;
}

- (void)setBreakinStateForTransmitter:(Boolean)state
{
	//  override in CW
}

- (void)showMonitor
{
	if ( _monitor ) {
		[ _monitor setTonePairMarker:&tonePair ] ;
		[ _monitor showWindow ] ;
	}
}

- (IBAction)openAuralSheet:(id)sender
{
	[ NSApp beginSheet:monitorSheet modalForWindow:auxWindow modalDelegate:nil didEndSelector:nil contextInfo:nil ] ;
}

- (IBAction)closeAuralSheet:(id)sender
{
	[ NSApp endSheet:monitorSheet ] ;	//  end modal beginSheet
	[ monitorSheet orderOut:self ] ;	//  remove the sheet
}

- (IBAction)openAuralMonitor:(id)sender 
{
	AuralMonitor *auralMonitor = [ [ NSApp delegate ] auralMonitor ] ;

	if ( auralMonitor ) [ auralMonitor showWindow ] ;
}

- (IBAction)auxButtonPushed:(id)sender
{
	if ( auxWindow ) [ auxWindow orderFront:self ] ;
}

- (void)squelchChanged
{
	if ( _receiver ) [ _receiver newSquelchValue:[ squelchSlider floatValue ] ] ;
}

- (void)txPolarityChanged
{
	txPolarity = ( [ txPolarityButton state ] == NSOnState ) ? 1 : 0 ;
	if ( txPolarity == 1 ) [ txPolarityButton setTitle:NSLocalizedString( @"Reversed", nil ) ] ; else [ txPolarityButton setTitle:NSLocalizedString( @"Normal", nil ) ] ; 
	if ( activeTransmitter ) [ (RTTYConfig*)_config txTonePairChanged:self ] ;
}

- (void)bandwidthChanged
{
	if ( _receiver ) [ _receiver selectBandwidth:(int)[ bandwidthMatrix selectedColumn ] ] ;
}

- (void)demodulatorModeChanged
{
	if ( _receiver ) [ _receiver selectDemodulator:(int)[ demodulatorModeMatrix selectedColumn ] ] ;
}

//  pass changes to the inpute attenuator to ModemConfig
- (void)inputAttenuatorChanged
{
	if ( _config ) [ _config inputAttenuatorChanged:inputAttenuator ] ;
}

- (void)rxPolarityChanged
{
	[ self updateTonePairInformation ] ;
	[ _receiver forceLTRS ] ;					// force to LTRS when polarity change 0.19
}

- (void)tonePairChanged
{
	[ self fetchTonePairFromMemory ] ;
	[ self updateTonePairInformation ] ;
}

- (void)shiftChanged
{
	tonePair.space = tonePair.mark + [ shiftField intValue ] ;
	[ self updateTonePairInformation ] ;
}

//  map baud rates so that 45 maps to 45.45
- (void)baudRateChanged
{
	float baud ;
	
	baud = [ baudRateBox floatValue ] ;
	//  v0.83 -- should not fix anything other than for 45 -> 45.45
	if ( baud > 44.99 && baud < 45.46 ) {
		baud = 1000.0/22 ;
	}
	tonePair.baud = baud ;	
	[ self updateTonePairInformation ] ;
}

//  tone pair memory menu changed
- (void)tonePairSelected
{
	selectedTone = (int)[ memorySelectMenu indexOfSelectedItem ] ;
	[ markFreq setIntValue:memory[selectedTone].mark ] ;
	[ shiftField setIntValue:fabs( memory[selectedTone].space - memory[selectedTone].mark ) ] ;
	[ self setBaudRateField:memory[selectedTone].baud ] ;
	[ self fetchTonePairFromMemory ] ;
	[ self updateTonePairInformation ] ;
}

- (IBAction)tonePairStore:(id)sender
{
	int index ;
	
	index = (int)[ memorySelectMenu indexOfSelectedItem ] ;
	memory[index].mark = [ markFreq intValue ] ;
	memory[index].space = memory[index].mark + [ shiftField intValue ] ;
	memory[index].baud = [ baudRateBox floatValue ] ;
}

- (void)hideMonitorOnDeactivation:(Boolean)hide
{
	if ( _monitor ) [ _monitor hideScopeOnDeactivation:hide ] ;
}

//  ---- preferences ----
//  preferences maintainence, called from RTTYConfig.m
//  setup default preferences (keys are found in Plist.h)

/* local */
- (NSString*)toneString:(int*)f
{
	return [ NSString stringWithFormat:@"%d,%d,%d,%d", f[0], f[1], f[2], f[3] ] ;
}

/* local */
- (NSString*)baudString:(float*)f
{
	return [ NSString stringWithFormat:@"%.2f,%.2f,%.2f,%.2f", f[0], f[1], f[2], f[3] ] ;
}

/* local */
- (void)decodeToneString:(NSString*)str into:(int*)p
{
	sscanf( [ str cStringUsingEncoding:NSASCIIStringEncoding  ], "%d,%d,%d,%d", &p[0], &p[1], &p[2], &p[3] ) ;
}

/* local */
- (void)decodeBaudString:(NSString*)str into:(float*)p
{
	sscanf( [ str cStringUsingEncoding:NSASCIIStringEncoding  ], "%f,%f,%f,%f", &p[0], &p[1], &p[2], &p[3] ) ;
}

- (void)setupBasicDefaultPreferences:(Preferences*)pref config:(ModemConfig*)cfg
{
	RTTYConfigSet *set ;
	NSRect frame ;
	
	self.config = cfg ;
	set = [ (RTTYConfig*)self.config configSet ] ;
	
	//  get sidebandMenu interface from CWConfig
	sidebandMenu = [ (RTTYConfig*)_config sidebandMenu ] ;
	[ self setInterface:sidebandMenu to:@selector(tonePairChanged) ] ;

	[ pref setInt:0 forKey:set.sideband ] ;
	[ pref setFloat:0.6 forKey:set.squelch ] ;

	if ( auxWindow && set.controlWindow ) {
		if ( uniqueID != 0 ) {
			//  offset sub control a little
			frame = [ auxWindow frame ] ;
			frame.origin.y += 20 ;
			frame.origin.x += 20 ;
			[ auxWindow setFrame:frame display:NO ] ;
		}
		[ pref setString:[ auxWindow stringWithSavedFrame ] forKey:set.controlWindow ] ;
	}
}

//	v0.78
//  (Private API)
- (void)setupAuralMonitorDefaultPreferences:(Preferences*)pref config:(ModemConfig*)cfg
{
	//  create a sub dictionary to hold RTTY Aural Monitor parameters
	_auralMonitorPlist = [ [ SubDictionary alloc ] init ] ;

	if ( _auralMonitorPlist ) {
		[ _auralMonitorPlist setInt:0 forKey:kRxMonitorEnable ] ;
		[ _auralMonitorPlist setInt:0 forKey:kRxMonitorAttenuator ] ;
		[ _auralMonitorPlist setInt:1 forKey:kRxMonitorFixSelect ] ;
		[ _auralMonitorPlist setInt:1760 forKey:kRxMonitorFrequency ] ;

		[ _auralMonitorPlist setFloat:0.5 forKey:kRxClickVolume ] ;
		[ _auralMonitorPlist setFloat:1000.0 forKey:kRxClickPitch ] ;
		[ _auralMonitorPlist setInt:0 forKey:kRxSoftLimit ] ;

		[ _auralMonitorPlist setInt:0 forKey:kTxMonitorEnable ] ;
		[ _auralMonitorPlist setInt:6 forKey:kTxMonitorAttenuator ] ;
		[ _auralMonitorPlist setInt:1 forKey:kTxMonitorFixSelect ] ;
		[ _auralMonitorPlist setInt:1048 forKey:kTxMonitorFrequency ] ;
		
		[ _auralMonitorPlist setInt:0 forKey:kWideMonitorEnable ] ;
		[ _auralMonitorPlist setInt:10 forKey:kWideMonitorAttenuator ] ;

		[ _auralMonitorPlist setInt:1 forKey:kMonitorMute ] ;
		[ _auralMonitorPlist setFloat:0.5 forKey:kMonitorVolume ] ;
	}
}

- (void)setupDefaultPreferences:(Preferences*)pref config:(ModemConfig*)cfg
{
	RTTYConfigSet *set ;
	float f[4] ;
	int i, g[4] ;
	
	[ self setupBasicDefaultPreferences:pref config:cfg ] ;

	set = [ (RTTYConfig*)_config configSet ] ;
	if ( set.usesRTTYAuralMonitor ) [ self setupAuralMonitorDefaultPreferences:pref config:cfg ] ;	//  v0.78
	
	[ pref setInt:selectedTone forKey:set.tone ] ;				// tone memorsideband = 0 ;
	[ pref setInt:0 forKey:set.rxPolarity ] ;
	[ pref setInt:0 forKey:set.txPolarity ] ;
	
	for ( i = 0; i < 4; i++ ) g[i] = memory[i].mark ;
	[ pref setString:[ self toneString:g ] forKey:set.mark ] ;
	
	for ( i = 0; i < 4; i++ ) g[i] = memory[i].space ;
	[ pref setString:[ self toneString:g ] forKey:set.space ] ;
	
	for ( i = 0; i < 4; i++ ) f[i] = memory[i].baud ;
	[ pref setString:[ self baudString:f ] forKey:set.baud ] ;
}

- (void)updateBasicFromPlist:(Preferences*)pref config:(ModemConfig*)cfg 
{
	RTTYConfigSet *set ;
	
	_config = cfg ;
	set = [ (RTTYConfig*)_config configSet ] ;
	
	if ( auxWindow && set.controlWindow ) {
		[ auxWindow setFrameFromString:[ pref stringValueForKey:set.controlWindow ] ] ;
	}
	if ( _receiver ) [ _receiver setSquelchValue:[ pref floatValueForKey:set.squelch ] ] ;
	
	//  menus for tone pair polarities
	[ sidebandMenu selectItemAtIndex:[ pref intValueForKey:set.sideband ] ] ;
	//  tone pair table selection
	[ self fetchTonePairFromMemory ];
	[ self updateTonePairInformation ] ;
}

//	v0.78
- (void)updateAuralMonitorFromPlist:(Preferences*)pref config:(ModemConfig*)cfg 
{
	RTTYConfigSet *set ;

	if ( _auralMonitorPlist != nil ) {
		//  merge plist that is read into auralMonitorPlist
		set = [ (RTTYConfig*)_config configSet ] ;
		
		[ [ _auralMonitorPlist dictionary ] addEntriesFromDictionary:[ pref dictionaryForKey:set.auralMonitor ] ] ;

		//  global (both receive and transmit)
		if ( auralLevelSlider != nil ) {
			[ auralLevelSlider setFloatValue:[ _auralMonitorPlist floatValueForKey:kMonitorVolume ] ] ;
			[ self auralVolumeChanged:auralLevelSlider ] ;
		}
		if ( auralMonitorMute != nil ) {
			[ auralMonitorMute setState:( [ _auralMonitorPlist intValueForKey:kMonitorMute ] == 0 ) ? NSOffState : NSOnState ] ;
			[ self auralMuteChanged:auralMonitorMute ] ;
		}

		//  receive
		if ( rxMonitorCheckbox != nil ) {
			[ rxMonitorCheckbox setState:( [ _auralMonitorPlist intValueForKey:kRxMonitorEnable ] == 0 ) ? NSOffState : NSOnState ] ;
			[ self rxMonitorChanged:rxMonitorCheckbox ] ;
		}
		if ( rxMonitorAttenuationField != nil ) {
			[ rxMonitorAttenuationField setIntValue:[ _auralMonitorPlist intValueForKey:kRxMonitorAttenuator ] ] ;
			[ self rxAttenuatorChanged:rxMonitorAttenuationField ] ;
		}
		if ( rxMonitorFrequencyField != nil ) {
			[ rxMonitorFrequencyField setFloatValue:[ _auralMonitorPlist floatValueForKey:kRxMonitorFrequency ] ] ;
			[ self rxFrequencyChanged:rxMonitorFrequencyField ] ;
		}
		if ( rxFixedRadioButton != nil ) {
			[ rxFixedRadioButton selectCellAtRow:[ _auralMonitorPlist intValueForKey:kRxMonitorFixSelect ] column:0 ] ;
			[ self rxFixedRadioButtonChanged:rxFixedRadioButton ] ;
		}
		
		//  wideband
		if ( rxMonitorBackgroundCheckbox != nil ) {
			[ rxMonitorBackgroundCheckbox setState:( [ _auralMonitorPlist intValueForKey:kWideMonitorEnable ] == 0 ) ? NSOffState : NSOnState ] ;
			[ self rxWideMonitorChanged:rxMonitorBackgroundCheckbox ] ;
		}
		if ( rxMonitorBackgroundAttenuator != nil ) {
			[ rxMonitorBackgroundAttenuator setIntValue:[ _auralMonitorPlist intValueForKey:kWideMonitorAttenuator ] ] ;
			[ self rxWideAttenuatorChanged:rxMonitorBackgroundAttenuator ] ;
		}	
		
		//  click buffer beep (v0.88c)
		if ( rxMonitorClickVolumeSlider != nil ) {
			[ rxMonitorClickVolumeSlider setFloatValue:[ _auralMonitorPlist floatValueForKey:kRxClickVolume ] ] ;
			[ [ _receiver rttyAuralMonitor ] setClickVolume:[ rxMonitorClickVolumeSlider floatValue ] ] ;
		}
		if ( rxMonitorClickPitchSlider != nil ) {
			[ rxMonitorClickPitchSlider setFloatValue:[ _auralMonitorPlist floatValueForKey:kRxClickPitch ] ] ;
			[ [ _receiver rttyAuralMonitor ] setClickPitch:[ rxMonitorClickPitchSlider floatValue ] ] ;
		}
		if ( rxMonitorSoftLimitCheckbox != nil ) {
			int intval = [ _auralMonitorPlist intValueForKey:kRxSoftLimit ] ;
			[ rxMonitorSoftLimitCheckbox setState:( intval == 0 ) ? NSOffState : NSOnState ] ;
			[ [ _receiver rttyAuralMonitor ] setSoftLimit:( intval != 0 ) ] ;
		}
		
		//  transmit
		if ( txMonitorCheckbox != nil ) {
			[ txMonitorCheckbox setState:( [ _auralMonitorPlist intValueForKey:kTxMonitorEnable ] == 0 ) ? NSOffState : NSOnState ] ;
			[ self txMonitorChanged:txMonitorCheckbox ] ;
		}
		if ( txMonitorAttenuationField != nil ) {
			[ txMonitorAttenuationField setIntValue:[ _auralMonitorPlist intValueForKey:kTxMonitorAttenuator ] ] ;
			[ self txAttenuatorChanged:txMonitorAttenuationField ] ;
		}
		if ( txMonitorFrequencyField != nil ) {
			[ txMonitorFrequencyField setFloatValue:[ _auralMonitorPlist floatValueForKey:kTxMonitorFrequency ] ] ;
			[ self txFrequencyChanged:txMonitorFrequencyField ] ;
		}
		if ( txFixedRadioButton != nil ) {
			[ txFixedRadioButton selectCellAtRow:[ _auralMonitorPlist intValueForKey:kTxMonitorFixSelect ] column:0 ] ;
			[ self txFixedRadioButtonChanged:txFixedRadioButton ] ;
		}
	}
}

- (void)updateFromPlist:(Preferences*)pref config:(ModemConfig*)cfg 
{
	RTTYConfigSet *set ;
	float f[4] ;
	int i, g[4] ;
	
	_config = cfg ;
	set = [ (RTTYConfig*)_config configSet ] ;
	
	[ self decodeToneString:[ pref stringValueForKey:set.mark ] into:g ] ;
	for ( i = 0; i < 4; i++ ) memory[i].mark = g[i] ;
	
	[ self decodeToneString:[ pref stringValueForKey:set.space ] into:g ] ;
	for ( i = 0; i < 4; i++ ) memory[i].space = g[i] ;
	
	[ self decodeBaudString:[ pref stringValueForKey:set.baud ] into:f ] ;
	for ( i = 0; i < 4; i++ ) memory[i].baud = f[i] ;

	selectedTone = [ pref intValueForKey:set.tone ] ;
	if ( selectedTone > 3 ) selectedTone = 0 ;
	[ memorySelectMenu selectItemAtIndex:selectedTone ] ;
	
	//  menus for tone pair polarities
	[ rxPolarityButton setState:( [ pref intValueForKey:set.rxPolarity ] == 0 ) ? NSOffState : NSOnState ] ;
	[ txPolarityButton setState:( [ pref intValueForKey:set.txPolarity ] == 0 ) ? NSOffState : NSOnState ] ;
	//  tone pair table selection
	[ markFreq setIntValue:(int)memory[ selectedTone ].mark ] ;
	[ shiftField setIntValue:(int)( fabs( memory[ selectedTone ].space - memory[ selectedTone ].mark + 0.1 ) ) ] ;
	[ self setBaudRateField:memory[selectedTone].baud ] ;
	
	if ( set.usesRTTYAuralMonitor ) [ self updateAuralMonitorFromPlist:pref config:cfg ] ;	//  v0.78
	[ self updateBasicFromPlist:pref config:cfg ] ;
}

- (void)retrieveBasicForPlist:(Preferences*)pref config:(ModemConfig*)cfg
{
	RTTYConfigSet *set ;
	
	_config = cfg ;
	set = [ (RTTYConfig*)_config configSet ] ;

	if ( auxWindow && set.controlWindow ) {
		[ pref setString:[ auxWindow stringWithSavedFrame ] forKey:set.controlWindow ] ;
	}
	[ pref setInt:sideband forKey:set.sideband ] ;

	if ( _receiver ) [ pref setFloat:[ _receiver squelchValue ] forKey:set.squelch ] ;
}

//  v0.78
- (void)retrieveAuralMonitorForPlist:(Preferences*)pref config:(ModemConfig*)cfg
{
	RTTYConfigSet *set ;

	if ( _auralMonitorPlist != nil ) {
		[ _auralMonitorPlist setInt:( [ rxMonitorCheckbox state ] == NSOnState ) forKey:kRxMonitorEnable ] ;
		[ _auralMonitorPlist setInt:( [ txMonitorCheckbox state ] == NSOnState ) forKey:kTxMonitorEnable ] ;
		[ _auralMonitorPlist setInt:( [ rxMonitorBackgroundCheckbox state ] == NSOnState ) forKey:kWideMonitorEnable ] ;

		[ _auralMonitorPlist setInt:[ rxMonitorFrequencyField intValue ] forKey:kRxMonitorFrequency ] ;
		[ _auralMonitorPlist setInt:[ txMonitorFrequencyField intValue ] forKey:kTxMonitorFrequency ] ;

		[ _auralMonitorPlist setInt:[ rxMonitorAttenuationField intValue ] forKey:kRxMonitorAttenuator ] ;
		[ _auralMonitorPlist setInt:[ txMonitorAttenuationField intValue ] forKey:kTxMonitorAttenuator ] ;
		[ _auralMonitorPlist setInt:[ rxMonitorBackgroundAttenuator intValue ] forKey:kWideMonitorAttenuator ] ;
		
		[ _auralMonitorPlist setFloat:[ rxMonitorClickVolumeSlider floatValue ] forKey:kRxClickVolume ] ;
		[ _auralMonitorPlist setFloat:[ rxMonitorClickPitchSlider floatValue ] forKey:kRxClickPitch ] ;
		[ _auralMonitorPlist setInt:( [ rxMonitorSoftLimitCheckbox state ] == NSOnState ) forKey:kRxSoftLimit ] ;
		
		[ _auralMonitorPlist setInt:( [ auralMonitorMute state ] == NSOnState ) forKey:kMonitorMute ] ;
		[ _auralMonitorPlist setFloat:[ auralLevelSlider floatValue ] forKey:kMonitorVolume ] ;

		[ _auralMonitorPlist setInt:(int)[ rxFixedRadioButton selectedRow ] forKey:kRxMonitorFixSelect ] ;
		[ _auralMonitorPlist setInt:(int)[ txFixedRadioButton selectedRow ] forKey:kTxMonitorFixSelect ] ;
		
		//  copy auralMonitorPlist into plist 
		set = [ (RTTYConfig*)_config configSet ] ;
		[ pref setDictionary:[ _auralMonitorPlist dictionary ] forKey:set.auralMonitor ] ;
	}
}

- (void)retrieveForPlist:(Preferences*)pref config:(ModemConfig*)cfg
{
	RTTYConfigSet *set ;
	float f[4] ;
	int i, g[4] ;
	
	set = [ (RTTYConfig*)_config configSet ] ;

	if ( set.usesRTTYAuralMonitor ) [ self retrieveAuralMonitorForPlist:pref config:cfg ] ;		//  v0.78
	[ self retrieveBasicForPlist:pref config:cfg ] ;
	 
	for ( i = 0; i < 4; i++ ) g[i] = memory[i].mark ;
	[ pref setString:[ self toneString:g ] forKey:set.mark ] ;
	
	for ( i = 0; i < 4; i++ ) g[i] = memory[i].space ;
	[ pref setString:[ self toneString:g ] forKey:set.space ] ;
	
	for ( i = 0; i < 4; i++ ) f[i] = memory[i].baud ;
	[ pref setString:[ self baudString:f ] forKey:set.baud ] ;

	[ pref setInt:selectedTone forKey:set.tone ] ;		// tone memory
	[ pref setInt:rxPolarity forKey:set.rxPolarity ] ;
	[ pref setInt:txPolarity forKey:set.txPolarity ] ;
	
	if ( _receiver ) [ pref setFloat:[ _receiver squelchValue ] forKey:set.squelch ] ;
}

@end
