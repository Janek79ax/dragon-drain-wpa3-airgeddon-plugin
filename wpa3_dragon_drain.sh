#!/usr/bin/env bash

#Global shellcheck disabled warnings
#shellcheck disable=SC2034,SC2154

plugin_name="WPA3 Dragon Drain"
plugin_description="A plugin to perform a WPA3 Dragon Drain DoS attack"
plugin_author="Janek"

plugin_enabled=1

plugin_minimum_ag_affected_version="11.50"
plugin_maximum_ag_affected_version=""
plugin_distros_supported=("Kali", "Kali arm", "Parrot", "Parrot arm", "Debian", "Ubuntu", "Mint", "Backbox", "Raspberry Pi OS", "Raspbian", "Cyborg")

#Custom function. Execute WPA3 Dragon Drain attack
function exec_wpa3_dragon_drain_attack() {

	debug_print

	#TODO pending to check if finally this is needed
	rm -rf "${tmpdir}agwpa3"* > /dev/null 2>&1
	mkdir "${tmpdir}agwpa3" > /dev/null 2>&1

	recalculate_windows_sizes

	manage_output "-hold +j -bg \"#000000\" -fg \"#FFC0CB\" -geometry ${g1_topright_window} -T \"wpa3 dragon drain attack\"" "${python3} ${scriptfolder}${plugins_dir}wpa3_dragon_drain_attack.py ${bssid} ${channel} ${interface}"
	wait_for_process "${python3} ${scriptfolder}${plugins_dir}wpa3_dragon_drain_attack.py ${bssid} ${channel} ${interface}"
}

#Custom function. Validate a WPA3 network
function validate_wpa3_network() {

	debug_print

	if [ "${enc}" != "WPA3" ]; then
		echo
		language_strings "${language}" "wpa3_online_attack_6" "red"
		language_strings "${language}" 115 "read"
		return 1
	fi

	return 0
}

#Custom function. Validate if the needed plugin python file exists
function attack_script_validation() {

	debug_print

	if ! [ -f "${scriptfolder}${plugins_dir}wpa3_dragon_drain_attack.py" ]; then
		echo
		language_strings "${language}" "wpa3_online_attack_8" "red"
		language_strings "${language}" 115 "read"
		return 1
	fi

	return 0
}

#Custom function. Validate if the system has python3.1+ installed and set python launcher
function python3_validation() {

	debug_print

	if ! hash python3 2> /dev/null; then
		if ! hash python 2> /dev/null; then
			echo
			language_strings "${language}" "wpa3_online_attack_7" "red"
			language_strings "${language}" 115 "read"
			return 1
		else
			python_version=$(python -V 2>&1 | sed 's/.* \([0-9]\).\([0-9]\).*/\1\2/')
			if [ "${python_version}" -lt "31" ]; then
				echo
				language_strings "${language}" "wpa3_online_attack_7" "red"
				language_strings "${language}" 115 "read"
				return 1
			fi
			python3="python"
		fi
	else
		python_version=$(python3 -V 2>&1 | sed 's/.* \([0-9]\).\([0-9]\).*/\1\2/')
		if [ "${python_version}" -lt "31" ]; then
			echo
			language_strings "${language}" "wpa3_online_attack_7" "red"
			language_strings "${language}" 115 "read"
			return 1
		fi
		python3="python3"
	fi

	return 0
}

#Custom function. Prepare WPA3 dragon drain attack
function wpa3_dragon_drain_attack_option() {

	debug_print

	aircrack_wpa3_version="1.7"
	get_aircrack_version

	if compare_floats_greater_than "${aircrack_wpa3_version}" "${aircrack_version}"; then
		echo
		language_strings "${language}" "wpa3_online_attack_10" "red"
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
		language_strings "${language}" "wpa3_online_attack_9" "yellow"
		echo
		language_strings "${language}" 115 "read"
		echo
		monitor_option "${interface}"
	fi

	if ! validate_wpa3_network; then
		return 1
	fi

	if ! python3_validation; then
		return 1
	fi

	if ! attack_script_validation; then
		return 1
	fi

	echo
	language_strings "${language}" 32 "green"
	echo
	language_strings "${language}" 33 "yellow"
	language_strings "${language}" 4 "read"

	exec_wpa3_dragon_drain_attack
}

#Custom function. Create the WPA3 attacks menu
function wpa3_attacks_menu() {

	debug_print

	clear
	language_strings "${language}" "wpa3_online_attack_2" "title"
	current_menu="wpa3_attacks_menu"
	initialize_menu_and_print_selections
	echo
	language_strings "${language}" 47 "green"
	print_simple_separator
	language_strings "${language}" 59
	language_strings "${language}" 48
	language_strings "${language}" 55
	language_strings "${language}" 56
	language_strings "${language}" 49
	language_strings "${language}" 50 "separator"
	language_strings "${language}" "wpa3_online_attack_3"
	print_hint

	read -rp "> " wpa3_option
	case ${wpa3_option} in
		0)
			return
		;;
		1)
			select_interface
		;;
		2)
			monitor_option "${interface}"
		;;
		3)
			managed_option "${interface}"
		;;
		4)
			explore_for_targets_option "WPA3"
		;;
		5)
			wpa3_dragon_drain_attack_option
		;;
		*)
			invalid_menu_option
		;;
	esac

	wpa3_attacks_menu
}

