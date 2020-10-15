CC = riscv64-unknown-elf-gcc
LD = riscv64-unknown-elf-ld
OBJCOPY = riscv64-unknown-elf-objcopy
OBJDUMP = riscv64-unknown-elf-objdump

# directories
BINDIR = bin
OBJDIR = obj
SRCDIR_K = kernel
SRCDIR_U = user
SRCDIR_ULIB = ulib
OBJDIR_ULIB = $(OBJDIR)/ulib
KERNEL = $(BINDIR)/kernel
USER = \
	   $(BINDIR)/cat \
	   $(BINDIR)/echo \
	   $(BINDIR)/forktest \
	   $(BINDIR)/grep \
	   $(BINDIR)/init \
	   $(BINDIR)/kill \
	   $(BINDIR)/ln \
	   $(BINDIR)/ls \
	   $(BINDIR)/mkdir \
	   $(BINDIR)/rm \
	   $(BINDIR)/sh \
	   $(BINDIR)/stressfs \
	   $(BINDIR)/usertests \
	   $(BINDIR)/grind \
	   $(BINDIR)/wc \
	   $(BINDIR)/zombie

# source definitions
SRC_K_S := $(shell find $(SRCDIR_K) -type f -name '*.S')
OBJ_K_S := $(patsubst $(SRCDIR_K)/%,$(OBJDIR)/%,$(SRC_K_S:.S=.o))
SRC_K := $(shell find $(SRCDIR_K) -type f -name '*.c')
OBJ_K := $(patsubst $(SRCDIR_K)/%,$(OBJDIR)/%,$(SRC_K:.c=.o))
SRC_U := $(shell find $(SRCDIR_U) -type f -name 'cat.c')
OBJ_U := $(patsubst $(SRCDIR_U)/%,$(OBJDIR)/%,$(SRC_U:.c=.o))
SRC_ULIB_S := $(shell find $(SRCDIR_ULIB) -type f -name '*.S')
OBJ_ULIB_S := $(patsubst $(SRCDIR_ULIB)/%,$(OBJDIR_ULIB)/%,$(SRC_ULIB_S:.S=.o))
SRC_ULIB := $(shell find $(SRCDIR_ULIB) -type f -name '*.c')
OBJ_ULIB := $(patsubst $(SRCDIR_ULIB)/%,$(OBJDIR_ULIB)/%,$(SRC_ULIB:.c=.o))
DEP := $(OBJ:.o=.d)
-include $(DEP)

CFLAGS =  -Wall -Werror -O -fno-omit-frame-pointer -ggdb -MD -mcmodel=medany -march=rv64imaf -mabi=lp64
CFLAGS += -ffreestanding -fno-common -nostdlib -mno-relax -fno-stack-protector -fno-pie -no-pie -I.
LDFLAGS = -z max-page-size=4096

all: createdirs $(KERNEL) $(USER)

# kernel
$(KERNEL): $(OBJ_K) $(OBJ_K_S)
	$(LD) $(LDFLAGS) -T $(SRCDIR_K)/kernel.ld -o $(KERNEL) $(OBJ_K) $(OBJ_K_S)

# user applications
$(BINDIR)/%: $(OBJDIR)/%.o $(OBJ_ULIB_S) $(OBJ_ULIB) 
	$(LD) $(LDFLAGS) -N -e main -Ttext 0 -o $@ $^

# kernel
$(OBJDIR)/%.o: $(SRCDIR_K)/%.c
	$(CC) $(CFLAGS) -c -MMD -MP -o $@ $<
$(OBJDIR)/%.o: $(SRCDIR_K)/%.S
	$(CC) $(CFLAGS) -c -MMD -MP -o $@ $<

# user
$(OBJDIR)/%.o: $(SRCDIR_U)/%.c
	$(CC) $(CFLAGS) -c -MMD -MP -o $@ $<

# ulib
$(OBJDIR_ULIB)/%.o: $(SRCDIR_ULIB)/%.c
	$(CC) $(CFLAGS) -c -MMD -MP -o $@ $<
$(OBJDIR_ULIB)/%.o: $(SRCDIR_ULIB)/%.S
	$(CC) $(CFLAGS) -c -MMD -MP -o $@ $<

$(OBJDIR)/initcode: $(SRCDIR_U)/initcode.S
	$(CC) $(CFLAGS) -Ikernel -c -MMD -MP -c $< -o $(OBJDIR)/initcode.o
	$(LD) $(LDFLAGS) -N -e start -Ttext 0 -o $(OBJDIR)/initcode.out $(OBJDIR)/initcode.o
	$(OBJCOPY) -S -O binary $(OBJDIR)/initcode.out $(OBJDIR)/initcode

createdirs:
	@mkdir -p $(OBJDIR) $(OBJDIR_ULIB) $(BINDIR)

clean:
	rm -rf $(KERNEL) $(OBJ_K) $(OBJ_U) $(OBJ_K_S) $(OBJ_ULIB) $(OBJ_ULIB_S) $(OBJDIR)/initcode $(DEP)
	rmdir $(OBJDIR) $(BINDIR) 2> /dev/null; true
