include "gen/constants.asm"

; TODO: If we need more zero page we can use the whole language ZP allocation or take over the
; machine, but for now let's start by being BASIC compatible.
org &70
guard &90
.state skip 5 ; this must be at a BASIC-compatible location as we seed it from the loader
.noise_index skip 1
.uninitialised_zp_start
.patch_zp skip 2
.step_size_mutation_count skip 1
.temp skip 1
.temp2 skip 1

; TODO: If we need more space we could take over the whole machine and relocate down much lower,
; but in practice we're probably bottlenecked on CPU cycles more than RAM.
org &e00
runtime_guard = screen_base + (top_flame_line * screen_line_length_bytes)
guard runtime_guard

bytes_per_screen_cell = 8
osbyte_wait_for_vsync = 19
osbyte_read_key = 129
osbyte_select_tape = 140
vdu_set_palette = 19
osrdch = &ffd0
oswrch = &ffee
osbyte = &fff4

macro cool_even line
    if line >= double_cool_threshold_line
        lda single_cool_table_even,x
    else
        lda double_cool_table_even,x
    endif
endmacro

macro cool_odd line
    if line >= double_cool_threshold_line
        lda single_cool_table_odd,x
    else
        lda double_cool_table_odd,x
    endif
endmacro

macro move_line_for_column_y_for_strip_based_at_p_by_2 line, strip_base_addr
    ldx strip_base_addr+2,y:                         cool_even line:sta strip_base_addr+0,y
    ldx strip_base_addr+3,y:                         cool_odd line: sta strip_base_addr+1,y
    ldx strip_base_addr+4,y:                         cool_even line:sta strip_base_addr+2,y
    ldx strip_base_addr+5,y:                         cool_odd line: sta strip_base_addr+3,y
    ldx strip_base_addr+6,y:                         cool_even line:sta strip_base_addr+4,y
    ldx strip_base_addr+7,y:                         cool_odd line: sta strip_base_addr+5,y
    ldx strip_base_addr+screen_line_length_bytes+0,y:cool_even line:sta strip_base_addr+6,y
    ldx strip_base_addr+screen_line_length_bytes+1,y:cool_odd line: sta strip_base_addr+7,y
endmacro

macro move_line_for_column_y_for_strip_based_at_p_by_4 line, strip_base_addr
    ldx strip_base_addr+4,y:                         cool_even line:sta strip_base_addr+0,y
    ldx strip_base_addr+5,y:                         cool_odd line: sta strip_base_addr+1,y
    ldx strip_base_addr+6,y:                         cool_even line:sta strip_base_addr+2,y
    ldx strip_base_addr+7,y:                         cool_odd line: sta strip_base_addr+3,y
    ldx strip_base_addr+screen_line_length_bytes+0,y:cool_even line:sta strip_base_addr+4,y
    ldx strip_base_addr+screen_line_length_bytes+1,y:cool_odd line: sta strip_base_addr+5,y
    ldx strip_base_addr+screen_line_length_bytes+2,y:cool_even line:sta strip_base_addr+6,y
    ldx strip_base_addr+screen_line_length_bytes+3,y:cool_odd line: sta strip_base_addr+7,y
endmacro

; TODO: The next two macros have a special case which means that if they're copying from the noise
; line at the bottom, they only copy the top four screen rows and pretend the bottom half is a
; duplicate. This was originally done before the second variant 4-pixel tall row of noise was 
; added, so I didn't have to actually double up the noise (which looked a bit ugly). We do now have
; variant noise there, so we don't need this special case in order to avoid copying black from the
; empty bottom half of that row. We could experiment to see if it would look better not to have the
; special case and let the variant noise be copied up. There is a small performance benefit from
; this special case though, which might be more valuable.

