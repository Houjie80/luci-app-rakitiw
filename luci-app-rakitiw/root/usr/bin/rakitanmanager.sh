#!/bin/bash
# Copyright 2024 RTA SERVER

log_file="/var/log/tes.log"
exec 1>>"$log_file" 2>&1
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

modem_status="Disabled"

# Baca file JSON
json_file="/www/rakitiw/data_modem.json"
jenis_modem=()
nama_modem=()
apn_modem=()
port_modem=()
interface_modem=()
iporbit_modem=()
usernameorbit_modem=()
passwordorbit_modem=()
hostbug_modem=()
devicemodem_modem=()
delayping_modem=()


send_telegram() { #$1 Token - $2 Chat ID - $3 Nama Modem - $4 New IP
    TOKEN="$1"
    CHAT_ID="$2"
    MESSAGE="====== RAKITAN MANAGER ======\nModem : $3\nNew IP : $4"
    MESSAGE=$(echo "$MESSAGE" | sed 's/"/\\"/g')
    curl_response=$(curl -s -X POST \
        "https://api.telegram.org/bot$TOKEN/sendMessage" \
        -d "chat_id=$CHAT_ID" \
        -d "text=$MESSAGE" \
        -H "Content-Type: application/json"
    )
    if [[ "$curl_response" == *"\"ok\":true"* ]]; then
        log "Pesan telah berhasil terkirim."
    else
        log "Gagal mengirim pesan. Periksa token bot dan ID grup Anda."
    fi
}


parse_json() {
    modems=$(jq -r '.modems | length' "$json_file")
    for ((i = 0; i < modems; i++)); do
        jenis_modem[$i]=$(jq -r ".modems[$i].jenis" "$json_file")
        nama_modem[$i]=$(jq -r ".modems[$i].nama" "$json_file")
        apn_modem[$i]=$(jq -r ".modems[$i].apn" "$json_file")
        port_modem[$i]=$(jq -r ".modems[$i].portmodem" "$json_file")
        interface_modem[$i]=$(jq -r ".modems[$i].interface" "$json_file")
        iporbit_modem[$i]=$(jq -r ".modems[$i].iporbit" "$json_file")
        usernameorbit_modem[$i]=$(jq -r ".modems[$i].usernameorbit" "$json_file")
        passwordorbit_modem[$i]=$(jq -r ".modems[$i].passwordorbit" "$json_file")
        hostbug_modem[$i]=$(jq -r ".modems[$i].hostbug" "$json_file")
        devicemodem_modem[$i]=$(jq -r ".modems[$i].devicemodem" "$json_file")
        delayping_modem[$i]=$(jq -r ".modems[$i].delayping" "$json_file")
    done
}

