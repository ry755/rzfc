use core::num::NonZeroU16;
use std::fs::File;
use std::io::prelude::*;
use tms9918a_emu::TMS9918A;
use minifb::{Key, KeyRepeat, Scale, Window, WindowOptions};
use z80emu::*;
use rand::Rng;
type TsClock = host::TsCounter<i32>;

struct SIO {
    current_rr: u8,
    current_key: u8,
}

// Z80 IO bus
struct Bus {
    vdp: TMS9918A,
    sio: SIO,
    rom: [u8; 32*1024],
    ram: [u8; 32*1024],
    cold_reset: bool,
    warm_reset: bool,
}

impl Io for Bus {
    type Timestamp = i32;
    type WrIoBreak = ();
    type RetiBreak = ();

    #[inline(always)]
    fn write_io(&mut self, port: u16, data: u8, _ts: i32) -> (Option<()>, Option<NonZeroU16>) {
        let masked_port = port & 0x00FF;
        //println!("[write_io] masked_port: {:#X}, data: {:#X}", masked_port, data);
        // VDP control
        if masked_port == 0b00010010 {
            //println!("[write_io] writing to VDP control port");
            self.vdp.write_control_port(data);
        }

        // VDP data
        if masked_port == 0b00010000 {
            //println!("[write_io] writing to VDP data port");
            self.vdp.write_data_port(data);
        }

        // SIO control
        if masked_port == 0b00000110 {
            self.sio.current_rr = data;
        }

        if masked_port == 0b00000100 {
            print!("{}", data as char);
        }

        (None, None)
    }

    #[inline(always)]
    fn read_io(&mut self, port: u16, _ts: i32) -> (u8, Option<NonZeroU16>) {
        let masked_port = port & 0x00FF;
        // VDP data
        if masked_port == 0b00010000 {
            //println!("[read_io ] reading from VDP data port");
            return (self.vdp.read_data_port(), None);
        }

        // SIO control
        if masked_port == 0b00000110 {
            if self.sio.current_rr == 0 {
                // RR0
                // input character available = 1
                if self.sio.current_key != 0 {
                    return (1, None)
                } else {
                    return (0, None);
                }
            }
            if self.sio.current_rr == 1 {
                // RR1
                // TX buffer empty = 1
                return (1, None);
            }
            return (1, None);
        }

        // SIO data
        if masked_port == 0b00000100 {
            let key = self.sio.current_key;
            self.sio.current_key = 0;
            return (key, None);
        }

        (0, None)
    }
}

impl Memory for Bus {
    type Timestamp = i32;
    fn read_debug(&self, address: u16) -> u8 {
        if address >= 0x8000 {
            self.ram[address as usize - 0x8000]
        } else {
            self.rom[address as usize]
        }
    }
    fn write_mem(&mut self, address: u16, value: u8, _ts: Self::Timestamp) {
        if address >= 0x8000 {
            self.ram[address as usize - 0x8000] = value;
            //println!("[write] {:#06X}: {:#04X}", address, value);
        } else {
            //self.rom[address as usize] = value;
            //println!("[invalid write] {:#06X}: {:#04X}", address, value);
        }
    }
}

