# shellcheck shell=bash
# lib/completions/shells.sh
# bash_completion_dir — User-writable bash-completion completions directory.
bash_completion_dir() {
	echo "${XDG_DATA_HOME:-$HOME/.local/share}/bash-completion/completions"
}

# completions_enable_bash — Enable bash completions (symlink preferred, profile fallback).
completions_enable_bash() {
	local drop_in link_dir link target
	drop_in="$(completions_state_dir)/completions.bash"
	target="$(launchlayer_share_dir)/completions/launchlayer.bash"
	write_completions_dropin bash "$drop_in" "$target"

	link_dir="$(bash_completion_dir)"
	mkdir -p "$link_dir"
	link="$link_dir/launchlayer"
	if safe_install_symlink "$target" "$link"; then
		write_completions_manifest BASH_METHOD "bash-completion:$link"
		echo "bash: enabled via bash-completion ($link)"
		return 0
	fi

	profile_append_completions_block "$HOME/.bashrc" "$drop_in"
	write_completions_manifest BASH_METHOD "profile:$HOME/.bashrc"
	echo "bash: enabled via managed block in ~/.bashrc"
}

# completions_disable_bash — Disable bash completions; only remove what we installed.
completions_disable_bash() {
	local method="" drop_in link path
	method="$(read_completions_manifest BASH_METHOD 2>/dev/null || true)"
	drop_in="$(completions_state_dir)/completions.bash"

	case "$method" in
		bash-completion:*)
			link="${method#bash-completion:}"
			safe_remove_symlink "$link" "$(launchlayer_share_dir)/completions/launchlayer.bash"
			;;
		profile:*)
			path="${method#profile:}"
			profile_remove_completions_block "$path"
			;;
	esac

	if [[ -z "$method" ]]; then
		link_dir="$(bash_completion_dir 2>/dev/null || true)"
		if [[ -n "$link_dir" ]]; then
			safe_remove_symlink "$link_dir/launchlayer" \
				"$(launchlayer_share_dir)/completions/launchlayer.bash"
		fi
		profile_remove_completions_block "$HOME/.bashrc"
	fi

	rm -f "$drop_in"
	remove_manifest_key BASH_METHOD
	echo "bash: disabled"
}

# completions_bash_status — Print bash completion install state.
completions_bash_status() {
	local method="" drop_in link
	method="$(read_completions_manifest BASH_METHOD 2>/dev/null || true)"
	drop_in="$(completions_state_dir)/completions.bash"
	if [[ "$method" == bash-completion:* ]]; then
		link="${method#bash-completion:}"
		if [[ -L "$link" ]] && symlink_points_to "$link" "$(launchlayer_share_dir)/completions/launchlayer.bash"; then
			echo "bash: enabled (bash-completion → $link)"
			return 0
		fi
	elif [[ "$method" == profile:* ]]; then
		if profile_has_completions_block "${method#profile:}"; then
			echo "bash: enabled (profile block → ${method#profile:})"
			return 0
		fi
	fi

	if [[ -f "$drop_in" ]]; then
		echo "bash: partially installed (drop-in present, reload shell or re-run enable)"
		return 0
	fi
	echo "bash: disabled"
}

# completions_enable_zsh — Enable zsh completions via profile drop-in.
completions_enable_zsh() {
	local drop_in target zshrc
	drop_in="$(completions_state_dir)/completions.zsh"
	target="$(launchlayer_share_dir)/completions/_launchlayer"
	zshrc="$(zsh_profile_path)"
	write_completions_dropin zsh "$drop_in" "$target"
	profile_append_completions_block "$zshrc" "$drop_in"
	write_completions_manifest ZSH_METHOD "profile:$zshrc"
	echo "zsh: enabled via managed block in $zshrc"
}

# completions_disable_zsh — Disable zsh completions.
completions_disable_zsh() {
	local method="" drop_in path
	method="$(read_completions_manifest ZSH_METHOD 2>/dev/null || true)"
	drop_in="$(completions_state_dir)/completions.zsh"
	path="${method#profile:}"
	[[ -n "$path" && "$method" == profile:* ]] || path="$(zsh_profile_path)"
	profile_remove_completions_block "$path"
	rm -f "$drop_in"
	remove_manifest_key ZSH_METHOD
	echo "zsh: disabled"
}

# completions_zsh_status — Print zsh completion install state.
completions_zsh_status() {
	local method="" drop_in
	method="$(read_completions_manifest ZSH_METHOD 2>/dev/null || true)"
	drop_in="$(completions_state_dir)/completions.zsh"
	if [[ "$method" == profile:* ]] && profile_has_completions_block "${method#profile:}"; then
		echo "zsh: enabled (profile block → ${method#profile:})"
	elif [[ -f "$drop_in" ]]; then
		echo "zsh: partially installed (drop-in present, reload shell or re-run enable)"
	else
		echo "zsh: disabled"
	fi
}

# completions_enable_nu — Enable nushell completions via completions dir symlink.
completions_enable_nu() {
	local nu_dir link target
	nu_dir="$(nu_completions_dir)"
	target="$(launchlayer_share_dir)/completions/launchlayer.nu"
	link="$nu_dir/launchlayer.nu"
	mkdir -p "$nu_dir"
	safe_install_symlink "$target" "$link"
	write_completions_manifest NU_METHOD "symlink:$link"
	echo "nu: enabled via symlink ($link)"
}

