.data?
    wsaData     WSADATA     <?>

.code
    invoke  WSAStartup, 0002h, addr wsaData
    test    eax, eax
    jz      _startupSucceeded

        ; error handling code

_startupSucceeded:

    ; check lower byte of wVersion (major version number)
    cmp     byte ptr [wsaData.wVersion], 2
    jae     _versionOK

        ; error: version < 2
        ; Winsock still has to be cleaned up though:
        jmp     _doCleanup

_versionOK:

    ; ------ call winsock functions here ------

_doCleanup:
    invoke  WSACleanup
    test    eax, eax
    jz      _cleanupSucceeded

        ; error handling code

_cleanupSucceeded: