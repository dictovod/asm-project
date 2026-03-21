// main_asm.S — 100% ARM64 Assembly, Android NativeActivity
// Hello World через ANativeWindow, рендер в отдельном потоке

.section .text
.global ANativeActivity_onCreate

// ─── КОНСТАНТЫ ───────────────────────────────────────────────
.equ ANDROID_LOG_INFO,           4
.equ ANDROID_LOG_ERROR,          6
.equ WINDOW_FORMAT_RGBA_8888,    1

// ANativeActivityCallbacks offsets
.equ CB_ONDESTROY,               40
.equ CB_ONNATIVEWINDOWCREATED,   56
.equ CB_ONNATIVEWINDOWDESTROYED, 72

// pthread_attr: default = 0 (NULL)
// nanosleep syscall = 101

// ─── ДАННЫЕ ──────────────────────────────────────────────────
.section .rodata
tag_str:       .asciz "ASM_HELLO"
msg_create:    .asciz "onCreate — pure ARM64 ASM"
msg_thread:    .asciz "Render thread started"
msg_window:    .asciz "Window acquired"
msg_render:    .asciz "Rendering Hello World"
msg_stop:      .asciz "Render thread stopped"
msg_nolock:    .asciz "ANativeWindow_lock failed"

// Пиксельный шрифт 5x7
// "Hello World!" — 12 символов, каждый 7 байт
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
.equ FONT_CHARS, 12

// ─── ГЛОБАЛЬНОЕ СОСТОЯНИЕ ────────────────────────────────────
.section .bss
.align 8
g_window:     .space 8    // ANativeWindow* (атомарно)
g_running:    .space 4    // 1 = работать, 0 = стоп
.align 4
g_thread:     .space 8    // pthread_t

.section .text

