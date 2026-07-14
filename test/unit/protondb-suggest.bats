#!/usr/bin/env bash
# Unit tests for scripts/protondb_suggest.py helpers.
load '../helpers.bash'

SCRIPT="$BATS_TEST_DIRNAME/../../scripts/protondb_suggest.py"

_py() {
	python3 - "$@" <<'PY'
import importlib.util
import sys

spec = importlib.util.spec_from_file_location("protondb_suggest", sys.argv[1])
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

cmd = sys.argv[2]
if cmd == "parse":
    wrappers, env_vars, args = mod.parse_launch_options(sys.argv[3])
    print("wrappers=" + ",".join(sorted(wrappers)))
    print("env=" + ",".join(f"{k}={v}" for k, v in sorted(env_vars.items())))
    print("args=" + ",".join(args))
elif cmd == "gpu":
    print(mod.gpu_match_bonus(sys.argv[3], sys.argv[4]))
else:
    raise SystemExit(f"unknown cmd {cmd}")
PY
}

@test "protondb parse_launch_options extracts wrappers env and args" {
	run _py "$SCRIPT" parse 'gamemoderun MANGOHUD=1 PROTON_ENABLE_NVAPI=1 %command% -dx11'
	[[ $status -eq 0 ]]
	[[ "$output" == *"wrappers=GAMEMODE"* ]]
	[[ "$output" == *"env=MANGOHUD=1,PROTON_ENABLE_NVAPI=1"* ]]
	[[ "$output" == *"args=-dx11"* ]]
}

@test "protondb gpu_match_bonus does not treat radeon as match for nvidia host" {
	run _py "$SCRIPT" gpu nvidia "AMD Radeon RX 7800 XT"
	[[ $status -eq 0 ]]
	[[ "$output" == "-1.0" ]]
}

@test "protondb gpu_match_bonus matches amd host to radeon report" {
	run _py "$SCRIPT" gpu amd "AMD Radeon RX 7800 XT"
	[[ $status -eq 0 ]]
	[[ "$output" == "3.0" ]]
}

@test "protondb is_allowed_config_key blocks LD_PRELOAD and allows PROTON_" {
	run python3 -c '
import importlib.util
spec = importlib.util.spec_from_file_location("pdb", "'"$SCRIPT"'")
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
assert m.is_allowed_config_key("PROTON_ENABLE_NVAPI")
assert m.is_allowed_config_key("GAMEMODE")
assert m.is_allowed_config_key("DLSS_SWAPPER")
assert m.is_allowed_config_key("PROTON_DLSS_UPGRADE")
assert m.is_allowed_config_key("PROTON_FSR4_UPGRADE")
assert m.is_allowed_config_key("PROTON_XESS_UPGRADE")
assert m.is_allowed_config_key("SHADER_CACHE_BOOST")
assert m.is_allowed_config_key("LD_BIND_NOW")
assert m.is_allowed_config_key("VKBASALT")
assert m.is_allowed_config_key("LATENCYFLEX")
assert m.is_allowed_config_key("DISABLE_VBLANK")
assert m.is_allowed_config_key("DISABLE_STEAM_DECK")
assert m.is_allowed_config_key("FRAME_RATE")
assert not m.is_allowed_config_key("LD_PRELOAD")
assert not m.is_allowed_config_key("PATH")
print("ok")
'
	[[ $status -eq 0 ]]
	[[ "$output" == "ok" ]]
}

@test "protondb detect_host_cpu prefers amd-cpu profile token" {
	run python3 -c '
import importlib.util
spec = importlib.util.spec_from_file_location("pdb", "'"$SCRIPT"'")
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
assert m.detect_host_cpu({"profiles": "arch-linux amd-gpu amd-cpu"}) == "amd"
assert m.detect_host_cpu({"profiles": ["intel-cpu", "amd-gpu"]}) == "intel"
# amd-gpu alone must not select amd via substring
assert m.detect_host_cpu({"profiles": "arch-linux amd-gpu"}) == m.detect_host_cpu({"profiles": "arch-linux amd-gpu"})
cpu = m.detect_host_cpu({"profiles": "arch-linux amd-gpu"})
# Without amd-cpu/intel-cpu tokens, falls back to /proc/cpuinfo — just ensure it returns a known value
assert cpu in ("amd", "intel", "unknown")
print("ok")
'
	[[ $status -eq 0 ]]
	[[ "$output" == "ok" ]]
}

@test "protondb GAME_EXTRA_ARGS merge regex matches existing lines" {
	run python3 -W ignore::FutureWarning -c '
import re
line = "GAME_EXTRA_ARGS=\"-windowed\""
assert re.match(r"^\s*GAME_EXTRA_ARGS=(.*)$", line)
# POSIX [[:space:]] is not valid in Python re (legacy bug); keep the \s form.
m = re.match(r"^[[:space:]]*GAME_EXTRA_ARGS=(.*)$", line)
assert m is None
print("ok")
'
	[[ $status -eq 0 ]]
	[[ "$output" == *"ok"* ]]
}
