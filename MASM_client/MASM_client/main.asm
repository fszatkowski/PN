; enable 386+ instruction set                                    
.386
; 32-bit memory model
.model flat, stdcall
; case insensitive syntax
option casemap: none	

; *************************************************************************
; MASM32 prototypes for Win32 functions and structures
; *************************************************************************  
include c:\masm32\include\windows.inc
include c:\masm32\include\user32.inc
include c:\masm32\include\kernel32.inc
include c:\masm32\include\masm32.inc
include c:\masm32\include\wsock32.inc

; *************************************************************************
; MASM32 libraries
; *************************************************************************  
includelib c:\masm32\lib\user32.lib
includelib c:\masm32\lib\kernel32.lib
includelib c:\masm32\lib\masm32.lib
includelib c:\masm32\lib\wsock32.lib

; *************************************************************************
; data section for variables declarations
; *************************************************************************
.data
	server_IP db "127.0.0.1",0

; console messages
	msg1 db "WinSock startup unsuccessfull", 13, 10, 0
	msg2 db "WinSock startup successfull", 13, 10, 0
	msg3 db "WinSock cleanup unsuccessfull", 13, 10, 0
	msg4 db "WinSock cleanup successfull", 13, 10, 0      
	msg5 db "WinSock version lower than 2", 13, 10, 0
	msg6 db "WinSock version correct(WinSock 2)", 13, 10, 0
	msg7 db "Error creating socket", 13, 10, 0
    msg8 db "Error closing socket", 13, 10, 0
    msg9 db "Error binding socket", 13, 10, 0    
    msg10 db "Error connecting to server", 13, 10, 0    
    msg12 db "WinSock error", 13, 10, 0    
    msg13 db "Connection with server estabilished", 13, 10, 0    
    msg14 db "Error sending data", 13, 10, 0    
    msg15 db "Error receiving data", 13, 10, 0    
    msg16 db "Connection socket closed", 13, 10, 0  
    
	newline db 13, 10, 0

; *************************************************************************
; section for noninitialized variables
; *************************************************************************
.data?
	wsaData WSADATA <?>
	error_code dd ?

	connection_socket dd ?

	dest_address sockaddr_in <?>
	dest_address_length dd ?
    
	send_buffer db 128 dup (?)
	recv_buffer db 128 dup (?)

; *************************************************************************
; section for constants
; *************************************************************************	
.const	
	MYPORT equ 3500

; *************************************************************************
; code section
; *************************************************************************
.code                         

start:

; initialize WinSock
WinSock_startup:
	invoke  WSAStartup, 0002h, addr wsaData ; initialize WinSock version 2 (2 low byte, 0 high byte), informations about winsock are stored in WSAData
    .if eax != NULL	; if error occured
    	invoke StdOut, addr msg1    
		jmp cleanup                 	
	.else ; initiliaization succesfull	
		invoke StdOut, addr msg2
    .endif

; if initialization was successull, check if winsock version equals 2
startup_suceeded:
	.if byte ptr [wsaData.wVersion] == 2
		jmp create_socket
	.else	
		invoke StdOut, addr msg5
		jmp cleanup
	.endif

create_socket:
	invoke StdOut, addr msg6
	invoke socket, AF_INET, SOCK_STREAM, 0 ; create TCP socket
	.if eax == INVALID_SOCKET
		invoke StdOut, addr msg7
		invoke WSAGetLastError
		invoke FormatMessage, FORMAT_MESSAGE_FROM_SYSTEM or FORMAT_MESSAGE_ALLOCATE_BUFFER, NULL, eax, LANG_NEUTRAL, offset error_code, 0, NULL
		invoke MessageBoxA,NULL,error_code,offset msg12,MB_OK
		jmp cleanup
	.else	; if socket is okay assign it to connection socket
		mov [connection_socket], eax
	.endif
	
assign_address:
	; set address family
	mov [dest_address.sin_family], AF_INET
	; set bytes to network byte order
	invoke htons, MYPORT
	mov [dest_address.sin_port], ax
	; convert ip address from dots to value in networt byte order
	invoke inet_addr, addr server_IP
	mov [dest_address.sin_addr.S_un.S_addr], eax 
	