macro move_line_for_column_y_for_strip_based_at_p_by_6 line, strip_base_addr
    if line < (bottom_flame_line - 1)
        ldx strip_base_addr+6,y:                         cool_even line:sta strip_base_addr+0,y
        ldx strip_base_addr+7,y:                         cool_odd line: sta strip_base_addr+1,y
        ldx strip_base_addr+screen_line_length_bytes+0,y:cool_even line:sta strip_base_addr+2,y
        ldx strip_base_addr+screen_line_length_bytes+1,y:cool_odd line: sta strip_base_addr+3,y
        ldx strip_base_addr+screen_line_length_bytes+2,y:cool_even line:sta strip_base_addr+4,y
        ldx strip_base_addr+screen_line_length_bytes+3,y:cool_odd line: sta strip_base_addr+5,y
        ldx strip_base_addr+screen_line_length_bytes+4,y:cool_even line:sta strip_base_addr+6,y
        ldx strip_base_addr+screen_line_length_bytes+5,y:cool_odd line: sta strip_base_addr+7,y
    else
        ldx strip_base_addr+6,y:                         cool_even line:sta strip_base_addr+0,y
        ldx strip_base_addr+7,y:                         cool_odd line: sta strip_base_addr+1,y
        ldx strip_base_addr+screen_line_length_bytes+0,y:cool_even line:sta strip_base_addr+2,y:sta strip_base_addr+4,y:sta strip_base_addr+6,y
        ldx strip_base_addr+screen_line_length_bytes+1,y:cool_odd line: sta strip_base_addr+3,y:sta strip_base_addr+5,y:sta strip_base_addr+7,y
    endif
endmacro

macro move_line_for_column_y_for_strip_based_at_p_by_8 line, strip_base_addr
    if line < (bottom_flame_line - 1)
        ldx strip_base_addr+screen_line_length_bytes+0,y:cool_even line:sta strip_base_addr+0,y
        ldx strip_base_addr+screen_line_length_bytes+1,y:cool_odd line: sta strip_base_addr+1,y
        ldx strip_base_addr+screen_line_length_bytes+2,y:cool_even line:sta strip_base_addr+2,y
        ldx strip_base_addr+screen_line_length_bytes+3,y:cool_odd line: sta strip_base_addr+3,y
        ldx strip_base_addr+screen_line_length_bytes+4,y:cool_even line:sta strip_base_addr+4,y
        ldx strip_base_addr+screen_line_length_bytes+5,y:cool_odd line: sta strip_base_addr+5,y
        ldx strip_base_addr+screen_line_length_bytes+6,y:cool_even line:sta strip_base_addr+6,y
        ldx strip_base_addr+screen_line_length_bytes+7,y:cool_odd line: sta strip_base_addr+7,y
    else
        ldx strip_base_addr+screen_line_length_bytes+0,y:cool_even line:sta strip_base_addr+0,y:sta strip_base_addr+4,y
        ldx strip_base_addr+screen_line_length_bytes+1,y:cool_odd line: sta strip_base_addr+1,y:sta strip_base_addr+5,y 
        ldx strip_base_addr+screen_line_length_bytes+2,y:cool_even line:sta strip_base_addr+2,y:sta strip_base_addr+6,y
        ldx strip_base_addr+screen_line_length_bytes+3,y:cool_odd line: sta strip_base_addr+3,y:sta strip_base_addr+7,y
    endif
endmacro

macro move_entire_column_y_for_strip_n_by_m strip_index, step_size
    ; bottom_flame_line has fresh noise written to it after we do the moving, so it's not handled
    ; here.
    for line, top_flame_line, bottom_flame_line - 1
        strip_base_addr = screen_base + (line * screen_line_length_bytes) + (left_column + strip_index * columns_per_strip) * bytes_per_screen_cell
        if step_size == 2
            move_line_for_column_y_for_strip_based_at_p_by_2 line, strip_base_addr
        elif step_size == 4
            move_line_for_column_y_for_strip_based_at_p_by_4 line, strip_base_addr
        elif step_size == 6
            move_line_for_column_y_for_strip_based_at_p_by_6 line, strip_base_addr
        elif step_size == 8
            move_line_for_column_y_for_strip_based_at_p_by_8 line, strip_base_addr
        else
            assert FALSE
        endif
    next
    rts
