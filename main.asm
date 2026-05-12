;========================================
; STC89C52 + HC-05 蓝牙串口通信（可直接用手机串口助手测试）
; 晶振: 11.0592MHz  波特率: 38400 8N1
;========================================

ORG     0000H
LJMP    MAIN

ORG     0023H           ; 串口中断入口
LJMP    UART_ISR

RX_FLAG EQU 20H         ; bit-addressable RAM bit
RX_BYTE EQU 30H         ; 最近一次接收到的字节

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
    ORL     AUXR, #40H      ; 定时器1切到1T模式
    MOV     TH1,  #0F7H     ; 波特率38400 @11.0592MHz (1T)
    MOV     TL1,  #0F7H
    CLR     TI              ; 清发送标志
    CLR     RI              ; 清接收标志
    CLR     RX_FLAG
    SETB    TR1             ; 启动定时器1

    ; === 开中断 ===
    SETB    ES              ; 开串口中断
    SETB    EA              ; 开总中断

    ; === 上电发送欢迎语 ===
    MOV     DPTR, #STR_HELLO
    LCALL   SEND_STR

LOOP:
    ; 在主循环里处理串口发送，避免在 ISR 里长时间阻塞
    JNB     RX_FLAG, LOOP
    CLR     RX_FLAG

    MOV     A, RX_BYTE

    ; 收到 '1' 点亮 P1.0，并回发 ON\r\n
    CJNE    A, #'1', CHECK0
    SETB    P1.0
    MOV     DPTR, #STR_ON
    LCALL   SEND_STR
    SJMP    LOOP

CHECK0:
    ; 收到 '0' 熄灭 P1.0，并回发 OFF\r\n
    CJNE    A, #'0', ECHO
    CLR     P1.0
    MOV     DPTR, #STR_OFF
    LCALL   SEND_STR
    SJMP    LOOP

ECHO:
    ; 其他字符直接回显
    LCALL   SEND_BYTE
    SJMP    LOOP

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
SEND_STR_NEXT:
    MOVC    A, @A+DPTR      ; 取字符
    JZ      SEND_STR_END    ; 遇到0结束
    LCALL   SEND_BYTE
    INC     DPTR
    CLR     A
    SJMP    SEND_STR_NEXT
SEND_STR_END:
    RET

;----------------------------------------
; 串口中断服务程序
; 只负责“快收快退”，把收到的字节交给主循环处理
;----------------------------------------
UART_ISR:
    PUSH    ACC

    JNB     RI, ISR_END
    MOV     A, SBUF         ; 先读数据
    CLR     RI              ; 再清接收标志
    MOV     RX_BYTE, A
    SETB    RX_FLAG

ISR_END:
    POP     ACC
    RETI

;----------------------------------------
; 字符串数据
;----------------------------------------
STR_HELLO:  DB  "HC-05 Ready. Send 1/0", 0DH, 0AH, 00H
STR_ON:     DB  "ON", 0DH, 0AH, 00H
STR_OFF:    DB  "OFF", 0DH, 0AH, 00H

END
