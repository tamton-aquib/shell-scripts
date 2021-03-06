#!/bin/sh

## OS/ENVIRONMENT INFO DETECTION

ostype="$(uname)"

if command -v getprop > /dev/null; then
	linuxtype=android
	host="$(getprop net.hostname)"
else
	. /etc/os-release
	case $ostype in
	Linux*) host="$(cat /proc/sys/kernel/hostname)";;
	*) host="host"
	esac
	linuxtype=none
fi
kernel="$(echo $(uname -r) | cut -d'-'  -f1-1)"
case $ostype in
	"Linux"*)
		if [ -f /bedrock/etc/bedrock-release ]; then
			os="$(brl version)"
		elif [ $linuxtype = android ]; then
			os="Android $(getprop ro.build.version.release)"
		else
			os="${PRETTY_NAME}"
		fi
		shell=${SHELL##*/};;
	"Darwin"*)
		while IFS='<>' read -r _ _ line _; do
			case $line in
				ProductVersion)
					IFS='<>' read -r _ _ mac_version _
					break;;
			esac
		done < /System/Library/CoreServices/SystemVersion.plist
		os="macOS ${mac_version}";;
	*) os="Idk"
esac

## PACKAGE MANAGER AND PACKAGES DETECTION

manager=$(which nix-env pkg yum zypper dnf rpm apt brew port pacman xbps-query  emerge cave apk kiss pmm /usr/sbin/slackpkg yay paru cpm pmm eopkg 2>/dev/null)
manager=${manager##*/}
case $manager in
	cpm) packages="$(cpm C)";;
	brew) packages="$(printf '%s\n' "$(brew --cellar)/"* | wc -l | tr -d '[:space:]')";;
	port) packages=$(port installed | tot);;
	apt) packages="$(dpkg-query -f '${binary:Package}\n' -W | wc -l)";;
	rpm) packages="$(rpm -qa --last| wc -l)";;
	yum) packages="$(yum list installed | wc -l)";;
	dnf) packages="$(dnf list installed | wc -l)";;
	zypper) packages="$(zypper se | wc -l)";;
	pacman) packages="$(pacman -Q | wc -l)";;
	yay) packages="$(yay -Q | wc -l)";;
	paru) packages="$(paru -Q | wc -l)";;
	kiss) packages="$(kiss list | wc -l)";;
	pkg|emerge) packages="$(qlist -I | wc -l)";;
	cave) packages="$(cave show installed-slots | wc -l)";;
	xbps-query) packages="$(xbps-query -l | wc -l)";;
	nix-env) packages="$(nix-store -q --requisites /run/current-system/sw | wc -l)";;
	apk) packages="$(apk list --installed | wc -l)";;
	pmm) packages="$(/bedrock/libexec/pmm pacman pmm -Q 2>/dev/null | wc -l )";;
	eopkg) packages="$(eopkg li | wc -l)";;
	/usr/sbin/slackpkg) packages="$(ls /var/log/packages | wc -l)";;
	*)
		packages="$(ls /usr/bin | wc -l)"
		manager="bin";;
esac

## UPTIME DETECTION

case $ostype in
	"Linux")
		IFS=. read -r s _ < /proc/uptime;;
	*) 
		s=$(sysctl -n kern.boottime)
		s=${s#*=}
		s=${s%,*}
		s=$(($(date +%s) - s));;
esac
d="$((s / 60 / 60 / 24))"
h="$((s / 60 / 60 % 24))"
m="$((s / 60 % 60))"
# Plurals
[ "$d" -gt 1 ] && dp=s
[ "$h" -gt 1 ] && hp=s
[ "$m" -gt 1 ] && mp=s
# Hide empty fields.
[ "$d" = 0 ] && d=
[ "$h" = 0 ] && h=
[ "$m" = 0 ] && m=
# Make the output of uptime smaller.
case $uptime_shorthand in
	tiny)
		[ "$d" ] && uptime="${d}d, "
		[ "$h" ] && uptime="$uptime${h}h, "
		[ "$m" ] && uptime="$uptime${m}m"
		uptime=${uptime%, };;
	*)
		[ "$d" ] && uptime="$d day$dp, "
		[ "$h" ] && uptime="$uptime$h hour$hp, "
		[ "$m" ] && uptime="$uptime$m min$mp"
		uptime=${uptime%, };;
esac

## RAM DETECTION

case $ostype in
	"Linux")
		while IFS=':k '  read -r key val _; do
			case $key in
				MemTotal)
					mem_used=$((mem_used + val))
					mem_full=$val;;
				Shmem) mem_used=$((mem_used + val));;
				MemFree|Buffers|Cached|SReclaimable) mem_used=$((mem_used - val));;
			esac
		done < /proc/meminfo
		mem_used=$((mem_used / 1024)) 
		mem_full=$((mem_full / 1024));;
	"Darwin"*)
		mem_full=$(($(sysctl -n hw.memsize) / 1024 / 1024))
		while IFS=:. read -r key val; do
			case $key in
				*' wired'*|*' active'*|*' occupied'*)
					mem_used=$((mem_used + ${val:-0}));;
			esac
			done <<-EOF
				$(vm_stat)
						EOF

			mem_used=$((mem_used * 4 / 1024));;
	*)
		mem_full="idk"
		mem_used="idk"
esac
memstat="${mem_used}/${mem_full} MB"
if which dc > /dev/null 2>&1; then
	mempercent="($(echo 100 ${mem_used} \* ${mem_full} / p | dc)%)"
fi
## DEFINE COLORS

bold='[1m'
black='[30m'
red='[31m'
green='[32m'
yellow='[33m'
blue='[34m'
magenta='[35m'
cyan='[36m'
white='[37m'
grey='[90m'
reset='[0m'

## USER VARIABLES -- YOU CAN CHANGE THESE

lc="${reset}${bold}${magenta}"  # labels
nc="${reset}${bold}${yellow}"   # user
hn="${reset}${bold}${blue}"     # hostname
ic="${reset}${green}"           # info
c0="${reset}${blue}"            # first color
c1="${reset}${white}"           # second color
c2="${reset}${yellow}"          # third color

cat <<EOF

${c0}           .              ${nc}${USER}${red}@${reset}${hn}${host}${reset} 
${c0}          / \\             ${lc}  ${ic}${os}${reset}
${c0}         /   \\            ${lc}  ${ic}${kernel}${reset}
${c0}        /^.   \\           ${lc}  ${ic}${RAM}${memstat} ${mempercent}
${c0}       /  .-.  \\          ${lc}  ${ic}${packages} (${manager})${reset}
${c0}      /  (   ) _\\         ${lc}  ${ic}${uptime}${reset}
${c0}     / _.~   ~._^\\        ${lc}穀 ${ic}ᗪᗯᗰ 
${c0}    /.^         ^.\\       ${lc}  ${red}███${green}███${yellow}███${blue}███${magenta}███${cyan}███${reset}


EOF
