\ *******************************************************************************
\ * Marconi Communications Systems Ltd                                          *
\ * SERNET Message Protocol Test Program.                                       *
\ * For the BBC Micro computer.                                                 *
\ *                                                                             *
\ * Simulates change of parameters (e.g. Freq change) every 1 hour.             *
\ *                                                                             *
\ * Disassembly by Dermot using the original SERNET program by Andy Mallett.    *
\ *                                                                             *
\ * SERNET Message Format:                                                      *
\ * ----------------------                                                      *
\ * AAAAA - 5 bytes of SOH used for frame alignment                             *
\ * BB    - 1 byte of STX indicating Start of Transmission                      *
\ * DD    - 2 bytes: hex characters indicating length of message (DD+EE+Fn)     *
\ * EE    - 2 bytes: hex chars indicating message number/counter (&00 to &FF)   *
\ * Fn    - n bytes: Text content of message.                                   *
\ * GG    - 2 bytes: hex chars indicating checksum MSB (sum of bytes DD+EE+Fn)  *
\ * HH    - 2 bytes: hex chars indicating checksum LSB (sum of bytes DD+EE+Fn)  *
\ * C     - 1 byte of ETX indicating End of Transmission                        *
\ * I     - 1 byte of CR indicating Carriage Return                             *
\ * J     - 1 byte of LF indicating Line Feed                                   *
\ *                                                                             *
\ * Serial Port Config:                                                         *
\ * -------------------                                                         *
\ * 9600 baud Tx and Rx                                                         *
\ * 1 Start bit                                                                 *
\ * 7 Data bits                                                                 *
\ * Even Parity                                                                 *
\ * 1 Stop bit                                                                  *
\ * RTS/CTS handshaking                                                         *
\ *                                                                             *
\ * Usage:                                                                      *
\ * ------                                                                      *
\ * At BBC Micro command prompt type: *TRFC1HR <data filename>                  *
\ *                                                                             *
\ * Function Keys:                                                              *
\ * --------------                                                              *
\ * f0 = Read next sequence from data file with printer logging                 *
\ * f1 = Read next sequence from data file without printer logging              *
\ * f2 = Restart reading data file                                              *
\ * f3 = Stop reading data file (closes data file)                              *
\ * f4 = Toggle printer ON/OFF                                                  *
\ *                                                                             *
\ * Control Keys:                                                               *
\ * -------------                                                               *
\ * TAB ............ : insert/overwrite                                         *
\ * DELETE ......... : delete backwards                                         *
\ * COPY ........... : delete forwards                                          *
\ * CURSOR UP ...... : increment tx number                                      *
\ * CURSOR DOWN .... : unchanging tx number                                     *
\ *                                                                             *
\ * Use BEEBASM for assembly                                                    *
\ * NOTE: The 1hr time interval can be changed in the function                  *
\ * .resetCountdownTimerToOneHour then re-assemble the code.                    *
\ *******************************************************************************

\ *** CONSTANTS ********************************************************************
charNUL         			=     0      		\ NUL
charSOH         			=     1      		\ Start of Heading
charSTX         			=     2        		\ Start of Text
charETX         			=     3        		\ End of Txt
charEOT         			=     4        		\ End of Transmission
charENQ         			=     5        		\ Enquiry
charACK         			=     6        		\ Acknowledge
charBEL         			=     7               	\ Bell character
charHTAB        			=     9        		\ Horizontal TAB char
charLF          			=     10       		\ Line feed character code
charCR          			=     13       		\ Carriage Return character code
charNAK         			=     21       		\ Negative Acknowledge
charSPC         			=     32       		\ SPACE character
char0           			=     48       		\ char 0 (&30) = end of string
charDEL        				=     &7F      		\ DELETE character
char252         			=     252      		\ Custom character 252
char253         			=     253      		\ Custom character 253
char254         			=     254      		\ Custom character 254
char255         			=     255      		\ Custom character 255

\ *** FUNCTION KEY ACTIONS *********************************************************
fAction_NONE    			=     0      
fAction_CLOSEFILE 			=     1      		\ Close current data file and stop command sequence tx
fAction_NEXTWithLogging 		=     2       		\ Process next data sequence with printer logging
fAction_NEXTNoLogging 			=     3       		\ Process next data sequence without printer logging
fAction_OPENFILE 			=     4      		\ Re-start data sequence tx from beginning of data file

\ *** TEXT WINDOW ENUMS **********************************************************************************
windowMainTitle 			=     0        		\ Window number for Main Title
windowMessageEditor 			=     1        		\ Window number for Message Editor
windowTransmittedMessages 		=     2       		\ Window number for Transmitted Messages
windowReceivedMessages 			=     3       		\ Window number for Received Messages

\ *** CONSTANTS ******************************************************************************************
maxFilenameLength 			=     8        		\ Max length of filename
maxMessageLength 			=     &32      		\ Max length of messages = 50 chars
textLineLength  			=     80       		\ Line length (80 chars)
minutes         			=     60       		\ No. of minutes in an hour
seconds         			=     60       		\ No. of seconds in a minute
defaultPrintBufferLength 		=     &4F     		\ Length of Printer Buffer = 80 chars (&00 to &4F)

\ *** VARIABLES ******************************************************************************************
tempVar1        			=     &70             	\ general variable 1
action_Ins_overwrite 			=     &71            	\ TAB key action: &00=Insert\  &FF=Overwrite
messageCharPointer 			=     &72             	\ Pointer to char in messageBuffer
transmitMessageBufferPointer 		=     &73    		\ Pointer to char in Transmit Message Buffer. &FF = message is not constructed/formatted
noChars423OutputBuffer 			=     &74          	\ No of chrs remaining in RS423 O/P buffer (minus 4)
txMessageCheckSum 			=     &75		\ Sum of ascii values of message chars stored as two byte hex chars
messageCounterFlag 			=     &77    	        \ Nominal message counter indicator. 1=On, 0=Off

receiveMessageBufferPointer 		=     &78     		\ Char position in receive message buffer
rxMessageLength 			=     &79             	\ Length of Rx message text
RxCharStatus    			=     &7A             	\ Status of char received from 423
rxChecksumLoByte 			=     &7B             	\ Lo byte of Rx Checksum
rxChecksumHiByte 			=     &7C             	\ Hi byte of Rx checksum
rxMessageFieldValue 			=     &7D             	\ Value of char field in Rx Message
skipCounterIncrement 			=     &7E            	\ 1=skip increment,0=increment

dataFilenameLength 			=     &80             	\ Length of data filename
fileStringLength 			=     &81
fileStringAddressPointer 		=     &82     		\ Pointer to error message
fileHandle      			=     &86             	\ Handle of file opened with OSFIND
printerStatus   			=     &87             	\ 0 = OFF, &FF = ON

printerStatusChanged 			=     &88            	\ &00 = not changed, &FF = changed
secondsTimer    			=     &8A             	\ Countdown timer for seconds
minutesTimer    			=     &8B             	\ Countdown timer for minutes
hoursTimer      			=     &8C             	\ Countdown timer for hours
readNextDataSequence 			=     &8D            	\ &00 = read next sequence required, &FF = read not required
printerLogging  			=     &8E             	\ &00 = printer logging disabled, &FF = logging enabled
dataFilenameChanged 			=     &8F           	\ &00 = no change, &01 = changed

messageBufferVector 			=     &90     		\ Vector message buffer
funcKeyAction   			=     &92		\ Next action required after function key press
twoSecondTimer  			=     &95             	\ Two second countdown timer
printerBufferCharLength 		=     &93         	\ Length of chars in Printer Buffer
printerBufferCharPointer 		=     &94        	\ Pointer to char in Printer Buffer
tempPrintCharVar96 			=     &96             	\ General var for print char moving
tempPrintCharVar97 			=     &97             	\ General var for print char moving

charsToPrintRemaining 			=     &98		\ Number of chars left in buffer to print

stringInputBufferAddress 		=     &F2     		\ Start address of input string holding data filename (entered on CLI)

dataFileName    			=     &1900		\ Address of raw data filename + drive/directory attributes
dataFilenameBuffer 			=     &1980		\ Address of (clean) data filename
dataFileMessageBuffer 			=     &1A00 		\ Buffer for message read from datafile
messageBuffer   			=     &1B08           	\ MessageBuffer
transmitMessageBuffer 			=     &1B60         	\ Buffer for transmit message. Includes CRC?
transmitMessageTextBuffer 		=     &1B68     	\ Buffer for Tx message text excludes SOH/STX/lenTxMessage
winCursorXPos   			=     &1BF0   		\ X cursor position for window no in X reg
winCursorYPos   			=     &1BF8   		\ Y cursor position for window no in X reg
receiveMessageBuffer 			=     &1C00  		\ Buffer holding received message
printBuffer     			=     &1D00  		\ Printer Buffer

\ *** OS Vector definitions *****************************************************************************
EVNTV           			=     &0220           	\ Events vector

\ *** OS Call definitions *******************************************************************************
OSFIND          			=     &FFCE           	\ Open or close a file
OSBGET          			=     &FFD7           	\ Load a single byte to A from file
OSRDCH          			=     &FFE0           	\ Read character from current i/p stream
OSASCI          			=     &FFE3           	\ Write a character (to screen) from A plus LF if (A)=&0D
OSWRCH          			=     &FFEE           	\ Write character to current o/p stream
OSWORD          			=     &FFF1           	\ Perform miscellaneous OS operation control block to pass parameters
OSBYTE          			=     &FFF4           	\ Perform miscellaneous OS operation using registers to pass parameters

