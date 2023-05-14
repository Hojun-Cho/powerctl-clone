powerctl(8)

# NAME

powerctl - control power management states

# SYNOPSIS

*powerctl* [-qDIM] <desired state>

# DESCRIPTION

*powerctl* is a tool which manages power states on Linux. Users of this tool
must be root or a member of the "power" group. When run with no options, it sets
the system's sleep state to the specified state, which causes the system to
immediately enter a sleep state (e.g. suspend). The -D, -I, and -M options
configure the system's sleep states and behavior. The -q option takes no
argument and prints the current system sleep configuration, and does not require
root access or membership in the power group.

# USAGE

*powerctl* <disk|freeze|standby|mem>
	When executed with no options, the specified sleep state is entered,
	immediately putting the system into some level of suspension. The
	options have the following meanings:

	*disk*
		Enter the "hibernation" state. A system memory image is written
		to disk and the system enters the state associated with the
		_disk_ configuration (see *powerctl -D*).

	*freeze*
		Enter the "suspend to idle" state, a software-supported
		low-power state which is always supported but achieves the worst
		power performance.

	*standby*
		Enter the "standby" state, in which more system resources are
		powered down or placed into a low-power mode than s2idle. This
		offers improved power savings over *s2idle*, but increases
		system resume latency.

	*mem*
		Enter the _mem_ state (see *powerctl -M*).

*powerctl -q*
	Query the current system power management configuration and supported
	options, and print them to stdout. This operation does not require
	elevated permissions.

*powerctl -D* <platform|shutdown|reboot|suspend|test_resume>
	Configures the behavior following a suspend-to-disk operation. The
	options have the following meanings:

	*platform*
		Enter the platform-specific suspended state, if supported, e.g.
		ACPI S4.

	*shutdown*
		Power off the system.

	*reboot*
		Reboot the system. Useful for diagnostics and testing.

	*suspend*
		Enter the "hybrid" suspend mode. This state enters the sleep
		mode specified by the _mem_ state, then, if the system
		successfully wakes up from this state, the hibernation state is
		discarded. Otherwise, the system resumes as if from the normal
		hibernation state.

	*test_resume*
		Immediately resume from the hibernation state and perform a full
		system resume. Useful for diagnostics and testing.

*powerctl -I* <size in bytes>
	Configure the desired maximum hibernation image size. The kernel
	interprets this value as a best-effort target, and, if necessary, a
	larger image will be produced. Setting this value to zero will always
	produce the smallest possible image.

*powerctl -M* <s2idle|shallow|deep>
	Configures the desired system suspend behavior for the _mem_ state. The
	options have the following meanings:

	*s2idle*
		Use the "suspend to idle" state, a software-supported low-power
		state which is always supported but achieves the worst power
		performance.

	*shallow*
		Use the "standby" state, in which more system resources are
		powered down or placed into a low-power mode than s2idle. This
		offers improved power savings over *s2idle*, but increases
		system resume latency.

	*deep*
		Use the "suspend to RAM" state, in which all system resources
		are powered off except for RAM. This mode offers the best power
		savings among these options, but has the highest resume latency
		and requires re-initializing all I/O devices.