#Prehook for explore_for_targets_option function to show right message on WPA3 filtered scanning
#shellcheck disable=SC2016
function wpa3_dragon_drain_prehook_explore_for_targets_option() {

	sed -zri 's|"WPA3"\)\n\t{4}#Only WPA3 including WPA2\/WPA3 in Mixed mode\n\t{4}#Not used yet in airgeddon\n\t{4}:|"WPA3"\)\n\t\t\t\t#Only WPA3 including WPA2/WPA3 in Mixed mode\n\t\t\t\tlanguage_strings "${language}" "wpa3_online_attack_4" "yellow"|' "${scriptfolder}${scriptname}" 2> /dev/null
}

#Override hookable_for_menus function to add the WPA3 menu
function wpa3_online_attack_override_hookable_for_menus() {

	debug_print

	case ${current_menu} in
		"wpa3_attacks_menu")
			print_iface_selected
			print_all_target_vars
			return 0
		;;
		*)
			return 1
		;;
	esac
}

#Override hookable_for_hints function to print custom messages related to WPA3 on WPA3 menu
function wpa3_online_attack_override_hookable_for_hints() {

	debug_print

	declare wpa3_hints=(128 134 437 438 442 445 516 590 626 660 697 699 "wpa3_online_attack_5")

	case "${current_menu}" in
		"wpa3_attacks_menu")
			store_array hints wpa3_hints "${wpa3_hints[@]}"
			hintlength=${#wpa3_hints[@]}
			((hintlength--))
			randomhint=$(shuf -i 0-"${hintlength}" -n 1)
			strtoprint=${hints[wpa3_hints|${randomhint}]}
		;;
	esac
}

#Override main_menu function to add the WPA3 attack category
function wpa3_dragon_drain_override_main_menu() {

	debug_print

	clear
	language_strings "${language}" 101 "title"
	current_menu="main_menu"
	initialize_menu_and_print_selections
	echo
	language_strings "${language}" 47 "green"
	print_simple_separator
	language_strings "${language}" 61
	language_strings "${language}" 48
	language_strings "${language}" 55
	language_strings "${language}" 56
	print_simple_separator
	language_strings "${language}" 118
	language_strings "${language}" 119
	language_strings "${language}" 169
	language_strings "${language}" 252
	language_strings "${language}" 333
	language_strings "${language}" 426
	language_strings "${language}" 57
	language_strings "${language}" "wpa3_online_attack_1"
	print_simple_separator
	language_strings "${language}" 60
	language_strings "${language}" 444
	print_hint

	read -rp "> " main_option
	case ${main_option} in
		0)
			exit_script_option
		;;
		1)
			select_interface
		;;
		2)
			monitor_option "${interface}"
		;;
		3)
			managed_option "${interface}"
		;;
		4)
			dos_attacks_menu
		;;
		5)
			handshake_pmkid_decloaking_tools_menu
		;;
		6)
			decrypt_menu
		;;
		7)
			evil_twin_attacks_menu
		;;
		8)
			wps_attacks_menu
		;;
		9)
			wep_attacks_menu
		;;
		10)
			enterprise_attacks_menu
		;;
		11)
			wpa3_attacks_menu
		;;
		12)
			credits_option
		;;
		13)
			option_menu
		;;
		*)
			invalid_menu_option
		;;
	esac

	main_menu
}

#TODO pending to check if finally this hook is needed
#Posthook clean_tmpfiles function to remove temp wpa3 attack files on exit
function wpa3_dragon_drain_posthook_clean_tmpfiles() {

	rm -rf "${tmpdir}agwpa3"* > /dev/null 2>&1
}

