org &70
guard &90
.line skip 1
.column skip 1
.from skip 2
.from2 skip 2
.to skip 2
.to2 skip 2
.noise_index skip 1
.update_index_within_chunk skip 1
.update_chunk skip 1
.column_to_modify skip 1
.patch_zp skip 2
.seed skip 2

oswrch = &ffee
osbyte = &fff4

macro inccs addr
    bcc no_carry
    inc addr
.no_carry
endmacro

    start_line=21

org &8000
guard &c000
.start_swr
    
if FALSE
    ldx #0
.loop2
    ldy #7
.loop
    tya:lsr a:bcs odd
    lda colour_table1,x
    jmp store
.odd
    lda colour_table2,x
.store
    sta &3000+256,y ; hackily self modified
    dey
    bpl loop
    clc:lda store+1:adc #8:sta store+1:bcc no_carry:inc store+2:.no_carry
    inx
    cpx #10
    bne loop2

    jmp  version2

    lda #lo(&3000+31*640):sta to
    lda #hi(&3000+31*640):sta to+1
    ldy #0
    lda #255
.initialise
    sta (to),y
    dey
    bne initialise

    
.forever
    lda #2:sta line
.line_loop
    ldx line
    lda line_addr_low,x:sta to
    lda line_addr_high,x:sta to+1
    lda line_addr_low+1,x:sta from
    lda line_addr_high+1,x:sta from+1
    lda to:clc:adc #1:sta to2:lda to+1:adc #0:sta to2+1
    lda from:clc:adc #1:sta from2:lda from+1:adc #0:sta from2+1
    lda #10:sta column
.column_loop
    ldy #6
.inner_loop
    ; Y is always even?
    lda (from),y
    tax:lda cool_table1,x
    sta (to),y
    lda (from2),y
    tax:lda cool_table2,x
    sta (to2),y
    dey:dey:bpl inner_loop
    clc:lda from:adc #8:sta from:inccs from+1
    clc:lda to:adc #8:sta to:inccs to+1
    clc:lda from2:adc #8:sta from2:inccs from2+1
    clc:lda to2:adc #8:sta to2:inccs to2+1
    dec column:bpl column_loop
    dec line:bpl line_loop
    jmp forever
endif
    

