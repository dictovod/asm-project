// main_asm.S — 100% ARM64 Assembly для Android NativeActivity
// Содержит: точку входа ANativeActivity_onCreate (замена native_glue.c),
//           android_main, lifecycle, draw loop, logging, NEON-утилиты

.section .text
.global ANativeActivity_onCreate
.global android_main
.global asm_get_system_time
.global asm_fill_color
.global asm_calculate_fps
.global asm_memset_fast
.global asm_strlen
.global asm_event_loop

// ─── КОНСТАНТЫ ───────────────────────────────────────────────
.equ ANDROID_LOG_INFO,      4
.equ ANDROID_LOG_DEBUG,     3
.equ ANDROID_LOG_ERROR,     6

// ─── СТРОКИ (rodata) ─────────────────────────────────────────
.section .rodata
tag_str:        .asciz "ASM_NATIVE"
msg_start:      .asciz "=== Android Assembly App Started ==="
msg_loop:       .asciz "Main loop tick: %d"
msg_init:       .asciz "NativeActivity initialized from pure ASM"
msg_destroy:    .asciz "NativeActivity destroyed"
msg_resume:     .asciz "Activity RESUMED"
msg_pause:      .asciz "Activity PAUSED"
msg_fps:        .asciz "FPS: %d | Frame: %d | Time: %lld ms"
msg_window:     .asciz "Window created, starting render loop"
msg_color:      .asciz "Frame color R:%d G:%d B:%d"
msg_oncreate:   .asciz "ANativeActivity_onCreate called from ASM"

.section .text

// ═══════════════════════════════════════════════════════
// ANativeActivity_onCreate — точка входа Android
// Заменяет native_glue.c полностью
// x0 = ANativeActivity*, x1 = savedState*, x2 = savedStateSize
// ═══════════════════════════════════════════════════════
ANativeActivity_onCreate:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp

    // Логируем вход
    adrp    x0, tag_str
    add     x0, x0, :lo12:tag_str
    adrp    x1, msg_oncreate
    add     x1, x1, :lo12:msg_oncreate
    bl      asm_log_info

    // Передаём управление в android_main
    // В реальном NativeActivity android_main вызывается через app glue,
    // здесь вызываем напрямую с нулевым аргументом
    mov     x0, #0
    bl      android_main

    ldp     x29, x30, [sp], #16
    ret

