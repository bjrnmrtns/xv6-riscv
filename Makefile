CC = riscv64-unknown-elf-gcc
LD = riscv64-unknown-elf-ld
OBJCOPY = riscv64-unknown-elf-objcopy
OBJDUMP = riscv64-unknown-elf-objdump
QEMU = qemu-system-riscv64

CFLAGS =  -Wall -Werror -O -fno-omit-frame-pointer -ggdb -MD -mcmodel=medany -march=rv64imaf -mabi=lp64
CFLAGS += -ffreestanding -fno-common -nostdlib -mno-relax -fno-stack-protector -fno-pie -no-pie -I.
LDFLAGS = -z max-page-size=4096

SRC_K := kernel/entry.S kernel/start.c kernel/console.c kernel/printf.c kernel/uart.c kernel/kalloc.c kernel/spinlock.c kernel/string.c kernel/main.c kernel/vm.c \
	kernel/proc.c kernel/swtch.S kernel/trampoline.S kernel/trap.c kernel/syscall.c kernel/sysproc.c kernel/bio.c kernel/fs.c kernel/log.c kernel/sleeplock.c kernel/file.c \
	kernel/pipe.c kernel/exec.c kernel/sysfile.c kernel/kernelvec.S kernel/plic.c kernel/virtio_disk.c

SRC_U = \
	   user/cat.c \
	   user/echo.c \
	   user/forktest.c \
	   user/grep.c \
	   user/init.c \
	   user/kill.c \
	   user/ln.c \
	   user/ls.c \
	   user/mkdir.c \
	   user/rm.c \
	   user/sh.c \
	   user/stressfs.c \
	   user/usertests.c \
	   user/grind.c \
	   user/wc.c \
	   user/zombie.c

SRC_ULIB := ulib/usys.S ulib/printf.c ulib/ulib.c ulib/umalloc.c 

OBJ_K_C := $(patsubst %.c, obj/%.o, $(filter %.c, $(SRC_K)))
OBJ_K_S := $(patsubst %.S, obj/%.o, $(filter %.S, $(SRC_K)))
OBJ_K := $(OBJ_K_S) $(OBJ_K_C) 

OBJ_ULIB_C := $(patsubst %.c, obj/%.o, $(filter %.c, $(SRC_ULIB)))
OBJ_ULIB_S := $(patsubst %.S, obj/%.o, $(filter %.S, $(SRC_ULIB)))
OBJ_ULIB := $(OBJ_ULIB_S) $(OBJ_ULIB_C) 

BIN_U := $(patsubst user/%.c, bin/%, $(SRC_U))

-include obj/kernel/*.d obj/user/*.d obj/ulib/*.d

all: bin/kernel bin/fs.img

# kernel
bin/kernel: $(OBJ_K)
	mkdir -p bin
	$(LD) $(LDFLAGS) -T kernel/kernel.ld -o bin/kernel $(OBJ_K)
obj/kernel/%.o: kernel/%.c
	mkdir -p obj/kernel
	$(CC) $(CFLAGS) -c -o $@ $<
obj/kernel/%.o: kernel/%.S
	mkdir -p obj/kernel
	$(CC) $(CFLAGS) -c -o $@ $<

# ulib
obj/ulib/%.o: ulib/%.c
	mkdir -p obj/ulib
	$(CC) $(CFLAGS) -c -o $@ $<
obj/ulib/%.o: ulib/%.S
	mkdir -p obj/ulib
	$(CC) $(CFLAGS) -c -o $@ $<

# user applications
bin/%: obj/user/%.o $(OBJ_ULIB)
	mkdir -p bin
	$(LD) $(LDFLAGS) -N -e main -Ttext 0 -o $@ $^
obj/user/%.o: user/%.c
	mkdir -p obj/user
	$(CC) $(CFLAGS) -c -o $@ $<

bin/mkfs: mkfs/mkfs.c kernel/fs.h kernel/param.h
	gcc -Werror -Wall -I. -o bin/mkfs mkfs/mkfs.c

bin/fs.img: bin/mkfs $(BIN_U)
	bin/mkfs bin/fs.img $(BIN_U)

QEMUOPTS = -machine virt -bios none -kernel bin/kernel -m 128M -smp 2 -nographic
QEMUOPTS += -drive file=bin/fs.img,if=none,format=raw,id=x0
QEMUOPTS += -device virtio-blk-device,drive=x0,bus=virtio-mmio-bus.0

qemu: bin/kernel bin/fs.img
	$(QEMU) $(QEMUOPTS)

clean:
	rm bin/kernel $(BIN_U) $(OBJ_K) bin/mkfs bin/fs.img
	rm -f obj/kernel/*.d obj/user/*.d obj/ulib/*.d
	rmdir bin obj/kernel obj/user obj/ulib obj

