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
; used ip adress
	IP_address0 db "127.0.0.1",0

; used for allocating sockets responsible for every thread
	thread_counter dword 0

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
    msg10 db "Error listening", 13, 10, 0    
    msg11 db "Error accepting connection", 13, 10, 0    
    msg12 db "WinSock error", 13, 10, 0    
    msg13 db "Connection with client estabilished", 13, 10, 0
	msg14 db "Error sending data", 13, 10, 0    
    msg15 db "Error receiving data", 13, 10, 0    
    msg16 db "Connection socket closed", 13, 10, 0  
	msg17 db "Waiting for connection", 13, 10, 0    
	msg18 db "Connection accepted", 13, 10, 0  

; newline is needed to print out received data in a clear way
	newline db 13, 10, 0

; program commands and responses
	com_quit db "quit", 0
	com_echo db "echo", 0
	com_read db "read", 0
	com_show db "show", 0

	resp_quit db "Connection terminated by server", 0 
	resp_unknown db "Command unknown", 0
	resp_done db "Done", 0

	req_1 db "data1", 0
	req_2 db "data2", 0
	req_3 db "data3", 0

	data1 db "<data 1>", 0
	data2 db "<data 2>", 0
	data3 db "<data 3>", 0

; *************************************************************************
; section for noninitialized variables
; *************************************************************************
.data?
	; struct used by winsock
	wsaData WSADATA <?>
	; variable holding eventual error codes
	error_code dd ?

	; socket descriptors used by program
	my_socket dd ?
	client_socket dd ?

	; free sockets for threads
	free_socket dd 100 dup (?)
	
	; addresses used by program
	my_address sockaddr_in <?>
	client_address sockaddr_in <?>
	; length of address
    client_address_length dd ?
    
	; number of thread
	ThreadId DWORD ? 

	; buffers used in communication
	send_buffer db 128 dup (?)
	recv_buffer db 128 dup (?)

	; variables used to interpret received data
	temp db 128 dup (?)
	command_buffer db 4 dup (?)

; *************************************************************************
; section for constants
; *************************************************************************	
.const
; used port
	MYPORT equ 3500

; *************************************************************************
; code section
; *************************************************************************
.code                         
start:


; initialize WinSock
WinSock_startup:
	invoke  WSAStartup, 0002h, addr wsaData ; initialize WinSock version 2 (2 low byte, 0 high byte)
    .if eax != NULL	; if error occured
    	invoke StdOut, addr msg1    
		jmp cleanup                 	
	.else ; initiliaization succesfull	
		invoke StdOut, addr msg2
    .endif


; if initialization was successull, check if winsock version equals 2
startup_suceeded:
	.if byte ptr [wsaData.wVersion] == 2
		jmp create_listening_socket
	.else	
		invoke StdOut, addr msg5
		jmp cleanup
	.endif


create_listening_socket:
	invoke StdOut, addr msg6
	invoke socket, AF_INET, SOCK_STREAM, 0 ; create TCP socket, internet address family
	.if eax == INVALID_SOCKET
		invoke StdOut, addr msg7
		invoke WSAGetLastError	;moves error code to eax
		invoke FormatMessage, FORMAT_MESSAGE_FROM_SYSTEM or FORMAT_MESSAGE_ALLOCATE_BUFFER, NULL, eax, LANG_NEUTRAL, offset error_code, 0, NULL ; translates error code from eax into string
		invoke MessageBoxA,NULL,error_code,offset msg12,MB_OK ; outputs box with error code
		jmp cleanup
	.else	; if socket is okay assign its descriptor stored in eax to listening_socket
		mov [my_socket], eax
	.endif
	

assign_address:
	; set address family
	mov [my_address.sin_family], AF_INET
	; set bytes to network byte order
	invoke htons, MYPORT
	mov [my_address.sin_port], ax
	; convert ip address from dots to value in networt byte order
	invoke inet_addr, addr IP_address0
	mov [my_address.sin_addr.S_un.S_addr], eax 
	

bind_socket:	
	invoke bind, [my_socket], addr my_address, sizeof my_address
	.if eax == INVALID_SOCKET
		invoke StdOut, addr msg9
		invoke WSAGetLastError 
		invoke FormatMessage, FORMAT_MESSAGE_FROM_SYSTEM or FORMAT_MESSAGE_ALLOCATE_BUFFER, NULL, eax, LANG_NEUTRAL, offset error_code, 0, NULL
		invoke MessageBoxA,NULL,error_code,offset msg12,MB_OK
		jmp close_socket
	.endif
	

start_listening:
	invoke listen, [my_socket], SOMAXCONN ; SOMAXCONN - max. number of sockets waiting for connection to listening server, chosen automaticaly
	.if eax == INVALID_SOCKET
		invoke StdOut, addr msg10
		invoke WSAGetLastError
		invoke FormatMessage, FORMAT_MESSAGE_FROM_SYSTEM or FORMAT_MESSAGE_ALLOCATE_BUFFER, NULL, eax, LANG_NEUTRAL, offset error_code, 0, NULL
		invoke MessageBoxA,NULL,error_code,offset msg12,MB_OK
		jmp close_socket
	.else
		invoke StdOut, addr msg17
	.endif