perform_ping() {
    nama="${1:-}"
    jenis="${2:-}"
    host="${3:-}"
    devicemodem="${4:-}"
    delayping="${5:-}"
    apn="${6:-}"
    portmodem="${7:-}"
    interface="${8:-}"
    iporbit="${9:-}"
    usernameorbit="${10:-}"
    passwordorbit="${11:-}"

    max_attempts=5
    attempt=1

    while true; do
        log_size=$(wc -c < "$log_file")
        max_size=$((2 * 2048))
        if [ "$log_size" -gt "$max_size" ]; then
            # Kosongkan isi file log
            echo -n "" > "$log_file"
            log "Log dibersihkan karena melebihi ukuran maksimum."
        fi

        status_Internet=false

        for pinghost in $host; do
            if [ "$devicemodem" = "" ]; then
                if [[ $(curl -si -m 5 $pinghost | grep -c 'Date:') == "1" ]]; then
                    log "[$jenis - $nama] $pinghost dapat dijangkau"
                    status_Internet=true
                    attempt=1
                else
                    log "[$jenis - $nama] $pinghost tidak dapat dijangkau"
                fi
            else
                if [[ $(curl -sI -m 5 --interface "$devicemodem" "$pinghost" | grep -c 'Date:') == "1" ]]; then
                    log "[$jenis - $nama] $pinghost dapat dijangkau Dengan Interface $devicemodem"
                    status_Internet=true
                    attempt=1
                else
                    log "[$jenis - $nama] $pinghost tidak dapat dijangkau Dengan Interface $devicemodem"
                fi
            fi
        done

        if [ "$status_Internet" = false ]; then
            if [ "$jenis" = "rakitan" ]; then
                log "[$jenis - $nama] Internet mati. Percobaan $attempt/$max_attempts"
                if [ "$attempt" = "1" ]; then
                    log "[$jenis - $nama] Mengaktifkan Mode Pesawat"
                    echo AT+CFUN=4 | atinout - "$portmodem" -
                    sleep 5
                elif [ "$attempt" = "2" ]; then
                    log "[$jenis - $nama] Mencoba Menghubungkan Kembali Modem Dengan APN : $apn"
                    modem_info=$(mmcli -L)
                    modem_number=$(echo "$modem_info" | awk -F 'Modem/' '{print $2}' | awk '{print $1}')
                    mmcli -m "$modem_number" --simple-connect="apn=$apn"
                    ifdown "$interface"
                    sleep 5
                    ifup "$interface"
                elif [ "$attempt" = "3" ]; then
                    log "[$jenis - $nama] Restart Modem Manager"
                    /etc/init.d/modemmanager restart
                    sleep 5
                elif [ "$attempt" = "4" ]; then
                    log "[$jenis - $nama] Mencoba Menghubungkan Kembali Modem Dengan APN : $apn"
                    modem_info=$(mmcli -L)
                    modem_number=$(echo "$modem_info" | awk -F 'Modem/' '{print $2}' | awk '{print $1}')
                    mmcli -m "$modem_number" --simple-connect="apn=$apn"
                    ifdown "$interface"
                    sleep 5
                    ifup "$interface"
                fi
                attempt=$((attempt + 1))
                
                if [ $attempt -ge $max_attempts ]; then
                    log "[$jenis - $nama] Upaya maksimal tercapai. Internet masih mati. Restart modem akan dijalankan"
                    echo AT^RESET | atinout - "$portmodem" - && sleep 20 && ifdown "$interface" && ifup "$interface"
                    attempt=1
                fi
                log "[$jenis - $nama] New IP: $(ip address | awk '/$devicemodem/ {print $2}' | sed "s/$devicemodem://")"
            elif [ "$jenis" = "hp" ]; then
                log "[$jenis - $nama] Mencoba Menghubungkan Kembali"
                log "[$jenis - $nama] Mengaktifkan Mode Pesawat"
                adb shell cmd connectivity airplane-mode enable
                sleep 2
                log "[$jenis - $nama] Menonaktifkan Mode Pesawat"
                adb shell cmd connectivity airplane-mode disable
                sleep 7
                new_ip_hp=$(adb shell ip addr show rmnet_data0 | grep 'inet ' | awk '{print $2}' | cut -d / -f 1)
                Log "[$jenis - $nama] New IP = $new_ip_hp"
            elif [ "$jenis" = "orbit" ]; then
                log "[$jenis - $nama] Mencoba Menghubungkan Kembali Modem Orbit / Huawei"
                python3 /usr/bin/modem-orbit.py $iporbit $usernameorbit $passwordorbit
                log "[$jenis - $nama] New IP $(cat /tmp/ip_orbit.txt)"
            fi
        fi
        sleep "$delayping"
    done
}

main() {
    parse_json

    # Loop through each modem and perform actions
    for ((i = 0; i < ${#jenis_modem[@]}; i++)); do
        perform_ping "${nama_modem[$i]}" "${jenis_modem[$i]}" "${hostbug_modem[$i]}" "${devicemodem_modem[$i]}" "${delayping_modem[$i]}" "${apn_modem[$i]}" "${port_modem[$i]}" "${interface_modem[$i]}" "${iporbit_modem[$i]}" "${usernameorbit_modem[$i]}" "${passwordorbit_modem[$i]}" &
    done
}

rakitiw_stop() {
    # Hentikan skrip jika sedang berjalan
    if pidof rakitanmanager.sh > /dev/null; then
        modem_status="Disabled"
        killall -9 rakitanmanager.sh
        log "Rakitiw Berhasil Di Hentikan."
    else
        log "Rakitiw is not running."
    fi
}

while getopts ":skrpcvh" rakitiw ; do
    case $rakitiw in
        s)
            main
            ;;
        k)
            rakitiw_stop
            ;;
    esac
done