fn main() {
    let mut tsc = TsClock::default();
    let mut cpu = Z80CMOS::default();

    // randomize sram contents
    let mut sram: [u8; 32*1024] = [0; 32*1024];
    for i in sram.iter_mut() {
        *i = rand::thread_rng().gen();
    }

    let mut window = Window::new(
        "RY-Z80",
        256,
        196,
        WindowOptions {
            resize: false,
            scale: Scale::X4,
            ..WindowOptions::default()
        },
    ).expect("Unable to create window");

    // limit to max ~60 fps update rate
    window.limit_update_rate(Some(std::time::Duration::from_micros(16600)));

    let mut bus = Bus {
        vdp: TMS9918A::new(),
        sio: SIO { current_rr: 0, current_key: 0 },
        rom: *include_bytes!("../rom.bin"),
        ram: sram,
        cold_reset: false,
        warm_reset: false
    };

    cpu.reset();

    while window.is_open() {
        if bus.cold_reset {
            cpu.reset();
            for i in bus.ram.iter_mut() {
                *i = rand::thread_rng().gen();
            }
            bus.vdp.cold_reset();
            bus.vdp.update();
            bus.cold_reset = false;
        }

        update_keys(&mut bus, &mut window);
        if bus.warm_reset {
            cpu.reset();
            bus.vdp.warm_reset();
            bus.vdp.update();
            bus.warm_reset = false;
        }

        for _ in 0..10000 {
            //match cpu.execute_next(&mut bus, &mut tsc, Some(|debug| println!("{:#X}", debug) )) {
            match cpu.execute_next(&mut bus, &mut tsc, Some(|_debug| {} )) {
                Err(BreakCause::Halt) => {
                    println!("CPU HALTED!");

                    let reg_a = cpu.get_reg(Reg8::A, None);
                    let reg_bc = cpu.get_reg16(StkReg16::BC);
                    let reg_de = cpu.get_reg16(StkReg16::DE);
                    let reg_hl = cpu.get_reg16(StkReg16::HL);
                    let reg_pc = cpu.get_pc();

                    let mut reg_string = String::from("Register contents on halt:\n");

                    reg_string.push_str(&format!("A:  {:#04X}\n", reg_a));
                    reg_string.push_str(&format!("BC: {:#06X}\n", reg_bc));
                    reg_string.push_str(&format!("DE: {:#06X}\n", reg_de));
                    reg_string.push_str(&format!("HL: {:#06X}\n", reg_hl));
                    reg_string.push_str(&format!("PC: {:#06X}", reg_pc));

                    println!("{}", reg_string);

                    println!("Flags register contents on halt:\n{:?}", cpu.get_flags());
                    break
                }
                _ => {}
            }
        }

        bus.vdp.update();

        window.update_with_buffer(
            &bus.vdp.frame,
            bus.vdp.frame_width,
            bus.vdp.frame_height,
        ).unwrap();
    }

    // write memory contents to file
    let mut file = File::create("memory_dump.bin").unwrap();
    file.write_all(&bus.rom).expect("Error writing to file");
    file.write_all(&bus.ram).expect("Error writing to file");
}