accept_connection:
	mov client_address_length, sizeof client_address
	invoke  accept, [my_socket], addr client_address, addr client_address_length ; accept connection with listening socket, store address of client and return descriptor in eax
    .if eax == INVALID_SOCKET
		invoke StdOut, addr msg11
		invoke WSAGetLastError
		invoke FormatMessage, FORMAT_MESSAGE_FROM_SYSTEM or FORMAT_MESSAGE_ALLOCATE_BUFFER, NULL, eax, LANG_NEUTRAL, offset error_code, 0, NULL
		invoke MessageBoxA,NULL,error_code,offset msg12,MB_OK
		jmp close_socket
	.else	
		mov [client_socket], eax
    .endif

; send client welcome message
acknowledge_connection:
	invoke StdOut, addr msg13
	invoke send, [client_socket], addr msg18, sizeof msg18, 0
	.if eax == SOCKET_ERROR
		invoke StdOut, addr msg14
		invoke WSAGetLastError 
		invoke FormatMessage, FORMAT_MESSAGE_FROM_SYSTEM or FORMAT_MESSAGE_ALLOCATE_BUFFER, NULL, eax, LANG_NEUTRAL, offset error_code, 0, NULL
		invoke MessageBoxA,NULL,error_code,offset msg12,MB_OK
		jmp close_socket
	.endif

; create new thread for client
; copy client_socket descriptor into free socket and call new thread with this descriptor
create_thread:
	; get first free socket address where we can store descrpitor
	mov ebx, offset free_socket
	mov ecx, thread_counter
	loop_th:
		inc ebx
	loop loop_th
	; move client descripor into that free address
	mov ebx, client_socket
	mov eax, offset ThreadProc
	; call create thread with default parameters on function ThreadProc and give it pointer to socket of the newest client
	invoke CreateThread, 0, 0, eax, ebx, 0, addr ThreadId
	inc thread_counter
	;return to listening
	jmp start_listening


; before ending close socket
close_socket:
	invoke closesocket, [my_socket]
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
	

; thread code here
; param - address of socket descriptor
ThreadProc PROC Param: DWORD


receive_data:
	invoke recv, [Param], addr recv_buffer, 128, 0
	.if eax == 0
		invoke StdOut, addr msg16
		invoke WSAGetLastError 
		invoke FormatMessage, FORMAT_MESSAGE_FROM_SYSTEM or FORMAT_MESSAGE_ALLOCATE_BUFFER, NULL, eax, LANG_NEUTRAL, offset error_code, 0, NULL
		invoke MessageBoxA,NULL,error_code,offset msg12,MB_OK
		jmp close_thread_socket
	.elseif eax == SOCKET_ERROR
		invoke StdOut, addr msg15
		invoke WSAGetLastError 
		invoke FormatMessage, FORMAT_MESSAGE_FROM_SYSTEM or FORMAT_MESSAGE_ALLOCATE_BUFFER, NULL, eax, LANG_NEUTRAL, offset error_code, 0, NULL
		invoke MessageBoxA,NULL,error_code,offset msg12,MB_OK
		jmp close_thread_socket
	.endif

; read command - extract first 4 characters(command) and rest(temp)
; and decide what to do
read_command:
	; move first 4 characters into command
	mov  esi, OFFSET recv_buffer
    mov  edi, OFFSET command_buffer
    mov  ecx, SIZEOF command_buffer
	loop1:
		mov  al,[esi]           ; get a character from source
		mov  [edi],al           ; store it in the target
		inc  esi                ; move to next character
		inc  edi
    loop loop1	
	
	; move the rest into temp
	mov  esi, OFFSET recv_buffer+5
    mov  edi, OFFSET temp
    mov  ecx, SIZEOF temp
	loop2:
		mov  al,[esi]           ; get a character from source
		mov  [edi],al           ; store it in the target
		inc  esi                ; move to next character
		inc  edi
    loop loop2	


; compare command with known commands
compare:
	invoke lstrcmpiA, addr com_echo, addr command_buffer
	.if eax == 0
		jmp command_echo
	.endif

	invoke lstrcmpiA, addr com_show, addr command_buffer
	.if eax == 0
		jmp command_show
	.endif

	invoke lstrcmpiA, addr com_read, addr command_buffer
	.if eax == 0
		jmp command_read
	.endif

	invoke lstrcmpiA, addr com_quit, addr command_buffer
	.if eax == 0
		jmp command_quit
	.endif
	
	jmp command_unknown


command_echo:
	; copy temp into send buffer
	mov  esi, OFFSET temp
    mov  edi, OFFSET send_buffer
    mov  ecx, SIZEOF send_buffer
	loop_echo:
		mov  al,[esi]           ; get a character from source
		mov  [edi],al           ; store it in the target
		inc  esi                ; move to next character
		inc  edi
    loop loop_echo	
	jmp send_data