\ *** Set Start address *********************************************************************************
ORG  &2000

.start
\ *** Entry point ***************************************************************************************

.checkForDataFilename 
		JSR getDataFilename
		
.initialiseFileHandle LDA #&00
                STA fileHandle
                LDA #charCR
                
.initialiseDataFilenameBuffer 
		STA dataFilenameBuffer
		
.initialiseDataFileFlag 
		LDA #&01       					\ Don't highlight Data Filename
                STA dataFilenameChanged
                
.initialiseFunctionKeyAction 
		LDA #fAction_NONE
                STA funcKeyAction
                
.initialisePrinterLoggingOff 
		LDA #&00  					\ Set printer logging OFF
                STA printerLogging
                
.initialiseTwoSecondTimer
		LDA #&02     					\ Load two second timer to 2s
                STA twoSecondTimer
                
                JSR closeAllOpenFiles
                JSR checkFilenameIntegrity
                JSR checkFilenameEnd
                BCC checkFilenameValid
                JMP SernetMainEntry

.checkFilenameValid 
		JSR checkForDriveInfo
                BCS checkValidCommandLine
                LDA #<errorInvalidFilename
                STA fileStringAddressPointer
                LDA #>errorInvalidFilename
                STA fileStringAddressPointer+1
                JMP printErrorMessage

.checkValidCommandLine 
		LDA #<dataFilenameBuffer
                STA fileStringAddressPointer
                LDA #>dataFilenameBuffer
                STA fileStringAddressPointer+1
                JSR trimFileString
                JSR checkFilenameIntegrity
                JSR checkFilenameEnd
                BCS openFilename
                LDA #<errorJunkInCommandLine
                STA fileStringAddressPointer
                LDA #>errorJunkInCommandLine
                STA fileStringAddressPointer+1
                JMP printErrorMessage

.openFilename    
		JSR openFileInFilenameBuffer
                BNE fileOpened
                LDA #<errorFileNotFound
                STA fileStringAddressPointer
                LDA #>errorFileNotFound
                STA fileStringAddressPointer+1
                JMP printErrorMessage

.fileOpened     
		STA fileHandle
                JMP SernetMainEntry

.printErrorMessage 
		LDY #&FF
.loopPrintErrorMessage 
		INY
                LDA (fileStringAddressPointer),Y
                BEQ exitFilenameChecks
                JSR OSASCI
                JMP loopPrintErrorMessage

.exitFilenameChecks 
		JSR closeAllOpenFiles
                RTS

.errorInvalidFilename 
		EQUS &07,&0D,"ERROR : Invalid filename !",&0D,&0D,0
		
.errorFileNotFound 
		EQUS &07,&0D,"ERROR : File not found !",&0D,&0D,0
		
.errorJunkInCommandLine 
		EQUS &07,&0D,"ERROR : Junk in command line !",&0D,&0D,0

\*** Entry point of SER9600 ****************************************************************************
.SernetMainEntry
		LDA #&03: JSR OSWRCH            		\ VDU 3 - Disable printer
                LDA #&E5: LDX #&01: JSR OSBYTE            	\ *FX 229,1 - Treat Escape key as ASCII character 27 (&1B)
                LDA #&04: LDX #&01: JSR OSBYTE            	\ *FX 4,1 - Disable cursor editing - keys return codes &87 to &8B
                LDA #&E1: LDX #&A0: LDY #&00: JSR OSBYTE        \ *FX 225, 160 - user defined codes for functions keys starting F0=160 (&A0)
                LDA #&0C: LDX #&04: JSR OSBYTE            	\ *FX 12, 4 - set keyboard auto repeat rate to 0.4 seconds
                LDA #&90: LDX #&00: LDY #&01: JSR OSBYTE        \ *FX 144, 0, 1 (*TV 0,1) - TV interlace off.
                
\*** Disable events ************************************************************************************
		LDA #&03: STA tempVar1
.loopFX19       LDA #&0D: LDX tempVar1: LDY #&00: JSR OSBYTE    \ *FX 13, 4 to 9 - disable events.
                INC tempVar1
                LDA tempVar1
                CMP #&0A
                BNE loopFX19
                
\*******************************************************************************
\*  VDU Data write loop.                                                       *
\*  Data in VDUData1 to VDUData8                                               *
\*  Equivalent:                                                                *
\*  VDU 22, 0 (MODE 0) (640 x 256, 2 colours, 80 x 32 text)                    *
\*  VDU 19, 0, 4, 0, 0, 0 (Set logical colour 0 to 4 - i.e changes black       *
\* background to blue background)                                              *
\*  VDU 19, 1, 4, 0, 0, 0 (Set logical colour 1 to 4 i.e. changes white text   *
\* to blue)                                                                    *
\*  VDU 23, 255, 170, 170, 170, 170, 170, 170, 170, 0 (reprogram chr 255 to    *
\* display this)                                                               *
\*  VDU 23, 254, 170, 170, 170, 170, 170, 170, 170, 170 (reprogram chr 254 to  *
\* display this)                                                               *
\*  VDU 23, 252, 99, 82, 74, 75, 74, 82, 99, 00 (reprogram chr 252 to display  *
\* this)                                                                       *
\*  VDU 23, 253, 208, 16, 16, 144, 16, 16, 222, 0 (reprogram chr 253 to        *
\* display this)                                                               *
\*  VDU 31, 0, 31 (move text cursor to 0, 31)                                  *
\*******************************************************************************
                LDX #&00
.loopVDUData    
		LDA vduData1,X: JSR OSWRCH            		\ Write the VDU data
                INX
                CPX #&39
                BNE loopVDUData
                JSR cursorOff         				\ VDU 23, 1, 0; 0; 0; 0; (cursor off)
                LDA #char254
                JSR write80Chrs       				\ VDU 254 eighty times (one screen line of customer chr 254)
                LDA #&1E: JSR OSWRCH				\ VDU 30 (move text cursor to top left of text area)
                LDA #&0B: JSR OSWRCH            		\ VDU 11 (Move cursor up one line) - puts cursor at start of line
                
                LDX #&00
.loopPrintTitles 
		JSR printTitles       				\ Print 4 text Titles to the screen at 4 different places
                INX: CPX #&04
                BNE loopPrintTitles
                
                LDX #&00
.loopVDU19      
		LDA vduData9,X: JSR OSWRCH
                INX: CPX #&06
                BNE loopVDU19

.initStartofFrameChars 
		LDX #&FF
.loopMessageHeader 
		INX
                LDA strMessageHeader,X
                STA messageBuffer,X
                BNE loopMessageHeader
                LDA #&00
                TAX
.loopFillRxMessBuff1 
		STA receiveMessageBuffer,X 			\ Initialise/clears Rx Mess Buff to all 00
                INX: BNE loopFillRxMessBuff1
                LDA #&00
                STA receiveMessageBufferPointer

.setDefaultRxCharStatus 
		LDA #&00: STA RxCharStatus

.setDefaultSkipCounterIncToOff 
		LDA #&00: STA skipCounterIncrement 		\ Message Counter not used when ACK or NAK messages constructed.

.zeroWinCursorPosArray 
		LDX #&06: LDA #&00
.loopZeroCursorXY 
		STA winCursorXPos,X
                STA winCursorYPos,X
                DEX: BPL loopZeroCursorXY

\*** Flush Various Buffers *****************************************************************************
                SEI
                LDA #&15: LDX #&00: JSR OSBYTE            	\ *FX 21, 0 (flush keyboard buffer)
                LDX #&01: JSR OSBYTE            		\ *FX 21, 1 (RS423 input buffer emptied)
                LDX #&02: JSR OSBYTE            		\ *FX 21, 2 (RS423 output buffer emptied)
                LDA #&80: LDX #&FD: LDY #&FF: JSR OSBYTE        \ *FX 128, 253 (Y=255) (Get no of chrs remaining in RS423 output buffer)
                TXA: SEC: SBC #&04: STA noChars423OutputBuffer
                CLI
                
                LDA #&02: LDX #&02: JSR OSBYTE            	\ *FX 2, 2 (Select input stream - keyboard selected, RS423 enabled)

.setRxBaud9600   
		LDA #&07: LDX #&07: JSR OSBYTE            	\ *FX 7, 7 (Set RS423 receive baud rate to 9600)

.setTxBaud9600   
		LDA #&08: LDX #&07: JSR OSBYTE            	\ *FX 8, 7 (Set RS423 transmit baud rate to 9600)

.set7E1Parity    
		LDA #&9C: LDX #&00: LDY #&FF: JSR OSBYTE        \ *FX 156, 0, 255 (Read 6850 ACIA status register - valued returned in X)
		TXA                   				\ X = Manipulated 6850 ACIA control reg bits.
                AND #&E3              				\ Equiv: AND %1110 0011
                ORA #&08              				\ Equiv: OR %0000 1000
                TAX
                LDA #&9C: LDY #&00: JSR OSBYTE            	\ Sets Sheila &08 CR2/3/4 to 010 (7 bit even parity 1 stop)
                
