\ *********************************************************************************
\ * Marconi Communications Systems Ltd                                            *
\ * SERNET Message Protocol Test Program.                                         *
\ * For the BBC Micro computer.                                                   *
\ *                                                                               *
\ * Disassembly by Dermot using the original SERNET program by Andy Mallett.      *
\ *                                                                               *
\ * SERNET Message Format:                                                        *
\ * ----------------------                                                        *
\ * AAAAA - 5 bytes of SOH used for frame alignment                               *
\ * B     - 1 byte of STX indicating Start of Transmission                        *
\ * DD    - 2 bytes: hex characters indicating length of message (DD+EE+Fn)       *
\ * EE    - 2 bytes: hex chars indicating message number/counter (&00 to &FF)     *
\ * Fn    - n bytes: Text content of message.                                     *
\ * GG    - 2 bytes: hex chars indicating checksum MSB (sum of bytes DD+EE+Fn)    *
\ * HH    - 2 bytes: hex chars indicating checksum LSB (sum of bytes DD+EE+Fn)    *
\ * C     - 1 byte of ETX indicating End of Transmission                          *
\ * I     - 1 byte of CR indicating Carriage Return                               *
\ * J     - 1 byte of LF indicating Line Feed                                     *
\ *                                                                               *
\ * Serial Port Config:								  *
\ * -------------------								  *
\ * 9600 baud Tx and Rx								  *
\ * 1 Start bit									  *
\ * 7 Data bits									  *
\ * Even Parity									  *
\ * 1 Stop bit									  *
\ * RTS/CTS handshaking								  *
\ *                                                                               *
\ * Control Keys:								  *
\ * -------------								  *
\ * TAB ............ : insert/overwrite                                           *
\ * DELETE ......... : delete backwards                                           *
\ * COPY ........... : delete forwards                                            *
\ * CURSOR UP ...... : increment tx number                                        *
\ * CURSOR DOWN .... : unchanging tx number                                       *
\ *                                                                               *
\ * Use BEEBASM for assembly                                                      *
\ *********************************************************************************

\*** CONSTANTS ********************************************************************
charNUL 			= &00			\ NUL
charSOH 			= &01			\ SOH - Start of Heading
charSTX 			= &02			\ SOT - Start of Text
charETX 			= &03			\ EOT - End of Txt
charEOT 			= &04			\ ETX - End of Transmission
charENQ 			= &05			\ ENQ - Enquiry
charACK 			= &06			\ ACK - Acknowledge
charBEL 			= &07			\ BEL - Bell character
charHTAB 			= &09			\ HT - Horizontal TAB char
charLF 				= &0A			\ LF - Line feed character code
charCR 				= &0D			\ CR - Carriage Return character code
charNAK 			= &15			\ NAK - Negative Acknowledge
charSpace 			= &20			\ SPC - SPACE character
char0 				= &30			\ "0" (&30) = end of string
charDEL 			= &7F			\ DEL - DELETE character
char252 			= 252			\ Custom character 252
char253 			= 253			\ Custom character 253
char254 			= 254			\ Custom character 254
char255 			= 255			\ Custom character 255

windowMainTitle			= 0			\ Window number for Main Title
windowMessageEditor		= 1			\ Window number for Message Editor
windowTransmittedMessages	= 2			\ Window number for Transmitted Messages
windowReceivedMessages		= 3			\ Window number for Received Messages
numOfWindows			= 4			\ Number of text windows

maxMessageLength		= &32			\ Max length of messages = 50 chars
textLineLength			= 80			\ Line length (80 chars)

\*** Variables ******************************************************************************************
tempVar1			= &70			\ general variable 1
action_Ins_overwrite		= &71			\ TAB key action: &00=Insert; &FF=Overwrite
messageCharPointer		= &72			\ Pointer to char in messageBuffer
transmitMessageBufferPointer	= &73			\ Pointer to char in transmitMessageBuffer
noChars423OutputBuffer		= &74			\ No of chrs remaining in RS423 O/P buffer (minus 4)
txCheckSumLoByte		= &75			\ Sum of ascii values of message chars (low byte) stored as two byte hex chars
txCheckSumHiByte		= &76			\ Sum of ascii values of message chars (high byte) stored as two byte hex chars
messageCounterFlag 		= &77			\ Nominal message counter indicator. 1=On, 0=Off
receiveMessageBufferPointer 	= &78			\ Pointer to char in receiveMessageBuffer
rxMessageLength 		= &79			\ Length of Rx message text
RxCharStatus 			= &7A			\ Status of char received from 423
rxChecksumLoByte 		= &7B			\ Lo byte of Rx Checksum
rxChecksumHiByte 		= &7C			\ Hi byte of Rx checksum
rxMessageFieldValue 		= &7D			\ Value of char field in Rx Message
skipCounterIncrement 		= &7E			\ 1=skip increment,0=increment
messageBuffer			= &2908			\ MessageBuffer
transmitMessageBuffer 		= &2960			\ Buffer for transmit message.
transmitMessageTextBuffer 	= &2968			\ Text part of Tx message buffer (excludes SOH/STX/lenTxMessage)
winCursorXPos			= &29F0			\ Array of cursor X positions for window(X reg)
winCursorYPos			= &29F8			\ Array of cursor Y positions for window(X reg)
receiveMessageBuffer 		= &2A00			\ Buffer for received messages

