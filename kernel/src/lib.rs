#![no_std]

#[no_mangle]
extern "C" fn rust_kernel_function() {}

#[panic_handler]
fn panic(_info: &core::panic::PanicInfo) -> ! {
    loop {
        unsafe {
            riscv::asm::wfi();
        }
    }
}