.initialiseDataSequenceRead
		LDA #&00: STA readNextDataSequence
                JSR resetCountdownTimerToOneHour
                JSR enableIntervalTimerCrossingZero
                JSR newEVTNVector
                JSR initialisePrinterBuffer

.initVars        
		LDA #&00: STA action_Ins_overwrite 		\ Setup vars

.setDefaultMessCounterInc_Off 
		LDA #&00: STA messageCounterFlag 		\ Default to don't increment message counter
                LDA #&02: STA messageCharPointer
                LDA #&FF: STA transmitMessageBufferPointer 	\ Set pointer &FF to indicate message is not constructed/formatted
                JMP displayMessage

\*******************************************************************************
\*                      ***  MAIN EVENT LOOP  ***                              *
\*******************************************************************************
.mainEventLoop
		LDX #windowMessageEditor 			\ Set up a text window (Message Editor)
                JSR setupTextWindows
                LDA #&1F: JSR OSWRCH            		\ VDU31,X,Y - move cursor to last chr of message
                LDA #&01
                CLC: ADC messageCharPointer: JSR OSWRCH
                LDA #&00: JSR OSWRCH            		\ *** End of VDU31...
                JSR cursorOn
                JSR startPrintPrinterBuffer
                LDA printerStatusChanged
                BEQ checkForMainTitleDisplayUpdate
                JMP updatePrinterStatusDisplay

.checkForMainTitleDisplayUpdate 
		LDA dataFilenameChanged				\ Does the data filename need updating?
                BEQ chrInputLoop      				\ No change
                JMP setupMainTitleWindow			\ Yes it has changed so needs display updating

.chrInputLoop    
		LDA transmitMessageBufferPointer 		\ Check if Transmit Message is constructed/formatted
                CMP #&FF: BEQ checkRxCharStatusReady
                LDA #&80: LDX #&FD: LDY #&FF: JSR OSBYTE        \ *FX 128, 253, 255 (Read no of chrs remaining in RS423 output buffer)
                CPX noChars423OutputBuffer
                BCC readChrs423InputBuffers
                JMP transmitMessageRS423

.checkRxCharStatusReady 
		LDA RxCharStatus
                CMP #&00: BEQ readChrs423InputBuffers
                JSR checkIfETXorEOT
                JMP chrInputLoop

.readChrs423InputBuffers 
		LDA #&80: LDX #&FE: LDY #&FF: JSR OSBYTE        \ *FX 128, 254, 255 (Read no of chrs in RS423 input buffer)
                CPX #&00: BEQ noCharsIn423InoutBuffer
                JMP read423Chr

.noCharsIn423InoutBuffer 
		LDA funcKeyAction
                BEQ fActionNONEHandler
                JMP processFunctionKeyActionRequired

.fActionNONEHandler 
		LDA #&00: STA printerLogging    		\ Printer logging OFF (&00)
                LDA readNextDataSequence 			\ Is it time to read next data sequence?
                BEQ readChrsKeyboardInputBuffers
                DEC readNextDataSequence
                LDA #&02              				\ Reset 2s timer
                STA twoSecondTimer
                INC dataFilenameChanged 			\ Highlight Data Filename to OFF 
                LDA #fAction_NEXTNoLogging
                STA funcKeyAction
                JMP mainEventLoop

.readChrsKeyboardInputBuffers 
		LDA #&80: LDX #&FF: LDY #&FF: JSR OSBYTE        \ *FX 128, 255, 255 (Read no of chrs in keyboard buffer)
                CPX #&00: BEQ chrInputLoop      		\ No chars in buffers so back to wait loop
                JMP readKeyboardChr

.transmitMessageRS423
		JSR cursorOff    				\ Turn off cursor (VDU23,1,0;0;0;0;)
                LDX #windowTransmittedMessages
                JSR setupTextWindows  				\ Set up Transmitted Messages text window

.loopOutputRS423 
		LDX transmitMessageBufferPointer
                INC transmitMessageBufferPointer
                LDA transmitMessageBuffer,X
                CMP #charLF
                BNE notNewLine
                LDA #&FF: STA transmitMessageBufferPointer
                LDA #&02: STA twoSecondTimer              	\ Reset 2s timer
                LDA #charLF

.notNewLine      
		PHA: TAY                			\ Not new line chr so send it to RS423
                LDA printerLogging: BNE skipOver423Out
                TYA: JSR printCharToPrinter 			\ Log char to Printer
                LDA #&8A: LDX #&02: JSR OSBYTE            	\ *FX 138, 2, Y (Insert chr into RS423 output buffer)
.skipOver423Out  
		PLA: JSR controlChrHandler
                LDA transmitMessageBufferPointer
                CMP #&FF: BEQ checkSkipCounterIncrement
                LDA #&80: LDX #&FD: LDY #&FF: JSR OSBYTE        \ *FX 128, 253, 255 (Read no of chrs remaining in RS423 output buffer)
                CPX noChars423OutputBuffer
                BCS loopOutputRS423

.getTransMessCursorPos 
		LDX #windowTransmittedMessages 			\ get text cursor positions in Transmitted Messages window
                JSR storeTextCursorPosition
                JMP mainEventLoop     				\ Return to start of main event loop

.checkSkipCounterIncrement 
		LDA skipCounterIncrement 			\ Check if Message Counter increment should be skipped or not. 1 = skip
                BEQ incrementMessageCounter
                LDA #&00: STA skipCounterIncrement		\ Set don't skip Message Counter increment
                JMP getTransMessCursorPos

.incrementMessageCounter 
		LDA messageCounterFlag 				\ Check if message counter needs incrementing
                BEQ getTransMessCursorPos 			\ No - incrementing turned off
                LDX #windowTransmittedMessages 			\ Yes - incrementing turned on
                JSR storeTextCursorPosition
                LDA messageBuffer+1
                JSR incHexChr
                STA messageBuffer+1
                CMP #char0: BNE jumpToDisplayMessage
                LDA messageBuffer
                JSR incHexChr
                STA messageBuffer

.jumpToDisplayMessage
		JMP displayMessage

\ *** incHexChr ******************************************************
\ Routine to increment a Hex number displayed as a character.
\ If chr is 9 it increments to A. If chr is F it increments to 0
\ ********************************************************************
.incHexChr
		CMP #'9'              				\ Is chr = 9
                BEQ charIs9           				\ Yes: Chr = 9
                BCC charIsLess9       				\ No: Chr is < 9
                CMP #'F'              				\ Is chr = F
                BCS charIsOverF       				\ No: Chr is >= F
                JMP charIsLess9

.charIs9         
		LDA #'A': JMP incHexChrRTS              	\ Set chr = A and return (9+1=A in hex)
                
.charIsOverF    
		LDA #'0': JMP incHexChrRTS              	\ Set chr = 0 and return
                
.charIsLess9     
		CLC: ADC #&01					\ Add 1
                
.incHexChrRTS    
		RTS                   				\ Return with A+1 (incremented in Hex)

\ *** read423Chr ***************************************************************
\ Reads a character from RS423 input stream
\ ******************************************************************************
.read423Chr
		JSR cursorOff
                LDX #windowReceivedMessages
                JSR setupTextWindows  				\ Received Messages window
                LDA #&02: LDX #&01: JSR OSBYTE            	\ *FX 2, 1 (RS423 input stream selected & enabled)

.readInputChr    
		JSR OSRDCH
                JSR processRS423Input
                LDX transmitMessageBufferPointer
                CPX #&FF: BNE skipAsPrinterOff
                JSR printCharToPrinter
.skipAsPrinterOff 
		JSR controlChrHandler
                LDA #&80: LDX #&FE: LDY #&FF: JSR OSBYTE        \ *FX 80, 254, 255 (Get no of chrs in RS423 input buffer)
                CPX #&00: BNE readInputChr
                LDX #windowReceivedMessages
                JSR storeTextCursorPosition
                JMP mainEventLoop     				\ Return to start of main event loop

.readKeyboardChr 
		LDA #&02: LDX #&02: JSR OSBYTE            	\ *FX 2,2 (Select input stream - keyboard selected RS423 enabled)
                JSR OSRDCH            				\ Read chr from input stream
                CMP #charCR: BNE chkForLeftArrow           	\ Is it CR?
                LDA #<messageBuffer: STA messageBufferVector
                LDA #>messageBuffer: STA messageBufferVector+1
                JMP crHandler

.chkForLeftArrow 
		CMP #&88: BNE chkForRightArrow
                JMP leftArrowHandler

.chkForRightArrow 
		CMP #&89: BNE chkForUpArrow
                JMP rightArrowHandler

.chkForUpArrow   
		CMP #&8B: BNE chkForDownArrow
                LDA #&01: STA messageCounterFlag              	\ Turn on message counter incrementing
                JMP mainEventLoop

.chkForDownArrow 
		CMP #&8A: BNE checkForF0

.downArrowHandler 
		LDA #&00: STA messageCounterFlag             	\ Turn off message counter incrementing
                JMP mainEventLoop

.checkForF0      
		CMP #&A0: BNE checkForF1              		\ Is it f0?
		LDA #fAction_NEXTWithLogging
                STA funcKeyAction
                JMP mainEventLoop

.checkForF1      
		CMP #&A1: BNE checkForF2              		\ Is it f1?
                LDA #fAction_NEXTNoLogging
                STA funcKeyAction
                JMP mainEventLoop