endmacro

.runtime_start
    ; Clear the flame area as it may still have leftover data from our high load.
    lda #0:tax
.clear_screen_loop
.clear_screen_sta
    sta screen_base + top_flame_line * screen_line_length_bytes,x ; patched
    inx:bne clear_screen_loop
    inc clear_screen_sta+2:bpl clear_screen_loop

.main_loop
    ; Move the flame body up the screen.

    ; If we have more than one strip, we could technically interleave things differently here to
    ; share a single ldy # across all strips. The performance and code size impact would likely be 
    ; minimal and it would also make the runtime patching of these jsrs much fiddlier.
    for strip, 0, strip_count - 1
        if strip == strip_count - 1
            columns_in_strip = column_count - (columns_per_strip * (strip_count - 1))
        else
            columns_in_strip = columns_per_strip
        endif
        for column, 0, columns_in_strip-1
            ldy #column * bytes_per_screen_cell
            if strip == 0
                jsr move_entire_column_y_for_strip_0_by_2 ; patched later
            elif strip == 1
                jsr move_entire_column_y_for_strip_1_by_2 ; patched later
            else
                assert FALSE
            endif
        next
    next

    ; Write new noise at the bottom of the screen into the space (logically) vacated by the move up
    ; of the flame body. This will start to move up itself in the next frame.
    ;
    ; The noise is pre-computed but we apply a small random variation to it on each frame.
    ldx noise_index
    for column, 0, column_count - 1
        ; We randomly nudge block indexes by eoring with a two bit value. If block_count isn't a
        ; multiple of 4, this might bump a value above block_count.
        assert (block_count mod 4) == 0

        noise_base = screen_base + bottom_flame_line * screen_line_length_bytes + (left_column + column) * bytes_per_screen_cell
        ldy noise_table + column * noise_table_length,x
        jsr prng:sta temp2:and #%11:eor identity_table,y:tay
        lda block_even_screen_bytes,y:sta noise_base+0:sta noise_base+2
        lda block_odd_screen_bytes,y: sta noise_base+1:sta noise_base+3
        ; Fabricate a variant "lower half" for the noise block.
        lda temp2:lsr a:lsr a:and #%11:eor identity_table,y:tay
        lda block_even_screen_bytes,y:sta noise_base+4:sta noise_base+6
        lda block_odd_screen_bytes,y: sta noise_base+5:sta noise_base+7
    next
    ; TODO: Would it help to randomly skip a noise index sometimes? My gut feeling is that it
    ; wouldn't help much, but I haven't tried it.
    if noise_table_length == 256
        inc noise_index
    else
        inx
        cpx #noise_table_length:bcc no_wrap
        ldx #0
    .no_wrap
        stx noise_table_length
    endif

    ; Mutate the step size for one or more columns.
    ;
    ; The effect does work if we just hard-code a randomly selected step size per column in
    ; main_loop. It looks a lot better if we have additional variability from the step sizes
    ; changing. 
    ;
    ; We can change this relatively efficiently by patching the jsr instruction for a column in
    ; main_loop to point to a subroutine for the same strip but a different step size. The patching
    ; is slightly fiddly but not that big a deal.
    ;
    ; TODO: The big problem is deciding what to change and when. I am not at all sure what I have
    ; here is best or gives any value for the complexity. In order to have what is hopefully
    ; "vaguely clumpy" noise, we pick a random column to change and re-use *a* value from the
    ; noise table for that column. We're not using sequential values, and because the column is
    ; picked randomly, this may not really give any clumping at all. There might well be a better
    ; approach, and it's possible that just picking a random column and setting it to a random
    ; step size would work just as well, or better, and be faster as well.

    ; TODO: It might help to do multiple mutations per frame, but in practice one seems to work OK.
    ; It's possible there's a trade-off between PRNG quality and speed here.
    step_size_mutations_per_frame = 1
    if step_size_mutations_per_frame > 1
        lda #step_size_mutations_per_frame:sta step_size_mutation_count
    .step_size_mutation_loop
    endif

    ; Pick a random column to modify.
    jsr prng
    if (column_count and (column_count - 1)) == 0
        and #column_count - 1
    else
        assert column_count <= 64
        ; We use a simple biased algorithm to reduce the value into range. This is probably fine
        ; given what we're doing.
        and #63
        cmp #column_count:bcc in_range
        sec:sbc #column_count
    .in_range
    endif
    tax ; X is the randomly selected column to modify

    ; Set patch_zp to point to the target of the jsr for column X.
    ; TODO: Just possibly step_patch_table could live in zp and we could use it directly with (zp),y
    ; addressing, but it's probably not worth it.
    lda step_patch_table_low,x:sta patch_zp
    lda step_patch_table_high,x:sta patch_zp+1

    ; Very hackily get the noise value for column X in the current noise row and map it through
    ; the block_to_step_size* to bias it and convert it into the desired step size subroutine.
    assert noise_table_length == 256
    assert lo(noise_table) == 0
    txa:clc:adc #hi(noise_table):sta ldx_noise+2
    ldy noise_index