#Prehook for hookable_for_languages function to modify language strings
function wpa3_dragon_drain_prehook_hookable_for_languages() {

	arr["ENGLISH",60]="12. About & Credits / Sponsorship mentions"
	arr["SPANISH",60]="12. Acerca de & Créditos / Menciones de patrocinadores"
	arr["FRENCH",60]="12. À propos de & Crédits / Mentions du sponsors"
	arr["CATALAN",60]="12. Sobre & Crédits / Mencions de sponsors"
	arr["PORTUGUESE",60]="12. Sobre & Créditos / Nossos patrocinadores"
	arr["RUSSIAN",60]="12. О программе и Благодарности / Спонсорские упоминания"
	arr["GREEK",60]="12. Σχετικά με & Εύσημα / Αναφορές χορηγίας"
	arr["ITALIAN",60]="12. Informazioni & Crediti / Menzioni di sponsorizzazione"
	arr["POLISH",60]="12. O programie & Podziękowania / Wzmianki sponsorskie"
	arr["GERMAN",60]="12. About & Credits / Sponsoring-Erwähnungen"
	arr["TURKISH",60]="12. Krediler ve Sponsorluk Hakkında"
	arr["ARABIC",60]="12. فريق العمل برعاية"
	arr["CHINESE",60]="12. 关于 & 鸣谢 / 赞助"

	arr["ENGLISH",444]="13. Options and language menu"
	arr["SPANISH",444]="13. Menú de opciones e idioma"
	arr["FRENCH",444]="13. Menu options et langues"
	arr["CATALAN",444]="13. Menú d'opcions i idioma"
	arr["PORTUGUESE",444]="13. Opções de menu e idioma"
	arr["RUSSIAN",444]="13. Настройки и языковое меню"
	arr["GREEK",444]="13. Μενού επιλογών και γλώσσας"
	arr["ITALIAN",444]="13. Menú opzioni e lingua"
	arr["POLISH",444]="13. Opcje i menu językowe"
	arr["GERMAN",444]="13. Optionen und Sprachmenü"
	arr["TURKISH",444]="13. Ayarlar ve dil menüsü"
	arr["ARABIC",444]="13. الخيارات وقائمة اللغة"
	arr["CHINESE",444]="13. 脚本设置和语言菜单"

	arr["ENGLISH","wpa3_online_attack_1"]="11. WPA3 attacks menu"
	arr["SPANISH","wpa3_online_attack_1"]="11. Menú de ataques WPA3"
	arr["FRENCH","wpa3_online_attack_1"]="11. Menu d'attaque WPA3"
	arr["CATALAN","wpa3_online_attack_1"]="11. Menú d'atacs WPA3"
	arr["PORTUGUESE","wpa3_online_attack_1"]="11. Menu de ataques WPA3"
	arr["RUSSIAN","wpa3_online_attack_1"]="11. Меню атак на WPA3"
	arr["GREEK","wpa3_online_attack_1"]="11. Μενού επιθέσεων WPA3"
	arr["ITALIAN","wpa3_online_attack_1"]="11. Menu degli attacchi WPA3"
	arr["POLISH","wpa3_online_attack_1"]="11. Menu ataków WPA3"
	arr["GERMAN","wpa3_online_attack_1"]="11. WPA3-Angriffsmenü"
	arr["TURKISH","wpa3_online_attack_1"]="11. WPA3 saldırılar menüsü"
	arr["ARABIC","wpa3_online_attack_1"]="11. WPA3 قائمة هجمات"
	arr["CHINESE","wpa3_online_attack_1"]="11. WPA3 攻击菜单"

	arr["ENGLISH","wpa3_online_attack_2"]="WPA3 attacks menu"
	arr["SPANISH","wpa3_online_attack_2"]="Menú de ataques WPA3"
	arr["FRENCH","wpa3_online_attack_2"]="Menu d'attaque WPA3"
	arr["CATALAN","wpa3_online_attack_2"]="Menú d'atacs WPA3"
	arr["PORTUGUESE","wpa3_online_attack_2"]="Menu de ataques WPA3"
	arr["RUSSIAN","wpa3_online_attack_2"]="Меню атак на WPA3"
	arr["GREEK","wpa3_online_attack_2"]="Μενού επιθέσεων WPA3"
	arr["ITALIAN","wpa3_online_attack_2"]="Menu degli attacchi WPA3"
	arr["POLISH","wpa3_online_attack_2"]="Menu ataków WPA3"
	arr["GERMAN","wpa3_online_attack_2"]="WPA3-Angriffsmenü"
	arr["TURKISH","wpa3_online_attack_2"]="WPA3 saldırılar menüsü"
	arr["ARABIC","wpa3_online_attack_2"]="WPA3 قائمة هجمات"
	arr["CHINESE","wpa3_online_attack_2"]="WPA3 攻击菜单"

	arr["ENGLISH","wpa3_online_attack_3"]="5.  WPA3 Dragon Drain attack"
	arr["SPANISH","wpa3_online_attack_3"]="5.  Ataque Dragon Drain WPA3"
	arr["FRENCH","wpa3_online_attack_3"]="\${pending_of_translation} 5.  Attaque de Dragon Drain WPA3"
	arr["CATALAN","wpa3_online_attack_3"]="\${pending_of_translation} 5.  Atac WPA3 Dragon Drain"
	arr["PORTUGUESE","wpa3_online_attack_3"]="\${pending_of_translation} 5.  Ataque de drenagem do dragão WPA3"
	arr["RUSSIAN","wpa3_online_attack_3"]="\${pending_of_translation} 5.  Атака на WPA3 Dragon Drain"
	arr["GREEK","wpa3_online_attack_3"]="\${pending_of_translation} 5.  Επίθεση WPA3 Dragon Drain"
	arr["ITALIAN","wpa3_online_attack_3"]="\${pending_of_translation} 5.  Attacco WPA3 Dragon Drain"
	arr["POLISH","wpa3_online_attack_3"]="\${pending_of_translation} 5.  Atak WPA3 Dragon Drain"
	arr["GERMAN","wpa3_online_attack_3"]="\${pending_of_translation} 5.  WPA3 Dragon Drain Angriff"
	arr["TURKISH","wpa3_online_attack_3"]="\${pending_of_translation} 5.  WPA3 Dragon Drain saldırı"
	arr["ARABIC","wpa3_online_attack_3"]="\${pending_of_translation} 5.  WPA3 Dragon Drain هجوم"
	arr["CHINESE","wpa3_online_attack_3"]="\${pending_of_translation} 5.  WPA3 Dragon Drain 攻击"

	arr["ENGLISH","wpa3_online_attack_4"]="WPA3 filter enabled in scan. When started, press [Ctrl+C] to stop..."
	arr["SPANISH","wpa3_online_attack_4"]="Filtro WPA3 activado en escaneo. Una vez empezado, pulse [Ctrl+C] para pararlo..."
	arr["FRENCH","wpa3_online_attack_4"]="Le filtre WPA3 est activé dans le scan. Une fois l'opération a été lancée, veuillez presser [Ctrl+C] pour l'arrêter..."
	arr["CATALAN","wpa3_online_attack_4"]="Filtre WPA3 activat en escaneig. Un cop començat, premeu [Ctrl+C] per aturar-lo..."
	arr["PORTUGUESE","wpa3_online_attack_4"]="Filtro WPA3 ativo na busca de redes wifi. Uma vez iniciado, pressione [Ctrl+C] para pará-lo..."
	arr["RUSSIAN","wpa3_online_attack_4"]="Для сканирования активирован фильтр WPA3. После запуска, нажмите [Ctrl+C] для остановки..."
	arr["GREEK","wpa3_online_attack_4"]="Το φίλτρο WPA3 ενεργοποιήθηκε κατά τη σάρωση. Όταν αρχίσει, μπορείτε να το σταματήσετε πατώντας [Ctrl+C]..."
	arr["ITALIAN","wpa3_online_attack_4"]="Filtro WPA3 attivato durante la scansione. Una volta avviato, premere [Ctrl+C] per fermarlo..."
	arr["POLISH","wpa3_online_attack_4"]="Filtr WPA3 aktywowany podczas skanowania. Naciśnij [Ctrl+C] w trakcie trwania, aby zatrzymać..."
	arr["GERMAN","wpa3_online_attack_4"]="WPA3-Filter beim Scannen aktiviert. Nach den Start, drücken Sie [Ctrl+C], um es zu stoppen..."
	arr["TURKISH","wpa3_online_attack_4"]="WPA3 filtesi taramada etkin. Başladıktan sonra, durdurmak için [Ctrl+C] yapınız..."
	arr["ARABIC","wpa3_online_attack_4"]="...للإيقاف [Ctrl+C] عند البدء ، اضغط على .WPA3 تم تفعيل المسح لشبكات"
	arr["CHINESE","wpa3_online_attack_4"]="已在扫描时启用  WPA3 过滤器。启动中... 按 [Ctrl+C] 停止..."

	arr["ENGLISH","wpa3_online_attack_5"]="WPA3 Dragon Drain attack runs forever aiming to overload the router (DoS)"
	arr["SPANISH","wpa3_online_attack_5"]="El ataque Dragon Drain de WPA3 se ejecuta indefinidamente con el objetivo de sobrecargar el router (DoS)"
	arr["FRENCH","wpa3_online_attack_5"]="\${pending_of_translation} L'attaque Dragon Drain de WPA3 s'exécute indéfiniment pour surcharger le routeur (DoS)"
	arr["CATALAN","wpa3_online_attack_5"]="\${pending_of_translation} L'atac Dragon Drain de WPA3 s'executa indefinidament amb l'objectiu de sobrecarregar el router (DoS)"
	arr["PORTUGUESE","wpa3_online_attack_5"]="\${pending_of_translation} O ataque Dragon Drain do WPA3 roda indefinidamente com o objetivo de sobrecarregar o roteador (DoS)"
	arr["RUSSIAN","wpa3_online_attack_5"]="\${pending_of_translation} Атака WPA3 Dragon Drain выполняется бесконечно, перегружая маршрутизатор (DoS)"
	arr["GREEK","wpa3_online_attack_5"]="\${pending_of_translation} Η επίθεση WPA3 Dragon Drain εκτελείται επ' αόριστον με σκοπό να υπερφορτώσει τον δρομολογητή (DoS)"
	arr["ITALIAN","wpa3_online_attack_5"]="\${pending_of_translation} L'attacco Dragon Drain WPA3 viene eseguito all'infinito per sovraccaricare il router (DoS)"
	arr["POLISH","wpa3_online_attack_5"]="\${pending_of_translation} Atak WPA3 Dragon Drain działa bez końca, próbując przeciążyć router (DoS)"
	arr["GERMAN","wpa3_online_attack_5"]="\${pending_of_translation} Der WPA3-Dragon-Drain-Angriff läuft ununterbrochen, um den Router zu überlasten (DoS)"
	arr["TURKISH","wpa3_online_attack_5"]="\${pending_of_translation} WPA3 Dragon Drain saldırısı, yönlendiriciyi aşırı yüklemek amacıyla sonsuza dek devam eder (DoS)"
	arr["ARABIC","wpa3_online_attack_5"]="\${pending_of_translation} (DoS) هجوم WPA3 Dragon Drain يستمر إلى ما لا نهاية بهدف إثقال كاهل جهاز التوجيه."
	arr["CHINESE","wpa3_online_attack_5"]="\${pending_of_translation} WPA3 龙之耗尽攻击持续运行，旨在使路由器过载。 (DoS)"

	arr["ENGLISH","wpa3_online_attack_6"]="The selected network is invalid. The target network must be WPA3 or WPA2/WPA3 in \"Mixed Mode\""
	arr["SPANISH","wpa3_online_attack_6"]="La red seleccionada no es válida. La red objetivo debe ser WPA3 o WPA2/WPA3 en \"Mixed Mode\""
	arr["FRENCH","wpa3_online_attack_6"]="Le réseau sélectionné n'est pas valide. Le réseau cible doit être WPA3 ou WPA2/WPA3 en \"Mixed Mode\""
	arr["CATALAN","wpa3_online_attack_6"]="La xarxa seleccionada no és vàlida. La xarxa objectiu ha de ser WPA3 o WPA2/WPA3 a \"Mixed Mode\""
	arr["PORTUGUESE","wpa3_online_attack_6"]="A rede selecionada é inválida. A rede deve ser WPA3 ou WPA2/WPA3 em \"Mixed Mode\""
	arr["RUSSIAN","wpa3_online_attack_6"]="Выбранная сеть недействительна. Целевая сеть должна быть WPA3 или WPA2/WPA3 в \"Mixed Mode\""
	arr["GREEK","wpa3_online_attack_6"]="Το επιλεγμένο δίκτυο δεν είναι έγκυρο. Το δίκτυο-στόχος πρέπει να είναι WPA3 ή WPA2/WPA3 σε \"Mixed Mode\""
	arr["ITALIAN","wpa3_online_attack_6"]="La rete selezionata non è valida. La rete obbiettivo deve essere WPA3 o WPA2/WPA3 in \"Mixed Mode\""
	arr["POLISH","wpa3_online_attack_6"]="Wybrana sieć jest nieprawidłowa. Sieć docelowa musi być w trybie WPA3 lub \"Mixed Mode\" WPA2/WPA3"
	arr["GERMAN","wpa3_online_attack_6"]="Das ausgewählte Netzwerk ist ungültig. Das Zielnetzwerk muss WPA3 oder WPA2/WPA3 im \"Mixed Mode\" sein"
	arr["TURKISH","wpa3_online_attack_6"]="Seçilen ağ geçersiz. Hedef ağ, \"Mixed Mode\" da WPA3 veya WPA2/WPA3 olmalıdır"
	arr["ARABIC","wpa3_online_attack_6"]="\"Mixed Mode\" WPA2/WPA3 او WPA3 الشبكة المحددة غير صالحة. يجب أن تكون الشبكة المستهدفة"
	arr["CHINESE","wpa3_online_attack_6"]="所选网络无效。目标网络必须是 WPA3 加密，或者“混合模式”下的 WPA2/WPA3"

	arr["ENGLISH","wpa3_online_attack_7"]="This attack requires to have python3.1+ installed on your system"
	arr["SPANISH","wpa3_online_attack_7"]="Este ataque requiere tener python3.1+ instalado en el sistema"
	arr["FRENCH","wpa3_online_attack_7"]="Cette attaque a besoin de python3.1+ installé sur le système"
	arr["CATALAN","wpa3_online_attack_7"]="Aquest atac requereix tenir python3.1+ instal·lat al sistema"
	arr["PORTUGUESE","wpa3_online_attack_7"]="Este ataque necessita do python3.1+ instalado no sistema"
	arr["RUSSIAN","wpa3_online_attack_7"]="Для этой атаки необходимо, чтобы в системе был установлен python3.1+"
	arr["GREEK","wpa3_online_attack_7"]="Αυτή η επίθεση απαιτεί την εγκατάσταση python3.1+ στο σύστημά σας"
	arr["ITALIAN","wpa3_online_attack_7"]="Questo attacco richiede che python3.1+ sia installato nel sistema"
	arr["POLISH","wpa3_online_attack_7"]="Ten atak wymaga zainstalowania w systemie python3.1+"
	arr["GERMAN","wpa3_online_attack_7"]="Für diesen Angriff muss python3.1+ auf dem System installiert sein"
	arr["TURKISH","wpa3_online_attack_7"]="Bu saldırı için sisteminizde, python3.1+'ün kurulu olmasını gereklidir"
	arr["ARABIC","wpa3_online_attack_7"]="على النظام python3.1+ يتطلب هذا الهجوم تثبيت"
	arr["CHINESE","wpa3_online_attack_7"]="此攻击需要在您的系统上安装 python3.1+"

	arr["ENGLISH","wpa3_online_attack_8"]="The python3 script required as part of this plugin to run this attack is missing. Please make sure that the file \"\${normal_color}wpa3_dragon_drain_attack.py\${red_color}\" exists and that it is in the plugins dir next to the \"\${normal_color}wpa3_dragon_drain_attack.sh\${red_color}\" file"
	arr["SPANISH","wpa3_online_attack_8"]="El script de python3 requerido como parte de este plugin para ejecutar este ataque no se encuentra. Por favor, asegúrate de que existe el fichero \"\${normal_color}wpa3_dragon_drain_attack.py\${red_color}\" y que está en la carpeta de plugins junto al fichero \"\${normal_color}wpa3_dragon_drain_attack.sh\${red_color}\""
	arr["FRENCH","wpa3_online_attack_8"]="Le script de python3 requis dans cet plugin pour exécuter cette attaque est manquant. Assurez-vous que le fichier \"\${normal_color}wpa3_dragon_drain_attack.py\${red_color}\" existe et qu'il se trouve dans le dossier plugins à côté du fichier \"\${normal_color}wpa3_dragon_drain_attack.sh\${red_color}\""
	arr["CATALAN","wpa3_online_attack_8"]="El script de python3 requerit com a part d'aquest plugin per executar aquest atac no es troba. Assegureu-vos que existeix el fitxer \"\${normal_color}wpa3_dragon_drain_attack.py\${red_color}\" i que està a la carpeta de plugins al costat del fitxer \"\${normal_color}wpa3_dragon_drain_attack.sh\${red_color}\""
	arr["PORTUGUESE","wpa3_online_attack_8"]="O arquivo python para executar este ataque está ausente. Verifique se o arquivo \"\${normal_color}wpa3_dragon_drain_attack.py\${red_color}\" existe e se está na pasta de plugins com o arquivo \"\${normal_color}wpa3_dragon_drain_attack.sh\${red_color}\""
	arr["RUSSIAN","wpa3_online_attack_8"]="Скрипт, необходимый этому плагину для запуска этой атаки, отсутствует. Убедитесь, что файл \"\${normal_color}wpa3_dragon_drain_attack.py\${red_color}\" существует и находится в папке для плагинов рядом с файлом \"\${normal_color}wpa3_dragon_drain_attack.sh\${red_color}\"."
	arr["GREEK","wpa3_online_attack_8"]="Το python3 script που απαιτείται ως μέρος αυτής της προσθήκης για την εκτέλεση αυτής της επίθεσης λείπει. Βεβαιωθείτε ότι το αρχείο \"\${normal_color}wpa3_dragon_drain_attack.py\${red_color}\" υπάρχει και ότι βρίσκεται στον φάκελο plugins δίπλα στο αρχείο \"\${normal_color}wpa3_dragon_drain_attack.sh\${red_color}\""
	arr["ITALIAN","wpa3_online_attack_8"]="Lo script python3 richiesto come parte di questo plugin per eseguire questo attacco è assente. Assicurati che il file \"\${normal_color}wpa3_dragon_drain_attack.py\${red_color}\" esista e che sia nella cartella dei plugin assieme al file \"\${normal_color}wpa3_dragon_drain_attack.sh\${red_color}\""
	arr["POLISH","wpa3_online_attack_8"]="Do uruchomienia tego ataku brakuje skryptu python3 wymaganego jako część pluginu. Upewnij się, że plik \"\${normal_color}wpa3_dragon_drain_attack.py\${red_color}\" istnieje i znajduje się w folderze pluginów obok pliku \"\${normal_color}wpa3_dragon_drain_attack.sh\${red_color}\""
	arr["GERMAN","wpa3_online_attack_8"]="Das python3-Skript, das als Teil dieses Plugins erforderlich ist, um diesen Angriff auszuführen, fehlt. Bitte stellen Sie sicher, dass die Datei \"\${normal_color}wpa3_dragon_drain_attack.py\${red_color}\" vorhanden ist und dass sie sich im Plugin-Ordner neben der Datei \"\${normal_color}wpa3_dragon_drain_attack.sh\${red_color}\" befindet"
	arr["TURKISH","wpa3_online_attack_8"]="Bu saldırıyı çalıştırmak için bu eklentinin bir parçası olarak gereken python3 komutu dosyası eksik. Lütfen, eklentiler klasöründe \"\${normal_color}wpa3_dragon_drain_attack.sh\${red_color}\" dosyasının yanında, \"\${normal_color}wpa3_dragon_drain_attack.py\${red_color}\" dosyasının da var olduğundan emin olun"
	arr["ARABIC","wpa3_online_attack_8"]="\"\${normal_color}wpa3_dragon_drain_attack.sh\${red_color}\" موجود وأنه موجود في مجلد المكونات الإضافية بجوار الملف \"\${normal_color}wpa3_dragon_drain_attack.py\${red_color}\" المطلوب كجزء من هذا البرنامج المساعد لتشغيل هذا الهجوم مفقود. يرجى التأكد من أن الملف pyhton3 سكربت"
	arr["CHINESE","wpa3_online_attack_8"]="作为此插件的一部分运行此攻击所需的 python3 脚本丢失。请确保文件 \"\${normal_color}wpa3_dragon_drain_attack.py\${red_color}\" 存在，并且位于 \"\${normal_color}wpa3_dragon_drain_attack.sh\${red_color}\" 旁边的插件目录中 文件"

	arr["ENGLISH","wpa3_online_attack_9"]="To launch this attack, the card must be in \"Monitor\" mode. It has been detected that your card is in \"Managed\" mode, so airgeddon will automatically change it to be able to carry out the attack"
	arr["SPANISH","wpa3_online_attack_9"]="Para lanzar este ataque es necesario que la tarjeta esté en modo \"Monitor\". Se ha detectado que tu tarjeta está en modo \"Managed\", por lo que airgeddon la cambiará automáticamente para poder realizar el ataque"
	arr["FRENCH","wpa3_online_attack_9"]="Pour lancer cette attaque, la carte doit être en mode \"Monitor\". Il a été détecté que votre carte est en mode \"Managed\", donc airgeddon la changera automatiquement pour pouvoir mener l'attaque"
	arr["CATALAN","wpa3_online_attack_9"]="Per llançar aquest atac cal que la targeta estigui en mode \"Monitor\". S'ha detectat que la teva targeta està en mode \"Managed\", pel que airgeddon la canviarà automàticament per poder realitzar l'atac"
	arr["PORTUGUESE","wpa3_online_attack_9"]="Para iniciar este ataque, a interface deve estar no modo \"Monitor\". Foi detectado que sua interface está no modo \"Managed\", o airgeddon irá alterá-la automaticamente para poder prosseguir com o ataque"
	arr["RUSSIAN","wpa3_online_attack_9"]="Для запуска этой атаки сетевая карта должна находиться в режиме \"Monitor\". Ваша карта находится в режиме \"Managed\", airgeddon автоматически поменяет режим, чтобы иметь возможность провести атаку"
	arr["GREEK","wpa3_online_attack_9"]="Για να ξεκινήσει αυτή η επίθεση, η κάρτα πρέπει να βρίσκεται σε λειτουργία \"Monitor\". Έχει εντοπιστεί ότι η κάρτα σας βρίσκεται σε λειτουργία \"Managed\", επομένως το airgeddon θα την αλλάξει αυτόματα για να μπορέσει να πραγματοποιήσει την επίθεση"
	arr["ITALIAN","wpa3_online_attack_9"]="Per lanciare questo attacco, la scheda deve essere in modalità \"Monitor\". È stato rilevato che la tua scheda è in modalità \"Managed\", quindi airgeddon la cambierà automaticamente per poter eseguire l'attacco"
	arr["POLISH","wpa3_online_attack_9"]="Aby przeprowadzić ten atak, karta musi być w trybie \"Monitor\". Wykryto, że twoja karta jest w trybie \"Managed\", więc aby móc przeprowadzić atak, airgeddon automatycznie go zmieni"
	arr["GERMAN","wpa3_online_attack_9"]="Um diesen Angriff zu starten, muss sich die Karte im \"Monitor\"-Modus befinden. Es wurde festgestellt, dass Ihre Karte im \"Managed\"-Modus ist, also wird airgeddon sie automatisch ändern, um den Angriff ausführen zu können"
	arr["TURKISH","wpa3_online_attack_9"]="Bu saldırıyı başlatmak için kartın \"Monitor\" modunda olması gerekir. Kartınızın \"Managed\" modunda olduğu tespit edildi, bu nedenle airgeddon saldırıyı gerçekleştirebilmek için kartı otomatik olarak değiştirecektir."
	arr["ARABIC","wpa3_online_attack_9"]="لبدء هذا الهجوم، يجب أن تكون الشريحتك في وضع \"Monitor\". تم اكتشاف أن شريحتك في وضع \"Monitor\"، لذلك سيقوم airgeddon بتغييرها تلقائيًا لتتمكن من تنفيذ الهجوم"
	arr["CHINESE","wpa3_online_attack_9"]="要发起此攻击，该卡必须处于“监听”模式。检测到您的卡处于“管理”模式，因此 airgeddon 会自动更改它以能够进行攻击"

	arr["ENGLISH","wpa3_online_attack_10"]="An old version of aircrack has been detected. To handle WPA3 networks correctly, at least version \${aircrack_wpa3_version} is required. Otherwise, the attack cannot be performed. Please upgrade your aircrack package to a later version"
	arr["SPANISH","wpa3_online_attack_10"]="Se ha detectado una versión antigua de aircrack. Para manejar redes WPA3 correctamente se requiere como mínimo la versión \${aircrack_wpa3_version}. De lo contrario el ataque no se puede realizar. Actualiza tu paquete de aircrack a una versión posterior"
	arr["FRENCH","wpa3_online_attack_10"]="Une version ancienne d'aircrack a été détectée. Pour gérer correctement les réseaux WPA3, la version \${aircrack_wpa3_version} est requise au moins. Dans le cas contraire, l'attaque ne pourra pas être faire. Mettez à jour votre package d'aircrack à une version ultérieure"
	arr["CATALAN","wpa3_online_attack_10"]="S'ha detectat una versió antiga d'aircrack. Per manejar xarxes WPA3 es requereix com a mínim la versió \${aircrack_wpa3_version} Si no, l'atac no es pot fer. Actualitza el teu paquet d'aircrack a una versió posterior"
	arr["PORTUGUESE","wpa3_online_attack_10"]="Uma versão antiga do aircrack foi detectada. Para lidar corretamente com redes WPA3, é necessário pelo menos a versão \${aircrack_wpa3_version}. Caso contrário o ataque não poderá ser realizado. Atualize seu pacote aircrack para uma versão posterior"
	arr["RUSSIAN","wpa3_online_attack_10"]="Обнаружена старая версия aircrack. Для корректной работы с WPA3 сетями требуется как минимум версия \${aircrack_wpa3_version}. В противном случае атака не может быть осуществлена. Обновите пакет aircrack до более новой версии"
	arr["GREEK","wpa3_online_attack_10"]="Εντοπίστηκε μια παλιά έκδοση του aircrack. Για να χειριστείτε σωστά τα δίκτυα WPA3, απαιτείται τουλάχιστον η έκδοση \${aircrack_wpa3_version}. Διαφορετικά η επίθεση δεν μπορεί να πραγματοποιηθεί. Ενημερώστε το πακέτο aircrack σε νεότερη έκδοση"
	arr["ITALIAN","wpa3_online_attack_10"]="È stata rilevata una versione vecchia di aircrack. Per gestire correttamente le reti WPA3 è richiesta almeno la versione \${aircrack_wpa3_version}, altrimenti l'attacco non può essere eseguito. Aggiorna il tuo pacchetto aircrack ad una versione successiva"
	arr["POLISH","wpa3_online_attack_10"]="Wykryto starą wersję narzędzia aircrack. Aby poprawnie obsługiwać sieci WPA3, wymagana jest co najmniej wersja \${aircrack_wpa3_version}. Inaczej atak nie będzie możliwy. Zaktualizuj pakiet aircrack do nowszej wersji"
	arr["GERMAN","wpa3_online_attack_10"]="Es wurde eine alte Version von Aircrack entdeckt. Für den korrekten Umgang mit WPA3-Netzwerken ist mindestens die Version \${aircrack_wpa3_version} erforderlich. Andernfalls kann der Angriff nicht durchgeführt werden. Aktualisieren Sie Ihr Aircrack-Paket auf eine neuere Version"
	arr["TURKISH","wpa3_online_attack_10"]="aircrack'in eski bir sürümü tespit edildi. WPA3 ağlarını doğru şekilde yönetmek için en az \${aircrack_wpa3_version} sürümü gereklidir. Aksi takdirde saldırı gerçekleştirilemez. Aircrack paketinizi daha sonraki bir sürüme güncelleyin"
	arr["ARABIC","wpa3_online_attack_10"]="إلى إصدار أحدث aircrack بشكل صحيح. قم بتحديث WPA3 على الأقل, للتعامل مع شبكات ال \${aircrack_wpa3_version} يلزم توفر الإصدار .aircrack تم اكتشاف نسخة قديمة من"
	arr["CHINESE","wpa3_online_attack_10"]="当前aircrack的版本已过期。如果您需要处理 WPA3 加密类型的网络，至少需要版本 \${aircrack_wpa3_version}。否则将无法进行攻击。请尝试将您的aircrack包更新到最高版本"
}