; TODO: Just a thought. If instead of "lda cool_table1,x" we used y and did "lda (cool_table1_ptr),y", we would save one byte on every cool operation, which would be pretty huge. This would cost us an extra cycle (there'd be no page crossing) but that's probably not *too* bad. And it would also (which is actually what made me think about it, whether or not this is a good idea) be possible to have a few different zp locations (we are not short of them - we could proably have one per column) pointing at the table, and then we could potentially semi-randomly switch in different cooling tables (e.g. one that cools at half the normal speed) which might help create some more variety. - this may be true, but it does feel like we now have quite a bit of variety in other areas, and the randomness of the step size might be a similar effect to this.


    ; TODO: Would it help to switch to a variant cooling table for lines "near the top" which cool "hot" stuff faster? This might reduce the effect where very "long" flame strips clip, while allowing us to take advantage of the extra space otherwise.
    ; TODO: It's just a hacky expedient to pass chunk_adr into cool_* macros isntead of the actual line number
    ; TODO: The line number threshold here should be computed (carefully to avoid off-by-one type errors) from a shared "number of lines" variable, but we're just hacking for now
    cool_line_threshold = start_line+4 ; empirically this feels about right with start_line=21
    macro cool_even chunk_addr
        line = (chunk_addr - &3000) / 640
        if line >= cool_line_threshold
        lda cool_table1,x
        else
        lda cool_table3,x
        endif
    endmacro
    macro cool_odd chunk_addr
        line = (chunk_addr - &3000) / 640
        if line >= cool_line_threshold
        lda cool_table2,x
        else
        lda cool_table4,x
        endif
    endmacro
    last_move_line_addr = &3000 + 30*640
    macro moveby2 chunk_addr
        ldx chunk_addr+2,y:cool_even chunk_addr:sta chunk_addr,y
        ldx chunk_addr+3,y:cool_odd chunk_addr:sta chunk_addr+1,y
        ldx chunk_addr+4,y:cool_even chunk_addr:sta chunk_addr+2,y
        ldx chunk_addr+5,y:cool_odd chunk_addr:sta chunk_addr+3,y
        ldx chunk_addr+6,y:cool_even chunk_addr:sta chunk_addr+4,y
        ldx chunk_addr+7,y:cool_odd chunk_addr:sta chunk_addr+5,y
        ldx chunk_addr+640,y:cool_even chunk_addr:sta chunk_addr+6,y
        ldx chunk_addr+641,y:cool_odd chunk_addr:sta chunk_addr+7,y
    endmacro
    macro moveby4 chunk_addr
        ldx chunk_addr+4,y:cool_even chunk_addr:sta chunk_addr,y
        ldx chunk_addr+5,y:cool_odd chunk_addr:sta chunk_addr+1,y
        ldx chunk_addr+6,y:cool_even chunk_addr:sta chunk_addr+2,y
        ldx chunk_addr+7,y:cool_odd chunk_addr:sta chunk_addr+3,y
        ldx chunk_addr+640,y:cool_even chunk_addr:sta chunk_addr+4,y
        ldx chunk_addr+641,y:cool_odd chunk_addr:sta chunk_addr+5,y
        ldx chunk_addr+642,y:cool_even chunk_addr:sta chunk_addr+6,y
        ldx chunk_addr+643,y:cool_odd chunk_addr:sta chunk_addr+7,y
    endmacro
    macro moveby6 chunk_addr
        if chunk_addr < last_move_line_addr
        ldx chunk_addr+6,y:cool_even chunk_addr:sta chunk_addr,y
        ldx chunk_addr+7,y:cool_odd chunk_addr:sta chunk_addr+1,y
        ldx chunk_addr+640,y:cool_even chunk_addr:sta chunk_addr+2,y
        ldx chunk_addr+641,y:cool_odd chunk_addr:sta chunk_addr+3,y
        ldx chunk_addr+642,y:cool_even chunk_addr:sta chunk_addr+4,y
        ldx chunk_addr+643,y:cool_odd chunk_addr:sta chunk_addr+5,y
        ldx chunk_addr+644,y:cool_even chunk_addr:sta chunk_addr+6,y
        ldx chunk_addr+645,y:cool_odd chunk_addr:sta chunk_addr+7,y
        else
        ldx chunk_addr+6,y:cool_even chunk_addr:sta chunk_addr,y
        ldx chunk_addr+7,y:cool_odd chunk_addr:sta chunk_addr+1,y
        ldx chunk_addr+640,y:cool_even chunk_addr:sta chunk_addr+2,y:sta chunk_addr+4,y:sta chunk_addr+6,y
        ldx chunk_addr+641,y:cool_odd chunk_addr:sta chunk_addr+3,y:sta chunk_addr+5,y:sta chunk_addr+7,y
        endif
    endmacro
    macro moveby8 chunk_addr
        ldx chunk_addr+640,y:cool_even chunk_addr:sta chunk_addr,y
        ldx chunk_addr+641,y:cool_odd chunk_addr:sta chunk_addr+1,y
        ldx chunk_addr+642,y:cool_even chunk_addr:sta chunk_addr+2,y
        ldx chunk_addr+643,y:cool_odd chunk_addr:sta chunk_addr+3,y
        if  chunk_addr < last_move_line_addr
        ldx chunk_addr+644,y:cool_even chunk_addr:sta chunk_addr+4,y
        ldx chunk_addr+645,y:cool_odd chunk_addr:sta chunk_addr+5,y
        ldx chunk_addr+646,y:cool_even chunk_addr:sta chunk_addr+6,y
        ldx chunk_addr+647,y:cool_odd chunk_addr:sta chunk_addr+7,y
        else
        ldx chunk_addr+640,y:cool_even chunk_addr:sta chunk_addr+4,y:sta chunk_addr+6,y
        ldx chunk_addr+641,y:cool_odd chunk_addr:sta chunk_addr+5,y:sta chunk_addr+7,y
        endif
    endmacro
    macro moveby_chunk step_size, base_chunk_addr
        for line2,start_line,30
            chunk_addr=base_chunk_addr+line2*640
            if step_size == 2
                moveby2 chunk_addr
            elif step_size == 4
                moveby4 chunk_addr
            elif step_size == 6
                moveby6 chunk_addr
            elif step_size == 8
                moveby8 chunk_addr
            else
                assert FALSE
            endif
        next
    endmacro
    macro putnoise column2
        ; note that we leave the bottom "half row" empty for now - it's sligtly ugly to duplicate it, and there's no logic to, given we now special case this in the moves which would reach "below" this half row
        top_addr = &3000+31*640+column2*8
        jsr random
        lda seed+1:and #7:tay:lda noise_offset,y
        clc:adc noise_table+column2*noise_table_length,x
        bmi clamp_at_zero
        cmp #16:bcc value_ok ; TODO hardcoded max colour+1!
        lda #15:bne value_ok
    .clamp_at_zero
        lda #0
    .value_ok
        tay
        lda colour_table1,y:sta top_addr:sta top_addr+2
        lda colour_table2,y:sta top_addr+1:sta top_addr+3
        ; Experimenteally generate a "similar" bottom half row - the hope here is that we can get a bit more of a solid "base" to the fire. (TODO: If this works, we could but don't have to allow the move code to handle the bottom row normally instead of restricting itself to the top half.)
        ; TODO: hackily using patch_zp just for working space!
        lda seed:and #%11:sta patch_zp
        tya:eor patch_zp:tay
        lda colour_table1,y:sta top_addr+4:sta top_addr+6
        lda colour_table2,y:sta top_addr+5:sta top_addr+7
    endmacro
    include "mainblock.asm"
.version2
    lda #0:sta noise_index
.forever2
    ; TODO: In principle we could split this code over the 16K sideways RAM and the memory (we could kill the DFS even on a model B etc) &E00-&3000, which would give us an extra 8K-ish for more of this code.
.mainblock_base
    mainblock
    ; assert (noise_table_length and (noise_table_length - 1)) == 0
    if FALSE ; TODO: we don't have this constant defined early enough, just hack it for now: noise_table_length < 256
    lda noise_index:clc:adc #1:cmp #noise_table_length:bcc no_wrap:lda #0:.no_wrap:sta noise_index
    else
    inc noise_index
    endif

    ; Randomly permute one of the step sizes
    ; TODO: Might be better to do this on the basis of some clumpy noise type function?
    {
    if FALSE
    jsr random
    lda seed+1:and #15:tay:ldx step_size_bias_table,y  ; step size table index
    lda seed:and #31 ; TODO hard-coded 32 columns
    else
        lda #3:sta update_chunk ; TODO reused var poor name
        .permute_loop

        ; Really hacky attempt to pick a random column and use "a rolling noise value" from that column to decide what step seize to set. The vague idea here is that because the noise doesn't change too dramatically from row to row, even though we're sampling each column randomly from it, we should get some approximately clumpy yet variable behaviour here.
        jsr random
        lda seed:and #31:pha ; TODO hard-coded 32 columns
        ; hackery ebcause we know the noise table has 256 rows per column
        clc:adc #hi(noise_table):sta patch_zp+1
        lda #lo(noise_table):sta patch_zp
        ; We're assuming step_size_bias table has num_colours entries here - we
        ; don't want to eg. and off some low bits because that would "wrap" high
        ; values and introduce discontinuity. As it happens right now there are
        ; colours 0-15 anyway, so an and #15 wouldn't wrap (it would just be
        ; irrelevant).
        ldy noise_index:lda (patch_zp),y:tay:ldx step_size_bias_table,y
        pla
    endif
    chunk_size = 32 ; assert chunk_size == 32
    sta column_to_modify
    if FALSE ; better to use a table, keeping half-written code jic
    and #chunk_size-1:sta update_index_within_chunk
    lda column_to_modify:lsr a:lsr a:lsr a:lsr a:lsr a:sta update_chunk
    lda column_to_modify:asl a:asl a:asl a:asl a ; if original <=63, won't overflow
    clc:adc column_to_modify:sta column_to_modify_times_5
    lda #0:adc #0:sta column_to_modify_times_5+1
    lda column_to_modify_times_5:clc:adc column_to_modify:sta column_to_modify_times_5
    lda column_to_modify_times_5+1:adc #0:sta column_to_modify_times_
    else
        ldy column_to_modify
        lda patch_table_low,y:sta patch_zp
        lda patch_table_high,y:sta patch_zp+1
        ; TODO: for now, we're just assuming this is chunk 0
        ldy #0:lda step_size_patch_table_low,x:sta (patch_zp),y
        iny:lda step_size_patch_table_high,x:sta (patch_zp),y
    endif
    dec update_chunk:bne permute_loop
    }

    lda #19:jsr osbyte ; TODO!?
    jmp forever2

; https://stardot.org.uk/forums/viewtopic.php?t=32214&hilit=prng&start=60 - lovebug fascinating
.random
LDA seed
LSR A
ROL seed+1
EOR seed+1
STA seed
RTS

.noise_offset
    equb &ff, 1, &ff, 1, &fe, 2, 0, 0

.step_size_bias_table
    for i, 1, 3
        equb 0 ; step size 2
    next
    for i, 1, 5
        equb 1 ; step size 4
    next
    for i, 1, 5
        equb 2 ; step size 6
    next
    for i, 1, 3
        equb 3 ; step size 8
    next
.step_size_bias_table_end
assert step_size_bias_table_end - step_size_bias_table == 16

.patch_table_low
    for i,0,columns-1
        equb lo(mainblock_base+i*5+3)
    next
.patch_table_high
    for i,0,columns-1
        equb hi(mainblock_base+i*5+3)
    next

.step_size_patch_table_low
    equb lo(moveby2_0)
    equb lo(moveby4_0)
    equb lo(moveby6_0)
    equb lo(moveby8_0)
.step_size_patch_table_high
    equb hi(moveby2_0)
    equb hi(moveby4_0)
    equb hi(moveby6_0)
    equb hi(moveby8_0)



    include "tables.asm"
.end_swr

org &1900
guard &7c00 ; bit arbitrary
.start_main
    ; TODO: We should probably read the system time and mix that into the seeds
    ; on startup
    lda #42:sta seed:sta seed+1
    ; TODO: Hacky use of bank 4
    lda #4:sta &f4:sta &fe30
    lda #lo(low_copy):sta &70
    lda #hi(low_copy):sta &71
    lda #0:sta &72
    lda #&80:sta &73
    ldx #&3F
    ldy #0
.copy
    lda (&70),y
    sta (&72),y
    dey
    bne copy
    inc &71
    inc &73
    dex
    bne copy
    lda #22:jsr oswrch:lda #1:jsr oswrch
    jmp &8000
.low_copy
    copyblock start_swr, end_swr, low_copy
.end_main

puttext "boot.txt", "!BOOT", 0
save "FLAME", start_main, low_copy + (end_swr - start_swr)

; TODO: It *might* be helpful to modify the screen to have 256 pixels per row - that would free up some more main RAM. For that matter, presumably we could reduce the screen *height* anyway and still keep the flames at the bottom, since we just cannot possibly hope to fill most of the screen height anyway?
; TODO: We could possibly do this in mode 5 to free up more RAM and/or to "fill more of the screen"

; TODO: The bottom line is a bit ugly. I almost wonder if we could move this "for free" into the first 640 bytes of SWR so it's just accessed like line 32 but isn't actually visible. TO be fair, if you could only see the top half of it (but we sort of have to have the bottom half, to make the 6/8 pixel moves work?) it might look OK. We could maybe have some basic timer interrupts to blank the palette at this point?! We could potentially also blank the palette in the top 2/3 of the screen in order to allow us to use that RAM for code without necessarily faffing around (I really don't know how flexible the system is in this respect) actually shrinking this displayed size of the screen and risking monitor compatibility issues. - this is probably fixed now

; TODO: If we really wanted to (working round the need for an RTI at &Dxx might be annoying) we could almost trivially kick the OS out and use "all" the main RAM not needed for the screen.

; TODO: It might be nice to generate (probably via a separate loader than pokes it in then loads the actual "runtime", to avoid wasting space) the noise sequence at runtime, so it's not the same every single time. Altneratively, we may well have spare cycles to have the noise "manipulated" frame to frame at runtime (we'd likely need to work with sorted indexed colours and use a lookup table to convert them to screen bytes, but the chances are that's not a huge deal), which would allow us to add a little randomness etc. It might be worth leaving this in the Python for now as it will be easier to experiment with noise styles that way, then I can always re-implement later. I do think it would actually be really nice if the pattern didn't "repeat" and was genuinely "chaotic"/unpredictable no matter how long you leave it running.

; TODO: Turn the cursor off! All this little stuff might well be best done via a simple BASIC loader, or a  machine code loader, to avoid wasting RAM.

; TODO: *Especially* for initial experimentation, nothig would stop me spreading the code over multiple sideways RAM banks, which would likely be easier than splittig it "around" the screen or resizing the screen. It could always be "squished" later on, once it becomes clear e.g. where the sweet spot in terms of visual size vs frame rate is.

; TODO: Back of envelope - a 256x256 screen is 16K. We actually use only about 80 pixels vertically, so (e.g. via palette blanking) we might be able to get the effective screen RAM down to about 5K at mode 1 resolution. That would - we can kick the OS out remember - give us 27K of free RAM even on a 32K machine with no sideways RAM, which is 1.68 times what we effectively have right now using a single SWR bank. Assuming the frame rate holds out, I don't think we want or need much more vertical height, so if we spent that on horizontal expansion, we'd get to 52 "columns", which is 208 pixels, or (since "visually" the monitor has 320 pixels, so to speak, even if we've shrunk the screen RAM) more or less 2/3 of the visible 4:3 screen. This really is not bad, I suspect by that point we might be pushing the frame rate, so maybe it would be worth pursuing a "kick the OS out and somewhat flat address space" model almost straight away, rather than faffing with other stuff!? I do worry a bit about loading this, evne if we load at &1100 before relocating down, that uses 4.25K - so we do just about fit, and of coruse we can blat our data over the mode 7 (or whatever) screen briefly if we want to. We could potentially generate some data at runtime, but since we probably can just about load everything raw, it is probably nicer not to have to precompute stuff just to save space.

; TODO: It's just possible we should stop regarding the basic block as a 2x2 "ordered dither" - maybe we should just have it as a 4x2 ordered dither. This is actually probably not much work at all at the machine code level, it's more about how we set up the data ahead of time in the Python code. - have done this, I think

; TODO: Is there a "4 colour mode 8" with e.g. 128x128? If there is, that might "just work" as an option which would share the same code but make the effect mostly fill the screen just with chunkier pixels.

; TODO: Unlikely I will try it now, but FWIW this effect might be a really good match for the NuLA's attribute mode.

; TODO: Note that with the "jsr using y (could be x) within chunk" approach, we *can* now dynamically change the step size for a column just by altering the jsr for that column. This gives us the possibility of varying the step size as well as the base noise for each column on each frame if we want. - OK, this isn't quite true as written, since each column gets multiple lines worth of thse jsrs. But we could probably pull those out into a jsr to a list of jsrs if we wanted. Or we could patch the multiple jsrs, which are "just" jsrs with no real calculation etc. We could potentially just randomly change one column's speed per frame - this would contribute to an ongoing randomness independent of any repeating noise table. - have kind of done this

; TODO: Maybe use Arlet's RNG: https://github.com/Arlet/pseudo-random-number-generator/blob/main/6502/minimal-6502.asm If I keep a lovebug style one, that one was just something I grabbed from the hread in a hurry, my seed is not sensibly chosen and that RNG is interesting visually but not necessarily particularly good or has a long period or accepts all seeds.