if strip_count == 1
.ldx_noise
    ldx &ff00,y ; patched
    ldy #0:lda block_to_step_size_subroutine_low,x:sta (patch_zp),y
    iny:   lda block_to_step_size_subroutine_high,x:sta (patch_zp),y
elif strip_count == 2
{
    txa
.^ldx_noise
    ldx &ff00,y ; patched
    cmp #columns_per_strip:bcs strip_1
    ldy #0:lda block_to_step_size_subroutine_low,x:sta (patch_zp),y
    iny:   lda block_to_step_size_subroutine_high,x:sta (patch_zp),y
    jmp done
.strip_1
    ldy #0:lda block_to_step_size_subroutine_strip_1_low,x:sta (patch_zp),y
    iny:   lda block_to_step_size_subroutine_strip_1_high,x:sta (patch_zp),y
.done
}
else
    assert FALSE
endif

    if step_size_mutations_per_frame > 1
        dec step_size_mutation_count
        bne step_size_mutation_loop
    endif

    ; TODO: I suspect it's better not to wait for vsync, but I'm not sure.
    ; lda #osbyte_wait_for_vsync:jsr osbyte

    ; For debugging or fun, we can pause once per update and wait for a keypress.
    ; jsr osrdch

    ; TODO: If we shut out the OS (reading the keyboard and reprogramming the palette ourselves),
    ; we could probably run with interrupts disabled all the time and maybe get slightly higher/
    ; more consistent frame rates.
    lda #osbyte_read_key:ldx #0:ldy #0:jsr osbyte
    bcs no_key_pressed
    cpx #'0':bcc no_key_pressed
    cpx #'3'+1:bcs no_key_pressed
    txa:sec:sbc #'0':tax
    lda #vdu_set_palette:jsr oswrch
    txa:jsr oswrch
    lda physical_colour_table,x:clc:adc #1:and #7:sta physical_colour_table,x:jsr oswrch
    lda #0:jsr oswrch:jsr oswrch:jsr oswrch
.no_key_pressed

    jmp main_loop

; This table is used in a relatively tight loop and it's worth ensuring there's no page crossing
; penalty.
.identity_table
    for i, 0, block_count - 1
        equb i
    next
assert hi(P% - 1) == hi(identity_table)

; TODO: It's possible some of these tables would benefit from not crossing pages but it's probably
; that big a deal and arranging this without wasting space is likely to be fiddly.

.physical_colour_table
    equb 0, 1, 3, 7 ; default mode 1 colours to start with, which are luckily perfect

.step_patch_table_low
    for column, 0, column_count - 1
        equb lo(main_loop + column * 5 + 3)
    next
.step_patch_table_high
    for column, 0, column_count - 1
        equb hi(main_loop + column * 5 + 3)
    next

