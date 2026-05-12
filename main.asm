;========================================
; STC89C52 + HC-05 蓝牙串口通信
; 晶振: 11.0592MHz  波特率: 9600
;========================================

ORG     0000H
LJMP    MAIN

ORG     0023H           ; 串口中断入口
LJMP    UART_ISR

;----------------------------------------
; 主程序
;----------------------------------------
ORG     0030H
MAIN:
    MOV     SP, #70H        ; 设置堆栈指针

    ; === 初始化串口 ===
    MOV     SCON, #50H      ; 串口模式1，允许接收(REN=1)
    MOV     TMOD, #20H      ; 定时器1，模式2(8位自动重装)
    MOV     TH1,  #0FDH     ; 波特率9600 @11.0592MHz
    MOV     TL1,  #0FDH
    SETB    TR1             ; 启动定时器1

    ; === 开中断 ===
    SETB    EA              ; 开总中断
    SETB    ES              ; 开串口中断

    ; === 上电发送欢迎语 ===
    MOV     DPTR, #STR_HELLO
    LCALL   SEND_STR

LOOP:
    SJMP    LOOP            ; 主循环（业务逻辑加这里）

;----------------------------------------
; 发送单个字节
; 入口: ACC = 要发送的字节
;----------------------------------------
SEND_BYTE:
    MOV     SBUF, A
WAIT_TI:
    JNB     TI, WAIT_TI     ; 等待发送完成
    CLR     TI
    RET

;----------------------------------------
; 发送字符串(DPTR指向字符串首地址)
; 以 00H 结尾
;----------------------------------------
SEND_STR:
    CLR     A
    MOVC    A, @A+DPTR      ; 取字符
    JZ      SEND_STR_END    ; 遇到0结束
    LCALL   SEND_BYTE
    INC     DPTR
    SJMP    SEND_STR
SEND_STR_END:
    RET

;----------------------------------------
; 串口中断服务程序
; 接收手机发来的数据，并回显
;----------------------------------------
UART_ISR:
    PUSH    ACC
    PUSH    PSW

    JNB     RI, ISR_END     ; 不是接收中断则跳过
    CLR     RI              ; 清接收标志
    MOV     A, SBUF         ; 读取接收到的数据

    ; === 在这里处理手机发来的指令 ===
    ; 示例：收到 '1' 点亮P1.0，收到 '0' 熄灭
    CJNE    A, #'1', CHECK0
    SETB    P1.0
    SJMP    ISR_END
CHECK0:
    CJNE    A, #'0', ECHO
    CLR     P1.0
    SJMP    ISR_END
ECHO:
    LCALL   SEND_BYTE       ; 其他字符回显给手机

ISR_END:
    POP     PSW
    POP     ACC
    RETI

;----------------------------------------
; 字符串数据
;----------------------------------------
STR_HELLO:  DB  "Hello Phone!", 0DH, 0AH, 00H

END