// ═══════════════════════════════════════════════════════════════
// ANativeActivity_onCreate
// x0=ANativeActivity*, x1=savedState*, x2=size
// ═══════════════════════════════════════════════════════════════
ANativeActivity_onCreate:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]

    mov     x19, x0                     // activity

    // g_running = 1
    adrp    x0, g_running
    add     x0, x0, :lo12:g_running
    mov     w1, #1
    str     w1, [x0]

    // g_window = NULL
    adrp    x0, g_window
    add     x0, x0, :lo12:g_window
    str     xzr, [x0]

    // Установить коллбеки через activity->callbacks
    ldr     x0, [x19]                   // callbacks*

    adrp    x1, cb_on_window_created
    add     x1, x1, :lo12:cb_on_window_created
    str     x1, [x0, #CB_ONNATIVEWINDOWCREATED]

    adrp    x1, cb_on_window_destroyed
    add     x1, x1, :lo12:cb_on_window_destroyed
    str     x1, [x0, #CB_ONNATIVEWINDOWDESTROYED]

    adrp    x1, cb_on_destroy
    add     x1, x1, :lo12:cb_on_destroy
    str     x1, [x0, #CB_ONDESTROY]

    // Запустить рендер-поток: pthread_create(&g_thread, NULL, render_thread, NULL)
    adrp    x0, g_thread
    add     x0, x0, :lo12:g_thread
    mov     x1, #0                      // attr = NULL
    adrp    x2, render_thread
    add     x2, x2, :lo12:render_thread
    mov     x3, #0                      // arg = NULL
    bl      pthread_create

    adrp    x0, tag_str
    add     x0, x0, :lo12:tag_str
    adrp    x1, msg_create
    add     x1, x1, :lo12:msg_create
    bl      asm_log

    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// ═══════════════════════════════════════════════════════════════
// cb_on_window_created — коллбек Android (быстрый, не блокирует)
// x0=ANativeActivity*, x1=ANativeWindow*
// ═══════════════════════════════════════════════════════════════
cb_on_window_created:
    adrp    x0, g_window
    add     x0, x0, :lo12:g_window
    str     x1, [x0]                    // g_window = window (атомарно для arm64)
    ret

// ═══════════════════════════════════════════════════════════════
// cb_on_window_destroyed
// ═══════════════════════════════════════════════════════════════
cb_on_window_destroyed:
    adrp    x0, g_window
    add     x0, x0, :lo12:g_window
    str     xzr, [x0]                   // g_window = NULL
    ret

// ═══════════════════════════════════════════════════════════════
// cb_on_destroy
// ═══════════════════════════════════════════════════════════════
cb_on_destroy:
    adrp    x0, g_running
    add     x0, x0, :lo12:g_running
    str     wzr, [x0]                   // g_running = 0
    // Дождаться завершения потока
    adrp    x0, g_thread
    add     x0, x0, :lo12:g_thread
    ldr     x0, [x0]
    mov     x1, #0
    b       pthread_join                // tail call

// ═══════════════════════════════════════════════════════════════
// render_thread — рендер в отдельном потоке
// x0 = arg (не используется)
// ═══════════════════════════════════════════════════════════════
render_thread:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]

    adrp    x0, tag_str
    add     x0, x0, :lo12:tag_str
    adrp    x1, msg_thread
    add     x1, x1, :lo12:msg_thread
    bl      asm_log

.wait_window:
    // Ждать пока g_running && g_window != NULL
    adrp    x0, g_running
    add     x0, x0, :lo12:g_running
    ldr     w0, [x0]
    cbz     w0, .thread_exit

    adrp    x0, g_window
    add     x0, x0, :lo12:g_window
    ldr     x19, [x0]
    cbnz    x19, .got_window

    // Спать 5ms и повторить
    sub     sp, sp, #16
    str     xzr, [sp]                   // tv_sec=0
    mov     x0, #0x4E20                 // 5_000_000 ns = 5ms
    movk    x0, #0x004C, lsl #16
    str     x0, [sp, #8]
    mov     x0, sp
    mov     x1, #0
    mov     x8, #101                    // SYS_nanosleep
    svc     #0
    add     sp, sp, #16
    b       .wait_window

.got_window:
    // Установить формат RGBA_8888
    mov     x0, x19
    mov     w1, #WINDOW_FORMAT_RGBA_8888
    mov     w2, #0
    mov     w3, #0
    bl      ANativeWindow_setBuffersGeometry

.render_loop:
    adrp    x0, g_running
    add     x0, x0, :lo12:g_running
    ldr     w0, [x0]
    cbz     w0, .thread_exit

    adrp    x0, g_window
    add     x0, x0, :lo12:g_window
    ldr     x0, [x0]
    cbz     x0, .wait_window            // окно пропало — ждать снова

    // Нарисовать кадр
    bl      asm_draw_frame

    // nanosleep 16ms (≈60fps)
    sub     sp, sp, #16
    str     xzr, [sp]                   // tv_sec=0
    mov     x0, #0x8000
    movk    x0, #0x00F4, lsl #16        // ≈16ms
    str     x0, [sp, #8]
    mov     x0, sp
    mov     x1, #0
    mov     x8, #101
    svc     #0
    add     sp, sp, #16

    b       .render_loop

.thread_exit:
    adrp    x0, tag_str
    add     x0, x0, :lo12:tag_str
    adrp    x1, msg_stop
    add     x1, x1, :lo12:msg_stop
    bl      asm_log

    mov     x0, #0
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// ═══════════════════════════════════════════════════════════════
// asm_draw_frame — нарисовать Hello World
// (берёт окно из g_window)
// ═══════════════════════════════════════════════════════════════
asm_draw_frame:
    stp     x29, x30, [sp, #-80]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    stp     x25, x26, [sp, #64]

    // Загрузить текущее окно
    adrp    x19, g_window
    add     x19, x19, :lo12:g_window
    ldr     x19, [x19]
    cbz     x19, .df_exit

    // ANativeWindow_Buffer на стеке (56 байт достаточно)
    sub     sp, sp, #64
    mov     x0, x19
    mov     x1, sp
    mov     x2, #0
    bl      ANativeWindow_lock
    cbnz    w0, .df_unlock_fail

    ldr     w20, [sp]                   // width
    ldr     w21, [sp, #4]               // height
    ldr     w22, [sp, #8]               // stride
    ldr     x23, [sp, #32]              // bits*

    // Залить фон 0xFF1A1A2E
    mov     w0, w21
    mul     w0, w0, w22
    mov     x24, x23
    mov     w1, w0
    mov     w2, #0x1A2E
    movk    w2, #0xFF1A, lsl #16
    bl      asm_fill_color

    // Масштаб: scale = max(2, width/120)
    mov     w25, w20
    mov     w26, #120
    udiv    w25, w25, w26
    cmp     w25, #2
    bge     .scale_ok
    mov     w25, #2
.scale_ok:
    cmp     w25, #8                     // ограничим масштаб
    ble     .scale_ok2
    mov     w25, #8
.scale_ok2:

    // text_width = FONT_CHARS * 6 * scale
    mov     w0, #FONT_CHARS
    mov     w1, #6
    mul     w0, w0, w1
    mul     w0, w0, w25

    // x_start = (width - text_width) / 2
    sub     w24, w20, w0
    asr     w24, w24, #1
    // Защита от отрицательного x
    cmp     w24, #0
    bge     .xstart_ok
    mov     w24, #2
.xstart_ok:

    // y_start = height/2 - (7*scale/2)
    mov     w0, #7
    mul     w0, w0, w25
    asr     w0, w0, #1
    asr     w26, w21, #1
    sub     w26, w26, w0
    cmp     w26, #0
    bge     .ystart_ok
    mov     w26, #2
.ystart_ok:

    // Нарисовать каждый символ
    mov     w19, #0                     // char_index (переиспользуем x19 как int)

.char_loop:
    cmp     w19, #FONT_CHARS
    bge     .chars_done

    // font_ptr = font_data + char_index * 7
    adrp    x0, font_data
    add     x0, x0, :lo12:font_data
    mov     w1, #7
    mul     w1, w19, w1
    add     x0, x0, x1                  // x0 = char font data

    // char_x = x_start + char_index * 6 * scale
    mov     w1, #6
    mul     w1, w19, w1
    mul     w1, w1, w25
    add     w1, w24, w1                 // char_x

    // Нарисовать символ: 7 строк x 5 колонок x scale x scale
    mov     w2, #0                      // row

.row_loop:
    cmp     w2, #7
    bge     .row_done
    ldrb    w3, [x0, x2]              // bitmap_row

    mov     w4, #0                      // col
.col_loop:
    cmp     w4, #5
    bge     .col_done

    // Проверить бит
    mov     w5, #4
    sub     w5, w5, w4
    lsr     w5, w3, w5
    and     w5, w5, #1
    cbz     w5, .col_next

    // Нарисовать scale×scale блок
    mov     w5, #0                      // sy
.sy_loop:
    cmp     w5, w25
    bge     .sy_done
    mov     w6, #0                      // sx
.sx_loop:
    cmp     w6, w25
    bge     .sx_done

    // py = y_start + row*scale + sy
    mul     w7, w2, w25
    add     w7, w26, w7
    add     w7, w7, w5
    cmp     w7, w21
    bge     .sx_next

    // px = char_x + col*scale + sx
    mul     w8, w4, w25
    add     w8, w1, w8
    add     w8, w8, w6
    cmp     w8, w20
    bge     .sx_next

    // offset = (py*stride + px) * 4
    mul     w9, w7, w22
    add     w9, w9, w8
    lsl     x9, x9, #2
    add     x9, x23, x9

    // Цвет текста 0xFFE8E8FF
    mov     w10, #0xE8FF
    movk    w10, #0xFFE8, lsl #16
    str     w10, [x9]

.sx_next:
    add     w6, w6, #1
    b       .sx_loop
.sx_done:
    add     w5, w5, #1
    b       .sy_loop
.sy_done:
.col_next:
    add     w4, w4, #1
    b       .col_loop
.col_done:
    add     w2, w2, #1
    b       .row_loop
.row_done:
    add     w19, w19, #1
    b       .char_loop

.chars_done:
    add     sp, sp, #64

    // ANativeWindow_unlockAndPost
    adrp    x0, g_window
    add     x0, x0, :lo12:g_window
    ldr     x0, [x0]
    cbz     x0, .df_exit
    bl      ANativeWindow_unlockAndPost
    b       .df_exit

.df_unlock_fail:
    add     sp, sp, #64

.df_exit:
    ldp     x25, x26, [sp, #64]
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #80
    ret

// ═══════════════════════════════════════════════════════════════
// asm_fill_color — NEON заливка
// x0=buf, w1=pixels, w2=color
// ═══════════════════════════════════════════════════════════════
asm_fill_color:
    cbz     w1, .fc_done
    cbz     x0, .fc_done
    dup     v0.4s, w2
    dup     v1.4s, w2
    dup     v2.4s, w2
    dup     v3.4s, w2
    lsr     w3, w1, #4
    cbz     w3, .fc_tail
.fc_loop:
    st1     {v0.4s, v1.4s, v2.4s, v3.4s}, [x0], #64
    subs    w3, w3, #1
    bne     .fc_loop
.fc_tail:
    and     w1, w1, #15
    cbz     w1, .fc_done
.fc_px:
    str     w2, [x0], #4
    subs    w1, w1, #1
    bne     .fc_px
.fc_done:
    ret

// ═══════════════════════════════════════════════════════════════
// asm_log — логирование
// x0=tag, x1=msg
// ═══════════════════════════════════════════════════════════════
asm_log:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    mov     x2, x1
    mov     w1, #ANDROID_LOG_INFO
    bl      __android_log_print
    ldp     x29, x30, [sp], #16
    ret

.end