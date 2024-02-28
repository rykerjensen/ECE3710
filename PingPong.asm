;================================================================================================
; Program Name: pingpongproject.asm
;
;	Authors: Ryker Jensen and Benson Willie  
;
; Description:
;------------------------------------------------------------------------------------------------
;This program facilitates a two-player pingpong game on the boards available from our ECE3710 class.
;The game starts when a player serves the ball by pressing a designated button. Game settings 
;are adjusted using switches: Switches 1 and 2 set the parameters for player 1's window, while 
;switches 3 and 4 adjust for player 2's window. Switch 7 adjusts the ball's speed. Serving 
;alternates between players each game. To begin a new game, simply press the reset button.
;
; Company:
;	Weber State University 
;
; Date				Version		Description
; ----				-------		-----------
; 2/6/2024		V1.0			File Creation
; 2/10/2024		V1.1			Added Update LEDs
; 2/16/2024		V1.2			Fixed alternating start direction
; 2/23/2024   V1.3			Fixed Delay subroutines
; 2/27/2024   V1.4			Debugging and clean up code
;=================================================================================================

$include (c8051f020.inc)


dseg at 20h
position: ds 1          
direction: ds 1        
start_direction: ds 1
game_started: ds 1  
old_btns: ds 1
Buttons: ds 1
speed: ds 1


cseg 								; Disable watchdog
    mov wdtcn, #0DEh
    mov wdtcn, #0ADh
    mov xbr2, #40h

;------------------------------------------------------------------------------------------------

START:
    MOV P1, #11111111B
    MOV A, start_direction					
    CPL A							;Compliments Starting position and direction each game
    MOV start_direction, A          
    ANL A, #01h        
    JZ Start_Right      

Start_Left:
    MOV position, #1						;Sets Starting position at LED1
    clr p3.0  
    MOV direction, #1  						;Sets Starting Direction Left
    SJMP Init_Game

Start_Right:
		clr p2.1
    MOV position, #10						;Create starting position at LED10
    MOV direction, #0  						;Sets Starting Direction Right

Init_Game:
    MOV game_started, #1					;Automatically start the game upon reset
    CALL delay_10ms    
    SJMP GAME_LOOP

GAME_LOOP:    							; MAIN game loop for PING PONG
CALL Ball_Movement
CALL Update_LEDs
CALL delay_speed
CALL Check_P1_Window
CALL Check_P2_Window                
SJMP GAME_LOOP
     
;------------------------------------------------------------------------------------------------
; CHECK BUTTON SUBROUTINE:
;
; Description: 
; In these subroutines we have our check buttons from lab 3. We split our check buttons into a 
; Check_Buttons_Right and a Check_Buttons_left where they only look for there specific buttons. 
; When the buttons are pressed then it will set the direction left or right. We have the 
; Initialize_game and a start_game subroutines in order to alternate the serve at the start of 
; every round.
;------------------------------------------------------------------------------------------------
Check_btns:    
		MOV A, P2
    		CPL A
    		XCH A, old_btns				; Old_btns prevents against the hold down condition
    		XRL A, old_btns
    		ANL A, old_btns
    		orl buttons, a
    		jb acc.6, foo				; Foo was used for debugging purposes
    		RET
foo:
		ret

Check_Button_right:
    		JB buttons.6, Set_Left 		 	; Check if Button 1 is pressed
    		RET

Check_button_left:
    		JB buttons.7, Set_Right  		; Check if Button 2 is pressed
    		RET

Start_Game:
    		MOV A, game_started					
    		JZ Initialize_Game  
    		SJMP Toggle_Direction  

Initialize_Game:
    		MOV game_started, #1  			;Automatically start the game upon reset
    		MOV direction, #0  
    		RET


Toggle_Direction:
    		MOV A, direction    
    		CJNE A, #0, Set_Left 			; Compare direction with 0, if not equal, set to move left
    		SJMP Set_Right      