\*** OS Call definitions *******************************************************************************
OSRDCH 				= &FFE0			\ Read character from current i/p stream
OSWRCH 				= &FFEE			\ Write character to current o/p stream
OSBYTE 				= &FFF4			\ Perform miscellaneous OS operation using registers to pass parameters

\*** Set Start address *********************************************************************************
ORG &1902

.start
\*** Entry point of SER9600 ****************************************************************************
.MainEntry
		LDA #&03:JSR OSWRCH            			\ VDU 3 - Disable printer
                LDA #&E5: LDX #&01: JSR OSBYTE			\ *FX 229,1 - Treat Escape key as ASCII character 27 (&1B)
                LDA #&04: LDX #&01: JSR OSBYTE			\ *FX 4,1 - Disable cursor editing - keys return codes &87 to &8B
                LDA #&E1: LDX #&A0: LDY #&00: JSR OSBYTE	\ *FX 225, 160 - user defined codes for functions keys starting F0=160 (&A0)
                LDA #&0C: LDX #&04: JSR OSBYTE			\ *FX 12, 4 - set keyboard auto repeat rate to 0.4 seconds
                LDA #&90: LDX #&00: LDY #&01: JSR OSBYTE	\ *FX 144, 0, 1 (*TV 0,1) - TV interlace off.
                LDA #&03: STA tempVar1
.loopFX19
		LDA #&0D: LDX tempVar1: LDY #&00: JSR OSBYTE	\ *FX 13, 4 to 9 - disable events.
                INC tempVar1
                LDA tempVar1: CMP #&0A
                BNE loopFX19
                
\********************************************************************************************************
\* VDU Data write loop.
\* Data in VDUData1 to VDUData8
\* Equivalent:
\*  VDU 22, 0 (MODE 0) (640 x 256, 2 colours, 80 x 32 text)
\*  VDU 19, 0, 4, 0, 0, 0 (Set logical colour 0 to 4 - i.e changes black background to blue background)
\*  VDU 19, 1, 4, 0, 0, 0 (Set logical colour 1 to 4 i.e. changes white text to blue)
\*  VDU 23, 255, 170, 170, 170, 170, 170, 170, 170, 0 (reprogram chr 255 to display this)
\*  VDU 23, 254, 170, 170, 170, 170, 170, 170, 170, 170 (reprogram chr 254 to display this)
\*  VDU 23, 252, 99, 82, 74, 75, 74, 82, 99, 00 (reprogram chr 252 to display this)
\*  VDU 23, 253, 208, 16, 16, 144, 16, 16, 222, 0 (reprogram chr 253 to display this)
\*  VDU 31, 0, 31 (move text cursor to 0, 31)
\********************************************************************************************************
                LDX #&00
.loopVDUData
		LDA vduData1,X: JSR OSWRCH			\ Write the VDU data
                INX: CPX #&39
                BNE loopVDUData
\  *** End of VDU Data write loop ***********************************************************************

                JSR cursorOff         				\ VDU 23, 1, 0; 0; 0; 0; (cursor off)
                LDA #char254: JSR write80Chrs       		\ VDU 254 eighty times (one screen line of customer chr 254)
                LDA #&1E: JSR OSWRCH            		\ VDU 30 (move text cursor to top left of text area)
                LDA #&0B: JSR OSWRCH            		\ VDU 11 (Move cursor up one line) - puts cursor at start of line

\ *** Print titles of the four screen areas ************************************************************
		LDX #&00
.loopPrintTitles
		JSR printTitles      				\ Print 4 text Titles to the screen at 4 different places
                INX: CPX #numOfWindows
                BNE loopPrintTitles
                
\*** Reinstate white text ******************************************************************************
                LDX #&00
.loopVDU19      
		LDA vduData9,X: JSR OSWRCH			\ VDU 19, 1, 7, 0, 0, 0 (changes logical colour 1 to 7 (text to white))
                INX: CPX #&06
                BNE loopVDU19
                