.checkForF2      
		CMP #&A2: BNE checkForF3              		\ Is it f2?                
                LDA #&02: STA twoSecondTimer			\ Reset 2s countdown timer                
                INC dataFilenameChanged 			\ Highlight Data Filename to OFF
                LDA #fAction_OPENFILE: STA funcKeyAction
                JMP mainEventLoop

.checkForF3     
		CMP #&A3: BNE checkForF4              		\ Is it f3? (Highlight filename and close it?)
                LDA #&02: STA twoSecondTimer              	\ Reset 2s countdown timer
                INC dataFilenameChanged 			\ Highlight Data Filename to OFF
                LDA #fAction_CLOSEFILE: STA funcKeyAction                
                JMP mainEventLoop

.checkForF4      
		CMP #&A4: BNE chkForValidHexChar	        \ Is it f4? (Toggle Printer On/Off)
                JSR togglePrinterStatus
                JMP mainEventLoop

.chkForValidHexChar 
		LDX messageCharPointer 				\ Checks char is correct range for hex number
                CPX #&02: BCS chkForHTAB
                CMP #'0': BCC skipToBeep              		\ Is it >= "0"                
                CMP #'G': BCS skipToBeep              		\ Is it <= "F"                
                CMP #':': BCC hexCharInRange              	\ Is it <= "9"                
                CMP #'A': BCS hexCharInRange              	\ Is it >= "A"                
                JMP skipToBeep        				\ Not a Hex character so beep and return to main event loop

.chkForHTAB      
		CMP #charHTAB: BNE chkForSpace			\ Is it TAB?
                JMP HTABHandler

.chkForSpace     
		CMP #charSPC: BCC skipToBeep			\ Is it Space?

.chkForBackspace 
		CMP #charDEL: BCC backspaceHandler		\ Is it DEL?
                BNE chkForCopy: JMP checkForStartOfMessage

.chkForCopy      
		CMP #&87: BNE skipToBeep			\ Is it COPY?
                JMP checkForMessageBufferEnd

.backspaceHandler 
		LDY action_Ins_overwrite
                BEQ shiftCharInMessage
                JMP hexCharInRange

.skipToBeep      
		JMP makeBeepSound     				\ Beep and jump to main event loop

.hexCharInRange  
		PHA
                LDX messageCharPointer
                LDA messageBuffer,X
                BEQ atEndofMessage
                PLA
                STA messageBuffer,X
                JMP rightArrowHandler

.shiftCharInMessage 
		PHA
                LDX #&02
.atEndofMessage  
		DEX
.loopMessageBuffer 
		INX
                LDA messageBuffer,X
                BNE loopMessageBuffer
                CPX #maxMessageLength-2
                BCC shift1CharToRight
                PLA
                JMP makeBeepSound

.shift1CharToRight 
		LDA messageBuffer,X
                INX: STA messageBuffer,X
                DEX: DEX
                CPX messageCharPointer: BCS shift1CharToRight
                INX
                PLA
                STA messageBuffer,X
                JMP rightArrowHandler

.checkForStartOfMessage 
		LDX messageCharPointer
                CPX #&03: BCS shift1CharToLeft  		\ Char pointer is >=3
                JMP makeBeepSound

.shift1CharToLeft 
		LDA messageBuffer,X
                DEX: STA messageBuffer,X
                INX: INX
                CMP #&00: BNE shift1CharToLeft  		\ Char pointer is >0
                JMP leftArrowHandler

.checkForMessageBufferEnd 
		LDX messageCharPointer
                LDA messageBuffer,X
                BNE moveChrLeft
                JMP makeBeepSound     				\ Beep and jump to main event loop

.moveChrLeft     
		INX                   				\ Moves character in message buffer to left after a character is deleted
                LDA messageBuffer,X
                DEX
                STA messageBuffer,X
                INX
                CMP #&00: BNE moveChrLeft
                JMP displayMessage

.leftArrowHandler 
		LDX messageCharPointer 				\ Left arrow key pressed
                BEQ skipToMakeBeep
                CPX #&02: BNE moveCursorToLeft			\ Check cursor is not at start of editable message                
                LDA #&CA: LDX #&00: LDY #&FF: JSR OSBYTE        \ *FX 202, 0, 255 (set keyboard status byte - CAPS LOCK?)
                TXA
                AND #&08              				\ CAPS LOCK is on?
                BEQ skipToMakeBeep

.moveCursorToLeft 
		DEC messageCharPointer
                JMP displayMessage

.rightArrowHandler 
		LDX messageCharPointer 				\ Right arrow key pressed
                LDA messageBuffer,X
                BEQ skipToMakeBeep
                INC messageCharPointer
                JMP displayMessage

.skipToMakeBeep  
		JMP makeBeepSound     				\ Make beep sound and return to main event loop

.HTABHandler     
		LDA action_Ins_overwrite 			\ Toggles insert/overwrite action when TAB pressed
                BNE skip4
                INC action_Ins_overwrite
                JMP mainEventLoop
                
.skip4           
		LDA #&00: STA action_Ins_overwrite
                JMP mainEventLoop

.displayMessage  
		JSR cursorOff
                LDX #windowMessageEditor
                JSR setupTextWindows  				\ Turn off cursor (VDU23,1,0;0;0;0;)
                LDA #&1F: JSR OSWRCH            		\ Set up a text window
                LDA #&01: JSR OSWRCH
                LDA #&00: JSR OSWRCH            		\ VDU 31, 0, 1 (move text cursor to 0, 1)
                
                LDX #&FF
.loopNotEndofMessage 	
		INX
                LDA messageBuffer,X: JSR OSWRCH
                BNE loopNotEndofMessage 			\ Display message being edited
                LDA #charSPC: JSR OSWRCH
                JMP mainEventLoop     				\ Back to main event loop

.crHandler       
		LDA transmitMessageBufferPointer
                CMP #&FF: BEQ LoadSOH_TxMessageBuffer		\ If transmit message is not formatted start doing so                
                JMP mainEventLoop

.LoadSOH_TxMessageBuffer 
		LDX #&00
                LDA #charSOH
.loopLoadSOH     
		STA transmitMessageBuffer,X
                INX
                CPX #&05: BNE loopLoadSOH

.LoadSTX_TxMessageBuffer 
		LDA #charSTX: STA transmitMessageBuffer,X
                INX
                LDY #&FF
.loopTransferMessageToTxBuffer 
		INY     					\ Add edited message to transmit message buffer
                LDA (messageBufferVector),Y
                STA transmitMessageTextBuffer,Y
                BNE loopTransferMessageToTxBuffer
                DEY: TYA
                CLC: ADC #&09
                PHA
                SEC: SBC #&06

.InsertMessageCounter 
		LDX #&06         				\ Converts the message counter to two Ascii chars and stores in the transmit message buffer
                JSR convertTo2ByteAscii
                PLA
                PHA
                TAX

.CalculateTxMessageChecksum 
		LDA #&00   					\ Calculates checksum for transmit message
                STA txMessageCheckSum
                STA txMessageCheckSum+1

.startTxMessageChecksum 
		DEX
                CPX #&05: BEQ constructTxMessageTrailer
                LDA transmitMessageBuffer,X
                CLC: ADC txMessageCheckSum
                STA txMessageCheckSum
                BCC startTxMessageChecksum
                INC txMessageCheckSum+1
                JMP startTxMessageChecksum

.constructTxMessageTrailer 
		PLA         					\ Formats Message trailer (inserts checksum,ETX,CR,LF)
                TAX
                LDA txMessageCheckSum+1
                JSR convertTo2ByteAscii
                LDA txMessageCheckSum
                JSR convertTo2ByteAscii
                LDA #charETX: STA transmitMessageBuffer,X	\ Insert ETX character into message                
                INX
                LDA #charCR: STA transmitMessageBuffer,X	\ Insert CR into message                
                INX
                LDA #charLF: STA transmitMessageBuffer,X        \ Insert LF into message                
                LDA #&00: STA transmitMessageBufferPointer	\ Reset message buffer pointer                
                JMP mainEventLoop     				\ Back to main loop

.convertTo2ByteAscii 
		PHA               				\ Convert char values to 2 byte hex charsand store in the message
                LSR A: LSR A: LSR A: LSR A                 	\ Shift LS 4 bits to MS 4 bits
                JSR convertLoByte
                PLA: AND #&0F              			\ Mask off LS 4 bits
.convertLoByte   
		CMP #10: BCC isCharAtoF
                CLC: ADC #&07
.isCharAtoF      
		CLC: ADC #&30
                STA transmitMessageBuffer,X
                INX
                RTS

.checkIfETXorEOT 
		LDA RxCharStatus      				\ Prepares ACK if Rx message valid or NACK if not valid
                CMP #charNUL: BEQ clearRxChar          		\ NUL received so ignore & return
                CMP #charETX: BEQ constructACKMessage          	\ ETX received so prepare ACK message
                CMP #charEOT: BEQ constructNAKMessage		\ EOT received so prepare NAK message
                CMP #charSOH: BEQ clearRxChar			\ SOH received so ignore & return
                CMP #charSTX: BEQ clearRxChar			\ STX received so ignore & return
                CMP #charENQ: BEQ clearRxChar			\ ENQ received so ignore & return
                JMP clearRxChar

.constructACKMessage 
		LDX #&FF
