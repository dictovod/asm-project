// main_asm.S — 100% ARM64 Assembly для Android NativeActivity
// Hello World на экране через ANativeWindow + программный рендер
// Нет C, нет C++ — только ASM

.section .text
.global ANativeActivity_onCreate
.global android_main

// ─── КОНСТАНТЫ ───────────────────────────────────────────────
.equ ANDROID_LOG_INFO,          4
.equ ANDROID_LOG_DEBUG,         3
.equ ANDROID_LOG_ERROR,         6

// ANativeActivity offsets
.equ ACTIVITY_CALLBACKS,        0
.equ ACTIVITY_VM,               8
.equ ACTIVITY_ENV,             16
.equ ACTIVITY_CLAZZ,           24

// ANativeActivityCallbacks offsets
.equ CB_ONDESTROY,             40
.equ CB_ONNATIVEWINDOWCREATED, 56
.equ CB_ONNATIVEWINDOWDESTROYED, 72

// Формат пикселей
.equ WINDOW_FORMAT_RGBA_8888,   1

// Цвета
.equ COLOR_BG_LO,   0x1A2E      // нижние 16 бит 0xFF1A2E1A... нет
// Используем mov/movk для полных 32-битных цветов

// ─── ДАННЫЕ ──────────────────────────────────────────────────
.section .rodata

tag_str:      .asciz "ASM_HELLO"
msg_create:   .asciz "ANativeActivity_onCreate — pure ARM64 ASM"
msg_window:   .asciz "Window created — rendering Hello World"
msg_destroy:  .asciz "Window destroyed"
msg_nolock:   .asciz "ANativeWindow_lock failed"

// Пиксельный шрифт 5x7: "Hello World"
// Каждый символ = 7 байт (7 строк по 5 бит)
font_data:
    // H
    .byte 0b10001, 0b10001, 0b11111, 0b10001, 0b10001, 0b10001, 0b10001
    // e
    .byte 0b00000, 0b00000, 0b01110, 0b10001, 0b11111, 0b10000, 0b01110
    // l
    .byte 0b01100, 0b00100, 0b00100, 0b00100, 0b00100, 0b00100, 0b01110
    // l
    .byte 0b01100, 0b00100, 0b00100, 0b00100, 0b00100, 0b00100, 0b01110
    // o
    .byte 0b00000, 0b00000, 0b01110, 0b10001, 0b10001, 0b10001, 0b01110
    // (space)
    .byte 0b00000, 0b00000, 0b00000, 0b00000, 0b00000, 0b00000, 0b00000
    // W
    .byte 0b10001, 0b10001, 0b10101, 0b10101, 0b10101, 0b11011, 0b10001
    // o
    .byte 0b00000, 0b00000, 0b01110, 0b10001, 0b10001, 0b10001, 0b01110
    // r
    .byte 0b00000, 0b00000, 0b10110, 0b11001, 0b10000, 0b10000, 0b10000
    // l
    .byte 0b01100, 0b00100, 0b00100, 0b00100, 0b00100, 0b00100, 0b01110
    // d
    .byte 0b00001, 0b00001, 0b01101, 0b10011, 0b10001, 0b10011, 0b01101
    // !
    .byte 0b00100, 0b00100, 0b00100, 0b00100, 0b00100, 0b00000, 0b00100
.equ FONT_CHAR_COUNT, 12

// ─── СОСТОЯНИЕ ───────────────────────────────────────────────
.section .bss
.align 8
g_window:    .space 8
g_running:   .space 4
.align 4

.section .text