command_show:
	; show temp
	invoke StdOut, addr temp
	invoke StdOut, addr newline
	; copy done msg into send buffer
	mov  esi, OFFSET resp_done
    mov  edi, OFFSET send_buffer
    mov  ecx, SIZEOF send_buffer
	loop_show:
		mov  al,[esi]           ; get a character from source
		mov  [edi],al           ; store it in the target
		inc  esi                ; move to next character
		inc  edi
    loop loop_show	
	jmp send_data


command_read:
	; check what data is required
	invoke lstrcmpiA, addr req_1, addr temp
	.if eax == 0
		invoke send, [Param], addr data1, sizeof data1, 0
		.if eax == SOCKET_ERROR
			invoke StdOut, addr msg14
			invoke WSAGetLastError 
			invoke FormatMessage, FORMAT_MESSAGE_FROM_SYSTEM or FORMAT_MESSAGE_ALLOCATE_BUFFER, NULL, eax, LANG_NEUTRAL, offset error_code, 0, NULL
			invoke MessageBoxA,NULL,error_code,offset msg12,MB_OK
			jmp close_thread_socket
		.endif
		jmp clear_buffer
	.endif

	invoke lstrcmpiA, addr req_2, addr temp
	.if eax == 0
		invoke send, [Param], addr data2, sizeof data2, 0
		.if eax == SOCKET_ERROR
			invoke StdOut, addr msg14
			invoke WSAGetLastError 
			invoke FormatMessage, FORMAT_MESSAGE_FROM_SYSTEM or FORMAT_MESSAGE_ALLOCATE_BUFFER, NULL, eax, LANG_NEUTRAL, offset error_code, 0, NULL
			invoke MessageBoxA,NULL,error_code,offset msg12,MB_OK
			jmp close_thread_socket
		.endif
		jmp clear_buffer
	.endif

	invoke lstrcmpiA, addr req_3, addr temp
	.if eax == 0
		invoke send, [Param], addr data3, sizeof data3, 0
		.if eax == SOCKET_ERROR
			invoke StdOut, addr msg14
			invoke WSAGetLastError 
			invoke FormatMessage, FORMAT_MESSAGE_FROM_SYSTEM or FORMAT_MESSAGE_ALLOCATE_BUFFER, NULL, eax, LANG_NEUTRAL, offset error_code, 0, NULL
			invoke MessageBoxA,NULL,error_code,offset msg12,MB_OK
			jmp close_thread_socket
		.endif
		jmp clear_buffer
	.endif
	jmp command_unknown



command_quit:
	;send one message and close socket
	invoke send, [Param], addr resp_quit, sizeof resp_quit, 0
	.if eax == SOCKET_ERROR
		invoke StdOut, addr msg14
		invoke WSAGetLastError 
		invoke FormatMessage, FORMAT_MESSAGE_FROM_SYSTEM or FORMAT_MESSAGE_ALLOCATE_BUFFER, NULL, eax, LANG_NEUTRAL, offset error_code, 0, NULL
		invoke MessageBoxA,NULL,error_code,offset msg12,MB_OK
		jmp close_thread_socket
	.endif
	jmp close_thread_socket


command_unknown:
	; copy unknown message into send buffer
	mov  esi, OFFSET resp_unknown
    mov  edi, OFFSET send_buffer
    mov  ecx, SIZEOF send_buffer
	loop_uk:
		mov  al,[esi]           ; get a character from source
		mov  [edi],al           ; store it in the target
		inc  esi                ; move to next character
		inc  edi
    loop loop_uk
	jmp send_data

send_data:
	invoke send, [Param], addr send_buffer, 128, 0
	.if eax == SOCKET_ERROR
		invoke StdOut, addr msg14
		invoke WSAGetLastError 
		invoke FormatMessage, FORMAT_MESSAGE_FROM_SYSTEM or FORMAT_MESSAGE_ALLOCATE_BUFFER, NULL, eax, LANG_NEUTRAL, offset error_code, 0, NULL
		invoke MessageBoxA,NULL,error_code,offset msg12,MB_OK
		jmp close_thread_socket
	.endif

clear_buffer:
    mov  edi, OFFSET send_buffer
    mov  ecx, SIZEOF send_buffer
	loop_clear:
		xor edi, edi
		inc  edi
    loop loop_clear

	jmp receive_data

close_thread_socket:
	invoke closesocket, [Param]
	.if eax == SOCKET_ERROR
		invoke StdOut, addr msg8
		invoke WSAGetLastError
		invoke FormatMessage, FORMAT_MESSAGE_FROM_SYSTEM or FORMAT_MESSAGE_ALLOCATE_BUFFER, NULL, eax, LANG_NEUTRAL, offset error_code, 0, NULL
		invoke MessageBoxA,NULL,error_code,offset msg12,MB_OK
	.endif
	; quit thread returning code 0
	invoke ExitThread, 0

ThreadProc ENDP

end start