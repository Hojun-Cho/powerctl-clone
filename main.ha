use os;
use getopt;
use fmt;
use strings;
use errors;
use fs;
use io;
use strconv;
use time;

type mem_state = enum uint {
	S2IDLE 	= 1 << 0,
	SHALLOW = 1 << 1,
	DEEP 	= 1 << 2,
};

type disk_state = enum uint {
	PLATFORM	= 1 << 0,
	SHUTDOWN	= 1 << 1,
	REBOOT		= 1 << 2,
	SUSPEND 	= 1 << 3,
	TEST_RESUME	= 1 << 4,
};

type sleep_state = enum uint {
	DISK	= 1 << 0,
	FREEZE	= 1 << 1,
	STANDBY	= 1 << 2,
	MEM	= 1 << 3,
};

type operation = enum {
	QUERY,
	SET_SLEEP,
	SET_DISK,
	SET_IMAGE,
	SET_MEM,
	ERR,
};

export fn main() void = {
	const help: []getopt::help = [
		"power control",
		('q', "query supported power states"),
		('d', "set disk suspend mode"),
		('i', "configure target hibernation image size"),
		('m', "set memory suspend mode"),
		('s', "set sleep mod"),
	];
	const cmd = getopt::parse(os::args, help...);
	defer getopt::finish(&cmd);

	const olen = len(cmd.opts);
	if (olen <= 0) {
		getopt::printhelp(os::stderr, "powerctl", help...);
		os::exit(1);
	};

	let op = operation::ERR;
	for (let i = 0z; i < olen; i += 1) {
		switch (cmd.opts[i].0) {
		case 'q' =>
			op = operation::QUERY;
		case 'd' =>
			op = operation::SET_DISK;
		case 'i' =>
			op = operation::SET_IMAGE;
		case 'm' =>
			op = operation::SET_MEM;
		case 's' =>
			op = operation::SET_SLEEP;
		case =>
			abort();
		};
	};

	if (op == operation::QUERY) {
		if (len(cmd.args) != 0) {
			getopt::printhelp(os::stderr, "powerctl", help...);
			os::exit(1);
		};
		match (query()) {
		case let err: io::error =>
			fmt::fatal("I/O error:", io::strerror(err));
		case let err: fs::error =>
			fmt::fatal("Error: this system dose not support any sleep states");
		case void =>
			os::exit(0);
		};
	};

	if (!checkgroup()) {
		fmt::fatalf("Error: Access denied. Are you a member of the {} group?",
			POWER_GROUP);
	};

	if (len(cmd.args) != 1) {
		getopt::printhelp(os::stderr, "powerctl", help...);
		os::exit(1);
	};

	switch (op) {
	case operation::QUERY =>
		abort();
	case operation::SET_DISK =>
		const state = match(disk_state_parse(cmd.args[0])) {
		case let state: disk_state =>
			yield state;
		case errors::invalid =>
			getopt::printhelp(os::stderr, "powerctl", help...);
			os::exit(1);
		};
		const result = set_disk_state(state);
		check_set_state(result);
	case operation::SET_SLEEP =>
		const state = match (sleep_state_parse(cmd.args[0])) {
		case let state: sleep_state =>
			yield state;
		case errors::invalid =>
			getopt::printhelp(os::stderr, "powerctl", help...);
			os::exit(1);
		};
		const result = set_sleep_state(state);
		check_set_state(result);
	};
};

fn check_set_state(result: (void | fs::error | io::error)) void = {
	match (result) {
	case let err: io::error =>
		fmt::fatal("I/O error:", io::strerror(err));
	case let err: fs::error =>
		fmt::fatal("Error: this system does not support any sleep states");
	case void =>
		yield;
	};
};

fn read_states(path: str) (strings::tokenizer | fs::error | io::error) = {
	static let buf: [512]u8 = [0...];

	const file = os::open(path)!;
	defer io::close(file)!;

	const z = match (io::read(file, buf)?) {
	case let z: size =>
		yield z;
	case =>
		abort("Unexpected EOF from sysfs");
	};
	const string = strings::rtrim(strings::fromutf8(buf[..z])!, '\n');
	return strings::tokenize(string, " ");
};

fn sleep_state_parse(in: str)(sleep_state | errors::invalid) = {
	switch (in) {
	case "disk" =>
		fmt::println("disk!!")!;
		return sleep_state::DISK;
	case "freeze" =>
		return sleep_state::FREEZE;
	case "standby" =>
		return sleep_state::STANDBY;
	case "mem"=>
		return sleep_state::MEM;
	case =>
		return errors::invalid;
	};
};

fn read_sleep_states() (sleep_state | fs::error | io::error) = {
	const tok = read_states("/sys/power/state")?;

	let states: sleep_state = 0;
	for (true) {
		const tok = match (strings::next_token(&tok)) {
		case let s: str =>
			yield s;
		case void =>
			break ;
		};

		fmt::printf("{}\n", tok)!;
		match (sleep_state_parse(tok)) {
		case let s: sleep_state =>
			states |= s;
		case =>
			continue;
		};
	};
	return states;
};

fn sleep_state_unparse(state: sleep_state) const str = {
	switch (state) {
	case sleep_state::DISK =>
		return "disk";
	case sleep_state::FREEZE =>
		return "freeze";
	case sleep_state::STANDBY =>
		return "standby";
	case sleep_state::MEM =>
		return "mem";
	};
};

fn set_sleep_state(state: sleep_state) (void | fs::error | io::error) = {
	time::sleep(250 * time::MILLISECOND);
	write_sysfs_file("/sys/power/state", sleep_state_unparse(state))?;
};