Set_Left:	
    		MOV direction, #0    			; Set direction to 0 (left)
    		SJMP End_Toggle      

Set_Right:
		MOV direction, #1   		 	; Set direction to 1 (right)
	
End_Toggle:
    RET

;------------------------------------------------------------------------------------------------
; WINDOWS:
;
;	Input: Positon, Switches 1-4      Output: Check buttons
;
; Description:
; In the following section we added in our dipswitch controlled windows. We assigned each of the
; last 3 leds on each side (LEDs 1-3 and LEDs 8-10) a switch. If the switch bit is a 0 then the
; code will skip over Check_Buttons_right/left to the next LED window state. If all switches are
; flipped then it will only leave LED 10 and LED 1 an option to check if a button is pressed. 
;------------------------------------------------------------------------------------------------
;P1 WINDOWS

Check_P1_Window: 						;check on led 8
		MOV A, position
		JNB p1.0, p1_window_next			;Check if switch 1 bit is 0
   		 CJNE A, #8, P1_Window_Next  
   		 SJMP Check_Button_right    
		  
P1_Window_Next: 						;check on led 9
		JNB p1.1, p1_window_last			;Check if switch 2 bit is 0, skip check_btns if so
  		CJNE A, #9, P1_Window_Last  
   		SJMP Check_Button_right  
		    
P1_Window_Last: 						;check on led 10
		CJNE A, #10, Window_Check_Done
		SJMP Check_Button_right
     

;P2 WINDOWS

Check_P2_Window: 						;check on led 3
		MOV A, position
		JNB p1.2, p2_window_next			;Check if switch 3 bit is 0, skip check_btns if so
    		CJNE A, #3, P2_Window_Next  
    		SJMP Check_Button_left      

P2_Window_Next: 						;check on led 2
		JNB p1.3, p2_window_next
    		CJNE A, #2, P2_Window_Last  			;Check if switch 4 bit is 0, skip Check_btns if so
   		 SJMP Check_Button_left       

P2_Window_Last: 						;check on led 1
    		CJNE A, #1, Window_Check_Done
   		 SJMP Check_Button_left      

Window_Check_Done:
    RET
;------------------------------------------------------------------------------------------------
; UPDATE LEDS:
; 
; 	Input: Position		Output: LED P3.0-P2.1
;
; Description: 
; The following section is where we handle all LED conditions. We have a subroutine for each LED
; case 1-10. Each routine we will compare if the position in which the LED is lit, turn on the 
; the new led, then we will jump to the next LED and repeat. The last 3 LEDs on each side have 
; the ability to jump to our Player windows to check for buttons.   
;------------------------------------------------------------------------------------------------
Update_LEDs:
   		MOV P3, #0xFF          				; Clears all LEDS
   		ORL P2, #0x03          
   		MOV A, position        
    		CJNE A, #1, Check_LED2				
    		CLR P3.0                			; Turn on LED 1 (P3.0)
		mov a, direction
		jz Check_P2_Window				;Check window switch condition
		JMP end_game

Check_LED2:
    		CJNE A, #2, Check_LED3
    		CLR P3.1                			; Turn on LED 2 (P3.1)
		mov a, direction
		jnz Check_P2_Window 				;Check window switch condition
    		SJMP Update_Done

Check_LED3:
    		CJNE A, #3, Check_LED4
		CLR P3.2                			; Turn on LED 3 (P3.2)
		mov a, direction
		jnz Check_P2_Window				;Check window switch condition
    		SJMP Update_Done

Check_LED4:
		CJNE A, #4, Check_LED5
    		CLR P3.3                 			; Turn on LED 4 (P3.3)
    		SJMP Update_Done

Check_LED5:
		CJNE A, #5, Check_LED6
		CLR P3.4                  			; Turn on LED 5 (P3.4)
    		SJMP Update_Done

Check_LED6:
    		CJNE A, #6, Check_LED7
    		CLR P3.5                  			; Turn on LED 6 (P3.5)
    		SJMP Update_Done