.block_to_step_size_subroutine_low
    for i, 0, block_count - 1
        if i <= block_count * (3 / 16) 
            equb lo(move_entire_column_y_for_strip_0_by_2)
        elif i <= block_count * (8 / 16)
            equb lo(move_entire_column_y_for_strip_0_by_4)
        elif i <= block_count * (12 / 16)
            equb lo(move_entire_column_y_for_strip_0_by_6)
        else
            equb lo(move_entire_column_y_for_strip_0_by_8)
        endif
    next
.block_to_step_size_subroutine_high
    for i, 0, block_count - 1
        if i <= block_count * (3 / 16)
            equb hi(move_entire_column_y_for_strip_0_by_2)
        elif i <= block_count * (8 / 16)
            equb hi(move_entire_column_y_for_strip_0_by_4)
        elif i <= block_count * (12 / 16)
            equb hi(move_entire_column_y_for_strip_0_by_6)
        else
            equb hi(move_entire_column_y_for_strip_0_by_8)
        endif
    next
if strip_count > 1
    assert strip_count == 2
.block_to_step_size_subroutine_strip_1_low
    for i, 0, block_count - 1
        if i <= block_count * (3 / 16) 
            equb lo(move_entire_column_y_for_strip_1_by_2)
        elif i <= block_count * (8 / 16)
            equb lo(move_entire_column_y_for_strip_1_by_4)
        elif i <= block_count * (12 / 16)
            equb lo(move_entire_column_y_for_strip_1_by_6)
        else
            equb lo(move_entire_column_y_for_strip_1_by_8)
        endif
    next
.block_to_step_size_subroutine_strip_1_high
    for i, 0, block_count - 1
        if i <= block_count * (3 / 16)
            equb hi(move_entire_column_y_for_strip_1_by_2)
        elif i <= block_count * (8 / 16)
            equb hi(move_entire_column_y_for_strip_1_by_4)
        elif i <= block_count * (12 / 16)
            equb hi(move_entire_column_y_for_strip_1_by_6)
        else
            equb hi(move_entire_column_y_for_strip_1_by_8)
        endif
    next
endif

.move_entire_column_y_for_strip_0_by_2
    move_entire_column_y_for_strip_n_by_m 0, 2
.move_entire_column_y_for_strip_0_by_4
    move_entire_column_y_for_strip_n_by_m 0, 4
.move_entire_column_y_for_strip_0_by_6
    move_entire_column_y_for_strip_n_by_m 0, 6
.move_entire_column_y_for_strip_0_by_8
    move_entire_column_y_for_strip_n_by_m 0, 8

if strip_count > 1
    .move_entire_column_y_for_strip_1_by_2
        move_entire_column_y_for_strip_n_by_m 1, 2
    .move_entire_column_y_for_strip_1_by_4
        move_entire_column_y_for_strip_n_by_m 1, 4
    .move_entire_column_y_for_strip_1_by_6
        move_entire_column_y_for_strip_n_by_m 1, 6
    .move_entire_column_y_for_strip_1_by_8
        move_entire_column_y_for_strip_n_by_m 1, 8
endif

; TODO: It's possible this is slower and higher quality than we need, but let's go with it for now.
; Might be interesting to try swapping in one of lovebug's minimal PRNGs later on - it may be that
; our RNG quality requirements are extremely low, the extra performance might be helpful and it
; might even be that some clumpiness in the output would look nicer. The fact we randomly seed the
; RNG in the loader might mean we need an RNG which doesn't need a carefully chosen seen though.
include "random.asm"

include "gen/tables.asm"

.runtime_end
;    print "RTE ", ~P%

