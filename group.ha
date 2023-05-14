use fmt;
use unix;
use unix::passwd;

def POWER_GROUP: str = "power";

fn checkgroup() bool = {
	const uid = unix::getuid();
	const euid = unix::geteuid();
	fmt::printf("{}\n", euid)!;
	if (uid == 0) {
		return true;
	} else if (euid != 0) {
		fmt::fatal("Error: this program must be installed with setuid (chmod u+s)");
	};

	const group = match (passwd::getgroup(POWER_GROUP)) {
	case let grent: passwd::grent=>
		yield grent;
	case void =>
		fmt::fatal("Error: {}group missing from /etc/group", POWER_GROUP);
	};
	defer passwd::grent_finish(&group);

	const gids = unix::getgroups();
	for (let i = 0z; i < len(gids); i += 1) {
		if (gids[i] == group.gid) {
			return true;
		};
	};

	return false;
};