fn query() (void | io::error | fs::error) = {
	const sstates = read_sleep_states()?;
	fmt::println("Supported sleep states:")!;
	print_state(sstates, 0, sleep_state::DISK, "disk");
	print_state(sstates, 0, sleep_state::FREEZE, "freeze");
	print_state(sstates, 0, sleep_state::STANDBY, "standby");
	print_state(sstates, 1, sleep_state::MEM, "mem");
	fmt::println()!;

	const (mstates, mactive) = read_mem_states()?;
	fmt::println("Supported mem sleep staes:")!;
	print_state(mstates, mactive, mem_state::S2IDLE, "s2idle");
	print_state(mstates, mactive, mem_state::SHALLOW, "shallow");
	print_state(mstates, mactive, mem_state::DEEP, "deep");
	if (mstates == 0) {
		fmt::println("(none)")!;
	};
	fmt::println()!;

	const (dstates, dactive) = read_disk_states()?;
	fmt::println("Supported disk sleep states:")!;
	print_state(dstates, dactive, disk_state::PLATFORM, "platform");
	print_state(dstates, dactive, disk_state::SHUTDOWN, "shutdown");
	print_state(dstates, dactive, disk_state::REBOOT, "reboot");
	print_state(dstates, dactive, disk_state::SUSPEND, "suspend");
	print_state(dstates, dactive, disk_state::TEST_RESUME, "test_resume");
	if (dstates == 0) {
		fmt::println("(none)")!;
	};
	fmt::println()!;

	const imgsize = read_image_size()?;
	fmt::printfln("Target hibernation imgge size ceiling: {} bytes", imgsize)!;
};

fn read_image_size() (size | fs::error | io::error) = {
	const file = os::open("/sys/power/image_size")?;
	defer io::close(file)!;

	let buf: [128]u8 = [0...];
	const z = match (io::read(file, buf)?) {
	case let z: size =>
		yield z;
	case io::EOF =>
		abort("Unexpected EOF from /sys/power/image_size");
	};

	const val = strings::rtrim(strings::fromutf8(buf[..z])!, '\n');
	match (strconv::stoz(val)) {
	case let z: size =>
		return z;
	case =>
		abort("Unexpected read from /sys/power/image_size");
	};
};

fn read_disk_states() ((disk_state, disk_state) | fs::error | io::error) = {
	const tok = read_states("/sys/power/disk")?;

	let states: disk_state = 0, active: disk_state = 0;
	for (true) {
		let tok = match (strings::next_token(&tok)) {
		case let s: str =>
			yield s;
		case void =>
			break;
		};

		const trimmed = strings::trim(tok, '[', ']');
		match (disk_state_parse(trimmed)) {
		case let s: disk_state =>
			states |= s;

			if (trimmed != tok) {
				active = s;
			};
		case =>
			continue;
		};
	};
	return (states, active);
};

fn read_mem_states() ((mem_state, mem_state) | fs::error | io::error) = {
	const tok= read_states("/sys/power/mem_sleep")?;

	let states: mem_state = 0, active: mem_state = 0;
	for (true) {
		let tok = match (strings::next_token(&tok)) {
		case let s: str =>
			yield s;
		case void =>
			break ;
		};

		const trimmed = strings::trim(tok, '[', ']');
		match (mem_state_parse(trimmed)) {
		case let s: mem_state =>
			states |= s;

			if (trimmed != tok) {
				active = s;
			};
		case =>
			continue;
		};
	};
	return (states, active);
};

fn mem_state_parse(in: str) (mem_state | errors::invalid) = {
	switch (in) {
	case "s2idle" =>
		return mem_state::S2IDLE;
	case "shallow" =>
		return mem_state::SHALLOW;
	case "deep" =>
		return mem_state::DEEP;
	case =>
		return errors::invalid;
	};
};
fn disk_state_parse(in: str) (disk_state | errors::invalid) = {
	switch (in) {
	case "platform" =>
		return disk_state::PLATFORM;
	case "shutdown" =>
		return disk_state::SHUTDOWN;
	case "reboot" =>
		return disk_state::REBOOT;
	case "suspend" =>
		return disk_state::SUSPEND;
	case "test_resume" =>
		return disk_state::TEST_RESUME;
	case =>
		return errors::invalid;
	};
};

fn print_state(
	supported: uint,
	active: uint,
	state: uint,
	name: str,
) void = {
	if (supported & state != 0) {
		fmt::printf("\t{}", name)!;
		if (active == state) {
			fmt::print(" (active)")!;
		};
		fmt::println()!;
	};
};

fn write_sysfs_file(path: str, content: str) (void | fs::error | io::error) = {
	const file = os::open(path, fs::flags::WRONLY | fs::flags::TRUNC)?;
	defer io::close(file)!;

	io::write(file, strings::toutf8(content))?;
};


fn disk_state_unparse(state: disk_state) const str = {
	switch (state) {
	case disk_state::PLATFORM =>
		return "platform";
	case disk_state::SHUTDOWN =>
		return "shutdown";
	case disk_state::REBOOT =>
		return "reboot";
	case disk_state::SUSPEND =>
		return "suspend";
	case disk_state::TEST_RESUME =>
		return "test_resume";
	};
};

fn set_disk_state(state: disk_state) (void | fs::error | io::error) = {
	//write_sysfs_file("/sys/power/disk", disk_state_unparse(state))?;
	write_sysfs_file("tmp", disk_state_unparse(state))?;
};
