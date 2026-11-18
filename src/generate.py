from dataclasses import dataclass
import random
import sys


def die(s):
    print(s, file=sys.stderr)
    sys.exit(1)


def write_auto_generated_header(f):
    for _ in range(5):
        f.write("; !!! AUTO-GENERATED FILE !!! - do not edit as your changes will be overwritten\n")
    f.write("\n")


def char_to_palette(c):
    if c == ' ':
        return 0
    elif c == '.':
        return 1
    elif c == ':':
        return 2
    elif c == '#':
        return 3
    else:
        assert False


def string_to_palette(s):
    assert len(s) == 4
    return [char_to_palette(c) for c in s]


def string_to_screen_byte(s):
    return screen_byte(*(string_to_palette(s)))


def screen_byte(a, b, c, d):
    assert 0 <= a <= 3
    assert 0 <= b <= 3
    assert 0 <= c <= 3
    assert 0 <= d <= 3

    def bits(x):
        return ((x & 2) << 3) | (x & 1)

    return (bits(a) << 3) | (bits(b) << 2) | (bits(c) << 1) | bits(d)


# Shared constants which need to be available everywhere

top_flame_line = 21 # inclusive
bottom_flame_line = 31 # inclusive
double_cool_threshold_line = top_flame_line + 4

screen_line_length_bytes = 512
screen_base = 0x4000 # + top_flame_line * screen_line_length_bytes

# Our "columns" are the internal 6845-style columns, not text columns - one column is four pixels.
# Columns are grouped into strips of size 256/8 so we can address any horizontal column within a screen
# row from that strip's base (top leftmost) address on the line.
if len(sys.argv) > 1:
    if sys.argv[1] == "wide":
        column_count = 50
    elif sys.argv[1] == "narrow":
        column_count = 32
    else:
        die(f"Unexpected command line argument: {sys.argv[1]}")
else:
    die("Please pass \"wide\" or \"narrow\" as an argument")