.loopReadAckMessageData 
		INX
                LDA AckMessageData,X: STA transmitMessageBuffer,X
                CMP #charLF: BNE loopReadAckMessageData		\ End of Ack Message Datablock reached?
                JMP skipMessageCounterIncrement

.constructNAKMessage 
		LDX #&FF
.loopReadNAKMessageData 
		INX
                LDA NAKMessageData,X: STA transmitMessageBuffer,X
                CMP #charLF: BNE loopReadNAKMessageData		\ End of NAK Message Datablock reached?
                JMP skipMessageCounterIncrement

\ *** skipMessageCounterIncrement *****************************************
\ * Set flag to skip message counter increment when ACK or NAK message is
\ * constructed
\ *************************************************************************
.skipMessageCounterIncrement 
		LDA #&01: STA skipCounterIncrement
                LDA #&00: STA transmitMessageBufferPointer

.clearRxChar     
		LDA #&00: STA RxCharStatus
                RTS

\ ACK Message:
\ {SOH}{SOH}{SOH}{SOH}{SOH}{STX},"0","3",{ACK},"0","0","6","9",{ETX}{CR}{LF}
.AckMessageData 
		EQUB &01,&01,&01,&01,&01,&02,&30,&33,&06,&30,&30,&36,&39,&03,&0D,&0A

\ NAK Message:
\ {SOH}{SOH}{SOH}{SOH}{SOH}{STX},"0","3",{NAK},"0","0","7","8",{ETX}{CR}{LF}
.NAKMessageData
		EQUB &01,&01,&01,&01,&01,&02,&30,&33,&15,&30,&30,&37,&38,&03,&0D,&0A

.processRS423Input 
		PHA
                CMP #charSOH: BEQ chrIsSOH			\ Is is Start of Header?
                CMP #charSTX: BEQ charIsSTX			\ Is it Start of Text?
                LDX receiveMessageBufferPointer
                STA receiveMessageBuffer,X 			\ Store chr in Rx buffer
                CMP #charLF: BNE checkForNextChar		\ Is it Line Feed?
                JSR checkCorrectRxMessageFormat

.chrIsSOH        
		LDA #&00: STA receiveMessageBufferPointer	\ SOH so set Rx message pointer to 0
                JMP endProcess423Input

.charIsSTX       
		STA receiveMessageBuffer 			\ STX so store in 1st char of message buffer
                LDA #&01: STA receiveMessageBufferPointer	\ Message pointer to 1st char of Rx message text
                JMP endProcess423Input

.checkForNextChar 
		INC receiveMessageBufferPointer

.endProcess423Input 
		PLA: RTS

.checkCorrectRxMessageFormat 
		LDX receiveMessageBufferPointer
                LDA receiveMessageBuffer,X
                CMP #charLF: BNE RxMessageFormatError		\ Check for Line Feed?
                DEX: LDA receiveMessageBuffer,X			\ Move back one char
                CMP #charCR: BNE RxMessageFormatError           \ Check for CR?
                DEX: LDA receiveMessageBuffer,X			\ Move back one char
                CMP #charETX: BNE RxMessageFormatError          \ Check for ETX?
                STX receiveMessageBufferPointer 		\ ETX found, store char pointer
                LDA receiveMessageBuffer 			\ Check 1st char in message is STX
                CMP #charSTX: BNE RxMessageFormatError          \ Check for STX?
                JMP getRxMessageLength

.RxMessageFormatError 
		JMP setRxCharToENQ

.getRxMessageLength 
		LDX #&01
                JSR getNumberFromRxMessageChars 		\ Gets the length of the Rx message text
                BCS setRxCharToEOT    				\ EOT if error
                STA rxMessageLength
                LDX rxMessageLength
                INX

.getRxMessageChkSumLow 		
		JSR getNumberFromRxMessageChars 		\ Gets the Checksum Hi byte from the Rx message text
                BCS setRxCharToEOT    				\ EOT if error
                STA rxChecksumHiByte

.getRxMessageChkSumHigh 
		JSR getNumberFromRxMessageChars 		\ Gets the Checksum Lo byte from the Rx message text
                BCS setRxCharToEOT    				\ EOT if error
                STA rxChecksumLoByte
                CPX receiveMessageBufferPointer
                BNE setRxCharToEOT    				\ EOT if error
                LDX rxMessageLength
.loopCheckRxCheckSumMatch 
		LDA rxChecksumLoByte 				\ Calculates Checksum of Rx message message and compares with received
                SEC: SBC receiveMessageBuffer,X
                STA rxChecksumLoByte
                LDA rxChecksumHiByte
                SBC #&00
                STA rxChecksumHiByte
                DEX: BNE loopCheckRxCheckSumMatch
                LDA rxChecksumLoByte: BNE setRxCharToEOT    	\ EOT if chksum Lo byte doesn't match
                LDA rxChecksumHiByte: BNE setRxCharToEOT    	\ EOT if chksum Hi byte doesn't match

.checkMaxMessageLength 
		LDA rxMessageLength
                CMP #maxMessageLength+1: BCS setRxCharToEOT 	\ Check message length <=50 chars. EOT if exceeded.
                CMP #charEOT: BCS getRxMessageSequenceNo
                CMP #charETX: BNE setRxCharToEOT
                LDA receiveMessageBuffer+3
                CMP #charACK: BEQ setRxCharToSOH
                CMP #charNAK: BEQ setRxCharToSTX
                JMP setRxCharToEOT

.getRxMessageSequenceNo 
		LDX #&03       					\ Sequence number in rxMessageFieldValue - no action
                JSR getNumberFromRxMessageChars
                BCS setRxCharToEOT
                LDX rxMessageLength
                JMP lastCheckRxMessageText

.checkRxMessageForDELorSPC 
		LDA receiveMessageBuffer,X 			\ EOT if DEL or SPC found
                CMP #charDEL: BCS setRxCharToEOT
                CMP #charSPC: BCC setRxCharToEOT
                DEX

.lastCheckRxMessageText 
		CPX #&05: BCS checkRxMessageForDELorSPC
                JMP setRxCharToETX    				\ Rx Message format is all correct so set status to ETX

.setRxCharToENQ  
		LDA #charENQ: JMP setRxCharStatus

.setRxCharToEOT  
		LDA #charEOT: JMP setRxCharStatus

.setRxCharToSOH  
		LDA #charSOH: JMP setRxCharStatus

.setRxCharToSTX 
		LDA #charSTX: JMP setRxCharStatus

.setRxCharToETX  
		LDA #charETX: JMP setRxCharStatus

.setRxCharStatus 
		STA RxCharStatus
                RTS

\ ******************************************************************************
\ *** getNumberFromRxMessageChars
\ ******************************************************************************
\ *** Converts two hex chars at position X in the receive message buffer and 
\ *** stores in rxMessageFieldValue 
\ *** Returns with carry clear if sucessful, or carry set if error
\ ******************************************************************************
.getNumberFromRxMessageChars LDA receiveMessageBuffer,X
                JSR convertHexCharToNumber 			\ Is char is in Ascii HEX range (0 to 9, A to F)?
                BCS HighCharNotHex    				\ Out of range
                ASL A: ASL A: ASL A: ASL A
                STA rxMessageFieldValue
                INX: LDA receiveMessageBuffer,X
                JSR convertHexCharToNumber
                BCS LowCharNotHex
                ORA rxMessageFieldValue
                INX
                CLC: RTS                   			\ Hex chars found so no error flag and return

.HighCharNotHex 
		INX
.LowCharNotHex
		INX
                SEC: RTS                   			\ Not HEX char so Carry flags an error

.convertHexCharToNumber
		CMP #'0': BCC hexOutOfRange			\ Check char is in Ascii HEX range (0 to 9, A to F)

.checkForCharA   
		CMP #'A': BCS checkForCharF

.checkForChar9   
		CMP #':': BCS hexOutOfRange
                SEC: SBC #&30					\ Convert hex char (0 to 9) to number and return
                CLC: RTS					\ Return - hex char converted to number in A

.checkForCharF   
		CMP #'G': BCS hexOutOfRange
                SEC: SBC #&37              			\ Convert hex char (A to F) to number and return
                CLC: RTS                   			\ Return - hex char converted to number in A

.hexOutOfRange   
		SEC: RTS

.controlChrHandler 
		AND #&7F            				\ Mask out Ascii chars above 127
                CMP #charLF: BEQ printNewLine
                CMP #charCR: BEQ printCR
                CMP #charSPC: BCC printSOH_STX_Chars
                CMP #charDEL: BEQ printDEL
                JSR OSWRCH
                RTS

.printSOH_STX_Chars 
		CLC: ADC #&40              			\ If SOH or STX invert text colour and print A or B
                JSR setTextInverted
                JSR OSWRCH
                JSR setTextNormal
                RTS

.printCR         
		JSR setTextNormal
                JMP OSWRCH

.printNewLine    
		JSR setTextNormal
                JMP OSWRCH

.printDEL        
		JSR setTextInverted
                LDA #char252: JSR OSWRCH
                LDA #char253: JSR OSWRCH            		\ VDU 252: VDU 253 (reprogrammed chrs to display "DEL")
                JSR setTextNormal
                RTS