Check_LED7:
    		CJNE A, #7, Check_LED8
    		CLR P3.6                 			; Turn on LED 7 (P3.6)
    		SJMP Update_Done

Check_LED8:
    		CJNE A, #8, Check_LED9
   		CLR P3.7                 			; Turn on LED 8 (P3.7)
		mov a, direction
		jz p1_window_jump				;Check window switch condition
    		SJMP Update_Done

Check_LED9:
    		CJNE A, #9, Check_LED10
    		CLR P2.0                 			; Turn on LED 9 (P2.0)
		mov a, direction
		jz p1_window_jump				;Check window switch condition
    		SJMP Update_Done

Check_LED10:
    		CJNE A, #10, Last_LED
    		CLR P2.1                 			; Turn on LED 10 (P2.1)
		JNZ p1_window_jump 				;Check window switch condition
		mov a, direction
		jmp end_game

p1_window_jump:							;Target was out of range, this allows us to ACALL windows
		acall check_P1_Window
		ret

Update_Done:         						;Returns 
    RET

Last_LED:
		CJNE A, #11, First_LED				; Sets Last LED before jumping to END GAME
		clr P2.1
		jmp end_game
		ret

First_LED:							; Sets First LED before jumping to END GAME
		clr P3.0	
		jmp end_game
		ret

;------------------------------------------------------------------------------------------------
; BALL MOVEMENT LOGIC
;
; Input: Direction   Output: move_left or move_right
;
; Description:
; Below is our ball movement logic. We split the logic into two places after the main routine. 
; When we move right we decrement the position which updates the LEDs making the ball move Right.
; The same is done for the left. We also update the direction with a new value so it is ready to 
; come back the other way. We have our endgame here as well which is an infinite loop and stops
; the game until reset.
;
;------------------------------------------------------------------------------------------------

Ball_Movement:
    		MOV A, direction									
    		JNZ Move_left					;Checks for Current direction # in the acc
		JZ Move_right					;Jmps to direction depending on #
		RET	

Move_Right:
    		DEC position					;Decrements LED positions from 10-1
		CALL Update_LEDs
    		MOV A, position
    		CJNE A, #11, Update_Position
    		MOV direction, #0				;Compliments Direction # 
    		DEC position
    		SJMP Move_Right

Move_Left:
    		INC position					; Increments LED positions from 1-10
		CALL Update_LEDs
   		MOV A, position
    		CJNE A, #0, Update_Position
    		MOV direction, #1				;Compliments Directon #
    		INC position
		SJMP Move_Left

Update_Position:
    RET

end_game:							;Infinite loop that stops game
		jmp end_game

;------------------------------------------------------------------------------------------------
; DELAYS:
;
; Input: Speed, Switch 7  
;
; Description: 
; We created 3 different delay conditions. Our Delay_10ms was calulated. Our values roughly come 
; out to a 10ms delay. This Delay looks for our switch 7 to slow it down if flipped. It is slowed
; by having to loop through more times than before. Our Delay_speed funciton takes in the value
; stored on the speed at the top. It checks the buttons every 10 ms. 
;------------------------------------------------------------------------------------------------


delay_10ms:
		MOV A, P1
		JNB ACC.7, Delay_long				;Checks switch 7 for slower condition
		mov R6, #10h
loop1:
		mov R7, #50h
loop2:
		djnz R7, loop2						
		djnz R6, loop1
		ret


delay_speed:
		mov R5, speed					;Puts speed variable into Register 5
		mov buttons, #0h				; Sets a 0 into the buttons variable after every iteration
loop3:
		call delay_10ms
		call check_btns					;Check_btns every 10ms
		djnz R5, loop3
		ret


delay_long:
		mov R6, #10h					;Bigger hex number slows down the delay_10ms subroutine
loop4:
		mov R7, #100h
loop5:
		djnz R7, loop5
		djnz R6, loop4
		ret

END