fn update_keys(bus: &mut Bus, window: &mut Window) {
    // this is the most annoying way to do this
    let keys = window.get_keys_pressed(KeyRepeat::Yes).into_iter();
    if !window.is_key_down(Key::LeftShift) && !window.is_key_down(Key::RightShift) {
        for key in keys {
            match key {
                Key::F1 => bus.warm_reset = true,
                Key::F2 => bus.cold_reset = true,

                Key::Backspace => bus.sio.current_key = 127 as u8,
                Key::Enter => bus.sio.current_key = 10 as u8,
                Key::Escape => bus.sio.current_key = 27 as u8,
                Key::Key0 => bus.sio.current_key = '0' as u8,
                Key::Key1 => bus.sio.current_key = '1' as u8,
                Key::Key2 => bus.sio.current_key = '2' as u8,
                Key::Key3 => bus.sio.current_key = '3' as u8,
                Key::Key4 => bus.sio.current_key = '4' as u8,
                Key::Key5 => bus.sio.current_key = '5' as u8,
                Key::Key6 => bus.sio.current_key = '6' as u8,
                Key::Key7 => bus.sio.current_key = '7' as u8,
                Key::Key8 => bus.sio.current_key = '8' as u8,
                Key::Key9 => bus.sio.current_key = '9' as u8,
                Key::Minus => bus.sio.current_key = '-' as u8,
                Key::Equal => bus.sio.current_key = '=' as u8,
                Key::Space => bus.sio.current_key = ' ' as u8,
                Key::Period => bus.sio.current_key = '.' as u8,
                Key::Comma => bus.sio.current_key = ',' as u8,
                Key::Slash => bus.sio.current_key = '/' as u8,
                Key::Backslash => bus.sio.current_key = '\\' as u8,
                Key::Apostrophe => bus.sio.current_key = '\'' as u8,
                Key::LeftBracket => bus.sio.current_key = '[' as u8,
                Key::RightBracket => bus.sio.current_key = ']' as u8,
                Key::A => bus.sio.current_key = 'a' as u8,
                Key::B => bus.sio.current_key = 'b' as u8,
                Key::C => bus.sio.current_key = 'c' as u8,
                Key::D => bus.sio.current_key = 'd' as u8,
                Key::E => bus.sio.current_key = 'e' as u8,
                Key::F => bus.sio.current_key = 'f' as u8,
                Key::G => bus.sio.current_key = 'g' as u8,
                Key::H => bus.sio.current_key = 'h' as u8,
                Key::I => bus.sio.current_key = 'i' as u8,
                Key::J => bus.sio.current_key = 'j' as u8,
                Key::K => bus.sio.current_key = 'k' as u8,
                Key::L => bus.sio.current_key = 'l' as u8,
                Key::M => bus.sio.current_key = 'm' as u8,
                Key::N => bus.sio.current_key = 'n' as u8,
                Key::O => bus.sio.current_key = 'o' as u8,
                Key::P => bus.sio.current_key = 'p' as u8,
                Key::Q => bus.sio.current_key = 'q' as u8,
                Key::R => bus.sio.current_key = 'r' as u8,
                Key::S => bus.sio.current_key = 's' as u8,
                Key::T => bus.sio.current_key = 't' as u8,
                Key::U => bus.sio.current_key = 'u' as u8,
                Key::V => bus.sio.current_key = 'v' as u8,
                Key::W => bus.sio.current_key = 'w' as u8,
                Key::X => bus.sio.current_key = 'x' as u8,
                Key::Y => bus.sio.current_key = 'y' as u8,
                Key::Z => bus.sio.current_key = 'z' as u8,
                _ => bus.sio.current_key = 0,
            }
        }
    } else {
        for key in keys {
            match key {
                Key::Backspace => bus.sio.current_key = 8 as u8,
                Key::Enter => bus.sio.current_key = 10 as u8,
                Key::Key0 => bus.sio.current_key = ')' as u8,
                Key::Key1 => bus.sio.current_key = '!' as u8,
                Key::Key2 => bus.sio.current_key = '@' as u8,
                Key::Key3 => bus.sio.current_key = '#' as u8,
                Key::Key4 => bus.sio.current_key = '$' as u8,
                Key::Key5 => bus.sio.current_key = '%' as u8,
                Key::Key6 => bus.sio.current_key = '^' as u8,
                Key::Key7 => bus.sio.current_key = '&' as u8,
                Key::Key8 => bus.sio.current_key = '*' as u8,
                Key::Key9 => bus.sio.current_key = '(' as u8,
                Key::Minus => bus.sio.current_key = '_' as u8,
                Key::Equal => bus.sio.current_key = '+' as u8,
                Key::Space => bus.sio.current_key = ' ' as u8,
                Key::Period => bus.sio.current_key = '>' as u8,
                Key::Comma => bus.sio.current_key = '<' as u8,
                Key::Slash => bus.sio.current_key = '?' as u8,
                Key::Backslash => bus.sio.current_key = '|' as u8,
                Key::Apostrophe => bus.sio.current_key = '"' as u8,
                Key::LeftBracket => bus.sio.current_key = '{' as u8,
                Key::RightBracket => bus.sio.current_key = '}' as u8,
                Key::A => bus.sio.current_key = 'A' as u8,
                Key::B => bus.sio.current_key = 'B' as u8,
                Key::C => bus.sio.current_key = 'C' as u8,
                Key::D => bus.sio.current_key = 'D' as u8,
                Key::E => bus.sio.current_key = 'E' as u8,
                Key::F => bus.sio.current_key = 'F' as u8,
                Key::G => bus.sio.current_key = 'G' as u8,
                Key::H => bus.sio.current_key = 'H' as u8,
                Key::I => bus.sio.current_key = 'I' as u8,
                Key::J => bus.sio.current_key = 'J' as u8,
                Key::K => bus.sio.current_key = 'K' as u8,
                Key::L => bus.sio.current_key = 'L' as u8,
                Key::M => bus.sio.current_key = 'M' as u8,
                Key::N => bus.sio.current_key = 'N' as u8,
                Key::O => bus.sio.current_key = 'O' as u8,
                Key::P => bus.sio.current_key = 'P' as u8,
                Key::Q => bus.sio.current_key = 'Q' as u8,
                Key::R => bus.sio.current_key = 'R' as u8,
                Key::S => bus.sio.current_key = 'S' as u8,
                Key::T => bus.sio.current_key = 'T' as u8,
                Key::U => bus.sio.current_key = 'U' as u8,
                Key::V => bus.sio.current_key = 'V' as u8,
                Key::W => bus.sio.current_key = 'W' as u8,
                Key::X => bus.sio.current_key = 'X' as u8,
                Key::Y => bus.sio.current_key = 'Y' as u8,
                Key::Z => bus.sio.current_key = 'Z' as u8,
                _ => bus.sio.current_key = 0,
            }
        }
    }
}