.setTextNormal   
		PHA                   				\ Sets white text on blue background
                LDA #&11: JSR OSWRCH
                LDA #&01: JSR OSWRCH            		\ VDU 17, 1 (Change text foreground colour to white)
                LDA #&11: JSR OSWRCH
                LDA #&80: JSR OSWRCH            		\ VDU 17, 128 (Change text background colour to blue)
                PLA: RTS

.setTextInverted 	
		PHA                   				\ Sets blue text on white background
                LDA #&11: JSR OSWRCH
                LDA #&00: JSR OSWRCH            		\ VDU 17, 0 (Change text foreground colour to blue)
                LDA #&11: JSR OSWRCH
                LDA #&81: JSR OSWRCH            		\ VDU 17, 129 (Change text background colour to white)
                PLA: RTS

.setupTextWindows 
		LDA #&1A: JSR OSWRCH            		\ VDU 26 (return graphics & text windows to defaults)
                LDA #&1C: JSR OSWRCH            		\ VDU 28, 0, x1, 79, (x2 + 2)
                LDA #&00: JSR OSWRCH
                LDA windowBottomY,X: JSR OSWRCH
                LDA #&4F: JSR OSWRCH
                LDA windowTopY,X
                CLC: ADC #&02
                JSR OSWRCH            				\ **** End of VDU 28... ****

.VDU31           
		LDA #&1F: JSR OSWRCH				\ VDU 31, cursor X,Y. Move text cursor to X,Y
                LDA winCursorXPos,X: JSR OSWRCH
                LDA winCursorYPos,X: JSR OSWRCH            	\ **** End of VDU31... ****
                RTS

.printTitles     
		TXA: PHA                   			\ Subroutine to set up a text window and print a screen label
                LDA #&1A: JSR OSWRCH            		\ VDU 26 (restore default graphics & text windows)
                LDA #&1F: JSR OSWRCH            		\ VDU 31, 0, x-1 (move text cursor to 0,x-1)
                LDA #&00: JSR OSWRCH
                LDA windowTopY,X
                SEC: SBC #&01: JSR OSWRCH            		\ *** End of  VDU 31... ****
                LDA #char255: JSR write80Chrs       		\ Write one line of custom Char 255
                LDA #&1C: JSR OSWRCH            		\ VDU 28, 0, x1, 79, x2 (set a text window)
                LDA #&00: JSR OSWRCH
                LDA windowBottomY,X: JSR OSWRCH
                LDA #&4F: JSR OSWRCH
                LDA windowTopY,X: JSR OSWRCH            	\ *** End of VDU28...
                LDA #&0C: JSR OSWRCH            		\ VDU 12 (clear text area)
                LDA #&1E: JSR OSWRCH            		\ VDU 30 (home text cursor to top of window)
                TXA: BEQ loopWrChr2
                TAY
                LDX #&FF

.loopWrChr1     
		INX
                LDA strTitle1,X: BNE loopWrChr1
                DEY: BNE loopWrChr1
                INX

.loopWrChr2      
		LDA strTitle1,X
                INX: JSR OSWRCH            			\ Print chrs from strTitle1 (offset by X) until a termination zero is located
                BNE loopWrChr2
                PLA: TAX: RTS                   		\ End of printTitles

\ *** storeTextCursorPosition ***************************************
\ Gets the current text window cursor positions and
\ stores in WinCursorXPos and WinCursorYPos
\ *******************************************************************
.storeTextCursorPosition 
		LDA tempVar1  					\ save current tempVar1 value
                PHA
                STX tempVar1          				\ temporarily save window number
                LDA #&86: JSR OSBYTE            		\ *FX 134 (Read text cursor position)
                TXA                   				\ X = HPOS
                LDX tempVar1          				\ restore window number
                STA winCursorXPos,X   				\ Store text horizontal cursor position winCursorXPos array
                TYA
                STA winCursorYPos,X   				\ Store text vertical cursor position in winCursorYPos array
                PLA
                STA tempVar1					\ restore tempVar1 value
                RTS  						

\ *** cursorOff/On *************************************************************
.cursorOff       
		LDA #&00: BEQ skipCursorOn			\ If entry here then VDU 23, 1, 0; 0; 0; 0; (cursor off)

.cursorOn        
		LDA #&01					\ If entry here then VDU 23, 1, 1; 0; 0; 0; (cursor on)

.skipCursorOn    
		PHA
                LDA #&17: JSR OSWRCH
                LDA #&01: JSR OSWRCH
                PLA: JSR OSWRCH
                LDA #&00: LDX #&08
.Loop8Zeroes
		JSR OSWRCH
                DEX: BNE Loop8Zeroes
                RTS  						\ End of cursorOn/Off

\ *** write80Chrs **************************************************************
.write80Chrs
		LDY #textLineLength
.loop80Chars    JSR OSWRCH            				\ Write 80 chars in A to VDU output
                DEY: BNE loop80Chars
                RTS                   				\ End of write80Chrs

\ *** makeBeepSound ************************************************************
.makeBeepSound   
		LDA #charBEL: JSR OSWRCH            		\ VDU 7 (make a short BEEP sound)
                JMP mainEventLoop     				\ Back to main event loop

