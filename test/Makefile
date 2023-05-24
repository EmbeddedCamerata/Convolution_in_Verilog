SRC_MODULE:=conv_with_buffer
SRC:="./${SRC_MODULE}_tb.sv"
OUTPUT:="./${SRC_MODULE}.vvp"
CMD:="./cmd.cf"

# Test parameters
INPUT_SIZE:=48
K_CHANNELS:=3
K_SIZE:=3

gen:
	python3 tools/test.py -i ${INPUT_SIZE} -c ${K_CHANNELS} -k ${K_SIZE}

comp:
	iverilog -g2012 -o ${OUTPUT} ${SRC} -c ${CMD} -DINPUT_SIZE=${INPUT_SIZE} -DKERNEL_CH=${K_CHANNELS} -DKERNEL_SIZE=${K_SIZE} -Wall

run:
	vvp ${OUTPUT} -fst -v

wave:
	gtkwave wave_${SRC_MODULE}.fst

check:
	python3 tools/test.py --check
