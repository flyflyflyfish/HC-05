;========================================
; STC89C52 + HC-05 蓝牙串口通信（可直接用手机串口助手测试）
; 晶振: 11.0592MHz  波特率: 9600 8N1
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

    ; === IO 初始化 ===
    CLR     P1.0            ; 默认关闭 LED

    ; === 初始化串口 ===
    MOV     SCON, #50H      ; 串口模式1，允许接收(REN=1)
    MOV     TMOD, #20H      ; 定时器1，模式2(8位自动重装)
    MOV     TH1,  #0FDH     ; 波特率9600 @11.0592MHz
    MOV     TL1,  #0FDH
    CLR     TI              ; 清发送标志
    CLR     RI              ; 清接收标志
    SETB    TR1             ; 启动定时器1

    ; === 开中断 ===
    SETB    ES              ; 开串口中断
    SETB    EA              ; 开总中断

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
; 接收手机发来的数据，并执行命令或回显
;----------------------------------------
UART_ISR:
    PUSH    ACC
    PUSH    PSW

    JNB     RI, ISR_END     ; 仅处理接收中断
    CLR     RI              ; 清接收标志
    MOV     A, SBUF         ; 读取接收到的数据

    ; 收到 '1' 点亮 P1.0
    CJNE    A, #'1', CHECK0
    SETB    P1.0
    MOV     A, #'O'
    LCALL   SEND_BYTE
    MOV     A, #'N'
    LCALL   SEND_BYTE
    MOV     A, #0DH
    LCALL   SEND_BYTE
    MOV     A, #0AH
    LCALL   SEND_BYTE
    SJMP    ISR_END

CHECK0:
    ; 收到 '0' 熄灭 P1.0
    CJNE    A, #'0', ECHO
    CLR     P1.0
    MOV     A, #'O'
    LCALL   SEND_BYTE
    MOV     A, #'F'
    LCALL   SEND_BYTE
    MOV     A, #'F'
    LCALL   SEND_BYTE
    MOV     A, #0DH
    LCALL   SEND_BYTE
    MOV     A, #0AH
    LCALL   SEND_BYTE
    SJMP    ISR_END

ECHO:
    ; 其他字符回显给手机
    LCALL   SEND_BYTE

ISR_END:
    POP     PSW
    POP     ACC
    RETI

;----------------------------------------
; 字符串数据
;----------------------------------------
STR_HELLO:  DB  "HC-05 Ready. Send 1/0", 0DH, 0AH, 00H

END
