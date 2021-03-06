//
//  PSKMonitor.m
//  cocoaModem
//
//  Created by Kok Chen on Tue Jul 27 2004.
	#include "Copyright.h"
//

#import "PSKMonitor.h"
#include "Oscilloscope.h"


@implementation PSKMonitor

//  PSKMonitor is an AudioDest

@synthesize connection = _connection;

- (id)init
{
	int i ;
	
	self = [ super init ] ;
	if ( self ) {
        _connection = [[NSMutableArray alloc] initWithCapacity:NUMCON];
		currentStyle = 0 ;
		for ( i = 0; i < 8; i++ ) {
            Connection *c = [[Connection alloc] init];
            c.pipe = nil;
            c.index = i;
            [_connection insertObject:c atIndex:i];
			//_connection[i].pipe = nil ;
			//_connection[i].index = i ;
		}
		selected = nil ;
		
		if ( [ [NSBundle mainBundle] loadNibNamed:@"Monitor" owner:self topLevelObjects:nil ] ) {
			// loadNib should have set up scopeView connection
			if ( scopeView ) {
				[ [ scopeView window ] setLevel:NSNormalWindowLevel ] ;
				[ [ scopeView window ] setHidesOnDeactivate:NO ] ;
				return self ;
			}
		}
	}
	return nil ;
}

/* local */
- (void)changeSourceTo:(int)index
{
    Connection *c = [_connection objectAtIndex:index];
	if ( c.pipe == nil ) {
		[ sourceArray deselectSelectedCell ] ;
		[ [ NSNotificationCenter defaultCenter ] postNotificationName:@"SysBeep" object:nil ] ;
		return ;
	}
	//  remove old connection
	if ( selected ) [ selected.pipe setTap:nil ] ;

	//  set new connection
	selected = _connection[index] ;
	[ selected.pipe setTap:self ] ;
	[ sourceArray deselectAllCells ] ;
	[ sourceArray selectCellAtRow:0 column:index ] ;
}

- (void)connect:(int)index to:(CMTappedPipe*)pipe title:(NSString*)name
{
	NSMatrix *matrix ;
	NSButton *button ;
	
	//  remove old connection
	if ( selected ) [ selected.pipe setTap:nil ] ;
	
	matrix = sourceArray ;
	button = [ matrix cellAtRow:0 column:index ] ;
	[ button setTitle:name ] ;
    Connection *c = [_connection objectAtIndex:index];
	c.pipe = pipe ;
	[ self changeSourceTo:index ] ;
}

//  data arrived from sound source
- (void)importData:(CMPipe*)pipe
{
	if ( scopeView && [ [ scopeView window ] isVisible ] ) {
		self.data = [ pipe stream ] ;
		[ scopeView addData:self.data isBaudot:NO timebase:1 ] ;
	}
	// PSK monitor has no destination
}

- (void)setTitle:(NSString*)title
{
	[ [ scopeView window ] setTitle:title ] ;
}

- (void)showWindow
{
	if ( scopeView ) [ [ scopeView window ] orderFront:self ] ;
}

- (void)setPlotColor:(NSColor*)color
{
	[ scopeView setDisplayStyle:currentStyle plotColor:color ] ;
}

- (void)hideScopeOnDeactivation:(Boolean)hide
{
	[ [ scopeView window ] setHidesOnDeactivate:hide ] ;
}

static NSString *freqLabel[] = { @"500", @"1000", @"1500", @"2000", @"2500" } ;

- (IBAction)styleChanged:(id)sender ;
{
	NSButton *button ;
	int index ;
	int i ;
	NSTextField *text ;
	
	button = [ sender selectedCell ] ;
	index = (int)[ button tag ] ;
	[ styleArray deselectAllCells ] ;
	[ styleArray selectCellAtRow:0 column:index ] ;
	
	for ( i = 0; i < 5; i++ ) {
		text = [ specLabel cellAtRow:0 column:i ] ;
		[ text setStringValue:( index == 0 ) ? freqLabel[i] : @"" ] ;
	}
	switch ( index ) {
	case 0:
	case 1:
		currentStyle = index ;
		[ scopeView setDisplayStyle:index plotColor:nil ] ;
		break ;
	}
}

- (IBAction)sourceChanged:(id)sender
{
	NSButton *button ;
	int index ;
	
	button = [ sender selectedCell ] ;
	index =(int) [ button tag ] ;

	[ self changeSourceTo:index ] ;

}

@end
