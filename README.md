# MCSL-SerNet

\ *********************************************************************************

\ * Marconi Communications Systems Ltd                                            *

\ * SERNET Message Protocol Test Program - used in the VOA Broadcast Transmitter  *

\ * projects.                                                                     *

\ * For the BBC Micro computer.                                                   *

\ *                                                                               *

\ * Disassembly by Dermot using the original SERNET program by Andy Mallett.      *

\ *                                                                               *

\ * SERNET serial Message Format:                                                 *

\ * -----------------------------                                                 *

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

\ * Serial Port Config:					                                          			  *

\ * -------------------								                                            *

\ * 9600 baud Tx and Rx								                                            *

\ * 1 Start bit									                                                  *

\ * 7 Data bits									                                                  *

\ * Even Parity									                                                  *

\ * 1 Stop bit									                                                  *

\ * RTS/CTS handshaking								                                            *

\ *                                                                               *

\ * Control Keys:								                                                  *

\ * -------------								                                                  *

\ * TAB ............ : insert/overwrite                                           *

\ * DELETE ......... : delete backwards                                           *

\ * COPY ........... : delete forwards                                            *

\ * CURSOR UP ...... : increment transmission number                              *

\ * CURSOR DOWN .... : unchanging transmission number                             *
\ *                                                                               *
\ * Use BEEBASM for assembly                                                      *

\ *********************************************************************************