; attempt to connect to server
; if there is no response throw out msg box
; when message box is closed, try again
start_connecting:
	invoke connect, [connection_socket], addr dest_address, sizeof dest_address
	.if eax == INVALID_SOCKET
		invoke StdOut, addr msg10
		invoke WSAGetLastError 
		invoke FormatMessage, FORMAT_MESSAGE_FROM_SYSTEM or FORMAT_MESSAGE_ALLOCATE_BUFFER, NULL, eax, LANG_NEUTRAL, offset error_code, 0, NULL
		invoke MessageBoxA,NULL,error_code,offset msg12,MB_OK
		jmp start_connecting
	.else
		jmp acknowledge_connection	
	.endif
	
; when connection is accepted read welcoming message from server
acknowledge_connection:
	invoke StdOut, addr msg13
	invoke recv, [connection_socket], addr recv_buffer, 128, 0
	.if eax == 0
		invoke StdOut, addr msg16
		invoke WSAGetLastError 
		invoke FormatMessage, FORMAT_MESSAGE_FROM_SYSTEM or FORMAT_MESSAGE_ALLOCATE_BUFFER, NULL, eax, LANG_NEUTRAL, offset error_code, 0, NULL
		invoke MessageBoxA,NULL,error_code,offset msg12,MB_OK
		jmp close_socket
	.elseif eax == SOCKET_ERROR
		invoke StdOut, addr msg15
		invoke WSAGetLastError 
		invoke FormatMessage, FORMAT_MESSAGE_FROM_SYSTEM or FORMAT_MESSAGE_ALLOCATE_BUFFER, NULL, eax, LANG_NEUTRAL, offset error_code, 0, NULL
		invoke MessageBoxA,NULL,error_code,offset msg12,MB_OK
		jmp close_socket
	.else
		invoke StdOut, addr recv_buffer 
	.endif

; read console input from user
get_msg:
	invoke StdIn, addr send_buffer, 128

; send this data to server
send_data:
	invoke send, [connection_socket], addr send_buffer, 128, 0
	.if eax == SOCKET_ERROR
		invoke StdOut, addr msg14
		invoke WSAGetLastError 
		invoke FormatMessage, FORMAT_MESSAGE_FROM_SYSTEM or FORMAT_MESSAGE_ALLOCATE_BUFFER, NULL, eax, LANG_NEUTRAL, offset error_code, 0, NULL
		invoke MessageBoxA,NULL,error_code,offset msg12,MB_OK
		jmp close_socket
	.endif

; receive servers response and print it
receive_data:
	invoke recv, [connection_socket], addr recv_buffer, 128, 0
	.if eax == 0
		invoke StdOut, addr msg16
		invoke WSAGetLastError 
		invoke FormatMessage, FORMAT_MESSAGE_FROM_SYSTEM or FORMAT_MESSAGE_ALLOCATE_BUFFER, NULL, eax, LANG_NEUTRAL, offset error_code, 0, NULL
		invoke MessageBoxA,NULL,error_code,offset msg12,MB_OK
		jmp close_socket
	.elseif eax == SOCKET_ERROR
		invoke StdOut, addr msg15
		invoke WSAGetLastError 
		invoke FormatMessage, FORMAT_MESSAGE_FROM_SYSTEM or FORMAT_MESSAGE_ALLOCATE_BUFFER, NULL, eax, LANG_NEUTRAL, offset error_code, 0, NULL
		invoke MessageBoxA,NULL,error_code,offset msg12,MB_OK
		jmp close_socket
	.endif
	
	invoke StdOut, addr recv_buffer
	invoke StdOut, addr newline
	
	;loop
	jmp get_msg

; this code is executed once server ends connections
; before ending close socket
close_socket:
	invoke closesocket, [connection_socket]
	.if eax == SOCKET_ERROR
		invoke StdOut, addr msg8
		invoke WSAGetLastError
		invoke FormatMessage, FORMAT_MESSAGE_FROM_SYSTEM or FORMAT_MESSAGE_ALLOCATE_BUFFER, NULL, eax, LANG_NEUTRAL, offset error_code, 0, NULL
		invoke MessageBoxA,NULL,error_code,offset msg12,MB_OK
	.endif
	
; cleanup WSAData		
cleanup:
	invoke WSACleanup
	.if eax != 0 ; if cleanup error occured
    	invoke StdOut, addr msg3                     	
	.else ; cleanup succesfull	
		invoke StdOut, addr msg4
	.endif
	
end start