; This code isn't needed once we start running, so it's allowed to extend into RAM which will be
; occupied by the flames, but not obviously past the top of RAM altogether.
clear runtime_guard, runtime_guard+1
; This load address is chosen experimentally to just fit. We could get away with &1100 in practice
; but it offers us no real benefit and this way we can be compatible with as many machines and in
; particular filing systems as possible.
org &2300
guard &8000
.load_start
;    PRINT "LS ", ~P%
copyblock runtime_start, runtime_end, load_start
runtime_size = runtime_end - runtime_start
;    PRINT "LS ", ~P%
org load_start + runtime_size
;    PRINT "EXEC ", ~P%
.exec
{
    lda #0:sta noise_index

    ; We reprogram the CRTC to get a 256 pixel wide version of mode 1 (which has already been
    ; selected by the loader). The technique works fine without this (all the line address 
    ; calculations are done at assembly time, so working with 320 pixel lines is just as easy as 
    ; 256 pixel lines) but we need memory to add more columns and this allows us to reclaim some 
    ; memory from the blank space to the left and right of the flames. In practice we don't have
    ; enough RAM to fill even 256 pixels' worth of flames, or the CPU time to animate them at a
    ; decent frame rate.
    ;
    ; If hide_data is TRUE, we also modify the screen height to hide the data at the top of the 
    ; screen; assuming it actually works and doesn't break on real hardware, this avoids the 
    ; complexity and CPU load of reprogramming the palette using interrupts to hide it.
    ;
    ; This is based on https://stardot.org.uk/forums/viewtopic.php?p=373506 combined with some
    ; "I don't know what I'm doing" experimentation.
    hide_data = TRUE
    crtc_reg = &fe00
    crtc_data = &fe01
    lda #1:sta crtc_reg:lda #64:sta crtc_data
    lda #2:sta crtc_reg:lda #90:sta crtc_data
    if hide_data
        screen_lines = bottom_flame_line - top_flame_line + 1
        lda #6:sta crtc_reg:lda #screen_lines:sta crtc_data
        lda #7:sta crtc_reg:lda #screen_lines+5:sta crtc_data
        crtc_screen_start = screen_base + top_flame_line * screen_line_length_bytes
    else
        crtc_screen_start = screen_base
    endif
    lda #12:sta crtc_reg:lda #hi(crtc_screen_start / 8):sta crtc_data
    lda #13:sta crtc_reg:lda #lo(crtc_screen_start / 8):sta crtc_data

    ; Select the tape filing system before we relocate down over workspace used for other filing
    ; systems. TODO: Do we need to do anything else to be safe? Especially on Econet?
    ; TODO: We could check OSHWM and not select tape if it's >=runtime_start. This would avoid
    ; the mildly annoying "soft break still has tape selected" behaviour on a Master. I don't know
    ; if selecting tape still has advantages in terms of preventing Econet interrupts which might
    ; harm performance though.
    lda #osbyte_select_tape:ldx #0:jsr osbyte

    ; Relocate down.
    pages_to_copy = (runtime_size + 255) div 256
    from_ptr = uninitialised_zp_start
    to_ptr = uninitialised_zp_start + 2
    lda #lo(load_start):sta from_ptr:lda #hi(load_start):sta from_ptr+1
    lda #lo(runtime_start):sta to_ptr:lda #hi(runtime_start):sta to_ptr+1
    ldx #pages_to_copy
    ldy #0
.copy_loop
    lda (from_ptr),y:sta (to_ptr),y
    dey:bne copy_loop
    inc from_ptr+1:inc to_ptr+1
    dex:bne copy_loop

    ; Enter relocated code.
    jmp runtime_start
}
.load_end

; We set the high word to indicate that the code should run in the I/O processor. The loader 
; refuses to run with a second processor active anyway, since it feels a bit risky to disrupt the
; I/O processor by running this code there, even though it does seem to work fine in practice on an
; emulator.
high_word = &30000
if wide
    puttext "boot.txt", "!BOOT", 0
    putbasic "loader.bas", "LOADER"
    save "FLAMEW", load_start, load_end, high_word or exec, high_word or load_start
else
    save "FLAMEN", load_start, load_end, high_word or exec, high_word or load_start
endif

; vi: colorcolumn=100