left_column = ((screen_line_length_bytes // 8) - column_count) // 2 # centre the flames
columns_per_strip = 256 // 8
# The trickery in the next line is an attempt to round up if we need a partial strip.
strip_count = (column_count + (columns_per_strip - 1)) // columns_per_strip

# This is used just for the hacky build system to decide what filename to give the binary.
wide = column_count > 32

noise_table_length = 256


# The basic building block of the display is a 4x2 group of pixels which forms a dithered colour
# "meta-pixel" which we refer to as a "block". These always appear vertically aligned to a two pixel
# boundary, so they have even and odd rows. This ramp is arranged in approximate order of visual
# intensity, but it doesn't have to be precise if this gives a better effect.

#        0       1       2       3       4       5       6       7       8       9      10      11      12      13      14      15
#be = ("    ", "  . ", ".   ", ". . ", " . .", "... ", "....", ":.. ", ".:..", ":.: ", ".:.:", " ::.", "::: ", "#:::", ":#::", "#:#:")
#bo = ("    ", " .  ", " . .", " .. ", "... ", ". ..", " ...", "..: ", ":.: ", " :.:", " ::.", ":.::", ".:::", "::#:", "#:#:", ":#:#")
#be = ("    ", "  . ", ".   ", ". . ", " . .", "... ", "....", ":.. ", ".:..", ":.:.", ".:.:", ".::.", ":::.", "#:::", ":#::", "#:#:")
#bo = ("    ", " .  ", " . .", " .. ", "... ", ". ..", " ...", "..: ", ":.: ", ".:.:", "#::.", ":.::", ".:::", "::#:", "#:#:", ":#:#")
# TODO: Is this variant better than my "original"?! Trying to avoid the "consistent vertical black
# lines feel"
be = ("    ", "  . ", ".   ", ". . ", " . .", "... ", "....", ":.. ", ".:..", ":.: ", ".:.:", " ::.", ":: :", "#:::", ":#::", "#:#:")
bo = ("    ", " .  ", " . .", " .. ", "... ", ". ..", " ...", "..: ", ":.: ", ": .:", " ::.", ":.::", ".:::", "::#:", "#:#:", ":#:#")

# Because of the trick we use to efficiently "cool" the blocks on screen, within each row each
# pattern must be unique.
def check_for_duplicates(b, parity):
    duplicates = {x for x in b if b.count(x) > 1}
    if duplicates:
        die(f"Duplicate {parity} block patterns found: {duplicates}")
check_for_duplicates(be, "even")
check_for_duplicates(bo, "odd")
        

@dataclass
class Block:
    screen_byte_even: int
    screen_byte_odd: int

blocks = []
for (even, odd) in zip(be, bo):
    blocks.append(Block(string_to_screen_byte(even), string_to_screen_byte(odd)))
block_count = len(blocks)


def make_block_index_cool_dict(cool_operation):
    d = {}
    for from_block_index, block in enumerate(blocks):
        to_block_index = cool_operation(from_block_index, block)
        assert d.get(from_block_index) is None
        d[from_block_index] = to_block_index
    return d

def single_cool_operation(from_block_index, _):
    return from_block_index - 1 if from_block_index > 0 else 0

def double_cool_operation(from_block_index, _):
    # TODO: We *might* want to take advantage of the block's details to cool in a per-block way. For
    # now we don't, and this may actually be the best way to do it, but perhaps worth experimenting.
    return from_block_index - 2 if from_block_index > 1 else 0

single_cool_table_by_block = make_block_index_cool_dict(single_cool_operation)
double_cool_table_by_block = make_block_index_cool_dict(double_cool_operation)



random.seed(42 + 1)

# Generate a set of randomly positioned anchors. There's always an anchor in the first and last
# column and no two anchors can be immediately adjacent. TODO: Increasing the minimum separation
# might help, although with a fixed random seed we know this looks OK in practice anyway.
anchor_count = column_count // 4
anchor_columns = [0, column_count - 1]
for i in range(anchor_count - 2):
    candidates = list(set(range(column_count)) - set(x for x in anchor_columns) - set(x + 1 for x in anchor_columns) - set(x - 1 for x in anchor_columns))
    anchor_columns.append(random.choice(candidates))
anchor_columns = sorted(anchor_columns)
assert len(anchor_columns) == anchor_count

# Edge anchor values are restricted to low values so the flames taper off slightly at the edges. All
# anchor value updates need to go through update_anchor_value() to ensure this scaling is applied
# consistently and only on updates, not on every mutation (which would otherwise slowly scale the
# edge anchors down to 0 even if they're not supposed to be changing).
edge_block_divisor = 4
edge_block_count = block_count // edge_block_divisor
def is_edge_anchor(anchor_index):
    return anchor_index in (0, anchor_count - 1)
def update_anchor_value(anchor_index, anchor_value):
    if is_edge_anchor(anchor_index):
        anchor_values[anchor_index] = anchor_value // edge_block_divisor
    else:
        anchor_values[anchor_index] = anchor_value

# Assign a random block ("colour"/"intensity") to each anchor.
anchor_values = [random.randrange(edge_block_count if is_edge_anchor(anchor_index) else block_count) for anchor_index in range(anchor_count)]
# print("Q", anchor_values)


# Generate simple value noise.
noise = []
for i in range(noise_table_length):
    # Interpolate the current noise values for each column from the anchors.
    noise_line = []
    for column in range(column_count):
        left_anchor_column_index = None
        for i, anchor_column in enumerate(anchor_columns):
            if anchor_column == column:
                noise_value = anchor_values[i]
                break
            elif anchor_column > column:
                right_anchor_column_index = i
                weight = float(column - anchor_columns[left_anchor_column_index]) / (anchor_columns[right_anchor_column_index] - anchor_columns[left_anchor_column_index])
                noise_value = anchor_values[left_anchor_column_index] * (1.0 - weight) + anchor_values[right_anchor_column_index] * weight
                break
            else:
                left_anchor_column_index = i
        noise_line.append(round(noise_value))
    noise.append(noise_line)
    #print("N", noise_line)

    # Mutate the anchors. We simply set one of them to a random value, which seems to work fairly
    # well. TODO: We could try other approaches here.
    update_anchor_value(random.randrange(anchor_count), random.randrange(block_count))




with open("gen/constants.asm", "w") as f:
    write_auto_generated_header(f)
    f.write(f"screen_base = &{screen_base:04x}\n")
    f.write(f"screen_line_length_bytes = &{screen_line_length_bytes:04x}\n")
    f.write(f"top_flame_line = {top_flame_line}\n")
    f.write(f"bottom_flame_line = {bottom_flame_line}\n")
    f.write(f"double_cool_threshold_line = {double_cool_threshold_line}\n")
    f.write(f"column_count = {column_count}\n")
    f.write(f"left_column = {left_column}\n")
    f.write(f"columns_per_strip = {columns_per_strip}\n")
    f.write(f"strip_count = {strip_count}\n")
    f.write(f"block_count = {block_count}\n")
    f.write(f"noise_table_length = {noise_table_length}\n")
    f.write(f"wide = {"TRUE" if wide else "FALSE"}\n")


with open("gen/tables.asm", "w") as f:
    write_auto_generated_header(f)
    
    # We'd rather these didn't cross page boundaries, but we'd also like to tuck them into any space
    # here before the page-alignment happens. We rather hackily just hope and then check at assembly
    # time. TODO: A proper fix would conditionally include these (treating each separately) here if
    # they fit or put them after the page-aligned data if necessary.
    if not wide:
        # The alignment doesn't work by chance on a narrow build and we can afford to waste space.
        f.write("align &100\n")
    f.write(".block_even_screen_bytes\n")
    for block in blocks:
        f.write(f"    equb &{block.screen_byte_even:02x}\n")
    f.write("assert hi(P%-1) == hi(block_even_screen_bytes)\n")
    f.write(".block_odd_screen_bytes\n")
    for block in blocks:
        f.write(f"    equb &{block.screen_byte_odd:02x}\n")
    f.write("assert hi(P%-1) == hi(block_odd_screen_bytes)\n")

    # The cool tables are all naturally page-sized, so they want page-alignment but we don't need to
    # align each one individually.
    f.write("align &100\n")

    def write_cool_table(f, cool_table, selector):
        screen_byte_dict = {selector(blocks[from_block_index]): selector(blocks[to_block_index]) for
                            (from_block_index, to_block_index) in cool_table.items()}
        for from_screen_byte in range(256):
            to_screen_byte = screen_byte_dict.get(from_screen_byte, 0)
            f.write(f"    equb &{to_screen_byte:02x} ; &{from_screen_byte:02x}\n")

    f.write(".single_cool_table_even\n")
    write_cool_table(f, single_cool_table_by_block, lambda x: x.screen_byte_even)
    f.write(".single_cool_table_odd\n")
    write_cool_table(f, single_cool_table_by_block, lambda x: x.screen_byte_odd)
    f.write(".double_cool_table_even\n")
    write_cool_table(f, double_cool_table_by_block, lambda x: x.screen_byte_even)
    f.write(".double_cool_table_odd\n")
    write_cool_table(f, double_cool_table_by_block, lambda x: x.screen_byte_odd)

    # The noise table is stored with all the values for column 0, then all the values for column 1,
    # etc. We can multiply by noise_table_length at assembly time, but we need to be able to index
    # from a specific column's base address by the current noise index.
    #
    # If (as is usually the case) noise_table_length is a power of 2, this is naturally page-aligned
    # and the page-alignment follows on from the alignment of the cool tables. If noise_table_length
    # isn't a power of 2, page-alignment doesn't really matter that much.
    #
    # TODO: Note that in practice the noise table data is all colour 1 (red) pixels in screen RAM.
    # This might be helpful for a variant where we use raster interrupts to reprogram the palette
    # dynamically, as we'd only need to reprogram colour 1 to black in this region to hide this.
    # If we were willing to AND #15 all the values as we pull them out of the noise table, we could
    # probably also include a static image using the other three colours inside this table, even
    # without on-the-fly palette reprogramming.
    f.write(".noise_table\n")
    for column in range(column_count):
        f.write(f"    ; column {column}\n")
        for noise_index in range(noise_table_length):
            f.write(f"    equb &{noise[noise_index][column]:02x}\n")

# vi: tw=100