\*** Set first 2 chrs of message to "00" ***************************************************************
\ (not sure why this is necessary - resets sequence number maybe?
.initStartofFrameChars 
		LDX #&FF        				\ Initialise X for loop counter
.loopMessageHeader 
		INX
                LDA strMessageHeader,X
                STA messageBuffer,X
                BNE loopMessageHeader
                
\*** Clear Rx Message Buffer *****************************************************************************
                LDA #&00: TAX
.loopFillRxMessBuff1 
		STA receiveMessageBuffer,X 			\ Initialise/clears Rx Mess Buff to all 00
                INX: BNE loopFillRxMessBuff1
\*** Set Rx Message Buffer pointer to default ************************************************************
		LDA #&00
                STA receiveMessageBufferPointer

\*** Set Rx Char Status to default ***********************************************************************
\*** RxCharStatus holds current assessed rx character. If this is 00 then ready for new message          *
\*** to be assessed. If this is ETX then complete message received.                                      *
.setDefaultRxCharStatus 
		LDA #&00
                STA RxCharStatus

.setDefaultSkipCounterIncToOff 
		LDA #&00
                STA skipCounterIncrement			\ Message Counter not used when ACK or NACK messages constructed.

\*** Clear array holding current text cursor positions for each message window ***************************
.zeroWinCursorPosArray 
		LDX #&06
                LDA #&00
.loopZeroCursorXY 
		STA winCursorXPos,X
                STA winCursorYPos,X
                DEX
                BPL loopZeroCursorXY

                SEI
                LDA #&15: LDX #&00: JSR OSBYTE			\ *FX 21, 0 (flush keyboard buffer)
                LDX #&01: JSR OSBYTE            		\ *FX 21, 1 (RS423 input buffer emptied)
                LDX #&02: JSR OSBYTE            		\ *FX 21, 2 (RS423 output buffer emptied)
                LDA #&80: LDX #&FD: LDY #&FF: JSR OSBYTE	\ *FX 128, 253 (Y=255) (Get no of chrs remaining in RS423 output buffer)
                TXA
                SEC
                SBC #&04
                STA noChars423OutputBuffer
                CLI
                
                LDA #&02: LDX #&02: JSR OSBYTE			\ *FX 2, 2 (Select input stream - keyboard selected, RS423 enabled)

.setRxBaud9600   
		LDA #&07: LDX #&07: JSR OSBYTE			\ *FX 7, 7 (Set RS423 receive baud rate to 9600)

.setTxBaud9600
		LDA #&08: LDX #&07: JSR OSBYTE			\ *FX 8, 7 (Set RS423 transmit baud rate to 9600)

.set7E1Parity    						
		LDA #&9C: LDX #&00: LDY #&FF: JSR OSBYTE	\ *FX 156, 0, 255 (Read 6850 ACIA status register - valued returned in X)
                TXA                   				\ X = Manipulated 6850 ACIA control reg bits.
                AND #&E3					\ Equiv: AND %1110 0011
                ORA #&08					\ Equiv: OR %0000 1000
                TAX
                LDA #&9C
                LDY #&00
                JSR OSBYTE            				\ Sets Sheila &08 CR2/3/4 to 010 (7 bit even parity 1 stop)

.initVars        
		LDA #&00					\ Setup vars
                STA action_Ins_overwrite
                
.setDefaultMessCounterInc_Off 
		LDA #&00
                STA messageCounterFlag 				\ Default to don't increment message counter
                LDA #&02
                STA messageCharPointer
                LDA #&FF
                STA transmitMessageBufferPointer		\ Set pointer &FF to indicate message is not constructed/formatted
                JMP displayMessage

\*****************************************************************************************************
\*** MAIN EVENT LOOP *********************************************************************************
\*****************************************************************************************************
.mainEventLoop   
		LDX #windowMessageEditor
                JSR setupTextWindows  				\ Set up a text window (Message Editor)
                LDA #&1F: JSR OSWRCH   				\ VDU31,X,Y - move cursor to last chr of message
                LDA #&01: CLC
                ADC messageCharPointer: JSR OSWRCH
                LDA #&00: JSR OSWRCH				\ *** End of VDU31...
                JSR cursorOn          				\ Turn on cursor (VDU23,1,1\0\0\0\)
                
.chrInputLoop   
		LDA transmitMessageBufferPointer		\ Check if Transmit Message is constructed/formatted
                CMP #&FF
                BEQ checkRxCharStatusReady
                LDA #&80: LDX #&FD: LDY #&FF: JSR OSBYTE        \ *FX 128, 253, 255 (Read no of chrs remaining in RS423 output buffer)
                CPX noChars423OutputBuffer
                BCC readChrs423InputBuffers
                JMP transmitMessageRS423

.checkRxCharStatusReady 
		LDA RxCharStatus
                CMP #&00
                BEQ readChrs423InputBuffers
                JSR checkIfETXorEOT
                JMP chrInputLoop

.readChrs423InputBuffers 
		LDA #&80: LDX #&FE: LDY #&FF: JSR OSBYTE        \ *FX 128, 254, 255 (Read no of chrs in RS423 input buffer)
                CPX #&00
                BEQ readChrsKeyboardInputBuffers
                JMP read423Chr

.readChrsKeyboardInputBuffers 
		LDA #&80: LDX #&FF: LDY #&FF: JSR OSBYTE        \ *FX 128, 255, 255 (Read no of chrs in keyboard buffer)
                CPX #&00
                BEQ chrInputLoop      				\ No chars in buffers so back to wait loop
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
                LDA #&FF
                STA transmitMessageBufferPointer
                LDA #charLF
.notNewLine      
		PHA                   				\ Not new line chr so send it to RS423
                TAY
                LDA #&8A: LDX #&02: JSR OSBYTE            	\ *FX 138, 2, Y (Insert chr into RS423 output buffer)
                PLA
                JSR controlChrHandler
                LDA transmitMessageBufferPointer
                CMP #&FF
                BEQ checkSkipCounterIncrement
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
                LDA #&00              				\ Set don't skip Message Counter increment
                STA skipCounterIncrement
                JMP getTransMessCursorPos

.incrementMessageCounter 
		LDA messageCounterFlag 				\ Check if message counter needs incrementing
                BEQ getTransMessCursorPos 			\ No - incrementing turned off
                LDX #windowTransmittedMessages 			\ Yes - incrementing turned on
                JSR storeTextCursorPosition
                LDA messageBuffer+1
                JSR incHexChr
                STA messageBuffer+1
                CMP #char0
                BNE jumpToDisplayMessage
                LDA messageBuffer
                JSR incHexChr
                STA messageBuffer

.jumpToDisplayMessage 
		JMP displayMessage

\ *** incHexChr ******************************************************
\ Routine to increment a Hex displayed as a character.
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
		LDA #'A'              				\ Set chr = A and return (9+1=A in hex)
                JMP incHexChrRTS
.charIsOverF     
		LDA #'0'             	 			\ Set chr = 0 and return
                JMP incHexChrRTS
.charIsLess9     
		CLC
                ADC #&01
.incHexChrRTS    
		RTS                   				\ Return with A+1 (incremented in Hex)

\*** read423Chr *********************************************************************
\ Reads a character from RS423 input stream
\************************************************************************************
.read423Chr      
		JSR cursorOff
                LDX #windowReceivedMessages
                JSR setupTextWindows  				\ Received Messages window
                LDA #&02: LDX #&01: JSR OSBYTE            	\ *FX 2, 1 (RS423 input stream selected & enabled)
.readInputChr    
		JSR OSRDCH            				\ Read character from RS423 input stream
                JSR processRS423Input
.check423InputBuffer 
		JSR controlChrHandler
                LDA #&80: LDX #&FE: LDY #&FF: JSR OSBYTE        \ *FX 80, 254, 255 (Get no of chrs in RS423 input buffer)
                CPX #&00
                BNE readInputChr
                LDX #windowReceivedMessages
                JSR storeTextCursorPosition
                JMP mainEventLoop     				\ Return to start of main event loop
\************************************************************************************

.readKeyboardChr 
		LDA #&02: LDX #&02: JSR OSBYTE            	\ *FX 2,2 (Select input stream - keyboard selected RS423 enabled)
                JSR OSRDCH            				\ Read chr from input stream
                CMP #charCR           				\ Is it Enter/Return char?
                BNE chkForLeftArrow
                JMP crHandler

.chkForLeftArrow 
		CMP #&88
                BNE chkForRightArrow
                JMP leftArrowHandler

.chkForRightArrow 
		CMP #&89
                BNE chkForUpArrow
                JMP rightArrowHandler

.chkForUpArrow   
		CMP #&8B
                BNE chkForDownArrow
                LDA #&01              				\  Turn on message counter incrementing
                STA messageCounterFlag
                JMP mainEventLoop

.chkForDownArrow 
		CMP #&8A
                BNE chkForValidHexChar

.downArrowHandler 
		LDA #&00             				\ Turn off message counter incrementing
                STA messageCounterFlag
                JMP mainEventLoop

.chkForValidHexChar 
		LDX messageCharPointer 				\ Checks char is correct range for hex number
                CPX #&02
                BCS chkForHTAB
                CMP #'0'	              			\ Is it >= "0"
                BCC skipToBeep
                CMP #'F'	              			\ Is it <= "F"
                BCS skipToBeep
                CMP #'9'	              			\ Is it <= "9"
                BCC hexCharInRange
                CMP #'A'	              			\ Is it >= "A"
                BCS hexCharInRange
                JMP skipToBeep        				\ Not a Hex character so beep and return to main event loop

.chkForHTAB      
		CMP #charHTAB
                BNE chkForSpace
                JMP HTABHandler

.chkForSpace     
		CMP #charSpace
                BCC skipToBeep

.chkForBackspace 
		CMP #charDEL
                BCC backspaceHandler
                BNE chkForCopy
                JMP checkForStartOfMessage

.chkForCopy      
		CMP #&87
                BNE skipToBeep
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
                BCC shift1CharToRight 				\ Max message length?
                PLA
                JMP makeBeepSound

.shift1CharToRight 
		LDA messageBuffer,X
                INX: STA messageBuffer,X
                DEX: DEX
                CPX messageCharPointer
                BCS shift1CharToRight
                INX
                PLA
                STA messageBuffer,X
                JMP rightArrowHandler

.checkForStartOfMessage 
		LDX messageCharPointer
                CPX #&03
                BCS shift1CharToLeft  				\ Char pointer is >=3
                JMP makeBeepSound

.shift1CharToLeft 
		LDA messageBuffer,X
                DEX: STA messageBuffer,X
                INX: INX
                CMP #&00
                BNE shift1CharToLeft  				\ Char pointer is >0
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
                CMP #&00
                BNE moveChrLeft
                JMP displayMessage

.leftArrowHandler 
		LDX messageCharPointer 				\ Left arrow key pressed
                BEQ skipToMakeBeep
                CPX #&02              				\ Check cursor is not at start of editable message
                BNE moveCursorToLeft
                LDA #&CA: LDX #&00 :LDY #&FF :JSR OSBYTE        \ *FX 202, 0, 255 (set keyboard status byte - CAPS LOCK?)
                TXA
                AND #&08
                BEQ skipToMakeBeep    				\ CAPS LOCK is on?

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
		JMP makeBeepSound				\ Make beep sound and return to main event loop

.HTABHandler     						\ Toggles insert/overwrite action when TAB pressed
		LDA action_Ins_overwrite
                BNE skip4
                INC action_Ins_overwrite
                JMP mainEventLoop

.skip4          LDA #&00
                STA action_Ins_overwrite
                JMP mainEventLoop

.displayMessage  
		JSR cursorOff
                LDX #windowMessageEditor
                JSR setupTextWindows  				\ Turn off cursor (VDU23,1,0\0\0\0\)
                LDA #&1F: JSR OSWRCH            		\ Set up a text window
                LDA #&01: JSR OSWRCH
                LDA #&00: JSR OSWRCH            		\ VDU 31, 0, 1 (move text cursor to 0, 1)
                LDX #&FF
.loopNotEndofMessage 
		INX
                LDA messageBuffer,X
                JSR OSWRCH					\ Display message being edited
                BNE loopNotEndofMessage
                LDA #charSpace
                JSR OSWRCH
                JMP mainEventLoop     				\ Back to main event loop

.crHandler       
		LDA transmitMessageBufferPointer
                CMP #&FF					\ If transmit message is not formatted start doing so
                BEQ LoadSOH_TxMessageBuffer
                JMP mainEventLoop

.LoadSOH_TxMessageBuffer 					\ Insert 5x SOH and STX in transmit message buffer
		LDX #&00
                LDA #charSOH
.loopLoadSOH     
		STA transmitMessageBuffer,X
                INX
                CPX #&05
                BNE loopLoadSOH
.LoadSTX_TxMessageBuffer 
		LDA #charSTX
                STA transmitMessageBuffer,X
                INX
                LDX #&FF
.loopTransferMessageToTxBuffer 					\ Add edited message to transmit message buffer
		INX
                LDA messageBuffer,X
                STA transmitMessageTextBuffer,X
                BNE loopTransferMessageToTxBuffer
                DEX: TXA
                CLC: ADC #&09
                PHA
                SEC: SBC #&06
.InsertMessageCounter 
		LDX #&06         				\ Converts the message counter to two Ascii chars and stores in the transmit message buffer
                JSR convertTo2ByteAscii
                PLA
                PHA
                TAX
.CalculateTxMessageChecksum 					\ Calculates checksum for transmit message
		LDA #&00
                STA txCheckSumLoByte
                STA txCheckSumHiByte
.startTxMessageChecksum 
		DEX
                CPX #&05
                BEQ constructTxMessageTrailer
                LDA transmitMessageBuffer,X
                CLC
                ADC txCheckSumLoByte
                STA txCheckSumLoByte
                BCC startTxMessageChecksum
                INC txCheckSumHiByte
                JMP startTxMessageChecksum

.constructTxMessageTrailer 
		PLA         					\ Formats Message trailer (inserts checksum,ETX,CR,LF)
                TAX
                LDA txCheckSumHiByte
                JSR convertTo2ByteAscii
                LDA txCheckSumLoByte
                JSR convertTo2ByteAscii
                LDA #charETX          				\ Insert End of Text character into message
                STA transmitMessageBuffer,X
                INX
                LDA #charCR           				\ Insert CR into message
                STA transmitMessageBuffer,X
                INX
                LDA #charLF           				\ Insert LF into message
                STA transmitMessageBuffer,X
                LDA #&00					\ Reset message buffer pointer
                STA transmitMessageBufferPointer
                JMP mainEventLoop     				\ Back to main loop

.convertTo2ByteAscii 
		PHA               				\ Convert char values to 2 byte hex charsand store in the message
                LSR A: LSR A: LSR A: LSR A			\ Shift LS 4 bits to MS 4 bits
                JSR convertLoByte
                PLA
                AND #&0F					\ Mask off LS 4 bits
.convertLoByte  CMP #&0A
                BCC isCharAtoF
                CLC
                ADC #&07
.isCharAtoF     CLC
                ADC #&30
                STA transmitMessageBuffer,X
                INX
                RTS

.checkIfETXorEOT						\ Prepares ACK if Rx message valid or NACK if not valid
		LDA RxCharStatus
                CMP #charNUL          				\ NUL received so ignore & return
                BEQ clearRxChar
                CMP #charETX					\ ETX received so prepare ACK message
                BEQ constructACKMessage
                CMP #charEOT					\ EOT received so prepare NAK message
                BEQ constructNAKMessage
                CMP #charSOH          				\ SOH received so ignore & return
                BEQ clearRxChar
                CMP #charSTX          				\ STX received so ignore & return
                BEQ clearRxChar
                CMP #charENQ          				\ ENQ received so ignore & return
                BEQ clearRxChar
                JMP clearRxChar

.constructACKMessage 
		LDX #&FF
.loopReadAckMessageData 
		INX
                LDA AckMessageData,X
                STA transmitMessageBuffer,X
                CMP #charLF           				\ End of Ack Message Datablock reached?
                BNE loopReadAckMessageData 			\ No: go back and loop
                JMP skipMessageCounterIncrement

.constructNAKMessage 
		LDX #&FF
.loopReadNAKMessageData 
		INX
                LDA NAKMessageData,X
                STA transmitMessageBuffer,X
                CMP #charLF           				\ End of NAK Message Datablock reached?
                BNE loopReadNAKMessageData 			\ No: go back and loop
                JMP skipMessageCounterIncrement

\ ***  skipMessageCounterIncrement ******************************
\ * Set flag to skip message counter increment when ACK or NAK message is
\ * constructed
\ ***************************************************************
.skipMessageCounterIncrement 
		LDA #&01
                STA skipCounterIncrement
                LDA #&00
                STA transmitMessageBufferPointer
.clearRxChar   
		LDA #charNUL
                STA RxCharStatus
                RTS

\ACK Message:   {SOH}{SOH}{SOH}{SOH}{SOH}{STX},"0","3",{ACK},"0","0","6","9",{ETX}{CR}{LF}
.AckMessageData  EQUB &01,&01,&01,&01,&01,&02,&30,&33,&06,&30,&30,&36,&39,&03,&0D,&0A
\NAK Message:   {SOH}{SOH}{SOH}{SOH}{SOH}{STX},"0","3",{NAK},"0","0","7","8",{ETX}{CR}{LF}
.NAKMessageData  EQUB &01,&01,&01,&01,&01,&02,&30,&33,&15,&30,&30,&37,&38,&03,&0D,&0A

.processRS423Input
		PHA                 				\ Process RS423 input
                CMP #charSOH          				\ Is is Start of Header?
                BEQ chrIsSOH
                CMP #charSTX          				\ Is it Start of Text?
                BEQ charIsSTX
                LDX receiveMessageBufferPointer
                STA receiveMessageBuffer,X 			\ Store chr in Rx buffer
                CMP #charLF           				\ Is it Line Feed?
                BNE checkForNextChar 				\ No so check for next chr
                JSR checkCorrectRxMessageFormat
.chrIsSOH       LDA #&00              				\ SOH so set Rx message pointer to 0
                STA receiveMessageBufferPointer
                JMP endProcess423Input

.charIsSTX      STA receiveMessageBuffer 			\ STX so store in 1st char of message buffer
                LDA #&01              				\ Message pointer to 1st char of Rx message text
                STA receiveMessageBufferPointer
                JMP endProcess423Input

.checkForNextChar 
		INC receiveMessageBufferPointer
.endProcess423Input 
		PLA: RTS

.checkCorrectRxMessageFormat 
		LDX receiveMessageBufferPointer
                LDA receiveMessageBuffer,X
                CMP #charLF           				\ Check for Line Feed?
                BNE RxMessageFormatError 			\ No, so set Rx status char to ENQ
                DEX                   				\ Move back one char
                LDA receiveMessageBuffer,X
                CMP #charCR           				\ Check for CR?
                BNE RxMessageFormatError 			\ No, so set Rx status char to ENQ
                DEX                   				\ Move back one char
                LDA receiveMessageBuffer,X
                CMP #charETX          				\ Check for ETX?
                BNE RxMessageFormatError 			\ No, so set Rx status char to ENQ
                STX receiveMessageBufferPointer 		\ ETX found, store char pointer
                LDA receiveMessageBuffer 			\ Check 1st char in message is STX
                CMP #charSTX          				\ Check for STX?
                BNE RxMessageFormatError 			\ No, so set Rx status char to ENQ
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
.loopCheckRxCheckSumMatch					\ Calculates Checksum of Rx message message and compares with received
		LDA rxChecksumLoByte
                SEC
                SBC receiveMessageBuffer,X
                STA rxChecksumLoByte
                LDA rxChecksumHiByte
                SBC #&00
                STA rxChecksumHiByte
                DEX
                BNE loopCheckRxCheckSumMatch
                LDA rxChecksumLoByte
                BNE setRxCharToEOT    				\ EOT if chksum doesn't match
                LDA rxChecksumHiByte
                BNE setRxCharToEOT    				\ EOT if chksum doesn't match
.checkMaxMessageLength
		LDA rxMessageLength 				\ Check message length <=50 chars
                CMP #maxMessageLength+1
                BCS setRxCharToEOT    				\ EOT if max message length exceeded
.checkIfSequenceNoPresent					\ Check if message counter is in message
                CMP #&04					\ Message length >= 4?
                BCS getRxMessageSequenceNo			
.checkIfAckOrNak
		CMP #&03					\ Check if ack or nak message
                BNE setRxCharToEOT
                LDA receiveMessageBuffer+3
                CMP #charACK
                BEQ setRxCharToSOH
                CMP #charNAK
                BEQ setRxCharToSTX
                JMP setRxCharToEOT

.getRxMessageSequenceNo
		LDX #&03       					\ Sequence number in rxMessageFieldValue - no action
                JSR getNumberFromRxMessageChars
                BCS setRxCharToEOT    				\ EOT if error
                LDX rxMessageLength
                JMP checkRxMessageForCtrlChar

.loopCheckRxMessageForCtrlChar
		LDA receiveMessageBuffer,X
                CMP #charDEL
                BCS setRxCharToEOT
                CMP #charSpace
                BCC setRxCharToEOT
                DEX

.checkRxMessageForCtrlChar					\ Ensure message content does not contain a control char
		CPX #&05
                BCS loopCheckRxMessageForCtrlChar
                JMP setRxCharToETX    				\Rx Message format is all correct so set status to ETX

.setRxCharToENQ  
		LDA #charENQ
                JMP setRxCharStatus

.setRxCharToEOT  
		LDA #charEOT
                JMP setRxCharStatus

.setRxCharToSOH  
		LDA #charSOH
                JMP setRxCharStatus

.setRxCharToSTX  
		LDA #charSTX          				\ Set RxChar status to STX
                JMP setRxCharStatus

.setRxCharToETX  
		LDA #charETX          				\ Set RxChar status to ETX
                JMP setRxCharStatus

.setRxCharStatus 
		STA RxCharStatus
                RTS

\**********************************************************************************************************
\*** getNumberFromRxMessageChars **************************************************************************
\*** Converts two hex chars at position X in the receive message buffer and stores in rxMessageFieldValue *
\*** Returns with carry clear if sucessful, or carry set if error
\**********************************************************************************************************
.getNumberFromRxMessageChars 
		LDA receiveMessageBuffer,X
                JSR convertHexCharToNumber 			\ Is char is in Ascii HEX range (0 to 9, A to F)?
                BCS HighCharNotHex   				\ Out of range
                ASL A
                ASL A
                ASL A
                ASL A
                STA rxMessageFieldValue
                INX
                LDA receiveMessageBuffer,X
                JSR convertHexCharToNumber
                BCS LowCharNotHex
                ORA rxMessageFieldValue
                INX
                CLC: RTS                  			\ Hex chars found so no error flag and return

.HighCharNotHex INX
.LowCharNotHex  INX
                SEC: RTS                   			\ Not HEX char so Carry flags an error
\**********************************************************************************************************

.convertHexCharToNumber						\ Check char is in Ascii HEX range (0 to 9, A to F)
		CMP #'0'       					
                BCC hexOutOfRange
.checkForCharA  
		CMP #'A'
                BCS checkForCharF
.checkForChar9  
		CMP #':'
                BCS hexOutOfRange
                SEC
                SBC #&30              				\ Convert hex char (0 to 9) to number and return
                CLC
                RTS                   				\ Return - hex char converted to number in A

.checkForCharF  
		CMP #'G'
                BCS hexOutOfRange
                SEC
                SBC #&37              				\ Convert hex char (A to F) to number and return
                CLC
                RTS                   				\ Return - hex char converted to number in A

.hexOutOfRange   
		SEC: RTS

.controlChrHandler 
		AND #&7F            				\ Mask out Ascii chars above 127
                CMP #charLF
                BEQ printNewLine
                CMP #charCR
                BEQ printCR
                CMP #charSpace
                BCC printSOH_STX_Chars
                CMP #charDEL
                BEQ printDEL
                JSR OSWRCH
                RTS
.printSOH_STX_Chars 
		CLC
                ADC #&40              				\ If SOH or STX invert text colour and print A or B
                JSR setTextInverted
                JSR OSWRCH
                JSR setTextNormal
                RTS
.printCR        
		JMP OSWRCH
.printNewLine   
		JMP OSWRCH
.printDEL       
		JSR setTextInverted
                LDA #char252: JSR OSWRCH
                LDA #char253: JSR OSWRCH            		\ VDU 252: VDU 253 (reprogrammed chrs to display "DEL")
                JSR setTextNormal
                RTS
.setTextNormal   						\ Sets white text on blue background
		PHA                   				
                LDA #&11: JSR OSWRCH
                LDA #&01: JSR OSWRCH            		\ VDU 17, 1 (Change text foreground colour to white)
                LDA #&11: JSR OSWRCH
                LDA #&80: JSR OSWRCH            		\ VDU 17, 128 (Change text background colour to blue)
                PLA
                RTS

.setTextInverted 						\ Sets blue text on white background
		PHA                   
                LDA #&11: JSR OSWRCH
                LDA #&00: JSR OSWRCH            		\ VDU 17, 0 (Change text foreground colour to blue)
                LDA #&11: JSR OSWRCH
                LDA #&81: JSR OSWRCH            		\ VDU 17, 129 (Change text background colour to white)
                PLA
                RTS

.setupTextWindows 
		LDA #&1A: JSR OSWRCH            		\ VDU 26 (return graphics & text windows to defaults)
                LDA #&1C: JSR OSWRCH            		\ VDU 28, 0, x1, 79, (x2 + 2)
                LDA #&00: JSR OSWRCH
                LDA windowBottomY,X: JSR OSWRCH
                LDA #&4F: JSR OSWRCH
                LDA windowTopY,X
                CLC: ADC #&02: JSR OSWRCH            		\ **** End of VDU 28... ****

.VDU31           						\ VDU 31, cursor X,Y. Move text cursor to X,Y
		LDA #&1F: JSR OSWRCH
                LDA winCursorXPos,X: JSR OSWRCH
                LDA winCursorYPos,X: JSR OSWRCH            	\ **** End of VDU31... ****
                RTS

.printTitles     						\ Subroutine to set up a text window and print a screen label
		TXA: PHA
                LDA #&1A: JSR OSWRCH            		\ VDU 26 (restore default graphics & text windows)
                
                LDA #&1F: JSR OSWRCH             		\ VDU 31, 0, x-1 (move text cursor to 0,x-1)
                LDA #&00: JSR OSWRCH
                LDA windowTopY,X: SEC: SBC #&01: JSR OSWRCH     \ *** End of  VDU 31... ****
                
                LDA #char255
                JSR write80Chrs       				\ Write one line of custom Char 255
                
                LDA #&1C: JSR OSWRCH              		\ VDU 28, 0, x1, 79, x2 (set a text window)
                LDA #&00: JSR OSWRCH
                LDA windowBottomY,X: JSR OSWRCH
                LDA #&4F: JSR OSWRCH
                LDA windowTopY,X: JSR OSWRCH            	\ *** End of VDU28...
                
                LDA #&0C: JSR OSWRCH            		\ VDU 12 (clear text area)
                LDA #&1E: JSR OSWRCH            		\ VDU 30 (home text cursor to top of window)
                TXA
                BEQ loopWrChr2
                TAY
                LDX #&FF

.loopWrChr1     
		INX
                LDA strTitle1,X
                BNE loopWrChr1
                DEY
                BNE loopWrChr1
                INX

.loopWrChr2     
		LDA strTitle1,X
                INX
                JSR OSWRCH            				\ Print chrs from strTitle1 (offset by X) until a termination zero is located
                BNE loopWrChr2
                PLA
                TAX
                RTS                   				\ End of printTitles

\ ***  storeTextCursorPosition  *******************************
\ Gets the current text window cursor positions and
\ stores in WinCursorXPos and WinCursorYPos
\ *************************************************************
.storeTextCursorPosition 
		LDA tempVar1  					\ save current temp1 value
                PHA
                STX tempVar1           				\ temporarily save window number
                LDA #&86: JSR OSBYTE            		\ *FX 134 (Read text cursor position)
                TXA                   				\ X = HPOS
                LDX tempVar1          				\ restore window number
                STA winCursorXPos,X   				\ Store text horizontal cursor position winCursorXPos array
                TYA
                STA winCursorYPos,X   				\ Store text vertical cursor position in winCursorYPos array
                PLA
                STA tempVar1          				\ restore tempVar1 value
                RTS                   				\ End of getTextCursorPosition

\*** cursorOff/On *******************************************************************************************
.cursorOff       
		LDA #&00              				\ If entry here then VDU 23, 1, 0; 0; 0; 0; (cursor off)
                BEQ skipCursorOn
.cursorOn        
		LDA #&01              				\ If entry here then VDU 23, 1, 1; 0; 0; 0; (cursor on)
.skipCursorOn       
		PHA
                LDA #&17: JSR OSWRCH
                LDA #&01: JSR OSWRCH
                PLA: JSR OSWRCH
                LDA #&00: LDX #&08
.Loop8Zeroes    JSR OSWRCH
                DEX: BNE Loop8Zeroes
                RTS                   				\ End of cursorOn/Off

\*** write80Chrs *******************************************************************************************
.write80Chrs     
		LDY #textLineLength   				\ Write 80 chars in A to VDU output
.loop80Chars    JSR OSWRCH
                DEY: BNE loop80Chars
                RTS                   				\ End of write80Chrs

\*** makeBeepSound ******************************************************************************************
.makeBeepSound   
		LDA #charBEL: JSR OSWRCH            		\ VDU 7 (make a short BEEP sound)
                JMP mainEventLoop     				\ Back to main event loop

\*** Data Constructs ****************************************************************************************
.vduData1        EQUB 	&16,&00         			\ VDU 22, 0 (MODE 0 - 640 x 256, 2 colours, 80 x 32 text)
.vduData2        EQUB	&13,&00,&04,&00,&00,&00 		\ VDU 19, 0, 4, 0, 0, 0 (Set logical colour 0 to 4 - i.e changes black background to blue background
.vduData3        EQUB	&13,&01,&04,&00,&00,&00 		\ VDU 19, 1, 4, 0, 0, 0 (Set logical colour 1 to 4 i.e. changes white to blue)
.vduData4        EQUB	&17,&FF,&AA,&AA,&AA,&AA,&AA,&AA,&AA,&00	\ VDU 23, 255, 170, 170, 170, 170, 170, 170, 170, 0 (reprogram chr 255)
.vduData5        EQUB	&17,&FE,&AA,&AA,&AA,&AA,&AA,&AA,&AA,&AA \ VDU 23, 254, 170, 170, 170, 170, 170, 170, 170, 170 (reprogram chr 254)
.vduData6        EQUB	&17,&FC,&63,&52,&4A,&4B,&4A,&52,&63,&00	\ VDU 23, 252, 99, 82, 74, 75, 74, 82, 99, 00 (reprogram chr 252)
.vduData7        EQUB	&17,&FD,&D0,&10,&10,&90,&10,&10,&DE,&00	\ VDU 23, 253, 208, 16, 16, 144, 16, 16, 222, 0 (reprogram chr 253)
.vduData8        EQUB	&1F,&00,&1F				\ VDU 31, 0, 31 (move text cursor to 0, 31)
.vduData9        EQUB	&13,&01,&07,&00,&00,&00 		\ VDU 19, 1, 7, 0, 0, 0 (changes logical colour 1 to 7 (white))
.windowTopY      EQUB	&01,&03,&08,&14				\ Array of Top Y coord for 4 text windows
.windowBottomY   EQUB	&01,&06,&12,&1E				\ Array of Bottom Y coord for 4 text windows
.strTitle1       EQUS 	"                THE VOICE OF AMERICA SERNET PROTOCOL TEST PROGRAM",&00
.strTitle2       EQUS	"MESSAGE EDITOR",&00
.strTitle3       EQUS	"TRANSMITTED MESSAGES",&00
.strTitle4       EQUS	"RECEIVED MESSAGES",&00
.strMessageHeader	
		 EQUS	"00",&00
\************************************************************************************************************

.end

\ ******************************************************************
\ *	Save the code
\ ******************************************************************

SAVE "SER96oo", start, end