\ *** Data Constructs **********************************************************
.vduData1        EQUB &16,&00         				\ VDU 22, 0 (MODE 0 - 640 x 256, 2 colours, 80 x 32 text)
.vduData2        EQUB &13,&00,&04,&00,&00,&00 			\ VDU 19, 0, 4, 0, 0, 0 (Set logical colour 0 to 4 - i.e changes black background to blue background
.vduData3        EQUB &13,&01,&04,&00,&00,&00 			\ VDU 19, 1, 4, 0, 0, 0 (Set logical colour 1 to 4 i.e. changes white to blue)
.vduData4        EQUB &17,&FF,&AA,&AA,&AA,&AA,&AA,&AA,&AA,&00 	\ VDU 23, 255, 170, 170, 170, 170, 170, 170, 170, 0 (reprogram chr 255)
.vduData5        EQUB &17,&FE,&AA,&AA,&AA,&AA,&AA,&AA,&AA,&AA 	\ VDU 23, 254, 170, 170, 170, 170, 170, 170, 170, 170 (reprogram chr 254)
.vduData6        EQUB &17,&FC,&63,&52,&4A,&4B,&4A,&52,&63,&00 	\ VDU 23, 252, 99, 82, 74, 75, 74, 82, 99, 00 (reprogram chr 252)
.vduData7        EQUB &17,&FD,&D0,&10,&10,&90,&10,&10,&DE,&00 	\ VDU 23, 253, 208, 16, 16, 144, 16, 16, 222, 0 (reprogram chr 253)
.vduData8        EQUB &1F,&00,&1F     				\ VDU 31, 0, 31 (move text cursor to 0, 31)
.vduData9        EQUB &13,&01,&07,&00,&00,&00 			\ VDU 19, 1, 7, 0, 0, 0 (changes logical colour 1 to 7 (white))

.windowTopY      EQUB &01,&03,&08,&14 				\ Array of Top Y coord for 4 text windows
.windowBottomY   EQUB &01,&06,&12,&1E 				\ Array of Bottom Y coord for 4 text windows

.strTitle1       EQUS "THE VOA SERNET PROTOCOL TEST PROGRAM",&00
.strTitle2       EQUS "MESSAGE EDITOR",&00
.strTitle3       EQUS "TRANSMITTED MESSAGES",&00
.strTitle4       EQUS "RECEIVED MESSAGES",&00

.strMessageHeader
		EQUS "00",&00

\ ******************************************************************************

.enableIntervalTimerCrossingZero 
		SEI
                LDA #<newEVTNVector: STA EVNTV
                LDA #>newEVTNVector: STA EVNTV+1
                LDA #&0E: LDX #&05: JSR OSBYTE            	\ *FX 14,5 - Enable interval timer crossing 0 event
                CLI
                RTS

\ *** resetCountdownTimerToOneHour *********************************************
\ This holds the interval between data message sequences being sent.
\ Adjust these values if different timer intervals are required.
\ ******************************************************************************
.resetCountdownTimerToOneHour 
		LDA #&00: STA secondsTimer
                LDA #&00: STA minutesTimer
                LDA #&01: STA hoursTimer        		\ Sets countdown timer to 1 hour
                RTS
\ ******************************************************************************

.newEVTNVector   
		PHP: PHA: TXA: PHA: TYA: PHA			\ Save registers
                LDX #<newIntervalTimerValue
                LDY #>newIntervalTimerValue
                LDA #&04: JSR OSWORD            		\ Write new value to Interval Timer (1s)
                LDA twoSecondTimer: BEQ decrementCountdownTimer
                DEC twoSecondTimer

.decrementCountdownTimer 
		DEC secondsTimer: BPL exitNewEVTN
                LDA #seconds-1: STA secondsTimer		\ Decrement seconds
                
                DEC minutesTimer: BPL exitNewEVTN
                LDA #minutes-1: STA minutesTimer		\ Decrement minutes
                
                DEC hoursTimer: BPL exitNewEVTN
                LDA #&00: STA hoursTimer			\ Decrement hours
                
                INC readNextDataSequence 			\ If timer reaches 0 then next data seq read req'd
                JSR resetCountdownTimerToOneHour

.exitNewEVTN     
		PLA: TAY: PLA: TAX: PLA: PLP			\ Restore registers
                RTS

\ ******************************************************************************
\ ***  newIntervalTimerValue ***************************************************
\ ***
\ *** 1 second = 100 centiseconds (100 x 0.01s)
\ *** LSB of IntVal Timer val = &9C = 156
\ *** 256 - 156 = 100 centiseconds
\ ***
\ ******************************************************************************
.newIntervalTimerValue 
		EQUB &9C,&FF,&FF,&FF,&FF 			\ Interval Timer = 1 second

.getDataFilename
		LDX #&00: STX dataFilenameLength
.loopGetFilename
		LDA (stringInputBufferAddress),Y
                STA dataFileName,X
                CMP #charCR: BEQ endOfFilenameInBufferFound
                INX: INY
                JMP loopGetFilename

.endOfFilenameInBufferFound 
		RTS

.openFileInFilenameBuffer 
		LDA #&40
                LDX #<dataFilenameBuffer
                LDY #>dataFilenameBuffer
                JMP OSFIND            				\ Open a file with name at address &1980

.closeAllOpenFiles 
		LDA #&00: LDY #&00: JMP OSFIND            	\ Close all open files

\ *** checkFilenameIntegrity ***************************************************
\ Checks to ensure no invalid chars in data filename
\ ******************************************************************************
.checkFilenameIntegrity 
		LDX dataFilenameLength
                DEX
.loopFileNameCheck 
		INX
                LDA dataFileName,X
                JSR checkForControlChars
                BCS loopFileNameCheck
                STX dataFilenameLength
                RTS
                
\ ******************************************************************************
.checkFilenameEnd 
		LDX dataFilenameLength
                LDA dataFileName,X
                CMP #charCR: BEQ endOfFilenameFoundCR
                CLC: RTS
.endOfFilenameFoundCR 
		SEC: RTS

\ ******************************************************************************
.checkForCharCR  
		CMP #charCR: BEQ CtrlCharFound
.checkForControlChars 
		CMP #charNUL: BEQ CtrlCharFound
                CMP #charHTAB: BEQ CtrlCharFound
                CMP #charSPC: BEQ CtrlCharFound
                CMP ',': BEQ CtrlCharFound
                CLC: RTS
.CtrlCharFound  
		SEC: RTS

\ ******************************************************************************
.checkForReservedFileChars 
		CMP #'!': BCC ReservedFileCharsFoundExit	\Is char < "!"? If yes then RTS
                CMP #charDEL: BCS ReservedFileCharsFoundExit
                CMP #'*': BEQ ReservedFileCharsFoundExit        \Is it "*"? If yes then RTS
                CMP #'.': BEQ ReservedFileCharsFoundExit        \Is it "."? If yes then RTS
                CMP #':': BEQ ReservedFileCharsFoundExit        \Is it ":"? If yes then RTS
                CMP #'!': BEQ ReservedFileCharsFoundExit        \Is it "!"? If yes then RTS
                SEC: RTS                   			\Not reserved chars
.ReservedFileCharsFoundExit 
		CLC: RTS

\ ******************************************************************************
.checkIfHexChar  
		CMP #'0': BCC notHexChar
                CMP #':': BCC charIsNumber
                CMP #'A': BCC notHexChar
                CMP #'G': BCC charIsUppercaseHexLetter
                CMP #'a': BCC notHexChar
                CMP #'g': BCC charIsLowercaseHexLetter
                JMP notHexChar
.charIsNumber    
		SEC: SBC #&30              			\ Convert hex number char to integer value
                JMP hexCharFound
.charIsUppercaseHexLetter 
		SEC: SBC #&37              			\ Convert hex upper case letter char to integer value
                JMP hexCharFound
.charIsLowercaseHexLetter
		SEC: SBC #&57              			\ Convert hex lower case letter char to integer value
                JMP hexCharFound
.notHexChar      
		CLC: RTS
.hexCharFound    
		SEC: RTS
\ ******************************************************************************

.checkForDriveInfo 
		LDX dataFilenameLength
                LDA dataFileName,X
                CMP #':': BNE notColon              		\Is it ":"?
                INX: LDA dataFileName,X
                CMP #'0': BCC exitDriveInfoCheckWithError	\Is it "0"? (Check drive number in range 0 to 3)
                CMP #'4': BCS exitDriveInfoCheckWithError	\Is it "4"?
                INX: LDA dataFileName,X
                CMP #'.': BNE exitDriveInfoCheckWithError	\Is it "."?
                INX
.notColon       
		INX: LDA dataFileName,X
                DEX
                CMP #'.': BNE notPeriod				\Is it "."?
                LDA dataFileName,X
                JSR checkForReservedFileChars
                BCC exitDriveInfoCheckWithError
                INX: INX
.notPeriod       
		DEX: LDY #&00
.loopCheckReservedChars 
		INX: LDA dataFileName,X
                JSR checkForReservedFileChars
                BCC checkFilenameLengthIsValid
                INY
                CPY #maxFilenameLength: BEQ exitDriveInfoCheckWithError
                JMP loopCheckReservedChars

.checkFilenameLengthIsValid 
		CPY #&00: BEQ exitDriveInfoCheckWithError
                JSR checkForCharCR: BCC exitDriveInfoCheckWithError
                STX fileStringLength
                SEC: RTS
.exitDriveInfoCheckWithError 
		CLC: RTS

.trimFileString  
		LDX dataFilenameLength
                LDY #&00
.loopTrimFileString 
		LDA dataFileName,X
                STA (fileStringAddressPointer),Y
                CPX fileStringLength: BEQ insertCharCR
                INX: INY
                JMP loopTrimFileString

.insertCharCR    
		LDA #charCR
                STA (fileStringAddressPointer),Y
                STX dataFilenameLength
                RTS

.startGetCharFromDataFile 
		LDX #&02
                LDY fileHandle
                JMP getCharFromDataFile

.testForNewLine  
		CMP #charLF
                BEQ getCharFromDataFile
                LDA #&07: JSR OSWRCH            		\ VDU 7 - make a beep

.getCharFromDataFile 
		JSR OSBGET: BCS invalidCharFound		\ Get char from open file
                CMP #charCR: BEQ writeEndOfString		\ Is it CR?
                CMP #'!': BNE checkForValidDataChar		\ Is it "!" (end of data sequence?)
                CPX #&02: BEQ resetDataFileMessageBuffer

.checkForValidDataChar 
		CMP #charSPC: BCC testForNewLine
                CMP #charDEL: BCS testForNewLine
                STA dataFileMessageBuffer,X
                INX
                CPX #maxMessageLength-1: BCC getCharFromDataFile \ Check max message length not exceeded
                
                LDX #&02
.checkForEndOfDataLine 
		JSR OSBGET: BCS invalidCharFound
                CMP #charCR: BNE checkForEndOfDataLine
                JMP testForNewLine

.writeEndOfString 
		LDA #charNUL
                STA dataFileMessageBuffer,X
                JMP returnFromGetCharFromDataFile

.resetDataFileMessageBuffer 
		LDA #charNUL
                LDX #&02
                STA dataFileMessageBuffer,X
                LDA #fAction_OPENFILE
                STA funcKeyAction
                JMP returnFromGetCharFromDataFile

.invalidCharFound 
		LDA #charNUL
                STA dataFileMessageBuffer,X
                LDA #fAction_CLOSEFILE
                STA funcKeyAction

.returnFromGetCharFromDataFile 
		RTS

.togglePrinterStatus						\ Toggles printer status ON/OFF 
		LDA printerStatus
                BEQ setPrinterStatusON               
.setPrinterStatusOFF 
		LDA #&00
                STA printerStatus
                JMP setPrinterStatusChanged
.setPrinterStatusON 
		LDA #&FF
                STA printerStatus     				\ Changes printer status to ON

.setPrinterStatusChanged 
		LDA #&FF
                STA printerStatusChanged 			\ Flag to indicate printer status display needs updating
                RTS

.updatePrinterStatusDisplay 
		JSR cursorOff 					\ Hide cursor
                LDX #windowMainTitle
                JSR setupTextWindows  				\ Set up a text window (Main Title)
                LDA #&1F: JSR OSWRCH
                LDA #&28: JSR OSWRCH
                LDA #&01: JSR OSWRCH            		\ VDU 31,40,1 - move text cursor to 40,1
                JSR setTextNormal
                LDX #&FF

.displayPrinterStatus 
		INX
                LDA printerMessageText,X
                JSR OSWRCH
                BNE displayPrinterStatus
                LDA printerStatus
                BNE printerIsON
                
.printerIsOFF    
		LDA #'O': JSR OSWRCH            		\ Print "O"
                LDA #'F': JSR OSWRCH            		\ Print "F"
                JSR OSWRCH            				\ Print "F"
                JMP endDisplayPrinterStatus

.printerIsON    
		JSR setTextInverted
                LDA #'O': JSR OSWRCH            		\ Print "O"
                LDA #'N': JSR OSWRCH            		\ Print "N"
                JSR setTextNormal
                LDA #charSPC: JSR OSWRCH

.endDisplayPrinterStatus
		LDA #&00: STA printerStatusChanged		\ &00 indicates printer status display update handled
                JMP mainEventLoop

.printerMessageText 
		EQUS "printer = ",&00

.setupMainTitleWindow 
		JSR cursorOff    				\ Hide cursor
                LDX #windowMainTitle
                JSR setupTextWindows  				\ Set up a text window (Main Title)
                LDA #&1F: JSR OSWRCH
                LDA #&38: JSR OSWRCH
                LDA #&01: JSR OSWRCH            		\ VDU 31,56,1 - move text cursor to 56,1
                JSR setTextNormal
                LDX #&FF
                
.loopOutputFileMessageText 
		INX: LDA fileMessageText,X: JSR OSWRCH
                BNE loopOutputFileMessageText
                LDA fileHandle: BNE displayDataFilename
                LDA #'<': JSR OSWRCH               		\ Print "<"
                LDA #'N': JSR OSWRCH               		\ Print "N"
                LDA #'O': JSR OSWRCH               		\ Print "O"
                LDA #'N': JSR OSWRCH               		\ Print "N"
                LDA #'E': JSR OSWRCH               		\ Print "E"
                LDA #'>': JSR OSWRCH               		\ Print ">"
                JMP padFilenameBoxWithSpaces

.displayDataFilename 
		LDX #&00
                LDA funcKeyAction: BEQ loopDisplayDataFilename
                JSR setTextInverted

.loopDisplayDataFilename 
		LDA dataFilenameBuffer,X
                CMP #charCR: BEQ padFilenameBoxWithSpaces
                JSR OSWRCH
                INX: CPX #&0D: BCC loopDisplayDataFilename

.padFilenameBoxWithSpaces 
		JSR setTextNormal
                LDA tempVar1
                PHA
                LDA #&86: JSR OSBYTE            \ *FX 134 - Read text cursor position
                STX tempVar1
                LDA #textLineLength-1
                SEC: SBC tempVar1
                TAX: PLA
                STA tempVar1
                CPX #&01: BCC noSpacesToFill
.loopPrintSpace  
		LDA #charSPC: JSR OSWRCH
                DEX: BNE loopPrintSpace

.noSpacesToFill  
		DEC dataFilenameChanged \ Highlight Data Filename to ON
                JMP mainEventLoop

.fileMessageText 
		EQUS "file = ",&00

.processFunctionKeyActionRequired
{		JSR resetCountdownTimerToOneHour
                LDA fileHandle: 		BEQ fileHandleNotFound
                LDA twoSecondTimer: 		BNE twoSecondTimerStillRunning
                LDA funcKeyAction
                CMP #fAction_CLOSEFILE: 	BEQ closeFile			\ Function key f3 pressed
                CMP #fAction_NEXTWithLogging: 	BEQ fAction_02_03_Handler	\ Function key f0 pressed
                CMP #fAction_NEXTNoLogging:   	BEQ fAction_02_03_Handler	\ Function key f1 pressed                
                CMP #fAction_OPENFILE:		BEQ openFileForInput		\ Function key f2 pressed
.fileHandleNotFound
		LDA #fAction_NONE: STA funcKeyAction
                JMP mainEventLoop
}

.twoSecondTimerStillRunning 
		JMP chrInputLoop

.closeFile       
		LDA #&00: LDY fileHandle: JSR OSFIND
                LDA #&00: STA fileHandle
                INC dataFilenameChanged 				\ Highlight Data Filename to OFF
                LDA #fAction_NONE: STA funcKeyAction
                JMP mainEventLoop

.openFileForInput 
{		LDA fileHandle: BEQ fileHandleNotFound
                JSR closeAllOpenFiles
                LDA #&40
                LDX #<dataFilenameBuffer
                LDY #>dataFilenameBuffer
                JSR OSFIND
                STA fileHandle
                INC dataFilenameChanged 				\ Highlight Data Filename to OFF
.fileHandleNotFound 
		LDA #fAction_NONE: STA funcKeyAction
                JMP mainEventLoop
}

.fAction_02_03_Handler 
		LDA transmitMessageBufferPointer 				\ Check if Transmit Message is constructed/formatted
                CMP #&FF: 			BNE exitFActionHandler		\ &FF = not formatted/constructed                
                JSR startGetCharFromDataFile
                LDA dataFileMessageBuffer+2: 	BNE prepareDataFileMessageForTx
                LDA funcKeyAction
                CMP #fAction_CLOSEFILE: 	BEQ exitFActionHandler
                CMP #fAction_OPENFILE: 		BEQ exitFActionHandler
                JMP setNoActionAndExit

.prepareDataFileMessageForTx 
		LDA messageBuffer: STA dataFileMessageBuffer
                LDA messageBuffer+1: STA dataFileMessageBuffer+1
                LDA #<dataFileMessageBuffer: STA messageBufferVector
                LDA #>dataFileMessageBuffer: STA messageBufferVector+1
                LDA funcKeyAction
                CMP #fAction_NEXTWithLogging: BNE skipPrinterLogging
                LDA #&FF: STA printerLogging    		\ Enable printer logging

.skipPrinterLogging 
		INC dataFilenameChanged 			\ Highlight Data Filename to OFF
                JMP crHandler

.setNoActionAndExit 
		LDA #fAction_NONE
                STA funcKeyAction

.exitFActionHandler 
		INC dataFilenameChanged 			\ Highlight Data Filename to OFF
                JMP mainEventLoop

.initialisePrinterBuffer 
		LDA #&00
                STA printerBufferCharLength
                STA printerBufferCharPointer
                JSR setPrinterStatusOFF
                LDA #defaultPrintBufferLength
                STA charsToPrintRemaining
                RTS

.startPrintPrinterBuffer 
		LDA printerBufferCharPointer
                CMP printerBufferCharLength
                BNE checkSpaceInPrinterBuffer
                RTS

.checkSpaceInPrinterBuffer 
		LDA #&80: LDX #&FC: LDY #&FF: JSR OSBYTE        \ *FX 128,252,255 - get number of chars remaining in Printer Buffer
                CPX #&04
                BCS printPrinterBuffer 				\ Printer Buffer is >4 chars remaining
                RTS

.printPrinterBuffer 
		LDA #&02: JSR OSWRCH            		\ VDU 2 - turn printer on
                LDA #&01: JSR OSWRCH            		\ VDU 1 - next char to printer only
                LDX printerBufferCharPointer
                LDA printBuffer,X: JSR OSWRCH
                CMP #charCR: BEQ endOfPrintBuffer
                DEC charsToPrintRemaining
                BNE loopPrintPrinterBuffer
                LDA #&01: JSR OSWRCH            		\ VDU 1 - next char to printer only
                LDA #charCR: JSR OSWRCH            		\ VDU 13 - carriage return
                LDA #&01: JSR OSWRCH            		\ VDU 1 - next char to printer only
                LDA #charLF: JSR OSWRCH            		\ VDU 10 - Line Feed                
.endOfPrintBuffer 
		LDA #defaultPrintBufferLength: STA charsToPrintRemaining
.loopPrintPrinterBuffer 
		LDA #&03: JSR OSWRCH            		\ VDU 3 - turn printer off
                INC printerBufferCharPointer
                JMP startPrintPrinterBuffer

.printCharToPrinter 
		PHA
                LDA printerStatus     				\ 0 = Printer Off\ &FF = Printer On
                BNE printerIsEnabled
                PLA: RTS

.printerIsEnabled 
		PLA: STA tempPrintCharVar96
                AND #&7F              				\ Mask out ASCII hi chars
                CMP #charLF:  		BEQ printLFText
                CMP #charCR:  		BEQ printCRText
                CMP #charSPC: 		BCC printSPCText
                CMP #charDEL: 		BEQ printDELText
                JMP addCharToPrintBuffer

.printSPCText    
		PHA
                LDA #'^'              				\ Char "^" (indicates a space character)
                JSR addCharToPrintBuffer
                PLA: CLC: ADC #&40
                JMP addCharToPrintBuffer

.printDELText    
		LDA #'<': JSR addCharToPrintBuffer                
                LDA #'D': JSR addCharToPrintBuffer
                LDA #'E': JSR addCharToPrintBuffer
                LDA #'L': JSR addCharToPrintBuffer
                LDA #'>': JMP addCharToPrintBuffer

.printLFText     
		LDA #'<': JSR addCharToPrintBuffer
                LDA #'L': JSR addCharToPrintBuffer
                LDA #'F': JSR addCharToPrintBuffer
                LDA #'>': JMP addCharToPrintBuffer

.printCRText     
		LDA #'<': JSR addCharToPrintBuffer
                LDA #'C': JSR addCharToPrintBuffer
                LDA #'R': JSR addCharToPrintBuffer
                LDA #'>': JSR addCharToPrintBuffer
                LDA #charCR: JMP addCharToPrintBuffer

.addCharToPrintBuffer 
		STA tempPrintCharVar97
                TXA: PHA
                LDX printerBufferCharLength
                LDA tempPrintCharVar97: STA printBuffer,X
                INX
                CPX printerBufferCharPointer
                BNE updatePrintBufferLength
                INC printerBufferCharPointer
                LDX printerBufferCharPointer
                LDA #'?':STA printBuffer,X
                INX
                LDA #charCR: STA printBuffer,X
                INX
                LDA #charLF: STA printBuffer,X
.updatePrintBufferLength
		INC printerBufferCharLength
                PLA: TAX
                LDA tempPrintCharVar96
                RTS

\ ************************************************************************************************************

.end

\  ******************************************************************
\  *	Save the code
\  ******************************************************************

SAVE "TRFC1HR$.6502", start, end