// ═══════════════════════════════════════════════════════════════
// ANativeActivity_onCreate
// x0=ANativeActivity*, x1=savedState*, x2=savedStateSize
// ═══════════════════════════════════════════════════════════════
ANativeActivity_onCreate:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]

    mov     x19, x0

    // g_running = 1
    adrp    x0, g_running
    add     x0, x0, :lo12:g_running
    mov     w1, #1
    str     w1, [x0]

    // Установить коллбеки
    ldr     x0, [x19, #ACTIVITY_CALLBACKS]

    adrp    x1, asm_on_window_created
    add     x1, x1, :lo12:asm_on_window_created
    str     x1, [x0, #CB_ONNATIVEWINDOWCREATED]

    adrp    x1, asm_on_window_destroyed
    add     x1, x1, :lo12:asm_on_window_destroyed
    str     x1, [x0, #CB_ONNATIVEWINDOWDESTROYED]

    adrp    x1, asm_on_destroy
    add     x1, x1, :lo12:asm_on_destroy
    str     x1, [x0, #CB_ONDESTROY]

    // Лог
    adrp    x0, tag_str
    add     x0, x0, :lo12:tag_str
    adrp    x1, msg_create
    add     x1, x1, :lo12:msg_create
    bl      asm_log_info

    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// ═══════════════════════════════════════════════════════════════
// asm_on_window_created
// x0=ANativeActivity*, x1=ANativeWindow*
// ═══════════════════════════════════════════════════════════════
asm_on_window_created:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]

    mov     x19, x1                     // window

    // g_window = window
    adrp    x0, g_window
    add     x0, x0, :lo12:g_window
    str     x19, [x0]

    // g_running = 1
    adrp    x0, g_running
    add     x0, x0, :lo12:g_running
    mov     w1, #1
    str     w1, [x0]

    adrp    x0, tag_str
    add     x0, x0, :lo12:tag_str
    adrp    x1, msg_window
    add     x1, x1, :lo12:msg_window
    bl      asm_log_info

    // Запустить рендер цикл
    mov     x0, x19
    bl      android_main

    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// ═══════════════════════════════════════════════════════════════
// asm_on_window_destroyed
// ═══════════════════════════════════════════════════════════════
asm_on_window_destroyed:
    adrp    x0, g_window
    add     x0, x0, :lo12:g_window
    str     xzr, [x0]
    adrp    x0, g_running
    add     x0, x0, :lo12:g_running
    str     wzr, [x0]
    adrp    x0, tag_str
    add     x0, x0, :lo12:tag_str
    adrp    x1, msg_destroy
    add     x1, x1, :lo12:msg_destroy
    b       asm_log_info

// ═══════════════════════════════════════════════════════════════
// asm_on_destroy
// ═══════════════════════════════════════════════════════════════
asm_on_destroy:
    adrp    x0, g_running
    add     x0, x0, :lo12:g_running
    str     wzr, [x0]
    ret

// ═══════════════════════════════════════════════════════════════
// android_main — рендер цикл
// x0 = ANativeWindow*
// ═══════════════════════════════════════════════════════════════
android_main:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]

    mov     x19, x0                     // window

    // Установить формат RGBA_8888
    mov     x0, x19
    mov     w1, #WINDOW_FORMAT_RGBA_8888
    mov     w2, #0
    mov     w3, #0
    bl      ANativeWindow_setBuffersGeometry

.render_loop:
    // Проверить g_running
    adrp    x0, g_running
    add     x0, x0, :lo12:g_running
    ldr     w0, [x0]
    cbz     w0, .render_exit

    // Нарисовать кадр
    mov     x0, x19
    bl      asm_draw_frame

    // nanosleep ~16ms (syscall 101)
    sub     sp, sp, #32
    str     xzr, [sp]                   // tv_sec = 0
    mov     x0, #0xF500
    movk    x0, #0x00F4, lsl #16        // tv_nsec ≈ 16ms
    str     x0, [sp, #8]
    mov     x0, sp
    mov     x1, #0
    mov     x8, #101
    svc     #0
    add     sp, sp, #32

    b       .render_loop

.render_exit:
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// ═══════════════════════════════════════════════════════════════
// asm_draw_frame — нарисовать Hello World
// x0 = ANativeWindow*
// ═══════════════════════════════════════════════════════════════
asm_draw_frame:
    stp     x29, x30, [sp, #-96]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    stp     x25, x26, [sp, #64]

    mov     x19, x0                     // window

    // ANativeWindow_Buffer: width(4) height(4) stride(4) format(4) bits(8) reserved(6*8)
    sub     sp, sp, #64
    mov     x1, sp
    mov     x2, #0
    mov     x0, x19
    bl      ANativeWindow_lock
    cbnz    w0, .frame_fail

    ldr     w20, [sp]                   // width
    ldr     w21, [sp, #4]               // height
    ldr     w22, [sp, #8]               // stride
    ldr     x23, [sp, #32]              // bits

    // Залить фон: тёмно-синий 0xFF1A1A2E
    mov     w0, w21
    mul     w0, w0, w22                 // total = height * stride
    mov     x24, x23
    mov     w1, w0
    mov     w2, #0x1A2E
    movk    w2, #0xFF1A, lsl #16
    bl      asm_fill_color

    // Масштаб текста: scale = width / 160  (минимум 2)
    mov     w25, #2
    lsr     w0, w20, #7                 // width / 128
    cmp     w0, #2
    csel    w25, w25, w0, lt            // scale = max(2, width/128)

    // Ширина строки = FONT_CHAR_COUNT * (5+1) * scale
    mov     w0, #FONT_CHAR_COUNT
    mov     w1, #6
    mul     w0, w0, w1
    mul     w0, w0, w25                 // text_width

    // x_start = (width - text_width) / 2
    sub     w24, w20, w0
    asr     w24, w24, #1                // x_start

    // y_start = height/2 - (7*scale/2)
    mov     w0, #7
    mul     w0, w0, w25
    asr     w0, w0, #1
    asr     w26, w21, #1
    sub     w26, w26, w0                // y_start

    // Нарисовать каждый символ
    mov     w0, #0                      // char index

.draw_chars:
    cmp     w0, #FONT_CHAR_COUNT
    bge     .draw_done_chars

    str     w0, [sp, #56]              // сохранить char index

    // font_ptr = font_data + char_index * 7
    adrp    x1, font_data
    add     x1, x1, :lo12:font_data
    ldr     w0, [sp, #56]
    mov     w2, #7
    mul     w2, w0, w2
    add     x1, x1, x2                 // char font ptr

    // x = x_start + char_index * 6 * scale
    ldr     w0, [sp, #56]
    mov     w2, #6
    mul     w2, w0, w2
    mul     w2, w2, w25
    add     w2, w24, w2                 // char_x

    // Нарисовать символ (7 строк, 5 колонок) * scale
    mov     w3, #0                      // row

.draw_row:
    cmp     w3, #7
    bge     .draw_row_done

    ldrb    w4, [x1, x3]              // bitmap row

    mov     w5, #0                      // col

.draw_col:
    cmp     w5, #5
    bge     .draw_col_done

    // Проверить бит
    mov     w6, #4
    sub     w6, w6, w5
    lsr     w6, w4, w6
    and     w6, w6, #1
    cbz     w6, .draw_col_next

    // Нарисовать scale x scale пиксельный блок
    mov     w7, #0                      // sy

.draw_sy:
    cmp     w7, w25
    bge     .draw_sy_done
    mov     w8, #0                      // sx

.draw_sx:
    cmp     w8, w25
    bge     .draw_sx_done

    // py = y_start + row*scale + sy
    mul     w9, w3, w25
    add     w9, w26, w9
    add     w9, w9, w7

    // px = char_x + col*scale + sx
    mul     w10, w5, w25
    add     w10, w2, w10
    add     w10, w10, w8

    // Проверить границы
    cmp     w9, w21
    bge     .draw_sx_next
    cmp     w10, w20
    bge     .draw_sx_next

    // offset = py*stride + px
    mul     w11, w9, w22
    add     w11, w11, w10
    lsl     x11, x11, #2
    add     x11, x23, x11

    // Цвет текста: 0xFFE8E8FF
    mov     w12, #0xE8FF
    movk    w12, #0xFFE8, lsl #16
    str     w12, [x11]

.draw_sx_next:
    add     w8, w8, #1
    b       .draw_sx

.draw_sx_done:
    add     w7, w7, #1
    b       .draw_sy

.draw_sy_done:
.draw_col_next:
    add     w5, w5, #1
    b       .draw_col

.draw_col_done:
    add     w3, w3, #1
    b       .draw_row

.draw_row_done:
    ldr     w0, [sp, #56]
    add     w0, w0, #1
    b       .draw_chars

.draw_done_chars:
    add     sp, sp, #64

    // ANativeWindow_unlockAndPost
    mov     x0, x19
    bl      ANativeWindow_unlockAndPost

    b       .frame_done

.frame_fail:
    add     sp, sp, #64
    adrp    x0, tag_str
    add     x0, x0, :lo12:tag_str
    adrp    x1, msg_nolock
    add     x1, x1, :lo12:msg_nolock
    bl      asm_log_info

.frame_done:
    ldp     x25, x26, [sp, #64]
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #96
    ret

// ═══════════════════════════════════════════════════════════════
// asm_fill_color — NEON заливка буфера
// x0=buf, w1=count(pixels), w2=color
// ═══════════════════════════════════════════════════════════════
asm_fill_color:
    cbz     w1, .fill_done
    dup     v0.4s, w2
    dup     v1.4s, w2
    dup     v2.4s, w2
    dup     v3.4s, w2
    lsr     w3, w1, #4
    cbz     w3, .fill_tail
.fill_loop:
    st1     {v0.4s, v1.4s, v2.4s, v3.4s}, [x0], #64
    subs    w3, w3, #1
    bne     .fill_loop
.fill_tail:
    and     w1, w1, #15
    cbz     w1, .fill_done
.fill_px:
    str     w2, [x0], #4
    subs    w1, w1, #1
    bne     .fill_px
.fill_done:
    ret

// ═══════════════════════════════════════════════════════════════
// asm_log_info
// x0=tag, x1=msg
// ═══════════════════════════════════════════════════════════════
asm_log_info:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    mov     x2, x1
    mov     w1, #ANDROID_LOG_INFO
    bl      __android_log_print
    ldp     x29, x30, [sp], #16
    ret

.end