# completions_disable_nu — Disable nushell completions.
completions_disable_nu() {
	local method="" link
	method="$(read_completions_manifest NU_METHOD 2>/dev/null || true)"
	link="${method#symlink:}"
	[[ -n "$link" && "$method" == symlink:* ]] || link="$(nu_completions_dir)/launchlayer.nu"
	safe_remove_symlink "$link" "$(launchlayer_share_dir)/completions/launchlayer.nu"
	remove_manifest_key NU_METHOD
	echo "nu: disabled"
}

# completions_nu_status — Print nushell completion install state.
completions_nu_status() {
	local method="" link
	method="$(read_completions_manifest NU_METHOD 2>/dev/null || true)"
	link="${method#symlink:}"
	[[ -n "$link" && "$method" == symlink:* ]] || link="$(nu_completions_dir)/launchlayer.nu"
	if [[ -L "$link" ]] && symlink_points_to "$link" "$(launchlayer_share_dir)/completions/launchlayer.nu"; then
		echo "nu: enabled (symlink → $link)"
	else
		echo "nu: disabled"
	fi
}

# completions_enable_pwsh — Enable PowerShell completions via profile drop-in.
completions_enable_pwsh() {
	local drop_in target profile
	drop_in="$(completions_state_dir)/completions.pwsh"
	target="$(launchlayer_share_dir)/completions/launchlayer.ps1"
	profile="$(pwsh_profile_path)"
	write_completions_dropin pwsh "$drop_in" "$target"
	profile_append_completions_block "$profile" "$drop_in"
	write_completions_manifest PWSH_METHOD "profile:$profile"
	echo "pwsh: enabled via managed block in $profile"
}

# completions_disable_pwsh — Disable PowerShell completions.
completions_disable_pwsh() {
	local method="" drop_in path
	method="$(read_completions_manifest PWSH_METHOD 2>/dev/null || true)"
	drop_in="$(completions_state_dir)/completions.pwsh"
	path="${method#profile:}"
	[[ -n "$path" && "$method" == profile:* ]] || path="$(pwsh_profile_path)"
	profile_remove_completions_block "$path"
	rm -f "$drop_in"
	remove_manifest_key PWSH_METHOD
	echo "pwsh: disabled"
}

# completions_pwsh_status — Print PowerShell completion install state.
completions_pwsh_status() {
	local method="" drop_in
	method="$(read_completions_manifest PWSH_METHOD 2>/dev/null || true)"
	drop_in="$(completions_state_dir)/completions.pwsh"
	if [[ "$method" == profile:* ]] && profile_has_completions_block "${method#profile:}"; then
		echo "pwsh: enabled (profile block → ${method#profile:})"
	elif [[ -f "$drop_in" ]]; then
		echo "pwsh: partially installed (drop-in present, reload shell or re-run enable)"
	else
		echo "pwsh: disabled"
	fi
}

# completions_status_json — JSON status for all shells.
completions_status_json() {
	local bash_s zsh_s fish_s nu_s pwsh_s
	bash_s="$(completions_bash_status | sed 's/^bash: //')"
	zsh_s="$(completions_zsh_status | sed 's/^zsh: //')"
	fish_s="$(completions_fish_status | sed 's/^fish: //')"
	nu_s="$(completions_nu_status | sed 's/^nu: //')"
	pwsh_s="$(completions_pwsh_status | sed 's/^pwsh: //')"
	printf '{"config_dir":%s,"bash":%s,"zsh":%s,"fish":%s,"nu":%s,"pwsh":%s,"osh":"uses bash completions"}\n' \
		"$(json_string "$CONFIG_DIR")" \
		"$(json_string "$bash_s")" \
		"$(json_string "$zsh_s")" \
		"$(json_string "$fish_s")" \
		"$(json_string "$nu_s")" \
		"$(json_string "$pwsh_s")"
}

# completions_enable_fish — Enable fish completions via completions dir symlink.
completions_enable_fish() {
	local fish_dir link target
	fish_dir="${XDG_CONFIG_HOME:-$HOME/.config}/fish/completions"
	target="$(launchlayer_share_dir)/completions/launchlayer.fish"
	link="$fish_dir/launchlayer.fish"
	safe_install_symlink "$target" "$link"
	write_completions_manifest FISH_METHOD "symlink:$link"
	echo "fish: enabled via symlink ($link)"
}

# completions_disable_fish — Disable fish completions.
completions_disable_fish() {
	local method="" link
	method="$(read_completions_manifest FISH_METHOD 2>/dev/null || true)"
	link="${method#symlink:}"
	[[ -n "$link" && "$method" == symlink:* ]] || link="${XDG_CONFIG_HOME:-$HOME/.config}/fish/completions/launchlayer.fish"
	safe_remove_symlink "$link" "$(launchlayer_share_dir)/completions/launchlayer.fish"
	remove_manifest_key FISH_METHOD
	echo "fish: disabled"
}

# completions_fish_status — Print fish completion install state.
completions_fish_status() {
	local method="" link
	method="$(read_completions_manifest FISH_METHOD 2>/dev/null || true)"
	link="${method#symlink:}"
	[[ -n "$link" && "$method" == symlink:* ]] || link="${XDG_CONFIG_HOME:-$HOME/.config}/fish/completions/launchlayer.fish"
	if [[ -L "$link" ]] && symlink_points_to "$link" "$(launchlayer_share_dir)/completions/launchlayer.fish"; then
		echo "fish: enabled (symlink → $link)"
	else
		echo "fish: disabled"
	fi
}
