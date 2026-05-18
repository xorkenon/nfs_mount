#!/bin/bash

# ==============================================================================
# smart_nfs.sh v2.0
# Descripción: Enumerador, montador y limpiador automatizado de recursos NFS.
# Uso para montar:    ./smart_nfs.sh <IP> [puerto]
# Uso para desmontar: ./smart_nfs.sh -u | --unmount
# ==============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' 

print_info() { echo -e "${BLUE}[*]${NC} $1"; }
print_success() { echo -e "${GREEN}[+]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
print_error() { echo -e "${RED}[-]${NC} $1"; }

check_command() {
    if ! command -v "$1" &> /dev/null; then
        print_error "Falta el comando '$1'. Instala nfs-common."
        exit 1
    fi
}

unmount_all() {
    echo -e "\n${BLUE}[*] ========================================================${NC}"
    echo -e "${BLUE}[*] Iniciando Smart NFS Cleaner${NC}"
    echo -e "${BLUE}[*] ========================================================${NC}\n"

    print_info "Buscando recursos montados por la herramienta..."
    
    # Extraer solo los puntos de montaje activos que empiecen por /tmp/nfs_
    local active_mounts=$(mount | grep "/tmp/nfs_" | awk '{print $3}')
    
    if [ -z "$active_mounts" ]; then
        print_warning "No se detectaron recursos activos en /tmp/nfs_*"
        
        # Limpieza residual de carpetas vacías por si quedó basura
        local empty_dirs=$(ls -d /tmp/nfs_* 2>/dev/null)
        if [ -n "$empty_dirs" ]; then
            print_info "Borrando carpetas residuales vacías..."
            rmdir /tmp/nfs_* 2>/dev/null
        fi
        
        echo -e "\n${GREEN}[+] Entorno limpio.${NC}\n"
        return 0
    fi

    # Desmontar iterativamente
    for m in $active_mounts; do
        print_info "Desmontando: $m"
        sudo umount "$m" 2>/dev/null
        
        if [ $? -eq 0 ]; then
            print_success "Desmontado correctamente. Borrando carpeta..."
            rmdir "$m" 2>/dev/null
        else
            print_error "Fallo al desmontar $m. (Asegúrate de no tener ninguna terminal abierta dentro de esa ruta)."
        fi
    done

    echo -e "\n${BLUE}[*] ========================================================${NC}"
    echo -e "${BLUE}[+] Operación de limpieza completada.${NC}"
    echo -e "${BLUE}[*] ========================================================${NC}\n"
}

check_host() {
    local host=$1
    if ping -c 1 -W 3 "$host" &> /dev/null; then
        return 0
    else
        print_warning "El host $host no responde al ping (quizás bloquea ICMP), pero continuaremos..."
        return 0
    fi
}

get_nfs_exports() {
    local host=$1
    local port=$2
    local showmount_cmd="showmount -e $host"
    
    [ -n "$port" ] && showmount_cmd="showmount -e $host --port=$port"
    
    if exports_output=$(eval "$showmount_cmd" 2>/dev/null); then
        echo "$exports_output"
        return 0
    else
        print_error "No se pudieron obtener los recursos de $host."
        return 1
    fi
}

parse_exports() {
    local exports_output="$1"
    local -a export_paths=()
    
    while IFS= read -r line; do
        if [[ "$line" =~ ^/.*[[:space:]] ]]; then
            export_path=$(echo "$line" | awk '{print $1}')
            export_paths+=("$export_path")
        fi
    done <<< "$exports_output"
    
    echo "${export_paths[@]}"
}

mount_nfs() {
    local host=$1
    local export_path=$2
    local port=$3
    
    local safe_path_name=$(echo "$export_path" | tr '/' '_')
    local mount_point="/tmp/nfs_${host}${safe_path_name}"
    local nfs_server="$host"
    
    if [ -n "$port" ]; then
        mount_options="nolock,port=$port"
        mount_options_v3="vers=3,nolock,port=$port"
    else
        mount_options="nolock"
        mount_options_v3="vers=3,nolock"
    fi
    
    mkdir -p "$mount_point"
    
    if mountpoint -q "$mount_point"; then
        print_warning "El recurso ya está montado en $mount_point"
        return 0
    fi
    
    print_info "Montando $export_path en $mount_point..."
    
    if sudo mount -t nfs "$nfs_server:$export_path" "$mount_point" -o "$mount_options" 2>/dev/null; then
        print_success "Montaje estándar exitoso."
        echo -e "    ${CYAN}└─ Ruta: $mount_point${NC}"
        return 0
    elif sudo mount -t nfs -o "$mount_options_v3" "$nfs_server:$export_path" "$mount_point" 2>/dev/null; then
        print_success "Montaje NFSv3 exitoso."
        echo -e "    ${CYAN}└─ Ruta: $mount_point${NC}"
        return 0
    else
        print_error "Fallo al montar $export_path"
        rmdir "$mount_point" 2>/dev/null
        return 1
    fi
}

main() {
    # Manejar argumento de desmontaje
    if [[ "$1" == "-u" || "$1" == "--unmount" ]]; then
        unmount_all
        exit 0
    fi

    echo -e "\n${BLUE}[*] ========================================================${NC}"
    echo -e "${BLUE}[*] Iniciando Smart NFS Recon & Mounter${NC}"
    echo -e "${BLUE}[*] ========================================================${NC}\n"
    
    check_command "showmount"
    check_command "mount"
    
    if [ -z "$1" ]; then
        print_error "Faltan argumentos."
        echo -e "Para montar:   $0 <IP> [puerto]"
        echo -e "Para limpiar:  $0 --unmount\n"
        exit 1
    fi
    
    local host=$1
    local port=$2
    
    check_host "$host"
    
    print_info "Consultando exportaciones en $host..."
    local exports_output
    if ! exports_output=$(get_nfs_exports "$host" "$port"); then
        exit 1
    fi
    
    echo -e "\n${GREEN}[+] Recursos descubiertos:${NC}"
    echo "$exports_output" | awk '{print "    " $0}'
    echo ""
    
    local export_paths=($(parse_exports "$exports_output"))
    
    if [ ${#export_paths[@]} -eq 0 ]; then
        print_error "No hay rutas para montar."
        exit 1
    fi
    
    print_info "Iniciando montaje automático de todos los recursos descubiertos..."
    for path in "${export_paths[@]}"; do
        mount_nfs "$host" "$path" "$port"
    done
    
    echo -e "\n${BLUE}[*] ========================================================${NC}"
    echo -e "${BLUE}[+] Proceso finalizado. Puedes explorar los directorios en /tmp/nfs_*${NC}"
    echo -e "${YELLOW}[!] Para limpiar todo el entorno ejecuta: $0 --unmount${NC}"
    echo -e "${BLUE}[*] ========================================================${NC}\n"
}

main "$@"