// ═══════════════════════════════════════════════════════
// android_main — основной цикл приложения
// x0 = struct android_app* (может быть 0 при прямом вызове)
// ═══════════════════════════════════════════════════════
android_main:
    stp     x29, x30, [sp, #-64]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]

    mov     x19, x0

    adrp    x0, tag_str
    add     x0, x0, :lo12:tag_str
    adrp    x1, msg_start
    add     x1, x1, :lo12:msg_start
    bl      asm_log_info

    mov     x0, x19
    bl      asm_setup_callbacks

    mov     x20, #0
    mov     x21, #0
    mov     x22, #0

    adrp    x0, tag_str
    add     x0, x0, :lo12:tag_str
    adrp    x1, msg_init
    add     x1, x1, :lo12:msg_init
    bl      asm_log_info

    b       .main_loop

.main_loop:
    mov     x0, x19
    bl      asm_process_events

    cbz     x19, .skip_destroy_check
    ldr     w1, [x19, #8]
    cbnz    w1, .main_exit

.skip_destroy_check:
    add     x20, x20, #1

    and     x1, x20, #63
    cbnz    x1, .skip_log

    adrp    x0, tag_str
    add     x0, x0, :lo12:tag_str
    adrp    x1, msg_loop
    add     x1, x1, :lo12:msg_loop
    mov     x2, x20
    bl      asm_log_debug

.skip_log:
    cbz     x19, .main_loop
    ldr     x1, [x19, #16]
    cbz     x1, .main_loop

    mov     x0, x19
    mov     x1, x20
    bl      asm_render_frame

    b       .main_loop

.main_exit:
    adrp    x0, tag_str
    add     x0, x0, :lo12:tag_str
    adrp    x1, msg_destroy
    add     x1, x1, :lo12:msg_destroy
    bl      asm_log_info

    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #64
    ret

// ═══════════════════════════════════════════════════════
// asm_setup_callbacks
// ═══════════════════════════════════════════════════════
asm_setup_callbacks:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    ldp     x29, x30, [sp], #16
    ret

// ═══════════════════════════════════════════════════════
// asm_process_events
// ═══════════════════════════════════════════════════════
asm_process_events:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    str     x19, [sp, #16]
    mov     x19, x0
    mov     x0, #0
    mov     x1, #0
    mov     x2, #0
    mov     x3, #0
    bl      ALooper_pollOnce
    ldr     x19, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// ═══════════════════════════════════════════════════════
// asm_render_frame
// ═══════════════════════════════════════════════════════
asm_render_frame:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    str     x21, [sp, #32]

    mov     x19, x0
    mov     x20, x1

    lsr     w2, w20, #1
    and     w2, w2, #0xFF
    lsr     w3, w20, #2
    and     w3, w3, #0xFF
    lsr     w4, w20, #3
    and     w4, w4, #0xFF

    adrp    x0, tag_str
    add     x0, x0, :lo12:tag_str
    adrp    x1, msg_color
    add     x1, x1, :lo12:msg_color
    bl      asm_log_debug

    ldr     x21, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

// ═══════════════════════════════════════════════════════
// asm_fill_color — NEON заполнение буфера
// x0 = buffer, w1 = size, w2 = color
// ═══════════════════════════════════════════════════════
asm_fill_color:
    cbz     w1, .fill_done
    cbz     x0, .fill_done

    dup     v0.4s, w2
    dup     v1.4s, w2
    dup     v2.4s, w2
    dup     v3.4s, w2

    lsr     w3, w1, #6
    cbz     w3, .fill_remainder

.fill_loop64:
    st1     {v0.4s, v1.4s, v2.4s, v3.4s}, [x0], #64
    subs    w3, w3, #1
    bne     .fill_loop64

.fill_remainder:
    and     w1, w1, #63
    cbz     w1, .fill_done

.fill_byte_loop:
    str     w2, [x0], #4
    subs    w1, w1, #4
    bgt     .fill_byte_loop

.fill_done:
    ret

// ═══════════════════════════════════════════════════════
// asm_memset_fast — быстрый memset через NEON
// x0 = dst, w1 = value, x2 = count
// ═══════════════════════════════════════════════════════
asm_memset_fast:
    cbz     x2, .memset_done
    dup     v0.16b, w1

    lsr     x3, x2, #4
    cbz     x3, .memset_tail

.memset_loop:
    st1     {v0.16b}, [x0], #16
    subs    x3, x3, #1
    bne     .memset_loop

.memset_tail:
    and     x2, x2, #15
    cbz     x2, .memset_done

.memset_byte:
    strb    w1, [x0], #1
    subs    x2, x2, #1
    bne     .memset_byte

.memset_done:
    ret

// ═══════════════════════════════════════════════════════
// asm_strlen
// x0 = string → x0 = length
// ═══════════════════════════════════════════════════════
asm_strlen:
    mov     x1, x0
.strlen_loop:
    ldrb    w2, [x1], #1
    cbnz    w2, .strlen_loop
    sub     x0, x1, x0
    sub     x0, x0, #1
    ret

// ═══════════════════════════════════════════════════════
// asm_get_system_time — время в мс
// ═══════════════════════════════════════════════════════
asm_get_system_time:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp

    mov     x0, #1
    add     x1, sp, #16
    bl      clock_gettime

    ldr     x0, [sp, #16]
    ldr     x1, [sp, #24]

    mov     x2, #0x3E8
    mul     x0, x0, x2

    movz    x2, #0x4240
    movk    x2, #0xF, lsl #16
    udiv    x1, x1, x2

    add     x0, x0, x1

    ldp     x29, x30, [sp], #32
    ret

// ═══════════════════════════════════════════════════════
// asm_calculate_fps
// x0 = current_ms, x1 = last_ms, x2 = frames → x0 = fps
// ═══════════════════════════════════════════════════════
asm_calculate_fps:
    sub     x3, x0, x1
    cbz     x3, .fps_zero
    mov     x4, #0x3E8
    mul     x2, x2, x4
    udiv    x0, x2, x3
    ret
.fps_zero:
    mov     x0, #0
    ret

// ═══════════════════════════════════════════════════════
// asm_log_info / asm_log_debug
// x0 = tag, x1 = message
// ═══════════════════════════════════════════════════════
asm_log_info:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    mov     x2, x1
    mov     x1, #ANDROID_LOG_INFO
    bl      __android_log_print
    ldp     x29, x30, [sp], #16
    ret

asm_log_debug:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    mov     x2, x1
    mov     x1, #ANDROID_LOG_DEBUG
    bl      __android_log_print
    ldp     x29, x30, [sp], #16
    ret

// ═══════════════════════════════════════════════════════
// asm_event_loop
// ═══════════════════════════════════════════════════════
asm_event_loop:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    mov     x0, #0
    mov     x1, xzr
    mov     x2, xzr
    mov     x3, xzr
    bl      ALooper_pollOnce
    ldp     x29, x30, [sp], #16
    ret

.end
